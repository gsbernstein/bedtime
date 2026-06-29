# Xcode Cloud screenshots

## Recommended: git-triggered workflow (no API polling)

The cleanest setup avoids App Store Connect API credentials entirely:

```text
main push                   →  screenshots on commit, Imgur URLs in commit comment
PR push                     →  compare vs main baseline commit comment, sticky comment on PR commit
git push screenshots/pr-42  →  on-demand screenshot run (branch start condition)
```

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
IMGUR_CLIENT_ID=...          # public image URLs
GITHUB_TOKEN=...             # sticky commit comments
```

`GITHUB_TOKEN` needs permission to create and update **commit comments** (`repo` scope or fine-grained equivalent).

No `APP_STORE_CONNECT_*` keys needed for the git-trigger path. No S3, no separate baseline branch.

### Sticky commit comments with before/after diffs

Screenshots are reported as a **commit comment** on the built commit (`github.com/{owner}/{repo}/commit/{sha}`). No PR required.

**Main builds** (`CI_COMMIT` on `main`):

1. Upload screenshots to Imgur
2. Post/update one sticky comment on that commit
3. Embed Imgur URLs in a hidden metadata block inside the comment (for baseline lookup)

**PR builds**:

1. Read Imgur URLs from the commit comment on `CI_PULL_REQUEST_TARGET_COMMIT` (main HEAD)
2. Download those images as the "before" baseline
3. Compare pixel-by-pixel against new screenshots
4. Post/update sticky comment on `CI_COMMIT` (PR head) with before/after table for changed/new only

First PR run after a fresh main baseline shows all screenshots as **new**. Unchanged PR re-runs show "no changes compared to `{main_sha}`".

### 3. Trigger from your machine or a Cursor agent

```bash
# On-demand screenshots for PR 42 with notes
./scripts/trigger-screenshots.sh --pr 42 --notes "Verify home + settings after sleep bank changes"

# Or push a tag (if the workflow uses tag start conditions)
./scripts/trigger-screenshots.sh --tag release-1.0 --notes "Release candidate UI pass"
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
python3 scripts/fetch_xcode_cloud_screenshots.py comment-commit \
  --repo owner/repo \
  --commit-sha abc123def456 \
  --baseline-commit mainsha789 \
  --run-id build-1 \
  --screenshots-dir ./screenshots
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

This still polls until the build completes. Prefer git push when possible.
