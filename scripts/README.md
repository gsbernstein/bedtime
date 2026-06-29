# Xcode Cloud screenshots

## What generates the screenshots

**`BedtimeUITests/ScreenshotTests.swift`** — XCUITest UI tests that capture PNG attachments for pull request previews.

The test launches the app with `-ui_testing` (mock sleep data, no HealthKit prompt) and saves screenshots with `XCTAttachment` lifetime `.keepAlways` so Xcode Cloud keeps them in the test result bundle.

Add `BedtimeUITests` to your Xcode Cloud workflow's **Test** action. In the test plan, set **Screenshots** to **On, and keep all** if you want images even when tests pass.

### Run locally

```bash
xcodebuild test \
  -project Bedtime/Bedtime.xcodeproj \
  -scheme Bedtime \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:BedtimeUITests/ScreenshotTests
```

## What happens after tests (Xcode Cloud Mac)

`Bedtime/ci_scripts/ci_post_xcodebuild.sh`:

1. Extracts PNGs from `CI_RESULT_BUNDLE_PATH` via `xcresulttool`
2. Uploads to **Imgur** (`IMGUR_CLIENT_ID`) or **S3** (`SCREENSHOTS_S3_BUCKET`)
3. Optionally posts a PR comment with embedded image URLs

### Simplest upload setup (Imgur)

Register at [api.imgur.com/oauth2/addclient](https://api.imgur.com/oauth2/addclient), then add one Xcode Cloud secret:

```bash
IMGUR_CLIENT_ID="your-client-id"
```

Optional PR comment:

```bash
GITHUB_TOKEN="..."
GITHUB_REPOSITORY="owner/repo"
GITHUB_PULL_REQUEST="123"
```

## Optional: fetch scripts (outside Xcode Cloud)

`scripts/fetch_xcode_cloud_screenshots.py` can trigger builds, wait for completion, and download result bundles via the App Store Connect API. Extraction still requires macOS (`xcresulttool`).

```bash
export APP_STORE_CONNECT_KEY_ID=...
export APP_STORE_CONNECT_ISSUER_ID=...
export APP_STORE_CONNECT_PRIVATE_KEY='...'

python3 scripts/fetch_xcode_cloud_screenshots.py trigger-and-fetch \
  --workflow-id WORKFLOW_ID \
  --branch main
```

On Linux, use `--skip-extract` — let `ci_post_xcodebuild.sh` handle extraction on Apple's Mac.
