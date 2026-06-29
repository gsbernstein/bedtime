#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Trigger an Xcode Cloud screenshot workflow via git push (no App Store Connect API).

Create a dedicated workflow in Xcode Cloud with a start condition for either:
  - branches beginning with screenshots/
  - tags beginning with screenshots/

Usage:
  scripts/trigger-screenshots.sh --pr 42 --notes "Check home and settings"
  scripts/trigger-screenshots.sh --branch feature/foo --notes "Dark mode pass"
  scripts/trigger-screenshots.sh --tag release-1.2.0 --notes "Release screenshots"

Options:
  --pr NUMBER       Target PR number (creates branch screenshots/pr-NUMBER)
  --branch NAME     Push to screenshots/NAME instead
  --tag NAME        Create annotated tag screenshots/NAME (use tag start condition)
  --notes TEXT      "What to test" notes included in the commit/tag message
  --dry-run         Print the git commands without running them
  -h, --help        Show this help

The commit/tag message uses this format:

  screenshots: trigger

  What to test:
  <your notes>
EOF
}

PR=""
BRANCH=""
TAG=""
NOTES=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr)
      PR="$2"
      shift 2
      ;;
    --branch)
      BRANCH="$2"
      shift 2
      ;;
    --tag)
      TAG="$2"
      shift 2
      ;;
    --notes)
      NOTES="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -n "$PR" && ( -n "$BRANCH" || -n "$TAG" ) ]]; then
  echo "Use only one of --pr, --branch, or --tag" >&2
  exit 1
fi

if [[ -z "$PR" && -z "$BRANCH" && -z "$TAG" ]]; then
  echo "Provide --pr, --branch, or --tag" >&2
  usage >&2
  exit 1
fi

if [[ -n "$PR" ]]; then
  REF="screenshots/pr-${PR}"
elif [[ -n "$BRANCH" ]]; then
  REF="screenshots/${BRANCH}"
else
  REF="screenshots/${TAG}"
fi

MESSAGE=$'screenshots: trigger\n'
if [[ -n "$NOTES" ]]; then
  MESSAGE+=$'\nWhat to test:\n'"${NOTES}"$'\n'
fi

run() {
  if [[ "$DRY_RUN" == true ]]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

if [[ -n "$TAG" ]]; then
  run git tag -fa "$REF" -m "$MESSAGE"
  run git push origin "$REF" --force
  echo "Pushed tag $REF"
else
  CURRENT_BRANCH="$(git branch --show-current)"
  run git checkout -B "$REF"
  run git commit --allow-empty -m "$MESSAGE"
  run git push -u origin "$REF"
  if [[ -n "$CURRENT_BRANCH" ]]; then
    run git checkout "$CURRENT_BRANCH"
  fi
  echo "Pushed branch $REF"
fi

echo "Xcode Cloud should start the screenshots workflow shortly."
