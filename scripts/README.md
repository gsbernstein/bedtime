# Xcode Cloud screenshots

## Recommended: git-triggered workflow (no API polling)

The cleanest setup avoids App Store Connect API credentials entirely:

```text
git push screenshots/pr-42     →  Xcode Cloud starts (branch/tag start condition)
  → BedtimeUITests capture PNGs
  → ci_post_xcodebuild compares to previous baseline
  → updates one sticky PR comment (before/after for changed screenshots only)
```

### 1. Create a dedicated Xcode Cloud workflow

In Xcode or App Store Connect, add a **Screenshots** workflow with:

| Setting | Value |
|---------|--------|
| Start condition | **Branch changes** → branches beginning with `screenshots/` |
| | and/or **Tag changes** → tags beginning with `screenshots/` |
| | and/or **Pull request changes** (runs on every PR automatically) |
| Test action | Scheme `Bedtime`, include `BedtimeUITests` |
| Test plan | Screenshots: **On, and keep all** |

Keep this workflow separate from your main CI so screenshot runs do not block merges.

### 2. Xcode Cloud secrets

```bash
IMGUR_CLIENT_ID=...          # public image URLs
GITHUB_TOKEN=...             # sticky PR comment + screenshot-baselines branch
```

`GITHUB_TOKEN` needs permission to write issue comments and repository contents (for the per-PR baseline manifest on branch `screenshot-baselines`).

No `APP_STORE_CONNECT_*` keys needed for the git-trigger path.

### Sticky PR comment with before/after diffs

Each PR keeps **one** screenshot comment (updated in place, not a new comment per build).

1. Load the previous baseline from `screenshot-baselines` → `prs/{number}/manifest.json`
2. Download previous images from the stored Imgur URLs
3. Compare pixel-by-pixel against the new screenshots
4. Embed a before/after table for **changed** and **new** screenshots only
5. Save the new baseline manifest for the next run

First run on a PR shows all screenshots as **new**. Later runs only surface diffs.

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

### 4. PR builds (zero extra trigger)

If the workflow includes a **Pull request** start condition, every PR push already runs screenshots. Xcode Cloud sets `CI_PULL_REQUEST_NUMBER` and `CI_PULL_REQUEST_TARGET_REPO` — no manual `GITHUB_PULL_REQUEST` env var needed.

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
