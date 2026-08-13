#!/bin/zsh
set -eu

if [[ "${CI_XCODEBUILD_ACTION:-}" == "archive" && -d "${CI_APP_STORE_SIGNED_APP_PATH:-}" ]]; then
  # Xcode Cloud sets CI_BRANCH only when a branch change started the build; pull request and
  # tag builds report their source in other variables. Reading an unset one would abort this
  # script under `set -u`, taking the whole archive action with it.
  if [[ -n "${CI_BRANCH:-}" ]]; then
    WHAT_TO_TEST="Branch: $CI_BRANCH"
  elif [[ -n "${CI_PULL_REQUEST_SOURCE_BRANCH:-}" ]]; then
    WHAT_TO_TEST="Pull request: $CI_PULL_REQUEST_SOURCE_BRANCH"
  elif [[ -n "${CI_TAG:-}" ]]; then
    WHAT_TO_TEST="Tag: $CI_TAG"
  else
    WHAT_TO_TEST="Build ${CI_BUILD_NUMBER:-unknown}"
  fi

  # Xcode Cloud doesn't expose the commit message as an environment variable, so read the latest
  # commit subject from the checked-out repo. Guard against git failing (e.g. missing repo path)
  # so a lookup failure doesn't abort the archive action under `set -e`.
  if [[ -n "${CI_PRIMARY_REPOSITORY_PATH:-}" ]]; then
    COMMIT_MESSAGE="$(git -C "$CI_PRIMARY_REPOSITORY_PATH" log -1 --pretty=%s 2>/dev/null || true)"
    if [[ -n "$COMMIT_MESSAGE" ]]; then
      WHAT_TO_TEST="$WHAT_TO_TEST"$'\n'"Commit: $COMMIT_MESSAGE"
    fi
  fi

  # what to test
  TESTFLIGHT_DIR_PATH=../TestFlight
  mkdir -p "$TESTFLIGHT_DIR_PATH"
  echo "$WHAT_TO_TEST" >! "$TESTFLIGHT_DIR_PATH/WhatToTest.en-US.txt"
fi
