from pathlib import Path

from scripts.xcode_cloud.github_pr import build_screenshot_comment
from scripts.xcode_cloud.upload import UploadedScreenshot


def test_build_screenshot_comment_lists_files_without_upload(tmp_path):
    shots = [tmp_path / "home.png", tmp_path / "settings.png"]
    body = build_screenshot_comment(shots, build_run_id="run-1")

    assert "run-1" in body
    assert "home.png" in body
    assert "public bucket" in body.lower()


def test_build_screenshot_comment_embeds_uploaded_images():
    uploaded = [
        UploadedScreenshot(
            name="home.png",
            key="bedtime/run-1/home.png",
            url="https://cdn.example.com/bedtime/run-1/home.png",
        )
    ]
    body = build_screenshot_comment([], build_run_id="run-1", uploaded=uploaded)

    assert "![home.png](https://cdn.example.com/bedtime/run-1/home.png)" in body


def test_build_screenshot_comment_handles_empty_list():
    body = build_screenshot_comment([], build_run_id="run-1")
    assert "no screenshot attachments" in body.lower()
