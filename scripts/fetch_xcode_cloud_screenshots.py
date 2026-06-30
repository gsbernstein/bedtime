#!/usr/bin/env python3
"""Fetch Xcode Cloud screenshots after a build run completes."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.xcode_cloud.asc_auth import create_asc_token, credentials_from_env
from scripts.xcode_cloud.client import XcodeCloudClient
from scripts.xcode_cloud.extract import XcresultToolNotFoundError
from scripts.xcode_cloud.build_report import (
    publish_build_failure_report,
    publish_no_screenshots_report,
    publish_screenshot_commit_report,
)
from scripts.xcode_cloud.github_comments import BuildStatus, build_screenshot_comment
from scripts.xcode_cloud.github_commit import upsert_commit_comment, wait_for_commit_report
from scripts.xcode_cloud.screenshots import (
    extract_screenshots_from_local_bundle,
    fetch_screenshots_from_build_run,
    fetch_test_result_bundle,
)
from scripts.xcode_cloud.trigger import trigger_and_wait
from scripts.xcode_cloud.upload import (
    UploadConfigError,
    UploadedScreenshot,
    upload_screenshots,
    write_manifest,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Fetch Xcode Cloud test screenshots after a build completes."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    fetch_parser = subparsers.add_parser(
        "fetch",
        help="Download the test result bundle for a completed build run.",
    )
    fetch_parser.add_argument("--run-id", required=True, help="ciBuildRuns ID")
    fetch_parser.add_argument(
        "--output-dir",
        default="./xcode-cloud-output",
        help="Directory for downloaded bundles and screenshots",
    )
    fetch_parser.add_argument(
        "--only-failures",
        action="store_true",
        help="Export only attachments associated with failing tests",
    )
    fetch_parser.add_argument(
        "--skip-extract",
        action="store_true",
        help="Download the bundle but do not run xcresulttool extraction",
    )

    wait_parser = subparsers.add_parser(
        "wait-and-fetch",
        help="Poll until the build run completes, then fetch screenshots.",
    )
    wait_parser.add_argument("--run-id", required=True, help="ciBuildRuns ID")
    wait_parser.add_argument(
        "--output-dir",
        default="./xcode-cloud-output",
        help="Directory for downloaded bundles and screenshots",
    )
    wait_parser.add_argument("--timeout-seconds", type=int, default=3600)
    wait_parser.add_argument("--poll-interval-seconds", type=int, default=30)
    wait_parser.add_argument("--only-failures", action="store_true")

    trigger_parser = subparsers.add_parser(
        "trigger-and-fetch",
        help="Start an Xcode Cloud build, wait until it finishes, then fetch screenshots.",
    )
    trigger_parser.add_argument("--workflow-id", required=True, help="ciWorkflows ID")
    branch_group = trigger_parser.add_mutually_exclusive_group(required=True)
    branch_group.add_argument("--branch", help="Branch name to build")
    branch_group.add_argument("--git-reference-id", help="scmGitReferences ID")
    trigger_parser.add_argument(
        "--output-dir",
        default="./xcode-cloud-output",
        help="Directory for downloaded bundles and screenshots",
    )
    trigger_parser.add_argument("--timeout-seconds", type=int, default=3600)
    trigger_parser.add_argument("--poll-interval-seconds", type=int, default=30)
    trigger_parser.add_argument("--only-failures", action="store_true")
    trigger_parser.add_argument(
        "--skip-extract",
        action="store_true",
        help="Download the bundle but do not run xcresulttool extraction",
    )

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

    wait_report_parser = subparsers.add_parser(
        "wait-for-commit-report",
        help="Poll until a terminal build report comment appears on a commit.",
    )
    wait_report_parser.add_argument("--repo", required=True, help="owner/repo")
    wait_report_parser.add_argument("--commit-sha", required=True)
    wait_report_parser.add_argument("--timeout-seconds", type=int, default=3600)
    wait_report_parser.add_argument("--poll-interval-seconds", type=int, default=30)
    wait_report_parser.add_argument(
        "--output-json",
        help="Write the parsed build-status payload to this JSON file",
    )

    upload_parser = subparsers.add_parser(
        "upload-screenshots",
        help="Upload extracted screenshots to a public S3 bucket.",
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

    failures_parser = subparsers.add_parser(
        "extract-failures",
        help="Print failing test summaries from a local .xcresult bundle.",
    )
    failures_parser.add_argument("--bundle-path", required=True)
    return parser


def _read_error_lines(path: str | None) -> list[str]:
    if not path:
        return []
    return [line.strip() for line in Path(path).read_text().splitlines() if line.strip()]


def _publish_comment_build(args: argparse.Namespace, parser: argparse.ArgumentParser) -> int:
    import os

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
        _print_screenshots(screenshots)
        return 0

    if args.command == "extract-failures":
        from scripts.xcode_cloud.extract import extract_test_failure_summaries

        for line in extract_test_failure_summaries(Path(args.bundle_path)):
            print(line)
        return 0

    if args.command == "comment-build":
        return _publish_comment_build(args, parser)

    if args.command == "comment-commit":
        import json
        import os

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

    if args.command == "wait-for-commit-report":
        import json
        import os

        token = os.environ.get("GITHUB_TOKEN")
        if not token:
            parser.error("GITHUB_TOKEN is required for wait-for-commit-report")

        try:
            report = wait_for_commit_report(
                args.repo,
                args.commit_sha,
                token=token,
                timeout_seconds=args.timeout_seconds,
                poll_interval_seconds=args.poll_interval_seconds,
            )
        except TimeoutError as error:
            print(str(error), file=sys.stderr)
            return 1

        print(f"Build report status: {report.status.value}")
        print(f"Comment: {report.comment_url}")
        if args.output_json:
            Path(args.output_json).write_text(json.dumps(report.payload, indent=2))
            print(f"Wrote status payload to {args.output_json}")
        return 0 if report.status == BuildStatus.SUCCESS else 1

    if args.command == "comment-pr":
        parser.error("comment-pr was removed; use comment-build or wait-for-commit-report")

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

    credentials = credentials_from_env()
    output_dir = Path(args.output_dir)
    build_succeeded = True

    with XcodeCloudClient(lambda: create_asc_token(credentials)) as client:
        run_id = getattr(args, "run_id", None)

        if args.command == "trigger-and-fetch":
            trigger_result = trigger_and_wait(
                client,
                args.workflow_id,
                git_reference_id=getattr(args, "git_reference_id", None),
                branch=getattr(args, "branch", None),
                timeout_seconds=args.timeout_seconds,
                poll_interval_seconds=args.poll_interval_seconds,
            )
            run_id = trigger_result.build_run_id
            build_succeeded = trigger_result.status.completion_status == "SUCCEEDED"
            print(
                f"Triggered build run {run_id}; completed with status "
                f"{trigger_result.status.completion_status or 'UNKNOWN'}"
            )

        elif args.command == "wait-and-fetch":
            status = client.wait_for_build_run(
                args.run_id,
                timeout_seconds=args.timeout_seconds,
                poll_interval_seconds=args.poll_interval_seconds,
            )
            run_id = status.run_id
            build_succeeded = status.completion_status == "SUCCEEDED"
            print(
                f"Build run {status.run_id} completed with status "
                f"{status.completion_status or 'UNKNOWN'}"
            )

        assert run_id is not None

        if getattr(args, "skip_extract", False):
            _, artifact_id, bundle_path = fetch_test_result_bundle(
                client,
                run_id,
                output_dir,
            )
            print(f"Downloaded artifact {artifact_id} to {bundle_path}")
            return 0 if build_succeeded else 1

        try:
            result = fetch_screenshots_from_build_run(
                client,
                run_id,
                output_dir,
                only_failures=getattr(args, "only_failures", False),
            )
        except XcresultToolNotFoundError as error:
            print(str(error), file=sys.stderr)
            return 2

        print(f"Test action: {result.test_action_id}")
        print(f"Artifact: {result.artifact_id}")
        print(f"Bundle: {result.bundle_path}")
        _print_screenshots(result.screenshot_paths)
        return 0 if build_succeeded else 1


def _print_screenshots(screenshots: list[Path] | tuple[Path, ...]) -> None:
    if not screenshots:
        print("No screenshots found.")
        return
    print(f"Extracted {len(screenshots)} screenshot(s):")
    for path in screenshots:
        print(path)


def _read_what_to_test(args: argparse.Namespace) -> str | None:
    path = getattr(args, "what_to_test_file", None)
    if not path:
        return None
    text = Path(path).read_text().strip()
    return text or None


if __name__ == "__main__":
    raise SystemExit(main())
