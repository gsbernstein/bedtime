"""Trigger Xcode Cloud builds and wait for completion."""

from __future__ import annotations

from dataclasses import dataclass

from scripts.xcode_cloud.client import BuildRunStatus, XcodeCloudClient, XcodeCloudError


@dataclass(frozen=True)
class TriggerResult:
    build_run_id: str
    status: BuildRunStatus


def repository_id_for_workflow(client: XcodeCloudClient, workflow_id: str) -> str:
    payload = client.get_workflow(workflow_id, include_repository=True)
    included = payload.get("included", [])
    for resource in included:
        if resource.get("type") == "scmRepositories":
            return resource["id"]

    relationships = payload.get("data", {}).get("relationships", {})
    repository = relationships.get("repository", {}).get("data")
    if repository and repository.get("id"):
        return repository["id"]

    raise XcodeCloudError(f"Could not resolve repository for workflow {workflow_id}")


def git_reference_id_for_branch(
    client: XcodeCloudClient,
    repository_id: str,
    branch: str,
) -> str:
    references = client.list_git_references(repository_id)
    normalized = branch.removeprefix("refs/heads/")
    for reference in references:
        attributes = reference.get("attributes", {})
        if attributes.get("kind") != "BRANCH":
            continue
        name = attributes.get("name", "")
        canonical = attributes.get("canonicalName", "")
        if name == normalized or canonical == f"refs/heads/{normalized}":
            return reference["id"]

    raise XcodeCloudError(
        f"Could not find git reference for branch '{branch}' in repository {repository_id}"
    )


def trigger_build_run(
    client: XcodeCloudClient,
    workflow_id: str,
    *,
    git_reference_id: str | None = None,
    branch: str | None = None,
) -> str:
    if bool(git_reference_id) == bool(branch):
        raise ValueError("Provide exactly one of git_reference_id or branch")

    resolved_reference_id = git_reference_id
    if branch is not None:
        repository_id = repository_id_for_workflow(client, workflow_id)
        resolved_reference_id = git_reference_id_for_branch(client, repository_id, branch)

    assert resolved_reference_id is not None
    payload = client.create_build_run(workflow_id, resolved_reference_id)
    return payload["data"]["id"]


def trigger_and_wait(
    client: XcodeCloudClient,
    workflow_id: str,
    *,
    git_reference_id: str | None = None,
    branch: str | None = None,
    timeout_seconds: int = 3600,
    poll_interval_seconds: int = 30,
) -> TriggerResult:
    build_run_id = trigger_build_run(
        client,
        workflow_id,
        git_reference_id=git_reference_id,
        branch=branch,
    )
    status = client.wait_for_build_run(
        build_run_id,
        timeout_seconds=timeout_seconds,
        poll_interval_seconds=poll_interval_seconds,
    )
    return TriggerResult(build_run_id=build_run_id, status=status)
