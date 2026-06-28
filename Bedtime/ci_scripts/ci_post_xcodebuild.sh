#!/bin/sh
set -eu

# Runs on the Xcode Cloud Mac after xcodebuild finishes.
# Uses the local result bundle directly — no App Store Connect API download needed.

OUTPUT_DIR="${CI_DERIVED_DATA_PATH:-/tmp}/xcode-cloud-screenshots"
ONLY_FAILURES="${XCODE_CLOUD_SCREENSHOT_ONLY_FAILURES:-false}"

if [ -z "${CI_RESULT_BUNDLE_PATH:-}" ]; then
  echo "ci_post_xcodebuild: CI_RESULT_BUNDLE_PATH is not set; skipping screenshot export."
  exit 0
fi

if [ ! -e "$CI_RESULT_BUNDLE_PATH" ]; then
  echo "ci_post_xcodebuild: result bundle not found at $CI_RESULT_BUNDLE_PATH"
  exit 0
fi

mkdir -p "$OUTPUT_DIR"

ARGS="extract-local --bundle-path \"$CI_RESULT_BUNDLE_PATH\" --output-dir \"$OUTPUT_DIR\""
if [ "$ONLY_FAILURES" = "true" ]; then
  ARGS="$ARGS --only-failures"
fi

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

echo "ci_post_xcodebuild: exporting screenshots from $CI_RESULT_BUNDLE_PATH"
# shellcheck disable=SC2086
"$PYTHON_BIN" "$REPO_ROOT/scripts/fetch_xcode_cloud_screenshots.py" $ARGS

if [ -n "${GITHUB_REPOSITORY:-}" ] && [ -n "${GITHUB_PULL_REQUEST:-}" ] && [ -n "${GITHUB_TOKEN:-}" ]; then
  echo "ci_post_xcodebuild: posting screenshot summary to PR #${GITHUB_PULL_REQUEST}"
  "$PYTHON_BIN" "$REPO_ROOT/scripts/fetch_xcode_cloud_screenshots.py" comment-pr \
    --repo "$GITHUB_REPOSITORY" \
    --pr-number "$GITHUB_PULL_REQUEST" \
    --run-id "${CI_BUILD_ID:-unknown}" \
    --screenshots-dir "$OUTPUT_DIR/screenshots"
fi

echo "ci_post_xcodebuild: screenshots available in $OUTPUT_DIR/screenshots"
