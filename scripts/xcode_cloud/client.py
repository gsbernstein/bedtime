"""App Store Connect API client for Xcode Cloud resources."""

from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Any, Callable
from urllib.parse import urljoin

import httpx


class XcodeCloudError(RuntimeError):
    """Raised when an Xcode Cloud API request fails."""


@dataclass(frozen=True)
class BuildRunStatus:
    run_id: str
    execution_progress: str
    completion_status: str | None


class XcodeCloudClient:
    BASE_URL = "https://api.appstoreconnect.apple.com/v1/"

    def __init__(
        self,
        token_provider: Callable[[], str],
        *,
        client: httpx.Client | None = None,
    ) -> None:
        self._token_provider = token_provider
        self._client = client or httpx.Client(timeout=60.0)

    def close(self) -> None:
        self._client.close()

    def __enter__(self) -> XcodeCloudClient:
        return self

    def __exit__(self, *args: object) -> None:
        self.close()

    def _request(self, method: str, path: str, **kwargs: Any) -> dict[str, Any]:
        url = path if path.startswith("http") else urljoin(self.BASE_URL, path.lstrip("/"))
        headers = kwargs.pop("headers", {})
        headers["Authorization"] = f"Bearer {self._token_provider()}"
        response = self._client.request(method, url, headers=headers, **kwargs)
        if response.status_code >= 400:
            raise XcodeCloudError(
                f"{method} {url} failed with {response.status_code}: {response.text}"
            )
        if not response.content:
            return {}
        return response.json()

    def get_build_run(self, run_id: str) -> dict[str, Any]:
        return self._request("GET", f"ciBuildRuns/{run_id}")

    def list_build_actions(self, run_id: str) -> list[dict[str, Any]]:
        payload = self._request("GET", f"ciBuildRuns/{run_id}/actions")
        return payload.get("data", [])

    def list_artifacts(self, action_id: str) -> list[dict[str, Any]]:
        payload = self._request("GET", f"ciBuildActions/{action_id}/artifacts")
        return payload.get("data", [])

    def get_artifact(self, artifact_id: str) -> dict[str, Any]:
        return self._request("GET", f"ciArtifacts/{artifact_id}")

    def get_build_run_status(self, run_id: str) -> BuildRunStatus:
        payload = self.get_build_run(run_id)
        attributes = payload["data"]["attributes"]
        return BuildRunStatus(
            run_id=run_id,
            execution_progress=attributes.get("executionProgress", ""),
            completion_status=attributes.get("completionStatus"),
        )

    def wait_for_build_run(
        self,
        run_id: str,
        *,
        timeout_seconds: int = 3600,
        poll_interval_seconds: int = 30,
    ) -> BuildRunStatus:
        deadline = time.time() + timeout_seconds
        while time.time() < deadline:
            status = self.get_build_run_status(run_id)
            if status.execution_progress == "COMPLETE":
                return status
            time.sleep(poll_interval_seconds)
        raise TimeoutError(f"Timed out waiting for build run {run_id} to complete")
