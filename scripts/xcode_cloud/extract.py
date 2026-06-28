"""Extract screenshot attachments from an .xcresult bundle."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path


class XcresultToolNotFoundError(RuntimeError):
    """Raised when xcresulttool is unavailable on the current machine."""


def xcresulttool_path() -> str | None:
    return shutil.which("xcresulttool")


def extract_attachments(
    bundle_path: Path,
    output_dir: Path,
    *,
    only_failures: bool = False,
) -> list[Path]:
    """Export XCTest attachments from a result bundle using xcresulttool."""
    if not bundle_path.exists():
        raise FileNotFoundError(f"Result bundle not found: {bundle_path}")

    tool = xcresulttool_path()
    if tool is None:
        raise XcresultToolNotFoundError(
            "xcresulttool was not found. Run this step on macOS with Xcode installed, "
            "or use ci_scripts/ci_post_xcodebuild.sh inside Xcode Cloud."
        )

    output_dir.mkdir(parents=True, exist_ok=True)
    command = [
        tool,
        "export",
        "attachments",
        "--path",
        str(bundle_path),
        "--output-path",
        str(output_dir),
    ]
    if only_failures:
        command.append("--only-failures")

    subprocess.run(command, check=True, capture_output=True, text=True)
    return sorted(path for path in output_dir.rglob("*.png") if path.is_file())
