from pathlib import Path
from unittest.mock import patch

import pytest

from scripts.xcode_cloud.extract import (
    XcresultToolNotFoundError,
    extract_attachments,
)


def test_extract_attachments_runs_xcresulttool(tmp_path):
    bundle_path = tmp_path / "Test.xcresult"
    bundle_path.mkdir()
    output_dir = tmp_path / "out"
    screenshot = output_dir / "shot.png"

    def fake_run(command, check, capture_output, text):
        assert command[0] == "/usr/bin/xcresulttool"
        assert command[1:4] == ["export", "attachments", "--path"]
        output_dir.mkdir(parents=True, exist_ok=True)
        screenshot.write_bytes(b"png")
        return None

    with patch("scripts.xcode_cloud.extract.xcresulttool_path", return_value="/usr/bin/xcresulttool"):
        with patch("scripts.xcode_cloud.extract.subprocess.run", side_effect=fake_run):
            paths = extract_attachments(bundle_path, output_dir)

    assert paths == [screenshot]


def test_extract_attachments_requires_xcresulttool(tmp_path):
    bundle_path = tmp_path / "Test.xcresult"
    bundle_path.mkdir()

    with patch("scripts.xcode_cloud.extract.xcresulttool_path", return_value=None):
        with pytest.raises(XcresultToolNotFoundError):
            extract_attachments(bundle_path, tmp_path / "out")
