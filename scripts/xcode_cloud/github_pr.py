"""Optional GitHub pull request comment helpers."""

from __future__ import annotations

from pathlib import Path

import httpx

from scripts.xcode_cloud.upload import UploadedScreenshot


def build_screenshot_comment(
    screenshot_paths: list[Path],
    *,
    build_run_id: str,
    title: str = "Xcode Cloud screenshots",
    uploaded: list[UploadedScreenshot] | None = None,
    what_to_test: str | None = None,
) -> str:
    if uploaded:
        lines = [
            f"### {title}",
            "",
            f"Build run `{build_run_id}`",
            "",
        ]
        if what_to_test:
            lines.extend(["**What to test**", "", what_to_test.strip(), ""])
        for item in uploaded:
            lines.append(f"**{item.name}**")
            lines.append("")
            lines.append(f"![{item.name}]({item.url})")
            lines.append("")
        return "\n".join(lines).rstrip()

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
        "Screenshots were extracted on the Xcode Cloud Mac but not uploaded to a public bucket.",
        "Set `SCREENSHOTS_S3_BUCKET` (and related env vars) to embed images in PR comments.",
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
