"""Shared GitHub screenshot comment formatting and URL metadata."""

from __future__ import annotations

import json
import re
from pathlib import Path

from scripts.xcode_cloud.compare import ScreenshotChange, ScreenshotComparison
from scripts.xcode_cloud.upload import UploadedScreenshot

COMMENT_MARKER = "<!-- bedtime-screenshot-report -->"
URLS_MARKER_START = "<!-- bedtime-screenshot-urls"
URLS_MARKER_END = "-->"


def github_headers(token: str) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }


def short_sha(commit_sha: str) -> str:
    return commit_sha[:7]


def embed_screenshot_urls(body: str, urls: dict[str, str]) -> str:
    stripped = strip_screenshot_urls_block(body).rstrip()
    payload = json.dumps(urls, separators=(",", ":"), sort_keys=True)
    block = f"{URLS_MARKER_START}\n{payload}\n{URLS_MARKER_END}"
    return f"{stripped}\n\n{block}"


def strip_screenshot_urls_block(body: str) -> str:
    pattern = re.compile(
        rf"\n*{re.escape(URLS_MARKER_START)}.*?{re.escape(URLS_MARKER_END)}",
        flags=re.DOTALL,
    )
    return pattern.sub("", body)


def parse_screenshot_urls(body: str) -> dict[str, str]:
    match = re.search(
        rf"{re.escape(URLS_MARKER_START)}\s*(\{{.*?\}})\s*{re.escape(URLS_MARKER_END)}",
        body,
        flags=re.DOTALL,
    )
    if not match:
        return {}
    try:
        payload = json.loads(match.group(1))
    except json.JSONDecodeError:
        return {}
    if not isinstance(payload, dict):
        return {}
    return {str(name): str(url) for name, url in payload.items()}


def build_screenshot_comment(
    screenshot_paths: list[Path],
    *,
    build_run_id: str,
    commit_sha: str | None = None,
    baseline_commit_sha: str | None = None,
    title: str = "UI screenshots",
    uploaded: list[UploadedScreenshot] | None = None,
    what_to_test: str | None = None,
    comparisons: list[ScreenshotComparison] | None = None,
    screenshot_urls: dict[str, str] | None = None,
) -> str:
    if comparisons is not None:
        body = _build_diff_comment(
            comparisons,
            build_run_id=build_run_id,
            commit_sha=commit_sha,
            baseline_commit_sha=baseline_commit_sha,
            title=title,
            what_to_test=what_to_test,
        )
    elif uploaded:
        lines = [
            COMMENT_MARKER,
            f"### {title}",
            "",
            f"Commit `{short_sha(commit_sha)}`" if commit_sha else f"Build run `{build_run_id}`",
            "",
        ]
        if what_to_test:
            lines.extend(["**What to test**", "", what_to_test.strip(), ""])
        for item in uploaded:
            lines.append(f"**{item.name}**")
            lines.append("")
            lines.append(f"![{item.name}]({item.url})")
            lines.append("")
        body = "\n".join(lines).rstrip()
    elif not screenshot_paths:
        body = (
            f"{COMMENT_MARKER}\n\n"
            f"### {title}\n\n"
            f"Build run `{build_run_id}` completed, but no screenshot attachments were found."
        )
    else:
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
        body = "\n".join(lines)

    if screenshot_urls:
        body = embed_screenshot_urls(body, screenshot_urls)
    return body


def _build_diff_comment(
    comparisons: list[ScreenshotComparison],
    *,
    build_run_id: str,
    commit_sha: str | None,
    baseline_commit_sha: str | None,
    title: str,
    what_to_test: str | None,
) -> str:
    changed = [item for item in comparisons if item.change == ScreenshotChange.CHANGED]
    new = [item for item in comparisons if item.change == ScreenshotChange.NEW]
    unchanged = [item for item in comparisons if item.change == ScreenshotChange.UNCHANGED]
    removed = [item for item in comparisons if item.change == ScreenshotChange.REMOVED]

    header = f"Commit `{short_sha(commit_sha)}`" if commit_sha else f"Build run `{build_run_id}`"
    lines = [
        COMMENT_MARKER,
        f"### {title}",
        "",
        header,
        "",
    ]
    if baseline_commit_sha:
        lines.append(f"Compared to `{short_sha(baseline_commit_sha)}`")
        lines.append("")
    lines.append(
        f"{len(changed)} changed, {len(new)} new, {len(unchanged)} unchanged, {len(removed)} removed"
    )
    lines.append("")

    if what_to_test:
        lines.extend(["**What to test**", "", what_to_test.strip(), ""])

    if not changed and not new:
        if baseline_commit_sha:
            lines.append(
                f"No screenshot changes compared to `{short_sha(baseline_commit_sha)}`."
            )
        else:
            lines.append("No screenshot changes detected.")
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
