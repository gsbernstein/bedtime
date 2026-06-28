# Xcode Cloud screenshot fetcher

Fetch UI test screenshots from Xcode Cloud after a build completes.

## Recommended flow: Imgur upload from Xcode Cloud

PR comments need **stable, public image URLs**. The simplest setup is **Imgur** — one free Client-ID, no AWS account, no bucket policies.

```text
UI tests finish on Xcode Cloud (macOS)
  → extract PNGs from CI_RESULT_BUNDLE_PATH   [macOS only]
  → upload to Imgur (anonymous)                 [IMGUR_CLIENT_ID only]
  → post PR comment with ![...](https://i.imgur.com/...)
```

Register an app at [api.imgur.com/oauth2/addclient](https://api.imgur.com/oauth2/addclient) (choose “anonymous usage without user authorization”), then add one Xcode Cloud secret:

```bash
IMGUR_CLIENT_ID="your-client-id"
```

Optional PR comment secrets:

```bash
GITHUB_TOKEN="..."
GITHUB_REPOSITORY="owner/repo"
GITHUB_PULL_REQUEST="123"
```

`Bedtime/ci_scripts/ci_post_xcodebuild.sh` handles extract → upload → comment automatically.

### Imgur caveats

- Images are **public** on Imgur
- Free tier has **rate limits** (~1,250 uploads/day per Client-ID)
- Imgur’s terms restrict **commercial** use on the free API — fine for side projects / internal CI, not for a production SaaS

## macOS requirement (extraction)

| Step | Runs on | Tool |
|------|---------|------|
| Trigger build | anywhere | App Store Connect API |
| Wait / download `.xcresult` | anywhere | App Store Connect API |
| **Extract PNGs** | **macOS only** | `xcresulttool` (ships with Xcode) |
| Upload to Imgur | anywhere | `IMGUR_CLIENT_ID` |
| Post PR comment | anywhere | `GITHUB_TOKEN` |

On Linux agents, use `--skip-extract` and let `ci_post_xcodebuild.sh` do extraction on the Xcode Cloud Mac.

## Alternatives to Imgur

| Option | Auth needed | Notes |
|--------|-------------|-------|
| **Imgur** | Client-ID only | Easiest; recommended default |
| **S3 / R2** | AWS keys + bucket policy | More control; set `SCREENSHOTS_S3_BUCKET` |
| **GitHub drag-and-drop URLs** | Browser session | No stable API with `GITHUB_TOKEN` alone |

S3 is still supported if you set `SCREENSHOTS_UPLOAD_BACKEND=s3` or only configure S3 env vars.

## Xcode Cloud secrets (S3 alternative)

```bash
SCREENSHOTS_S3_BUCKET="my-public-screenshots"
SCREENSHOTS_PUBLIC_BASE_URL="https://cdn.example.com"
AWS_ACCESS_KEY_ID="..."
AWS_SECRET_ACCESS_KEY="..."
```

## App Store Connect API (trigger from outside Xcode Cloud)

```bash
export APP_STORE_CONNECT_KEY_ID="..."
export APP_STORE_CONNECT_ISSUER_ID="..."
export APP_STORE_CONNECT_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
```

```bash
# Trigger, block until done, fetch (use --skip-extract on Linux)
python3 scripts/fetch_xcode_cloud_screenshots.py trigger-and-fetch \
  --workflow-id WORKFLOW_ID \
  --branch main
```

## Manual upload + PR comment

```bash
export IMGUR_CLIENT_ID="..."

python3 scripts/fetch_xcode_cloud_screenshots.py upload-screenshots \
  --screenshots-dir ./xcode-cloud-output/screenshots \
  --build-id BUILD_RUN_ID \
  --backend imgur

python3 scripts/fetch_xcode_cloud_screenshots.py comment-pr \
  --repo owner/repo \
  --pr-number 123 \
  --run-id BUILD_RUN_ID \
  --manifest ./xcode-cloud-output/screenshots-manifest.json
```

## Tests

```bash
cd scripts
python3 -m pip install -r requirements-dev.txt
python3 -m pytest
```
