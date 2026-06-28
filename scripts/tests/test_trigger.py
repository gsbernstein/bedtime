import httpx

from scripts.xcode_cloud.client import XcodeCloudClient
from scripts.xcode_cloud.trigger import (
    git_reference_id_for_branch,
    repository_id_for_workflow,
    trigger_and_wait,
    trigger_build_run,
)


def test_trigger_build_run_returns_run_id():
    create_response = {"data": {"type": "ciBuildRuns", "id": "new-run-1"}}

    def handler(request: httpx.Request) -> httpx.Response:
        if request.method == "POST" and request.url.path.endswith("/v1/ciBuildRuns"):
            return httpx.Response(201, json=create_response)
        raise AssertionError(f"Unexpected request: {request.method} {request.url}")

    client = httpx.Client(transport=httpx.MockTransport(handler))
    api = XcodeCloudClient(lambda: "token", client=client)

    run_id = trigger_build_run(
        api,
        "workflow-1",
        git_reference_id="git-ref-1",
    )

    assert run_id == "new-run-1"


def test_git_reference_id_for_branch():
    references = {
        "data": [
            {
                "id": "git-ref-main",
                "attributes": {
                    "kind": "BRANCH",
                    "name": "main",
                    "canonicalName": "refs/heads/main",
                },
            }
        ]
    }

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/gitReferences"):
            return httpx.Response(200, json=references)
        raise AssertionError(f"Unexpected request: {request.url}")

    client = httpx.Client(transport=httpx.MockTransport(handler))
    api = XcodeCloudClient(lambda: "token", client=client)

    ref_id = git_reference_id_for_branch(api, "repo-1", "main")
    assert ref_id == "git-ref-main"


def test_repository_id_for_workflow_from_included():
    workflow = {
        "data": {
            "id": "workflow-1",
            "type": "ciWorkflows",
            "relationships": {},
        },
        "included": [
            {"id": "repo-1", "type": "scmRepositories"},
        ],
    }

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/ciWorkflows/workflow-1"):
            return httpx.Response(200, json=workflow)
        raise AssertionError(f"Unexpected request: {request.url}")

    client = httpx.Client(transport=httpx.MockTransport(handler))
    api = XcodeCloudClient(lambda: "token", client=client)

    repo_id = repository_id_for_workflow(api, "workflow-1")
    assert repo_id == "repo-1"


def test_trigger_and_wait_polls_until_complete(monkeypatch):
    calls = {"count": 0}
    pending = {
        "data": {
            "id": "run-1",
            "attributes": {"executionProgress": "RUNNING", "completionStatus": None},
        }
    }
    complete = {
        "data": {
            "id": "run-1",
            "attributes": {"executionProgress": "COMPLETE", "completionStatus": "SUCCEEDED"},
        }
    }
    create_response = {"data": {"type": "ciBuildRuns", "id": "run-1"}}

    def handler(request: httpx.Request) -> httpx.Response:
        if request.method == "POST" and request.url.path.endswith("/v1/ciBuildRuns"):
            return httpx.Response(201, json=create_response)
        if request.url.path.endswith("/ciBuildRuns/run-1"):
            calls["count"] += 1
            return httpx.Response(200, json=complete if calls["count"] > 1 else pending)
        raise AssertionError(f"Unexpected request: {request.method} {request.url}")

    monkeypatch.setattr("scripts.xcode_cloud.client.time.sleep", lambda _: None)

    client = httpx.Client(transport=httpx.MockTransport(handler))
    api = XcodeCloudClient(lambda: "token", client=client)

    result = trigger_and_wait(
        api,
        "workflow-1",
        git_reference_id="git-ref-1",
        poll_interval_seconds=1,
    )

    assert result.build_run_id == "run-1"
    assert result.status.completion_status == "SUCCEEDED"
    assert calls["count"] >= 2
