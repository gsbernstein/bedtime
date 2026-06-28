"""Download Xcode Cloud test result bundles and extract screenshots."""

from __future__ import annotations

import shutil
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import httpx

from scripts.xcode_cloud.client import XcodeCloudClient, XcodeCloudError
from scripts.xcode_cloud.extract import extract_attachments


TEST_ACTION_TYPES = {"TEST"}
TEST_RESULT_FILE_TYPES = {"TEST_RESULT_BUNDLE", "XCRESULT"}


@dataclass(frozen=True)
class ScreenshotFetchResult:
    build_run_id: str
    test_action_id: str
    artifact_id: str
    bundle_path: Path
    screenshot_paths: tuple[Path, ...]


def find_test_action(actions: Iterable[dict]) -> dict:
    for action in actions:
        action_type = action.get("attributes", {}).get("actionType")
        if action_type in TEST_ACTION_TYPES:
            return action
    raise XcodeCloudError("No TEST build action found for this build run")


def find_test_result_artifact(artifacts: Iterable[dict]) -> dict:
    for artifact in artifacts:
        file_type = artifact.get("attributes", {}).get("fileType")
        if file_type in TEST_RESULT_FILE_TYPES:
            return artifact
    raise XcodeCloudError("No test result bundle artifact found for the TEST action")


def _download_file(url: str, destination: Path, *, client: httpx.Client | None = None) -> None:
    http = client or httpx.Client(timeout=120.0, follow_redirects=True)
    close_client = client is None
    try:
        with http.stream("GET", url) as response:
            response.raise_for_status()
            destination.parent.mkdir(parents=True, exist_ok=True)
            with destination.open("wb") as handle:
                for chunk in response.iter_bytes():
                    handle.write(chunk)
    finally:
        if close_client:
            http.close()


def _prepare_xcresult_bundle(download_path: Path, output_dir: Path) -> Path:
    if download_path.suffix == ".xcresult" and download_path.is_dir():
        return download_path

    if download_path.suffix == ".zip" or zipfile.is_zipfile(download_path):
        extract_dir = output_dir / "extracted"
        extract_dir.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(download_path) as archive:
            archive.extractall(extract_dir)
        candidates = list(extract_dir.rglob("*.xcresult"))
        if not candidates:
            raise XcodeCloudError(f"No .xcresult bundle found inside {download_path}")
        return candidates[0]

    if download_path.name.endswith(".xcresult"):
        if download_path.is_dir():
            return download_path
        bundle_dir = output_dir / download_path.name
        if bundle_dir.exists():
            shutil.rmtree(bundle_dir)
        shutil.move(str(download_path), str(bundle_dir))
        return bundle_dir

    raise XcodeCloudError(f"Unsupported test result artifact format: {download_path}")


def fetch_test_result_bundle(
    client: XcodeCloudClient,
    build_run_id: str,
    output_dir: Path,
    *,
    download_client: httpx.Client | None = None,
) -> tuple[str, str, Path]:
    """Download the Xcode Cloud test result bundle for a completed build run."""
    actions = client.list_build_actions(build_run_id)
    test_action = find_test_action(actions)
    test_action_id = test_action["id"]

    artifacts = client.list_artifacts(test_action_id)
    artifact = find_test_result_artifact(artifacts)
    artifact_id = artifact["id"]

    artifact_payload = client.get_artifact(artifact_id)
    download_url = artifact_payload["data"]["attributes"]["downloadUrl"]
    file_name = artifact_payload["data"]["attributes"].get("fileName", f"{artifact_id}.zip")

    download_path = output_dir / file_name
    _download_file(download_url, download_path, client=download_client)
    bundle_path = _prepare_xcresult_bundle(download_path, output_dir)
    return test_action_id, artifact_id, bundle_path


def fetch_screenshots_from_build_run(
    client: XcodeCloudClient,
    build_run_id: str,
    output_dir: Path,
    *,
    only_failures: bool = False,
    download_client: httpx.Client | None = None,
) -> ScreenshotFetchResult:
    """Fetch a build run's test bundle and extract screenshot attachments."""
    screenshots_dir = output_dir / "screenshots"
    test_action_id, artifact_id, bundle_path = fetch_test_result_bundle(
        client,
        build_run_id,
        output_dir,
        download_client=download_client,
    )
    screenshot_paths = extract_attachments(
        bundle_path,
        screenshots_dir,
        only_failures=only_failures,
    )
    return ScreenshotFetchResult(
        build_run_id=build_run_id,
        test_action_id=test_action_id,
        artifact_id=artifact_id,
        bundle_path=bundle_path,
        screenshot_paths=tuple(screenshot_paths),
    )


def extract_screenshots_from_local_bundle(
    bundle_path: Path,
    output_dir: Path,
    *,
    only_failures: bool = False,
) -> tuple[Path, ...]:
    """Extract screenshots from a local .xcresult bundle (Xcode Cloud Mac path)."""
    screenshots_dir = output_dir / "screenshots"
    return tuple(
        extract_attachments(
            bundle_path,
            screenshots_dir,
            only_failures=only_failures,
        )
    )
