# Xcode Cloud screenshots

## Recommended: git-triggered workflow (no API polling)

The cleanest setup avoids App Store Connect API credentials entirely:

```text
main push                   →  screenshots on commit, Imgur URLs in commit comment
PR push                     →  compare vs main baseline commit comment, sticky comment on PR commit
git push screenshots/pr-42  →  on-demand screenshot run (branch start condition)
```

### Agent feedback loop

Cloud agents can trigger, poll, and iterate without watching Xcode Cloud directly:

```text
1. ./scripts/trigger-screenshots.sh --pr 42 --notes "Check home screen"
2. Poll until a terminal commit comment appears:
     python3 scripts/fetch_xcode_cloud_screenshots.py wait-for-commit-report \
       --repo owner/repo --commit-sha <sha printed by trigger script>
3. Read status from the hidden JSON block:
     success        → screenshot diff table + Imgur URLs
     failed         → xcodebuild/test errors to fix
     no_screenshots → tests ran but no PNG attachments
4. Fix code, push again, repeat
```

`ci_post_xcodebuild.sh` **always** posts a terminal commit comment when `GITHUB_TOKEN` and `CI_COMMIT` are set — including build failures — so agents do not poll forever.

### 1. Create a dedicated Xcode Cloud workflow

In Xcode or App Store Connect, add a **Screenshots** workflow with:

| Setting | Value |
|---------|--------|
| Start condition | **Branch changes** → `main` (keeps baseline fresh) |
| | and/or branches beginning with `screenshots/` |
| | and/or **Pull request changes** |
| Test action | Scheme `Bedtime`, include `BedtimeUITests` |
| Test plan | Screenshots: **On, and keep all** |

Keep this workflow separate from your main CI so screenshot runs do not block merges.

### 2. Xcode Cloud secrets

```bash
IMGUR_CLIENT_ID=...          # public image URLs (success path only)
GITHUB_TOKEN=...             # sticky commit comments (success + failure)
```

`GITHUB_TOKEN` needs permission to create and update **commit comments**.

No `APP_STORE_CONNECT_*` keys needed for the git-trigger path. No S3, no separate baseline branch.

### Sticky commit comments

Screenshots and build outcomes are reported as a **commit comment** on the built commit (`github.com/{owner}/{repo}/commit/{sha}`). No PR required.

**Main builds** (`CI_COMMIT` on `main`):

1. Upload screenshots to Imgur
2. Post/update one sticky comment on that commit
3. Embed Imgur URLs in hidden metadata for baseline lookup

**PR builds**:

1. Read Imgur URLs from the commit comment on `CI_PULL_REQUEST_TARGET_COMMIT` (main HEAD)
2. Compare pixel-by-pixel against new screenshots
3. Post/update sticky comment on `CI_COMMIT` with before/after table for changed/new only

**Failed builds** (`CI_XCODEBUILD_EXIT_CODE != 0`):

1. Skip screenshot upload
2. Post/update sticky comment with exit code, test failures, and build log URL

Hidden status block (for agents):

```html
<!-- bedtime-build-status
{"status":"failed","build_id":"...","exit_code":65,"errors":["..."]}
-->
```

### 3. Trigger from your machine or a Cursor agent

```bash
# On-demand screenshots for PR 42 with notes
./scripts/trigger-screenshots.sh --pr 42 --notes "Verify home + settings after sleep bank changes"

# Poll for outcome (commit SHA printed by trigger script)
python3 scripts/fetch_xcode_cloud_screenshots.py wait-for-commit-report \
  --repo owner/repo --commit-sha abc123def456 --output-json /tmp/report.json
```

Commit/tag message format (parsed automatically):

```text
screenshots: trigger

What to test:
- Home screen with mock sleep data
- Settings sliders and wake time picker
```

### 4. Manual CLI

```bash
# Publish outcomes directly
python3 scripts/fetch_xcode_cloud_screenshots.py comment-build \
  --repo owner/repo \
  --commit-sha abc123 \
  --baseline-commit mainsha789 \
  --run-id build-1 \
  --status success \
  --screenshots-dir ./screenshots

python3 scripts/fetch_xcode_cloud_screenshots.py comment-build \
  --repo owner/repo \
  --commit-sha abc123 \
  --run-id build-1 \
  --status failed \
  --exit-code 65 \
  --errors-file ./errors.txt
```

## What generates the screenshots

**`BedtimeUITests/ScreenshotTests.swift`** — XCUITest that saves `XCTAttachment` PNGs with `.keepAlways`.

```bash
xcodebuild test \
  -project Bedtime/Bedtime.xcodeproj \
  -scheme Bedtime \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:BedtimeUITests/ScreenshotTests
```

## Optional: App Store Connect API path

Only needed if you cannot push git refs (e.g. trigger from a system with no git write access):

```bash
python3 scripts/fetch_xcode_cloud_screenshots.py trigger-and-fetch \
  --workflow-id WORKFLOW_ID --branch main
```

This still polls App Store Connect until the build completes. Prefer git push + `wait-for-commit-report` when possible.
