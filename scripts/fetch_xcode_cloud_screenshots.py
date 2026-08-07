#!/usr/bin/env python3
"""Xcode Cloud screenshot extraction and GitHub commit reporting."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.xcode_cloud.build_report import (
    publish_build_failure_report,
    publish_no_screenshots_report,
    publish_screenshot_commit_report,
)
from scripts.xcode_cloud.extract import extract_screenshots_from_local_bundle
from scripts.xcode_cloud.github_comments import BuildStatus, build_screenshot_comment
from scripts.xcode_cloud.github_commit import upsert_commit_comment
from scripts.xcode_cloud.upload import (
    UploadConfigError,
    UploadedScreenshot,
    upload_screenshots,
    write_manifest,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Extract Xcode Cloud UI test screenshots and publish GitHub commit reports."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    local_parser = subparsers.add_parser(
        "extract-local",
        help="Extract screenshots from a local .xcresult bundle.",
    )
    local_parser.add_argument("--bundle-path", required=True)
    local_parser.add_argument(
        "--output-dir",
        default="./xcode-cloud-output",
        help="Directory for extracted screenshots",
    )
    local_parser.add_argument("--only-failures", action="store_true")

    failures_parser = subparsers.add_parser(
        "extract-failures",
        help="Print failing test summaries from a local .xcresult bundle.",
    )
    failures_parser.add_argument("--bundle-path", required=True)

    comment_parser = subparsers.add_parser(
        "comment-build",
        help="Post or update a sticky build report comment on a Git commit.",
    )
    comment_parser.add_argument("--repo", required=True, help="owner/repo")
    comment_parser.add_argument("--commit-sha", required=True, help="Commit to comment on")
    comment_parser.add_argument("--run-id", required=True)
    comment_parser.add_argument(
        "--status",
        choices=[status.value for status in BuildStatus],
        help="Terminal build status to publish",
    )
    comment_parser.add_argument(
        "--baseline-commit",
        help="Baseline commit to compare against (success path only)",
    )
    comment_parser.add_argument(
        "--screenshots-dir",
        help="Directory containing extracted .png files (success path)",
    )
    comment_parser.add_argument("--exit-code", type=int, help="xcodebuild exit code (failed path)")
    comment_parser.add_argument(
        "--errors-file",
        help="Text file with one error per line (failed/no-screenshots paths)",
    )
    comment_parser.add_argument(
        "--log-file",
        help="Log excerpt to include in a failed build comment",
    )
    comment_parser.add_argument(
        "--what-to-test-file",
        help="Text file with What to test notes for the commit comment",
    )

    comment_commit_parser = subparsers.add_parser(
        "comment-commit",
        help="Alias for comment-build --status success.",
    )
    comment_commit_parser.add_argument("--repo", required=True, help="owner/repo")
    comment_commit_parser.add_argument("--commit-sha", required=True, help="Commit to comment on")
    comment_commit_parser.add_argument(
        "--baseline-commit",
        help="Baseline commit to compare against (e.g. main HEAD for PR builds)",
    )
    comment_commit_parser.add_argument("--run-id", required=True)
    comment_commit_parser.add_argument(
        "--screenshots-dir",
        help="Directory containing extracted .png files (used when no manifest is provided)",
    )
    comment_commit_parser.add_argument(
        "--manifest",
        help="JSON manifest written by upload-screenshots (legacy, no diff)",
    )
    comment_commit_parser.add_argument(
        "--what-to-test-file",
        help="Text file with What to test notes for the commit comment",
    )

    upload_parser = subparsers.add_parser(
        "upload-screenshots",
        help="Upload extracted screenshots to Imgur or S3.",
    )
    upload_parser.add_argument("--screenshots-dir", required=True)
    upload_parser.add_argument("--build-id", required=True)
    upload_parser.add_argument(
        "--backend",
        choices=["auto", "imgur", "s3"],
        default="auto",
        help="Upload backend (default: auto-detect from env)",
    )
    upload_parser.add_argument(
        "--manifest",
        default="./xcode-cloud-output/screenshots-manifest.json",
        help="Where to write the public URL manifest",
    )
    return parser


def _read_error_lines(path: str | None) -> list[str]:
    if not path:
        return []
    return [line.strip() for line in Path(path).read_text().splitlines() if line.strip()]


def _read_what_to_test(args: argparse.Namespace) -> str | None:
    path = getattr(args, "what_to_test_file", None)
    if not path:
        return None
    text = Path(path).read_text().strip()
    return text or None


def _publish_comment_build(args: argparse.Namespace, parser: argparse.ArgumentParser) -> int:
    token = os.environ.get("GITHUB_TOKEN")
    if not token:
        parser.error("GITHUB_TOKEN is required")

    what_to_test = _read_what_to_test(args)
    errors = _read_error_lines(getattr(args, "errors_file", None))
    log_excerpt = None
    log_file = getattr(args, "log_file", None)
    if log_file:
        log_excerpt = Path(log_file).read_text().strip() or None

    status = getattr(args, "status", None)
    if status is None and args.screenshots_dir:
        status = BuildStatus.SUCCESS.value
    if status is None:
        parser.error("comment-build requires --status or --screenshots-dir")

    if status == BuildStatus.SUCCESS.value:
        if not args.screenshots_dir:
            parser.error("comment-build --status success requires --screenshots-dir")
        result = publish_screenshot_commit_report(
            args.repo,
            args.commit_sha,
            args.run_id,
            Path(args.screenshots_dir),
            token=token,
            baseline_commit_sha=getattr(args, "baseline_commit", None),
            what_to_test=what_to_test,
        )
    elif status == BuildStatus.FAILED.value:
        result = publish_build_failure_report(
            args.repo,
            args.commit_sha,
            args.run_id,
            token=token,
            exit_code=getattr(args, "exit_code", None),
            errors=errors or None,
            log_excerpt=log_excerpt,
        )
    else:
        result = publish_no_screenshots_report(
            args.repo,
            args.commit_sha,
            args.run_id,
            token=token,
            errors=errors or None,
        )

    print(
        f"Published {result['status']} report on {args.repo}@{args.commit_sha[:7]}: "
        f"{result['comment_url']}"
    )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.command == "extract-local":
        screenshots = extract_screenshots_from_local_bundle(
            Path(args.bundle_path),
            Path(args.output_dir),
            only_failures=args.only_failures,
        )
        if not screenshots:
            print("No screenshots found.")
        else:
            print(f"Extracted {len(screenshots)} screenshot(s):")
            for path in screenshots:
                print(path)
        return 0

    if args.command == "extract-failures":
        from scripts.xcode_cloud.extract import extract_test_failure_summaries

        for line in extract_test_failure_summaries(Path(args.bundle_path)):
            print(line)
        return 0

    if args.command == "comment-build":
        return _publish_comment_build(args, parser)

    if args.command == "comment-commit":
        token = os.environ.get("GITHUB_TOKEN")
        if not token:
            parser.error("GITHUB_TOKEN is required for comment-commit")

        what_to_test = _read_what_to_test(args)

        if args.screenshots_dir:
            args.status = BuildStatus.SUCCESS.value
            return _publish_comment_build(args, parser)

        if args.manifest:
            manifest = json.loads(Path(args.manifest).read_text())
            uploaded = [
                UploadedScreenshot(name=item["name"], key=item["key"], url=item["url"])
                for item in manifest.get("screenshots", [])
            ]
            screenshot_urls = {item.name: item.url for item in uploaded}
            body = build_screenshot_comment(
                [],
                build_run_id=args.run_id,
                commit_sha=args.commit_sha,
                uploaded=uploaded,
                what_to_test=what_to_test,
                screenshot_urls=screenshot_urls,
            )
            upsert_commit_comment(
                args.repo,
                args.commit_sha,
                body,
                token=token,
            )
            print(f"Updated commit comment on {args.repo}@{args.commit_sha[:7]}")
            return 0

        parser.error("comment-commit requires --screenshots-dir or --manifest")

    if args.command == "upload-screenshots":
        try:
            uploads = upload_screenshots(
                Path(args.screenshots_dir),
                build_id=args.build_id,
                backend=args.backend,
            )
        except UploadConfigError as error:
            parser.error(str(error))

        manifest_path = Path(args.manifest)
        write_manifest(manifest_path, args.build_id, uploads)
        print(f"Uploaded {len(uploads)} screenshot(s) via {args.backend}")
        for item in uploads:
            print(item.url)
        print(f"Manifest: {manifest_path}")
        return 0

    parser.error(f"Unknown command: {args.command}")


if __name__ == "__main__":
    raise SystemExit(main())
