#!/bin/sh
set -eu

# Runs on the Xcode Cloud Mac after xcodebuild finishes.
# Extracts screenshots, compares to the main-branch baseline commit comment,
# uploads to Imgur, and updates a sticky comment on this commit.

OUTPUT_DIR="${CI_DERIVED_DATA_PATH:-/tmp}/xcode-cloud-screenshots"
SCREENSHOTS_DIR="$OUTPUT_DIR/screenshots"
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

if [ -n "$REPO_SLUG" ] && [ -n "$COMMIT_SHA" ] && [ -n "${GITHUB_TOKEN:-}" ] && [ -n "${IMGUR_CLIENT_ID:-}" ]; then
  echo "ci_post_xcodebuild: publishing sticky screenshot comment on commit ${COMMIT_SHA}"
  "$PYTHON_BIN" -m pip install --quiet -r "$REPO_ROOT/scripts/requirements.txt"
  COMMENT_ARGS="comment-commit --repo \"$REPO_SLUG\" --commit-sha \"$COMMIT_SHA\" --run-id \"$BUILD_ID\" --screenshots-dir \"$SCREENSHOTS_DIR\""
  if [ -n "$BASELINE_COMMIT" ] && [ "$BASELINE_COMMIT" != "$COMMIT_SHA" ]; then
    COMMENT_ARGS="$COMMENT_ARGS --baseline-commit \"$BASELINE_COMMIT\""
    echo "ci_post_xcodebuild: comparing against baseline commit ${BASELINE_COMMIT}"
  fi
  if [ -n "$WHAT_TO_TEST" ]; then
    WHAT_TO_TEST_FILE="$OUTPUT_DIR/what-to-test.txt"
    printf '%s\n' "$WHAT_TO_TEST" > "$WHAT_TO_TEST_FILE"
    COMMENT_ARGS="$COMMENT_ARGS --what-to-test-file \"$WHAT_TO_TEST_FILE\""
  fi
  # shellcheck disable=SC2086
  "$PYTHON_BIN" "$FETCH_SCRIPT" $COMMENT_ARGS
elif [ -n "${IMGUR_CLIENT_ID:-}" ] || [ -n "${SCREENSHOTS_S3_BUCKET:-}" ]; then
  echo "ci_post_xcodebuild: uploading screenshots without commit comment"
  if [ -n "${SCREENSHOTS_S3_BUCKET:-}" ]; then
    "$PYTHON_BIN" -m pip install --quiet boto3
  fi
  "$PYTHON_BIN" -m pip install --quiet -r "$REPO_ROOT/scripts/requirements.txt"
  "$PYTHON_BIN" "$FETCH_SCRIPT" upload-screenshots \
    --screenshots-dir "$SCREENSHOTS_DIR" \
    --build-id "$BUILD_ID" \
    --manifest "$OUTPUT_DIR/screenshots-manifest.json"
fi

echo "ci_post_xcodebuild: screenshots available in $SCREENSHOTS_DIR"
