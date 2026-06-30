#!/bin/sh
set -eu

# Runs on the Xcode Cloud Mac after xcodebuild finishes.
# Always posts a terminal sticky commit comment for agents to poll:
# success (screenshot diff), failed (build/test errors), or no_screenshots.

OUTPUT_DIR="${CI_DERIVED_DATA_PATH:-/tmp}/xcode-cloud-screenshots"
SCREENSHOTS_DIR="$OUTPUT_DIR/screenshots"
ONLY_FAILURES="${XCODE_CLOUD_SCREENSHOT_ONLY_FAILURES:-false}"
BUILD_ID="${CI_BUILD_ID:-unknown}"
XCODEBUILD_EXIT="${CI_XCODEBUILD_EXIT_CODE:-0}"

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
FETCH_SCRIPT="$REPO_ROOT/scripts/fetch_xcode_cloud_screenshots.py"

COMMIT_SHA="${CI_COMMIT:-}"
REPO_SLUG="${GITHUB_REPOSITORY:-${CI_PULL_REQUEST_TARGET_REPO:-${CI_PULL_REQUEST_SOURCE_REPO:-}}}"
BASELINE_COMMIT="${CI_PULL_REQUEST_TARGET_COMMIT:-}"

WHAT_TO_TEST=""
if [ -d "$REPO_ROOT/.git" ]; then
  WHAT_TO_TEST="$(git -C "$REPO_ROOT" log -1 --format=%B 2>/dev/null | awk '
    /^What to test:/ { capture=1; next }
    capture { print }
  ' | sed '/^[[:space:]]*$/d' || true)"
fi

mkdir -p "$OUTPUT_DIR"
ERRORS_FILE="$OUTPUT_DIR/errors.txt"
: > "$ERRORS_FILE"

COMMENT_ARGS="--repo \"$REPO_SLUG\" --commit-sha \"$COMMIT_SHA\" --run-id \"$BUILD_ID\""
if [ -n "$BASELINE_COMMIT" ] && [ "$BASELINE_COMMIT" != "$COMMIT_SHA" ]; then
  COMMENT_ARGS="$COMMENT_ARGS --baseline-commit \"$BASELINE_COMMIT\""
fi
if [ -n "$WHAT_TO_TEST" ]; then
  WHAT_TO_TEST_FILE="$OUTPUT_DIR/what-to-test.txt"
  printf '%s\n' "$WHAT_TO_TEST" > "$WHAT_TO_TEST_FILE"
  COMMENT_ARGS="$COMMENT_ARGS --what-to-test-file \"$WHAT_TO_TEST_FILE\""
fi

append_failures_from_bundle() {
  if [ -e "${CI_RESULT_BUNDLE_PATH:-}" ]; then
    "$PYTHON_BIN" "$FETCH_SCRIPT" extract-failures \
      --bundle-path "$CI_RESULT_BUNDLE_PATH" >> "$ERRORS_FILE" 2>/dev/null || true
  fi
}

publish_report() {
  if [ -z "$REPO_SLUG" ] || [ -z "$COMMIT_SHA" ] || [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "ci_post_xcodebuild: skipping commit report (need repo, commit, GITHUB_TOKEN)"
    return 0
  fi

  echo "ci_post_xcodebuild: publishing build report on commit ${COMMIT_SHA}"
  "$PYTHON_BIN" -m pip install --quiet -r "$REPO_ROOT/scripts/requirements.txt"
  # shellcheck disable=SC2086
  "$PYTHON_BIN" "$FETCH_SCRIPT" comment-build $COMMENT_ARGS
}

if [ "$XCODEBUILD_EXIT" != "0" ]; then
  echo "ci_post_xcodebuild: xcodebuild failed with exit code ${XCODEBUILD_EXIT}"
  printf '%s\n' "xcodebuild failed with exit code ${XCODEBUILD_EXIT}" >> "$ERRORS_FILE"
  if [ -n "${CI_XCODEBUILD_ACTION:-}" ]; then
    printf '%s\n' "Action: ${CI_XCODEBUILD_ACTION}" >> "$ERRORS_FILE"
  fi
  if [ -n "${CI_BUILD_URL:-}" ]; then
    printf '%s\n' "Build logs: ${CI_BUILD_URL}" >> "$ERRORS_FILE"
  fi
  append_failures_from_bundle
  COMMENT_ARGS="$COMMENT_ARGS --status failed --exit-code \"$XCODEBUILD_EXIT\" --errors-file \"$ERRORS_FILE\""
  publish_report || true
  exit 0
fi

if [ -z "${CI_RESULT_BUNDLE_PATH:-}" ] || [ ! -e "$CI_RESULT_BUNDLE_PATH" ]; then
  echo "ci_post_xcodebuild: no test result bundle available"
  printf '%s\n' "No test result bundle was produced." >> "$ERRORS_FILE"
  COMMENT_ARGS="$COMMENT_ARGS --status no_screenshots --errors-file \"$ERRORS_FILE\""
  publish_report || true
  exit 0
fi

EXTRACT_ARGS="extract-local --bundle-path \"$CI_RESULT_BUNDLE_PATH\" --output-dir \"$OUTPUT_DIR\""
if [ "$ONLY_FAILURES" = "true" ]; then
  EXTRACT_ARGS="$EXTRACT_ARGS --only-failures"
fi

echo "ci_post_xcodebuild: exporting screenshots from $CI_RESULT_BUNDLE_PATH"
set +e
# shellcheck disable=SC2086
"$PYTHON_BIN" "$FETCH_SCRIPT" $EXTRACT_ARGS
EXTRACT_EXIT=$?
set -eu

if [ "$EXTRACT_EXIT" -ne 0 ]; then
  printf '%s\n' "Screenshot extraction failed with exit code ${EXTRACT_EXIT}" >> "$ERRORS_FILE"
  append_failures_from_bundle
  COMMENT_ARGS="$COMMENT_ARGS --status failed --exit-code \"$EXTRACT_EXIT\" --errors-file \"$ERRORS_FILE\""
  publish_report || true
  exit 0
fi

SCREENSHOT_COUNT=0
if [ -d "$SCREENSHOTS_DIR" ]; then
  SCREENSHOT_COUNT="$(find "$SCREENSHOTS_DIR" -name '*.png' -type f | wc -l | tr -d ' ')"
fi

if [ "$SCREENSHOT_COUNT" = "0" ]; then
  echo "ci_post_xcodebuild: no screenshot PNGs extracted"
  printf '%s\n' "No screenshot PNG attachments were found in the test result bundle." >> "$ERRORS_FILE"
  append_failures_from_bundle
  COMMENT_ARGS="$COMMENT_ARGS --status no_screenshots --errors-file \"$ERRORS_FILE\""
  publish_report || true
  exit 0
fi

if [ -z "${IMGUR_CLIENT_ID:-}" ]; then
  echo "ci_post_xcodebuild: IMGUR_CLIENT_ID is not set"
  printf '%s\n' "IMGUR_CLIENT_ID is not configured for screenshot upload." >> "$ERRORS_FILE"
  COMMENT_ARGS="$COMMENT_ARGS --status failed --errors-file \"$ERRORS_FILE\""
  publish_report || true
  exit 0
fi

COMMENT_ARGS="$COMMENT_ARGS --status success --screenshots-dir \"$SCREENSHOTS_DIR\""
publish_report || true

echo "ci_post_xcodebuild: screenshots available in $SCREENSHOTS_DIR"
