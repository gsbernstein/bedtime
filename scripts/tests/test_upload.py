from pathlib import Path

import httpx
import pytest

from scripts.xcode_cloud.upload import (
    UploadConfigError,
    UploadedScreenshot,
    object_key,
    public_url_for_key,
    upload_backend_from_env,
    upload_config_from_env,
    upload_to_imgur,
    write_manifest,
)


def test_object_key_includes_build_id_and_filename():
    assert object_key("bedtime", "run-1", "home.png") == "bedtime/run-1/home.png"


def test_public_url_for_key():
    url = public_url_for_key("https://cdn.example.com/shots", "bedtime/run-1/home.png")
    assert url == "https://cdn.example.com/shots/bedtime/run-1/home.png"


def test_upload_backend_prefers_imgur(monkeypatch):
    monkeypatch.setenv("IMGUR_CLIENT_ID", "imgur-id")
    monkeypatch.setenv("SCREENSHOTS_S3_BUCKET", "my-bucket")
    assert upload_backend_from_env() == "imgur"


def test_upload_backend_uses_s3_when_configured(monkeypatch):
    monkeypatch.delenv("IMGUR_CLIENT_ID", raising=False)
    monkeypatch.setenv("SCREENSHOTS_S3_BUCKET", "my-bucket")
    assert upload_backend_from_env() == "s3"


def test_upload_backend_requires_configuration(monkeypatch):
    monkeypatch.delenv("IMGUR_CLIENT_ID", raising=False)
    monkeypatch.delenv("SCREENSHOTS_S3_BUCKET", raising=False)
    with pytest.raises(UploadConfigError, match="No upload backend"):
        upload_backend_from_env()


def test_upload_config_from_env(monkeypatch):
    monkeypatch.setenv("SCREENSHOTS_S3_BUCKET", "my-bucket")
    monkeypatch.setenv("SCREENSHOTS_S3_PREFIX", "bedtime")
    monkeypatch.setenv("SCREENSHOTS_PUBLIC_BASE_URL", "https://cdn.example.com")

    config = upload_config_from_env()

    assert config["bucket"] == "my-bucket"
    assert config["prefix"] == "bedtime"
    assert config["public_base_url"] == "https://cdn.example.com"


def test_upload_config_requires_bucket(monkeypatch):
    monkeypatch.delenv("SCREENSHOTS_S3_BUCKET", raising=False)
    with pytest.raises(UploadConfigError, match="SCREENSHOTS_S3_BUCKET"):
        upload_config_from_env()


def test_upload_to_imgur(tmp_path):
    image = tmp_path / "home.png"
    image.write_bytes(b"fakepng")

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.host == "api.imgur.com"
        assert request.headers["Authorization"] == "Client-ID test-client"
        return httpx.Response(
            200,
            json={
                "success": True,
                "data": {
                    "id": "abc123",
                    "link": "https://i.imgur.com/abc123.png",
                },
            },
        )

    client = httpx.Client(transport=httpx.MockTransport(handler))
    uploaded = upload_to_imgur(image, client_id="test-client", http_client=client)

    assert uploaded.url == "https://i.imgur.com/abc123.png"
    assert uploaded.key == "abc123"


def test_write_manifest(tmp_path):
    uploads = [
        UploadedScreenshot(
            name="home.png",
            key="abc123",
            url="https://i.imgur.com/abc123.png",
        )
    ]
    manifest_path = tmp_path / "manifest.json"
    write_manifest(manifest_path, "run-1", uploads)

    payload = manifest_path.read_text()
    assert "home.png" in payload
    assert "https://i.imgur.com/abc123.png" in payload
