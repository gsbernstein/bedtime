"""Optional GitHub pull request comment helpers."""

from __future__ import annotations

from pathlib import Path

import httpx


def build_screenshot_comment(
  screenshot_paths: list[Path],
  *,
  build_run_id: str,
  title: str = "Xcode Cloud screenshots",
) -> str:
    if not screenshot_paths:
        return (
            f"### {title}\n\n"
            f"Build run `{build_run_id}` completed, but no screenshot attachments were found."
        )

    lines = [
        f"### {title}",
        "",
        f"Build run `{build_run_id}`",
        "",
        "| Screenshot |",
        "| --- |",
    ]
    for path in screenshot_paths:
        lines.append(f"| `{path.name}` |")
    return "\n".join(lines)


def post_pr_comment(
    repo: str,
    pr_number: int,
    body: str,
    *,
    token: str,
    client: httpx.Client | None = None,
) -> dict:
    """Post a markdown comment on a GitHub pull request."""
    http = client or httpx.Client(timeout=30.0)
    close_client = client is None
    try:
        response = http.post(
            f"https://api.github.com/repos/{repo}/issues/{pr_number}/comments",
            headers={
                "Authorization": f"Bearer {token}",
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
            },
            json={"body": body},
        )
        response.raise_for_status()
        return response.json()
    finally:
        if close_client:
            http.close()
