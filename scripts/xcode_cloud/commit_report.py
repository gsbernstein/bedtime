"""Publish sticky commit screenshot reports with before/after diffs."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import httpx

from scripts.xcode_cloud.compare import compare_screenshot_sets
from scripts.xcode_cloud.github_comments import attach_upload_urls, build_screenshot_comment
from scripts.xcode_cloud.github_commit import (
    download_baseline_images,
    fetch_screenshot_urls_from_commit,
    upsert_commit_comment,
)
from scripts.xcode_cloud.upload import UploadBackend, upload_screenshots


def publish_screenshot_commit_report(
    repo: str,
    commit_sha: str,
    build_run_id: str,
    screenshots_dir: Path,
    *,
    token: str,
    baseline_commit_sha: str | None = None,
    what_to_test: str | None = None,
    upload_backend: UploadBackend = "auto",
    cache_root: Path | None = None,
) -> dict[str, Any]:
    cache_root = cache_root or screenshots_dir.parent / "baseline-cache"
    baseline_dir = cache_root / f"baseline-{baseline_commit_sha or 'none'}"

    with httpx.Client(timeout=60.0, follow_redirects=True) as client:
        baseline_urls: dict[str, str] = {}
        if baseline_commit_sha and baseline_commit_sha != commit_sha:
            baseline_urls = fetch_screenshot_urls_from_commit(
                repo,
                baseline_commit_sha,
                token=token,
                client=client,
            )
            if baseline_urls:
                download_baseline_images(
                    baseline_urls,
                    baseline_dir,
                    client=client,
                )

        comparisons = compare_screenshot_sets(
            screenshots_dir,
            baseline_dir if baseline_urls else None,
            baseline_urls=baseline_urls,
        )

        uploads = upload_screenshots(
            screenshots_dir,
            build_id=build_run_id,
            backend=upload_backend,
            http_client=client,
        )
        comparisons = attach_upload_urls(comparisons, uploads)
        screenshot_urls = {item.name: item.url for item in uploads}

        body = build_screenshot_comment(
            [],
            build_run_id=build_run_id,
            commit_sha=commit_sha,
            baseline_commit_sha=baseline_commit_sha,
            comparisons=comparisons,
            what_to_test=what_to_test,
            screenshot_urls=screenshot_urls,
        )
        comment = upsert_commit_comment(
            repo,
            commit_sha,
            body,
            token=token,
            client=client,
        )

    return {
        "comment_id": comment["id"],
        "comment_url": comment["html_url"],
        "upload_count": len(uploads),
        "comparison_count": len(comparisons),
        "baseline_commit_sha": baseline_commit_sha,
    }
