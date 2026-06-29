"""Store per-PR screenshot baselines via the GitHub Contents API."""

from __future__ import annotations

import base64
import json
from pathlib import Path
from typing import Any

import httpx

DEFAULT_BASELINE_BRANCH = "screenshot-baselines"
DEFAULT_BASELINE_ROOT = "prs"


def baseline_manifest_path(pr_number: int, *, root: str = DEFAULT_BASELINE_ROOT) -> str:
    return f"{root}/{pr_number}/manifest.json"


def baseline_dir_for_pr(pr_number: int, cache_root: Path) -> Path:
    return cache_root / f"pr-{pr_number}"


def _github_headers(token: str) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }


def fetch_baseline_manifest(
    repo: str,
    pr_number: int,
    *,
    token: str,
    branch: str = DEFAULT_BASELINE_BRANCH,
    client: httpx.Client | None = None,
) -> dict[str, Any] | None:
    http = client or httpx.Client(timeout=60.0)
    close_client = client is None
    path = baseline_manifest_path(pr_number)
    try:
        response = http.get(
            f"https://api.github.com/repos/{repo}/contents/{path}",
            params={"ref": branch},
            headers=_github_headers(token),
        )
        if response.status_code == 404:
            return None
        response.raise_for_status()
        payload = response.json()
        content = base64.b64decode(payload["content"]).decode("utf-8")
        manifest = json.loads(content)
        manifest["_sha"] = payload.get("sha")
        return manifest
    finally:
        if close_client:
            http.close()


def download_baseline_images(
    manifest: dict[str, Any],
    destination: Path,
    *,
    client: httpx.Client | None = None,
) -> dict[str, str]:
    http = client or httpx.Client(timeout=60.0, follow_redirects=True)
    close_client = client is None
    destination.mkdir(parents=True, exist_ok=True)
    urls: dict[str, str] = {}
    try:
        for item in manifest.get("screenshots", []):
            name = item["name"]
            url = item["url"]
            urls[name] = url
            target = destination / name
            response = http.get(url)
            response.raise_for_status()
            target.write_bytes(response.content)
        return urls
    finally:
        if close_client:
            http.close()


def write_baseline_manifest(
    repo: str,
    pr_number: int,
    manifest: dict[str, Any],
    *,
    token: str,
    branch: str = DEFAULT_BASELINE_BRANCH,
    client: httpx.Client | None = None,
) -> None:
    http = client or httpx.Client(timeout=60.0)
    close_client = client is None
    path = baseline_manifest_path(pr_number)
    body = {key: value for key, value in manifest.items() if not key.startswith("_")}
    encoded = base64.b64encode(json.dumps(body, indent=2).encode("utf-8")).decode("ascii")

    payload: dict[str, Any] = {
        "message": f"Update screenshot baseline for PR #{pr_number}",
        "content": encoded,
        "branch": branch,
    }
    existing_sha = manifest.get("_sha")
    if existing_sha:
        payload["sha"] = existing_sha

    try:
        response = http.put(
            f"https://api.github.com/repos/{repo}/contents/{path}",
            headers=_github_headers(token),
            json=payload,
        )
        if response.status_code == 404 and "_sha" not in manifest:
            _ensure_baseline_branch(repo, branch=branch, token=token, client=http)
            response = http.put(
                f"https://api.github.com/repos/{repo}/contents/{path}",
                headers=_github_headers(token),
                json=payload,
            )
        response.raise_for_status()
    finally:
        if close_client:
            http.close()


def _ensure_baseline_branch(
    repo: str,
    *,
    branch: str,
    token: str,
    client: httpx.Client,
) -> None:
    default_branch_response = client.get(
        f"https://api.github.com/repos/{repo}",
        headers=_github_headers(token),
    )
    default_branch_response.raise_for_status()
    default_branch = default_branch_response.json()["default_branch"]
    ref_response = client.get(
        f"https://api.github.com/repos/{repo}/git/ref/heads/{default_branch}",
        headers=_github_headers(token),
    )
    ref_response.raise_for_status()
    sha = ref_response.json()["object"]["sha"]
    create_response = client.post(
        f"https://api.github.com/repos/{repo}/git/refs",
        headers=_github_headers(token),
        json={"ref": f"refs/heads/{branch}", "sha": sha},
    )
    if create_response.status_code not in {201, 422}:
        create_response.raise_for_status()
