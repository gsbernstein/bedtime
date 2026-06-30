"""GitHub commit comments for screenshot reports."""

from __future__ import annotations

import time
from dataclasses import dataclass
from pathlib import Path

import httpx

from scripts.xcode_cloud.github_comments import (
    COMMENT_MARKER,
    TERMINAL_BUILD_STATUSES,
    BuildStatus,
    github_headers,
    parse_build_status,
    parse_build_status_payload,
    parse_screenshot_urls,
)


@dataclass(frozen=True)
class CommitReportResult:
    status: BuildStatus
    comment_id: int
    comment_url: str
    body: str
    payload: dict


def find_commit_comment_id(
    repo: str,
    commit_sha: str,
    *,
    token: str,
    client: httpx.Client | None = None,
) -> int | None:
    http = client or httpx.Client(timeout=30.0)
    close_client = client is None
    try:
        response = http.get(
            f"https://api.github.com/repos/{repo}/commits/{commit_sha}/comments",
            headers=github_headers(token),
        )
        if response.status_code == 404:
            return None
        response.raise_for_status()
        for comment in response.json():
            if COMMENT_MARKER in comment.get("body", ""):
                return comment["id"]
        return None
    finally:
        if close_client:
            http.close()


def upsert_commit_comment(
    repo: str,
    commit_sha: str,
    body: str,
    *,
    token: str,
    client: httpx.Client | None = None,
) -> dict:
    http = client or httpx.Client(timeout=30.0)
    close_client = client is None
    try:
        comment_id = find_commit_comment_id(
            repo,
            commit_sha,
            token=token,
            client=http,
        )
        headers = github_headers(token)
        if comment_id is not None:
            response = http.patch(
                f"https://api.github.com/repos/{repo}/comments/{comment_id}",
                headers=headers,
                json={"body": body},
            )
        else:
            response = http.post(
                f"https://api.github.com/repos/{repo}/commits/{commit_sha}/comments",
                headers=headers,
                json={"body": body},
            )
        response.raise_for_status()
        return response.json()
    finally:
        if close_client:
            http.close()


def fetch_commit_report(
    repo: str,
    commit_sha: str,
    *,
    token: str,
    client: httpx.Client | None = None,
) -> CommitReportResult | None:
    http = client or httpx.Client(timeout=30.0)
    close_client = client is None
    try:
        response = http.get(
            f"https://api.github.com/repos/{repo}/commits/{commit_sha}/comments",
            headers=github_headers(token),
        )
        if response.status_code == 404:
            return None
        response.raise_for_status()
        for comment in response.json():
            body = comment.get("body", "")
            if COMMENT_MARKER not in body:
                continue
            status = parse_build_status(body)
            if status is None:
                continue
            return CommitReportResult(
                status=status,
                comment_id=comment["id"],
                comment_url=comment["html_url"],
                body=body,
                payload=parse_build_status_payload(body),
            )
        return None
    finally:
        if close_client:
            http.close()


def wait_for_commit_report(
    repo: str,
    commit_sha: str,
    *,
    token: str,
    timeout_seconds: int = 3600,
    poll_interval_seconds: int = 30,
    client: httpx.Client | None = None,
) -> CommitReportResult:
    http = client or httpx.Client(timeout=30.0)
    close_client = client is None
    deadline = time.time() + timeout_seconds
    try:
        while time.time() < deadline:
            report = fetch_commit_report(repo, commit_sha, token=token, client=http)
            if report is not None and report.status.value in TERMINAL_BUILD_STATUSES:
                return report
            time.sleep(poll_interval_seconds)
    finally:
        if close_client:
            http.close()
    raise TimeoutError(
        f"Timed out after {timeout_seconds}s waiting for a terminal build report "
        f"on {repo}@{commit_sha[:7]}"
    )


def fetch_screenshot_urls_from_commit(
    repo: str,
    commit_sha: str,
    *,
    token: str,
    client: httpx.Client | None = None,
) -> dict[str, str]:
    http = client or httpx.Client(timeout=30.0)
    close_client = client is None
    try:
        response = http.get(
            f"https://api.github.com/repos/{repo}/commits/{commit_sha}/comments",
            headers=github_headers(token),
        )
        if response.status_code == 404:
            return {}
        response.raise_for_status()
        for comment in response.json():
            if COMMENT_MARKER not in comment.get("body", ""):
                continue
            urls = parse_screenshot_urls(comment["body"])
            if urls:
                return urls
        return {}
    finally:
        if close_client:
            http.close()


def download_baseline_images(
    urls: dict[str, str],
    destination: Path,
    *,
    client: httpx.Client | None = None,
) -> dict[str, str]:
    http = client or httpx.Client(timeout=60.0, follow_redirects=True)
    close_client = client is None
    destination.mkdir(parents=True, exist_ok=True)
    downloaded: dict[str, str] = {}
    try:
        for name, url in urls.items():
            target = destination / name
            response = http.get(url)
            response.raise_for_status()
            target.write_bytes(response.content)
            downloaded[name] = url
        return downloaded
    finally:
        if close_client:
            http.close()
