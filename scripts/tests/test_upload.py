import pytest

from scripts.xcode_cloud.upload import (
    UploadConfigError,
    UploadedScreenshot,
    object_key,
    public_url_for_key,
    upload_config_from_env,
    write_manifest,
)


def test_object_key_includes_build_id_and_filename():
    assert object_key("bedtime", "run-1", "home.png") == "bedtime/run-1/home.png"


def test_public_url_for_key():
    url = public_url_for_key("https://cdn.example.com/shots", "bedtime/run-1/home.png")
    assert url == "https://cdn.example.com/shots/bedtime/run-1/home.png"


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


def test_write_manifest(tmp_path):
    uploads = [
        UploadedScreenshot(
            name="home.png",
            key="bedtime/run-1/home.png",
            url="https://cdn.example.com/bedtime/run-1/home.png",
        )
    ]
    manifest_path = tmp_path / "manifest.json"
    write_manifest(manifest_path, "run-1", uploads)

    payload = manifest_path.read_text()
    assert "home.png" in payload
    assert "https://cdn.example.com/bedtime/run-1/home.png" in payload
