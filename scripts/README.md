# Xcode Cloud screenshot fetcher

Fetch UI test screenshots from Xcode Cloud after a build completes.

## Recommended flow: Xcode Cloud uploads to a public bucket

PR comments need **stable, public image URLs**. Apple's artifact `downloadUrl` values expire, and extraction requires **macOS + Xcode** (`xcresulttool`).

The recommended path is to do everything on the **Xcode Cloud Mac** in `Bedtime/ci_scripts/ci_post_xcodebuild.sh`:

```text
UI tests finish on Xcode Cloud (macOS)
  → extract PNGs from CI_RESULT_BUNDLE_PATH   [macOS only]
  → upload to public S3/R2 bucket             [stable URLs]
  → post PR comment with embedded images
```

Anything that runs on Linux (Cursor Cloud Agent, webhook handler, `trigger-and-fetch` without `--skip-extract`) can **trigger** builds and **download** bundles, but cannot extract screenshots unless you move the `.xcresult` to a Mac.

## macOS requirement (extraction)

| Step | Runs on | Tool |
|------|---------|------|
| Trigger build | anywhere | App Store Connect API |
| Wait for completion | anywhere | App Store Connect API |
| Download `.xcresult` | anywhere | App Store Connect API |
| **Extract PNGs** | **macOS only** | `xcresulttool` (ships with Xcode) |
| Upload to public bucket | anywhere with AWS creds | `boto3` |
| Post PR comment | anywhere | GitHub API |

On Linux, use `--skip-extract` to download the bundle only. Do not expect `fetch` or `trigger-and-fetch` to produce PNGs on a Linux agent.

## Xcode Cloud setup (public bucket + PR embed)

Add these as **Xcode Cloud workflow secrets**:

```bash
# S3 or S3-compatible bucket with public read on the prefix (bucket policy, or CDN in front)
SCREENSHOTS_S3_BUCKET="my-public-screenshots"
SCREENSHOTS_S3_PREFIX="bedtime"
SCREENSHOTS_PUBLIC_BASE_URL="https://my-public-screenshots.s3.amazonaws.com"  # or CloudFront URL
AWS_ACCESS_KEY_ID="..."
AWS_SECRET_ACCESS_KEY="..."

# Optional: PR comment with embedded images
GITHUB_TOKEN="..."
GITHUB_REPOSITORY="owner/repo"
GITHUB_PULL_REQUEST="123"   # set via custom env / script if not automatic
```

For R2 or other S3-compatible storage:

```bash
SCREENSHOTS_S3_ENDPOINT_URL="https://<account>.r2.cloudflarestorage.com"
SCREENSHOTS_PUBLIC_BASE_URL="https://screenshots.example.com"
```

`ci_post_xcodebuild.sh` will:

1. Extract screenshots from `CI_RESULT_BUNDLE_PATH`
2. Upload PNGs when `SCREENSHOTS_S3_BUCKET` is set
3. Post a PR comment with `![name](url)` markdown when GitHub env vars are set

## App Store Connect API (trigger / fetch from outside Xcode Cloud)

```bash
export APP_STORE_CONNECT_KEY_ID="..."
export APP_STORE_CONNECT_ISSUER_ID="..."
export APP_STORE_CONNECT_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
```

### Fully synchronous trigger + wait + fetch

```bash
python3 scripts/fetch_xcode_cloud_screenshots.py trigger-and-fetch \
  --workflow-id WORKFLOW_ID \
  --branch main
```

On Linux, add `--skip-extract` and rely on `ci_post_xcodebuild.sh` for extraction + upload.

### Wait for an existing build, then fetch

```bash
python3 scripts/fetch_xcode_cloud_screenshots.py wait-and-fetch --run-id BUILD_RUN_ID
```

### Manual upload + PR comment (after extraction on a Mac)

```bash
python3 scripts/fetch_xcode_cloud_screenshots.py upload-screenshots \
  --screenshots-dir ./xcode-cloud-output/screenshots \
  --build-id BUILD_RUN_ID

python3 scripts/fetch_xcode_cloud_screenshots.py comment-pr \
  --repo owner/repo \
  --pr-number 123 \
  --run-id BUILD_RUN_ID \
  --manifest ./xcode-cloud-output/screenshots-manifest.json
```

## Local development

```bash
cd scripts
python3 -m pip install -r requirements-dev.txt
python3 -m pytest
```

## Why not a GitHub Action?

A GitHub Action is optional. It only helps if you want macOS extraction **outside** Xcode Cloud. If Xcode Cloud already runs your UI tests, `ci_post_xcodebuild.sh` is the simpler place to extract and upload — no second macOS runner.
