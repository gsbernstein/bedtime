"""Publish sticky PR screenshot reports with before/after diffs."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import httpx

from scripts.xcode_cloud.baseline import (
    baseline_dir_for_pr,
    download_baseline_images,
    fetch_baseline_manifest,
    write_baseline_manifest,
)
from scripts.xcode_cloud.compare import compare_screenshot_sets, file_sha256
from scripts.xcode_cloud.github_pr import (
    attach_upload_urls,
    build_screenshot_comment,
    upsert_pr_comment,
)
from scripts.xcode_cloud.upload import UploadBackend, upload_screenshots


def publish_screenshot_pr_report(
    repo: str,
    pr_number: int,
    build_run_id: str,
    screenshots_dir: Path,
    *,
    token: str,
    what_to_test: str | None = None,
    upload_backend: UploadBackend = "auto",
    cache_root: Path | None = None,
) -> dict[str, Any]:
    cache_root = cache_root or screenshots_dir.parent / "baseline-cache"
    baseline_dir = baseline_dir_for_pr(pr_number, cache_root)

    with httpx.Client(timeout=60.0, follow_redirects=True) as client:
        previous_manifest = fetch_baseline_manifest(
            repo,
            pr_number,
            token=token,
            client=client,
        )
        baseline_urls: dict[str, str] = {}
        if previous_manifest:
            baseline_urls = download_baseline_images(
                previous_manifest,
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

        body = build_screenshot_comment(
            [],
            build_run_id=build_run_id,
            comparisons=comparisons,
            what_to_test=what_to_test,
        )
        comment = upsert_pr_comment(repo, pr_number, body, token=token, client=client)

        upload_by_name = {item.name: item for item in uploads}
        manifest_screenshots = []
        for path in sorted(screenshots_dir.rglob("*.png")):
            if not path.is_file():
                continue
            uploaded = upload_by_name[path.name]
            manifest_screenshots.append(
                {
                    "name": path.name,
                    "key": uploaded.key,
                    "url": uploaded.url,
                    "sha256": file_sha256(path),
                }
            )

        new_manifest: dict[str, Any] = {
            "build_id": build_run_id,
            "pr_number": pr_number,
            "screenshots": manifest_screenshots,
        }
        if previous_manifest and previous_manifest.get("_sha"):
            new_manifest["_sha"] = previous_manifest["_sha"]

        write_baseline_manifest(repo, pr_number, new_manifest, token=token, client=client)

    return {
        "comment_id": comment["id"],
        "comment_url": comment["html_url"],
        "upload_count": len(uploads),
        "comparison_count": len(comparisons),
    }
