#!/bin/sh
set -eu

# Runs on the Xcode Cloud Mac after xcodebuild finishes.
# Extracts screenshots, uploads to Imgur/S3, posts a PR comment.

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

# PR context: Xcode Cloud sets CI_PULL_REQUEST_* on PR builds; git-triggered
# screenshot branches can encode the PR number as screenshots/pr-42.
PR_NUMBER="${GITHUB_PULL_REQUEST:-${CI_PULL_REQUEST_NUMBER:-}}"
REPO_SLUG="${GITHUB_REPOSITORY:-${CI_PULL_REQUEST_TARGET_REPO:-}}"

if [ -z "$PR_NUMBER" ] && [ -n "${CI_BRANCH:-}" ]; then
  case "$CI_BRANCH" in
    screenshots/pr-*)
      PR_NUMBER="${CI_BRANCH#screenshots/pr-}"
      ;;
  esac
fi

if [ -z "$REPO_SLUG" ] && [ -n "${CI_PULL_REQUEST_TARGET_REPO:-}" ]; then
  REPO_SLUG="$CI_PULL_REQUEST_TARGET_REPO"
fi

WHAT_TO_TEST=""
if [ -d "$REPO_ROOT/.git" ]; then
  WHAT_TO_TEST="$(git -C "$REPO_ROOT" log -1 --format=%B 2>/dev/null | awk '
    /^What to test:/ { capture=1; next }
    capture { print }
  ' | sed '/^[[:space:]]*$/d' || true)"
fi

if [ -n "$REPO_SLUG" ] && [ -n "$PR_NUMBER" ] && [ -n "${GITHUB_TOKEN:-}" ]; then
  echo "ci_post_xcodebuild: posting screenshot summary to PR #${PR_NUMBER}"
  COMMENT_ARGS="comment-pr --repo \"$REPO_SLUG\" --pr-number \"$PR_NUMBER\" --run-id \"$BUILD_ID\""
  if [ -f "$MANIFEST_PATH" ]; then
    COMMENT_ARGS="$COMMENT_ARGS --manifest \"$MANIFEST_PATH\""
  else
    COMMENT_ARGS="$COMMENT_ARGS --screenshots-dir \"$SCREENSHOTS_DIR\""
  fi
  if [ -n "$WHAT_TO_TEST" ]; then
  WHAT_TO_TEST_FILE="$OUTPUT_DIR/what-to-test.txt"
  printf '%s\n' "$WHAT_TO_TEST" > "$WHAT_TO_TEST_FILE"
  COMMENT_ARGS="$COMMENT_ARGS --what-to-test-file \"$WHAT_TO_TEST_FILE\""
  fi
  # shellcheck disable=SC2086
  "$PYTHON_BIN" "$FETCH_SCRIPT" $COMMENT_ARGS
elif [ -f "$MANIFEST_PATH" ]; then
  echo "ci_post_xcodebuild: public screenshot URLs"
  "$PYTHON_BIN" - "$MANIFEST_PATH" <<'PY'
import json, sys
for item in json.load(open(sys.argv[1]))["screenshots"]:
    print(item["url"])
PY
fi

echo "ci_post_xcodebuild: screenshots available in $SCREENSHOTS_DIR"
