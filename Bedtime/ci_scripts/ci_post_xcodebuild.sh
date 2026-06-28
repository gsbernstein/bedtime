#!/bin/sh
set -eu

# Runs on the Xcode Cloud Mac after xcodebuild finishes.
# Extracts screenshots locally (macOS + xcresulttool), uploads to a public bucket,
# then optionally posts a PR comment with embeddable image URLs.

OUTPUT_DIR="${CI_DERIVED_DATA_PATH:-/tmp}/xcode-cloud-screenshots"
SCREENSHOTS_DIR="$OUTPUT_DIR/screenshots"
MANIFEST_PATH="$OUTPUT_DIR/screenshots-manifest.json"
ONLY_FAILURES="${XCODE_CLOUD_SCREENSHOT_ONLY_FAILURES:-false}"
BUILD_ID="${CI_BUILD_ID:-unknown}"

if [ -z "${CI_RESULT_BUNDLE_PATH:-}" ]; then
  echo "ci_post_xcodebuild: CI_RESULT_BUNDLE_PATH is not set; skipping screenshot export."
  exit 0
fi

if [ ! -e "$CI_RESULT_BUNDLE_PATH" ]; then
  echo "ci_post_xcodebuild: result bundle not found at $CI_RESULT_BUNDLE_PATH"
  exit 0
fi

mkdir -p "$OUTPUT_DIR"

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
FETCH_SCRIPT="$REPO_ROOT/scripts/fetch_xcode_cloud_screenshots.py"

EXTRACT_ARGS="extract-local --bundle-path \"$CI_RESULT_BUNDLE_PATH\" --output-dir \"$OUTPUT_DIR\""
if [ "$ONLY_FAILURES" = "true" ]; then
  EXTRACT_ARGS="$EXTRACT_ARGS --only-failures"
fi

echo "ci_post_xcodebuild: exporting screenshots from $CI_RESULT_BUNDLE_PATH"
# shellcheck disable=SC2086
"$PYTHON_BIN" "$FETCH_SCRIPT" $EXTRACT_ARGS

if [ -n "${IMGUR_CLIENT_ID:-}" ] || [ -n "${SCREENSHOTS_S3_BUCKET:-}" ]; then
  echo "ci_post_xcodebuild: uploading screenshots to public image host"
  if [ -n "${SCREENSHOTS_S3_BUCKET:-}" ]; then
    "$PYTHON_BIN" -m pip install --quiet boto3
  fi
  "$PYTHON_BIN" "$FETCH_SCRIPT" upload-screenshots \
    --screenshots-dir "$SCREENSHOTS_DIR" \
    --build-id "$BUILD_ID" \
    --manifest "$MANIFEST_PATH"
fi

if [ -n "${GITHUB_REPOSITORY:-}" ] && [ -n "${GITHUB_PULL_REQUEST:-}" ] && [ -n "${GITHUB_TOKEN:-}" ]; then
  echo "ci_post_xcodebuild: posting screenshot summary to PR #${GITHUB_PULL_REQUEST}"
  COMMENT_ARGS="comment-pr --repo \"$GITHUB_REPOSITORY\" --pr-number \"$GITHUB_PULL_REQUEST\" --run-id \"$BUILD_ID\""
  if [ -f "$MANIFEST_PATH" ]; then
    COMMENT_ARGS="$COMMENT_ARGS --manifest \"$MANIFEST_PATH\""
  else
    COMMENT_ARGS="$COMMENT_ARGS --screenshots-dir \"$SCREENSHOTS_DIR\""
  fi
  # shellcheck disable=SC2086
  "$PYTHON_BIN" "$FETCH_SCRIPT" $COMMENT_ARGS
fi

echo "ci_post_xcodebuild: screenshots available in $SCREENSHOTS_DIR"
