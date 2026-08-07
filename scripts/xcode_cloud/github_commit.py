"""GitHub commit comments for screenshot reports."""

from __future__ import annotations

from pathlib import Path

import httpx

from scripts.xcode_cloud.github_comments import COMMENT_MARKER, github_headers, parse_screenshot_urls


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
