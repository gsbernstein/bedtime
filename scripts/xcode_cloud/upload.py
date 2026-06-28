"""Upload extracted screenshots to a public image host."""

from __future__ import annotations

import base64
import json
import mimetypes
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

import httpx

UploadBackend = Literal["auto", "imgur", "s3"]


class UploadConfigError(ValueError):
    """Raised when required upload configuration is missing."""


@dataclass(frozen=True)
class UploadedScreenshot:
    name: str
    key: str
    url: str


def upload_backend_from_env() -> UploadBackend:
    explicit = os.environ.get("SCREENSHOTS_UPLOAD_BACKEND", "auto").strip().lower()
    if explicit in {"imgur", "s3"}:
        return explicit  # type: ignore[return-value]
    if explicit != "auto":
        raise UploadConfigError(
            "SCREENSHOTS_UPLOAD_BACKEND must be one of: auto, imgur, s3"
        )
    if os.environ.get("IMGUR_CLIENT_ID", "").strip():
        return "imgur"
    if os.environ.get("SCREENSHOTS_S3_BUCKET", "").strip():
        return "s3"
    raise UploadConfigError(
        "No upload backend configured. Set IMGUR_CLIENT_ID (simplest) or "
        "SCREENSHOTS_S3_BUCKET."
    )


def upload_config_from_env() -> dict[str, str]:
    bucket = os.environ.get("SCREENSHOTS_S3_BUCKET", "").strip()
    if not bucket:
        raise UploadConfigError("SCREENSHOTS_S3_BUCKET is required for S3 upload")

    public_base_url = os.environ.get("SCREENSHOTS_PUBLIC_BASE_URL", "").strip()
    if not public_base_url:
        region = os.environ.get("SCREENSHOTS_S3_REGION", "us-east-1").strip()
        public_base_url = f"https://{bucket}.s3.{region}.amazonaws.com"

    return {
        "bucket": bucket,
        "prefix": os.environ.get("SCREENSHOTS_S3_PREFIX", "xcode-cloud-screenshots").strip("/"),
        "public_base_url": public_base_url.rstrip("/"),
        "region": os.environ.get("SCREENSHOTS_S3_REGION", "us-east-1").strip(),
        "endpoint_url": os.environ.get("SCREENSHOTS_S3_ENDPOINT_URL", "").strip() or None,
    }


def object_key(prefix: str, build_id: str, filename: str) -> str:
    safe_name = Path(filename).name
    return "/".join(part for part in (prefix, build_id, safe_name) if part)


def public_url_for_key(public_base_url: str, key: str) -> str:
    return f"{public_base_url}/{key.lstrip('/')}"


def _s3_client(region: str, endpoint_url: str | None):
    try:
        import boto3
    except ImportError as error:
        raise RuntimeError(
            "boto3 is required for S3 upload. Install with: python3 -m pip install boto3"
        ) from error

    return boto3.client("s3", region_name=region, endpoint_url=endpoint_url)


def upload_to_imgur(
    screenshot: Path,
    *,
    client_id: str,
    http_client: httpx.Client | None = None,
) -> UploadedScreenshot:
    """Upload one image anonymously to Imgur using only a Client-ID."""
    http = http_client or httpx.Client(timeout=60.0)
    close_client = http_client is None
    try:
        response = http.post(
            "https://api.imgur.com/3/image",
            headers={"Authorization": f"Client-ID {client_id}"},
            data={"image": base64.b64encode(screenshot.read_bytes()).decode("ascii")},
        )
        response.raise_for_status()
        payload = response.json()
        if not payload.get("success"):
            raise RuntimeError(f"Imgur upload failed: {payload}")
        data = payload["data"]
        return UploadedScreenshot(
            name=screenshot.name,
            key=data.get("id", screenshot.name),
            url=data["link"],
        )
    finally:
        if close_client:
            http.close()


def upload_to_s3(
    screenshot: Path,
    *,
    build_id: str,
    bucket: str,
    prefix: str,
    public_base_url: str,
    region: str = "us-east-1",
    endpoint_url: str | None = None,
) -> UploadedScreenshot:
    key = object_key(prefix, build_id, screenshot.name)
    content_type = mimetypes.guess_type(screenshot.name)[0] or "image/png"
    extra_args = {
        "ContentType": content_type,
        "CacheControl": "public, max-age=31536000, immutable",
    }
    if os.environ.get("SCREENSHOTS_S3_USE_ACL", "false").lower() == "true":
        extra_args["ACL"] = "public-read"

    client = _s3_client(region, endpoint_url)
    client.upload_file(str(screenshot), bucket, key, ExtraArgs=extra_args)
    return UploadedScreenshot(
        name=screenshot.name,
        key=key,
        url=public_url_for_key(public_base_url, key),
    )


def upload_screenshots(
    screenshots_dir: Path,
    *,
    build_id: str,
    backend: UploadBackend = "auto",
    http_client: httpx.Client | None = None,
) -> list[UploadedScreenshot]:
    """Upload PNG screenshots and return stable public URLs."""
    screenshots = sorted(path for path in screenshots_dir.rglob("*.png") if path.is_file())
    if not screenshots:
        return []

    resolved_backend = backend if backend != "auto" else upload_backend_from_env()
    uploads: list[UploadedScreenshot] = []

    if resolved_backend == "imgur":
        client_id = os.environ.get("IMGUR_CLIENT_ID", "").strip()
        if not client_id:
            raise UploadConfigError("IMGUR_CLIENT_ID is required for Imgur upload")
        for screenshot in screenshots:
            uploads.append(
                upload_to_imgur(screenshot, client_id=client_id, http_client=http_client)
            )
        return uploads

    if resolved_backend == "s3":
        config = upload_config_from_env()
        for screenshot in screenshots:
            uploads.append(
                upload_to_s3(
                    screenshot,
                    build_id=build_id,
                    bucket=config["bucket"],
                    prefix=config["prefix"],
                    public_base_url=config["public_base_url"],
                    region=config["region"],
                    endpoint_url=config["endpoint_url"],
                )
            )
        return uploads

    raise UploadConfigError(f"Unsupported upload backend: {resolved_backend}")


def write_manifest(path: Path, build_id: str, uploads: list[UploadedScreenshot]) -> None:
    payload = {
        "build_id": build_id,
        "screenshots": [
            {"name": item.name, "key": item.key, "url": item.url}
            for item in uploads
        ],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2))
