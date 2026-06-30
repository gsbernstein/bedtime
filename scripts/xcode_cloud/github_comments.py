"""Shared GitHub screenshot comment formatting and URL metadata."""

from __future__ import annotations

import json
import re
from enum import Enum
from pathlib import Path
from typing import Any

from scripts.xcode_cloud.compare import ScreenshotChange, ScreenshotComparison
from scripts.xcode_cloud.upload import UploadedScreenshot

COMMENT_MARKER = "<!-- bedtime-screenshot-report -->"
URLS_MARKER_START = "<!-- bedtime-screenshot-urls"
STATUS_MARKER_START = "<!-- bedtime-build-status"
MARKER_END = "-->"

TERMINAL_BUILD_STATUSES = frozenset({"success", "failed", "no_screenshots"})


class BuildStatus(str, Enum):
    SUCCESS = "success"
    FAILED = "failed"
    NO_SCREENSHOTS = "no_screenshots"


def github_headers(token: str) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }


def short_sha(commit_sha: str) -> str:
    return commit_sha[:7]


def _strip_marker_block(body: str, marker_start: str) -> str:
    pattern = re.compile(
        rf"\n*{re.escape(marker_start)}.*?{re.escape(MARKER_END)}",
        flags=re.DOTALL,
    )
    return pattern.sub("", body)


def _parse_marker_json(body: str, marker_start: str) -> dict[str, Any]:
    match = re.search(
        rf"{re.escape(marker_start)}\s*(\{{.*?\}})\s*{re.escape(MARKER_END)}",
        body,
        flags=re.DOTALL,
    )
    if not match:
        return {}
    try:
        payload = json.loads(match.group(1))
    except json.JSONDecodeError:
        return {}
    return payload if isinstance(payload, dict) else {}


def _embed_marker_block(body: str, marker_start: str, payload: dict[str, Any]) -> str:
    stripped = _strip_marker_block(body, marker_start).rstrip()
    encoded = json.dumps(payload, separators=(",", ":"), sort_keys=True)
    block = f"{marker_start}\n{encoded}\n{MARKER_END}"
    return f"{stripped}\n\n{block}"


def strip_metadata_blocks(body: str) -> str:
    return _strip_marker_block(_strip_marker_block(body, STATUS_MARKER_START), URLS_MARKER_START)


def embed_screenshot_urls(body: str, urls: dict[str, str]) -> str:
    return _embed_marker_block(body, URLS_MARKER_START, urls)


def strip_screenshot_urls_block(body: str) -> str:
    return _strip_marker_block(body, URLS_MARKER_START)


def parse_screenshot_urls(body: str) -> dict[str, str]:
    urls_payload = _parse_marker_json(body, URLS_MARKER_START)
    if urls_payload and "status" not in urls_payload:
        return {str(name): str(url) for name, url in urls_payload.items()}

    status_payload = parse_build_status_payload(body)
    screenshot_urls = status_payload.get("screenshot_urls", {})
    if isinstance(screenshot_urls, dict):
        return {str(name): str(url) for name, url in screenshot_urls.items()}
    return {}


def embed_build_status(body: str, payload: dict[str, Any]) -> str:
    return _embed_marker_block(body, STATUS_MARKER_START, payload)


def parse_build_status_payload(body: str) -> dict[str, Any]:
    return _parse_marker_json(body, STATUS_MARKER_START)


def parse_build_status(body: str) -> BuildStatus | None:
    payload = parse_build_status_payload(body)
    status = payload.get("status")
    if status in TERMINAL_BUILD_STATUSES:
        return BuildStatus(status)
    return None


def build_status_payload(
    *,
    status: BuildStatus,
    build_run_id: str,
    commit_sha: str | None = None,
    exit_code: int | None = None,
    errors: list[str] | None = None,
    screenshot_urls: dict[str, str] | None = None,
    baseline_commit_sha: str | None = None,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "status": status.value,
        "build_id": build_run_id,
    }
    if commit_sha:
        payload["commit_sha"] = commit_sha
    if exit_code is not None:
        payload["exit_code"] = exit_code
    if errors:
        payload["errors"] = errors
    if screenshot_urls:
        payload["screenshot_urls"] = screenshot_urls
    if baseline_commit_sha:
        payload["baseline_commit_sha"] = baseline_commit_sha
    return payload


def build_failure_comment(
    *,
    build_run_id: str,
    commit_sha: str,
    exit_code: int | None = None,
    errors: list[str] | None = None,
    log_excerpt: str | None = None,
) -> str:
    lines = [
        COMMENT_MARKER,
        "### Xcode Cloud: failed",
        "",
        f"Commit `{short_sha(commit_sha)}`",
        f"Build `{build_run_id}`",
        "",
    ]
    if exit_code is not None:
        lines.append(f"`xcodebuild` exit code: `{exit_code}`")
        lines.append("")
    if errors:
        lines.extend(["**Errors**", ""])
        lines.extend(f"- {error}" for error in errors)
        lines.append("")
    if log_excerpt:
        lines.extend(["**Log excerpt**", "", "```", log_excerpt.rstrip(), "```", ""])
    lines.append("Fix the issues above and push again to re-run screenshots.")
    body = "\n".join(lines).rstrip()
    return embed_build_status(
        body,
        build_status_payload(
            status=BuildStatus.FAILED,
            build_run_id=build_run_id,
            commit_sha=commit_sha,
            exit_code=exit_code,
            errors=errors or [],
        ),
    )


def build_no_screenshots_comment(
    *,
    build_run_id: str,
    commit_sha: str,
    errors: list[str] | None = None,
) -> str:
    lines = [
        COMMENT_MARKER,
        "### Xcode Cloud: no screenshots",
        "",
        f"Commit `{short_sha(commit_sha)}`",
        f"Build `{build_run_id}`",
        "",
        "The build finished but no screenshot PNGs were extracted from the test result bundle.",
        "",
    ]
    if errors:
        lines.extend(["**Details**", ""])
        lines.extend(f"- {error}" for error in errors)
        lines.append("")
    body = "\n".join(lines).rstrip()
    return embed_build_status(
        body,
        build_status_payload(
            status=BuildStatus.NO_SCREENSHOTS,
            build_run_id=build_run_id,
            commit_sha=commit_sha,
            errors=errors or [],
        ),
    )


def finalize_success_comment(
    body: str,
    *,
    build_run_id: str,
    commit_sha: str,
    screenshot_urls: dict[str, str],
    baseline_commit_sha: str | None = None,
) -> str:
    body = embed_screenshot_urls(body, screenshot_urls)
    return embed_build_status(
        body,
        build_status_payload(
            status=BuildStatus.SUCCESS,
            build_run_id=build_run_id,
            commit_sha=commit_sha,
            screenshot_urls=screenshot_urls,
            baseline_commit_sha=baseline_commit_sha,
        ),
    )


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

    if screenshot_urls and commit_sha:
        return finalize_success_comment(
            body,
            build_run_id=build_run_id,
            commit_sha=commit_sha,
            screenshot_urls=screenshot_urls,
            baseline_commit_sha=baseline_commit_sha,
        )
    if screenshot_urls:
        return embed_screenshot_urls(body, screenshot_urls)
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
