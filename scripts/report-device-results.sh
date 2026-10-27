#!/usr/bin/env bash
# Posts a passing device run to GitHub as a commit status (`device/ios`,
# `device/android`), which the publish workflow requires on the tagged commit:
#
#   bash scripts/report-device-results.sh <ios|android> [sha]   (sha: HEAD)
#
# The test scripts call it after a full, clean, passing run. The commit must
# be on GitHub first; for a run made before the push, push and run this.
set -euo pipefail

platform="$1"
root="$(cd "$(dirname "$0")/.." && pwd)"
sha="${2:-$(git -C "$root" rev-parse HEAD)}"
result="$root/.device-results/$platform-$sha.json"

passed="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["passed"])' "$result")"
[ "$passed" = True ] || { echo "$result did not pass; nothing reported." >&2; exit 1; }
device="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["device"])' "$result")"

gh api "repos/{owner}/{repo}/statuses/$sha" --silent \
  -f state=success -f context="device/$platform" -f description="passed on $device" ||
  { echo "Could not report $sha (pushed yet?). Push, then: bash scripts/report-device-results.sh $platform $sha" >&2; exit 1; }
echo "Reported device/$platform on $sha"
