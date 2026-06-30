#!/bin/sh
set -eu

# Generate TestFlight "What to Test" notes after a successful archive upload.
# https://developer.apple.com/documentation/xcode/including-notes-for-testers-with-a-beta-release-of-your-app

if [ -z "${CI_APP_STORE_SIGNED_APP_PATH:-}" ] || [ ! -d "$CI_APP_STORE_SIGNED_APP_PATH" ]; then
  exit 0
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)}"
TESTFLIGHT_DIR="$PROJECT_DIR/TestFlight"
WHAT_TO_TEST_FILE="$TESTFLIGHT_DIR/WhatToTest.en-US.txt"

BRANCH_NAME="${CI_PULL_REQUEST_SOURCE_BRANCH:-${CI_BRANCH:-${CI_TAG:-unknown}}}"

mkdir -p "$TESTFLIGHT_DIR"

{
  printf 'Branch: %s\n\n' "$BRANCH_NAME"

  if [ -d "$REPO_ROOT/.git" ]; then
    COMMIT_NOTES=$(git -C "$REPO_ROOT" log -1 --format=%B 2>/dev/null | awk '
      /^What to test:/ { capture=1; next }
      capture { print }
    ' | sed '/^[[:space:]]*$/d' || true)

    if [ -n "$COMMIT_NOTES" ]; then
      printf 'What to test:\n%s\n' "$COMMIT_NOTES"
    fi
  fi
} > "$WHAT_TO_TEST_FILE"

echo "ci_post_xcodebuild: wrote TestFlight notes to $WHAT_TO_TEST_FILE"
