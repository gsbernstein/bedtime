"""GitHub pull request screenshot comments (legacy manifest path)."""

from __future__ import annotations

import httpx

from scripts.xcode_cloud.github_comments import (
    COMMENT_MARKER,
    attach_upload_urls,
    build_screenshot_comment,
    github_headers,
)


def find_pr_comment_id(
    repo: str,
    pr_number: int,
    *,
    token: str,
    client: httpx.Client | None = None,
) -> int | None:
    http = client or httpx.Client(timeout=30.0)
    close_client = client is None
    try:
        page = 1
        while True:
            response = http.get(
                f"https://api.github.com/repos/{repo}/issues/{pr_number}/comments",
                params={"per_page": 100, "page": page},
                headers=github_headers(token),
            )
            response.raise_for_status()
            comments = response.json()
            if not comments:
                return None
            for comment in comments:
                if COMMENT_MARKER in comment.get("body", ""):
                    return comment["id"]
            page += 1
    finally:
        if close_client:
            http.close()
    return None


def upsert_pr_comment(
    repo: str,
    pr_number: int,
    body: str,
    *,
    token: str,
    client: httpx.Client | None = None,
) -> dict:
    http = client or httpx.Client(timeout=30.0)
    close_client = client is None
    try:
        comment_id = find_pr_comment_id(repo, pr_number, token=token, client=http)
        headers = github_headers(token)
        if comment_id is not None:
            response = http.patch(
                f"https://api.github.com/repos/{repo}/issues/comments/{comment_id}",
                headers=headers,
                json={"body": body},
            )
        else:
            response = http.post(
                f"https://api.github.com/repos/{repo}/issues/{pr_number}/comments",
                headers=headers,
                json={"body": body},
            )
        response.raise_for_status()
        return response.json()
    finally:
        if close_client:
            http.close()


def post_pr_comment(
    repo: str,
    pr_number: int,
    body: str,
    *,
    token: str,
    client: httpx.Client | None = None,
) -> dict:
    return upsert_pr_comment(repo, pr_number, body, token=token, client=client)
