# Xcode Cloud screenshots

Every push runs Xcode Cloud. `ci_post_xcodebuild.sh` extracts UI test screenshots, uploads them to Imgur, and posts a sticky **commit comment** with results.

## Flow

```text
push to main  →  tests capture screenshots  →  commit comment (full set, becomes baseline)

push to PR    →  tests capture screenshots  →  commit comment (diff vs main baseline)
```

Cursor (or any agent) can **wait for CI to finish**, then read the commit comment on that push's SHA for screenshots, diffs, or failure details.

## Xcode Cloud setup

Add a workflow (or use your existing per-push workflow) with:

| Setting | Value |
|---------|--------|
| Start condition | **Every push** (branch + pull request) |
| Test action | Scheme `Bedtime`, include `BedtimeUITests` |
| Test plan | Screenshots: **On, and keep all** |

### Secrets

```bash
IMGUR_CLIENT_ID=...    # public image URLs (success path)
GITHUB_TOKEN=...       # commit comments (success + failure)
```

`GITHUB_TOKEN` needs permission to create and update **commit comments**.

## Commit comments

Reports appear on `github.com/{owner}/{repo}/commit/{sha}` (Commits tab on PRs).

**Main builds** — upload all screenshots to Imgur; embed URLs in the comment for baseline lookup.

**PR builds** — download main's baseline from `CI_PULL_REQUEST_TARGET_COMMIT`, pixel-compare, show before/after for changed and new screenshots only.

**Failed builds** — post exit code, test failures, and build log URL (no Imgur upload).

Hidden status block for programmatic reads:

```html
<!-- bedtime-build-status
{"status":"success","build_id":"...","screenshot_urls":{...}}
-->
```

## New screenshot scenarios

Use scenario-specific attachment names (e.g. `01-home-empty-bank`). When adding a new test case, **merge the test to main early** so main captures the baseline before the feature branch gets far ahead.

## Local / manual CLI

Used by `ci_post_xcodebuild.sh`; also runnable locally on a Mac with a `.xcresult` bundle:

```bash
python3 scripts/fetch_xcode_cloud_screenshots.py extract-local \
  --bundle-path /path/to/Result.xcresult \
  --output-dir ./screenshots

python3 scripts/fetch_xcode_cloud_screenshots.py comment-build \
  --repo owner/repo \
  --commit-sha abc123 \
  --baseline-commit mainsha789 \
  --run-id build-1 \
  --status success \
  --screenshots-dir ./screenshots
```

## What generates the screenshots

**`BedtimeUITests/ScreenshotTests.swift`** — XCUITest attachments with `.keepAlways`.

```bash
xcodebuild test \
  -project Bedtime/Bedtime.xcodeproj \
  -scheme Bedtime \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:BedtimeUITests/ScreenshotTests
```
