"""Extract screenshot attachments and failure summaries from an .xcresult bundle."""

from __future__ import annotations

import json
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


def extract_test_failure_summaries(
    bundle_path: Path,
    *,
    limit: int = 20,
) -> list[str]:
    """Return human-readable failing test summaries when xcresulttool is available."""
    if not bundle_path.exists():
        return []

    tool = xcresulttool_path()
    if tool is None:
        return []

    command = [
        tool,
        "get",
        "test-results",
        "tests",
        "--path",
        str(bundle_path),
        "--format",
        "json",
    ]
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode != 0 or not result.stdout.strip():
        return _summarize_test_failures_legacy(tool, bundle_path, limit=limit)

    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        return _summarize_test_failures_legacy(tool, bundle_path, limit=limit)

    failures: list[str] = []
    tests = payload.get("tests", payload)
    if isinstance(tests, list):
        for item in tests:
            if not isinstance(item, dict):
                continue
            status = str(item.get("testStatus", item.get("status", ""))).upper()
            if status not in {"FAILURE", "FAILED"}:
                continue
            name = item.get("name") or item.get("identifier", "unknown test")
            message = item.get("failureMessage") or item.get("message")
            if message:
                failures.append(f"{name}: {message}")
            else:
                failures.append(str(name))
            if len(failures) >= limit:
                break
    return failures


def _summarize_test_failures_legacy(
    tool: str,
    bundle_path: Path,
    *,
    limit: int,
) -> list[str]:
    command = [
        tool,
        "get",
        "test-results",
        "summary",
        "--path",
        str(bundle_path),
        "--format",
        "json",
    ]
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode != 0 or not result.stdout.strip():
        return []

    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        return []

    failed_count = payload.get("failedTests", payload.get("totalFailureCount"))
    if failed_count:
        return [f"{failed_count} test(s) failed"]
    return []
