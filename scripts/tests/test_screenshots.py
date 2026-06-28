import io
import zipfile
from pathlib import Path

import httpx
import pytest

from scripts.xcode_cloud.client import XcodeCloudClient, XcodeCloudError
from scripts.xcode_cloud.screenshots import (
    fetch_test_result_bundle,
    find_test_action,
    find_test_result_artifact,
)


def test_find_test_action(load_fixture):
    actions = load_fixture("build_actions.json")["data"]
    action = find_test_action(actions)
    assert action["id"] == "action-test-1"


def test_find_test_result_artifact(load_fixture):
    artifacts = load_fixture("artifacts_list.json")["data"]
    artifact = find_test_result_artifact(artifacts)
    assert artifact["id"] == "artifact-test-1"


def test_find_test_action_raises_when_missing():
    with pytest.raises(XcodeCloudError, match="No TEST build action"):
        find_test_action([])


def test_fetch_test_result_bundle_downloads_zip(tmp_path, load_fixture):
    actions_fixture = load_fixture("build_actions.json")
    artifacts_fixture = load_fixture("artifacts_list.json")
    artifact_fixture = load_fixture("artifact_detail.json")

    zip_buffer = io.BytesIO()
    with zipfile.ZipFile(zip_buffer, "w") as archive:
        archive.writestr("Test.xcresult/Info.plist", "plist")
    zip_bytes = zip_buffer.getvalue()

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/actions"):
            return httpx.Response(200, json=actions_fixture)
        if request.url.path.endswith("/artifacts") and "ciBuildActions" in request.url.path:
            return httpx.Response(200, json=artifacts_fixture)
        if request.url.path.endswith("/ciArtifacts/artifact-test-1"):
            return httpx.Response(200, json=artifact_fixture)
        if request.url.host == "example.com":
            return httpx.Response(200, content=zip_bytes)
        raise AssertionError(f"Unexpected request: {request.url}")

    api_client = httpx.Client(transport=httpx.MockTransport(handler))
    download_client = httpx.Client(transport=httpx.MockTransport(handler))
    api = XcodeCloudClient(lambda: "token", client=api_client)

    _, artifact_id, bundle_path = fetch_test_result_bundle(
        api,
        "build-run-123",
        tmp_path,
        download_client=download_client,
    )

    assert artifact_id == "artifact-test-1"
    assert bundle_path.suffix == ".xcresult"
    assert bundle_path.exists()
