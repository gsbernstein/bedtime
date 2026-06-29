"""GitHub pull request screenshot comments."""

from __future__ import annotations

from pathlib import Path

import httpx

from scripts.xcode_cloud.compare import ScreenshotChange, ScreenshotComparison
from scripts.xcode_cloud.upload import UploadedScreenshot

COMMENT_MARKER = "<!-- bedtime-screenshot-report -->"


def build_screenshot_comment(
    screenshot_paths: list[Path],
    *,
    build_run_id: str,
    title: str = "UI screenshots",
    uploaded: list[UploadedScreenshot] | None = None,
    what_to_test: str | None = None,
    comparisons: list[ScreenshotComparison] | None = None,
) -> str:
    if comparisons is not None:
        return _build_diff_comment(
            comparisons,
            build_run_id=build_run_id,
            title=title,
            what_to_test=what_to_test,
        )

    if uploaded:
        lines = [
            COMMENT_MARKER,
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
            f"{COMMENT_MARKER}\n\n"
            f"### {title}\n\n"
            f"Build run `{build_run_id}` completed, but no screenshot attachments were found."
        )

    lines = [
        COMMENT_MARKER,
        f"### {title}",
        "",
        f"Build run `{build_run_id}`",
        "",
        "Screenshots were extracted but not uploaded. Configure `IMGUR_CLIENT_ID` to embed images.",
        "",
        "| Screenshot |",
        "| --- |",
    ]
    for path in screenshot_paths:
        lines.append(f"| `{path.name}` |")
    return "\n".join(lines)


def _build_diff_comment(
    comparisons: list[ScreenshotComparison],
    *,
    build_run_id: str,
    title: str,
    what_to_test: str | None,
) -> str:
    changed = [item for item in comparisons if item.change == ScreenshotChange.CHANGED]
    new = [item for item in comparisons if item.change == ScreenshotChange.NEW]
    unchanged = [item for item in comparisons if item.change == ScreenshotChange.UNCHANGED]
    removed = [item for item in comparisons if item.change == ScreenshotChange.REMOVED]

    lines = [
        COMMENT_MARKER,
        f"### {title}",
        "",
        f"Build run `{build_run_id}`",
        "",
        (
            f"{len(changed)} changed, {len(new)} new, {len(unchanged)} unchanged, "
            f"{len(removed)} removed"
        ),
        "",
    ]

    if what_to_test:
        lines.extend(["**What to test**", "", what_to_test.strip(), ""])

    if not changed and not new:
        lines.append("No screenshot changes since the last run on this PR.")
        return "\n".join(lines).rstrip()

    lines.extend(["", "| Screenshot | Before | After |", "| --- | --- | --- |"])

    for item in [*changed, *new]:
        before = _image_cell(item.before_url, item.name, "before")
        after = _image_cell(item.after_url, item.name, "after")
        label = item.name
        if item.change == ScreenshotChange.NEW:
            label = f"{item.name} (new)"
        lines.append(f"| {label} | {before} | {after} |")

    if removed:
        lines.extend(["", "**Removed screenshots**", ""])
        for item in removed:
            lines.append(f"- `{item.name}`")

    return "\n".join(lines).rstrip()


def _image_cell(url: str | None, name: str, role: str) -> str:
    if not url:
        return "—"
    return f"![{name} {role}]({url})"


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
                headers=_github_headers(token),
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
        headers = _github_headers(token)
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


def _github_headers(token: str) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }


def attach_upload_urls(
    comparisons: list[ScreenshotComparison],
    uploads: list[UploadedScreenshot],
) -> list[ScreenshotComparison]:
    upload_by_name = {item.name: item.url for item in uploads}
    updated: list[ScreenshotComparison] = []
    for item in comparisons:
        after_url = upload_by_name.get(item.name, item.after_url)
        updated.append(
            ScreenshotComparison(
                name=item.name,
                change=item.change,
                before_path=item.before_path,
                after_path=item.after_path,
                before_url=item.before_url,
                after_url=after_url,
            )
        )
    return updated
