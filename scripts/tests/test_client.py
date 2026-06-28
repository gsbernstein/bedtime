import json

import httpx

from scripts.xcode_cloud.client import XcodeCloudClient


def test_get_build_run_status(load_fixture):
    fixture = load_fixture("build_run_complete.json")

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path.endswith("/v1/ciBuildRuns/build-run-123")
        return httpx.Response(200, json=fixture)

    client = httpx.Client(transport=httpx.MockTransport(handler))
    api = XcodeCloudClient(lambda: "token", client=client)

    status = api.get_build_run_status("build-run-123")

    assert status.execution_progress == "COMPLETE"
    assert status.completion_status == "SUCCEEDED"


def test_list_build_actions(load_fixture):
    fixture = load_fixture("build_actions.json")

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path.endswith("/v1/ciBuildRuns/build-run-123/actions")
        return httpx.Response(200, json=fixture)

    client = httpx.Client(transport=httpx.MockTransport(handler))
    api = XcodeCloudClient(lambda: "token", client=client)

    actions = api.list_build_actions("build-run-123")

    assert len(actions) == 2
    assert actions[1]["attributes"]["actionType"] == "TEST"
