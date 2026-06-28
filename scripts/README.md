# Xcode Cloud screenshot fetcher

Fetch UI test screenshots from Xcode Cloud after a build completes.

## Why not a GitHub Action?

A GitHub Action is **optional**, not required. It was only suggested earlier because `xcresulttool` needs macOS.

This repo uses two paths instead:

1. **`Bedtime/ci_scripts/ci_post_xcodebuild.sh`** (recommended on Xcode Cloud)
   Runs on Apple's Mac right after tests finish. It reads `CI_RESULT_BUNDLE_PATH` directly, so there is no API round-trip and no second macOS runner.

2. **`scripts/fetch_xcode_cloud_screenshots.py fetch`**
   For webhook handlers, local machines, or Cursor Cloud Agents. Downloads the test result bundle via the App Store Connect API, then extracts screenshots if `xcresulttool` is available.

Use a GitHub Action only if you want extraction to happen outside Xcode Cloud.

## Setup

```bash
cd scripts
python3 -m pip install -r requirements-dev.txt
```

### Credentials (Runtime Secrets in Cursor, or local env)

```bash
export APP_STORE_CONNECT_KEY_ID="..."
export APP_STORE_CONNECT_ISSUER_ID="..."
export APP_STORE_CONNECT_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
```

Optional for PR comments from `ci_post_xcodebuild.sh`:

```bash
export GITHUB_TOKEN="..."
export GITHUB_REPOSITORY="owner/repo"
export GITHUB_PULL_REQUEST="123"
```

## Usage

Trigger a build, block until it finishes, then fetch screenshots (fully synchronous):

```bash
python3 scripts/fetch_xcode_cloud_screenshots.py trigger-and-fetch \
  --workflow-id WORKFLOW_ID \
  --branch main
```

Poll an already-triggered build until complete, then fetch:

```bash
python3 scripts/fetch_xcode_cloud_screenshots.py wait-and-fetch --run-id BUILD_RUN_ID
```

Fetch a completed build:

```bash
python3 scripts/fetch_xcode_cloud_screenshots.py fetch --run-id BUILD_RUN_ID
```

Download only (skip extraction on Linux):

```bash
python3 scripts/fetch_xcode_cloud_screenshots.py fetch --run-id BUILD_RUN_ID --skip-extract
```

Extract from a local bundle (Xcode Cloud Mac or your laptop):

```bash
python3 scripts/fetch_xcode_cloud_screenshots.py extract-local \
  --bundle-path /path/to/resultbundle.xcresult
```

Post a PR summary comment:

```bash
python3 scripts/fetch_xcode_cloud_screenshots.py comment-pr \
  --repo owner/repo \
  --pr-number 123 \
  --run-id BUILD_RUN_ID \
  --screenshots-dir ./xcode-cloud-output/screenshots
```

## Tests

```bash
cd scripts
python3 -m pytest
```

## Flow

```text
Xcode Cloud test action finishes
  ├─ ci_post_xcodebuild.sh (on Mac)
  │    └─ extract from CI_RESULT_BUNDLE_PATH
  │
  └─ webhook / manual fetch (anywhere)
       └─ App Store Connect API → temporary downloadUrl
            └─ download .xcresult
                 └─ xcresulttool export attachments (macOS)
                      └─ optional GitHub PR comment
```

Apple's `downloadUrl` values are short-lived. Do not embed them directly in PRs. Extract PNGs and upload or reference stable assets instead.
