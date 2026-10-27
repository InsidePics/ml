#!/usr/bin/env bash
# The packages' JS API on a connected iPhone: test-apps/host built in Release
# (its JS bundled, no dev server), installed and launched; the app runs
# api-tests/ through Expo's real bridge and writes Documents/api-results.json,
# copied off here.
#
#   pnpm test:api:ios <device-udid> <team-id>
#
# On success the result lands in .device-results/api-ios-<sha>.json.
set -euo pipefail

udid="${1:?usage: $0 <device-udid> <team-id>}"
team="${2:?usage: $0 <device-udid> <team-id>}"
bundle_id="com.insidepics.mltesthost"

IOS_HOST_MODE=app source "$(dirname "$0")/lib/ios-host.sh"

derived="$host/ios/build/api"
xcodebuild build -quiet \
  -workspace ios/MLTestHost.xcworkspace -scheme MLTestHost -configuration Release \
  -destination "id=$udid" -derivedDataPath "$derived" -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$team" CODE_SIGN_STYLE=Automatic CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_IDENTITY="Apple Development"
app="$(find "$derived/Build/Products/Release-iphoneos" -maxdepth 1 -name '*.app' | head -1)"

xcrun devicectl device install app --device "$udid" "$app" > /dev/null
xcrun devicectl device process launch --device "$udid" --terminate-existing "$bundle_id" > /dev/null

out="$(mktemp -d)/api-results.json"
for _ in $(seq 1 120); do
  sleep 5
  if xcrun devicectl device copy from --device "$udid" --domain-type appDataContainer \
    --domain-identifier "$bundle_id" --source Documents/api-results.json \
    --destination "$out" > /dev/null 2>&1; then
    break
  fi
done
if [ ! -s "$out" ]; then
  progress="$(dirname "$out")/api-progress.json"
  xcrun devicectl device copy from --device "$udid" --domain-type appDataContainer \
    --domain-identifier "$bundle_id" --source Documents/api-progress.json \
    --destination "$progress" > /dev/null 2>&1 || true
  echo "No results from the device within 10 minutes. Progress:" >&2
  cat "$progress" >&2 2>/dev/null || echo "(none: the app never started the suite)" >&2
  exit 1
fi

results="$root/.device-results"
mkdir -p "$results"
sha="$(git -C "$root" rev-parse HEAD)"
dirty="$(git -C "$root" status --porcelain | wc -l | tr -d ' ')"
name="api-ios-$sha.json"
[ "$dirty" = 0 ] || name="api-ios-$sha-partial.json"
node -e '
  const results = require(process.argv[1]);
  const failed = results.filter((r) => !r.passed);
  for (const r of results) console.log(`${r.passed ? "✓" : "✗"} ${r.name}${r.passed ? "" : `\n    ${r.error}`}`);
  console.log(`\n${results.length - failed.length} passed, ${failed.length} failed`);
  require("fs").writeFileSync(process.argv[2], JSON.stringify({
    sha: process.argv[3], dirty: process.argv[4] !== "0", passed: failed.length === 0, results,
  }, null, 2));
  process.exit(failed.length ? 1 : 0);
' "$out" "$results/$name" "$sha" "$dirty"
