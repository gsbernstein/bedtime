"""Upload extracted screenshots to a public S3-compatible bucket."""

from __future__ import annotations

import json
import mimetypes
import os
from dataclasses import dataclass
from pathlib import Path


class UploadConfigError(ValueError):
    """Raised when required upload configuration is missing."""


@dataclass(frozen=True)
class UploadedScreenshot:
    name: str
    key: str
    url: str


def upload_config_from_env() -> dict[str, str]:
    bucket = os.environ.get("SCREENSHOTS_S3_BUCKET", "").strip()
    if not bucket:
        raise UploadConfigError("SCREENSHOTS_S3_BUCKET is required for upload")

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


def upload_screenshots(
    screenshots_dir: Path,
    *,
    build_id: str,
    bucket: str,
    prefix: str,
    public_base_url: str,
    region: str = "us-east-1",
    endpoint_url: str | None = None,
) -> list[UploadedScreenshot]:
    """Upload PNG screenshots and return stable public URLs."""
    screenshots = sorted(path for path in screenshots_dir.rglob("*.png") if path.is_file())
    if not screenshots:
        return []

    client = _s3_client(region, endpoint_url)
    uploads: list[UploadedScreenshot] = []

    for screenshot in screenshots:
        key = object_key(prefix, build_id, screenshot.name)
        content_type = mimetypes.guess_type(screenshot.name)[0] or "image/png"
        extra_args = {
            "ContentType": content_type,
            "CacheControl": "public, max-age=31536000, immutable",
        }
        if os.environ.get("SCREENSHOTS_S3_USE_ACL", "false").lower() == "true":
            extra_args["ACL"] = "public-read"

        client.upload_file(
            str(screenshot),
            bucket,
            key,
            ExtraArgs=extra_args,
        )
        uploads.append(
            UploadedScreenshot(
                name=screenshot.name,
                key=key,
                url=public_url_for_key(public_base_url, key),
            )
        )

    return uploads


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
