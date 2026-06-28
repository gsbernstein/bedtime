from pathlib import Path

from scripts.xcode_cloud.github_pr import build_screenshot_comment


def test_build_screenshot_comment_lists_files(tmp_path):
    shots = [tmp_path / "home.png", tmp_path / "settings.png"]
    body = build_screenshot_comment(shots, build_run_id="run-1")

    assert "run-1" in body
    assert "home.png" in body
    assert "settings.png" in body


def test_build_screenshot_comment_handles_empty_list():
    body = build_screenshot_comment([], build_run_id="run-1")
    assert "no screenshot attachments" in body.lower()
