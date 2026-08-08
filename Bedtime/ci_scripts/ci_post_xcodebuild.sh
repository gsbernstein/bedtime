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

  # what to test
  TESTFLIGHT_DIR_PATH=../TestFlight
  mkdir -p "$TESTFLIGHT_DIR_PATH"
  echo "$WHAT_TO_TEST" >! "$TESTFLIGHT_DIR_PATH/WhatToTest.en-US.txt"
fi
