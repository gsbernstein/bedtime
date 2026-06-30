#!/bin/zsh
set -eu

if [[ "${CI_XCODEBUILD_ACTION:-}" == "archive" && -d "${CI_APP_STORE_SIGNED_APP_PATH:-}" ]]; then
  # what to test
  TESTFLIGHT_DIR_PATH=../TestFlight
  mkdir -p "$TESTFLIGHT_DIR_PATH"
  echo "Branch: $CI_BRANCH" >! "$TESTFLIGHT_DIR_PATH/WhatToTest.en-US.txt"
fi
