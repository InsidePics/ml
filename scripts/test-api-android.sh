#!/usr/bin/env bash
# The packages' JS API on an Android emulator or device: test-apps/host built
# in release (its JS bundled), installed and launched; the app runs
# api-tests/ through Expo's real bridge and prints each result to logcat,
# read here. Apple's tests register on iOS only.
#
#   pnpm test:api:android [adb-serial]     (the only device when omitted)
#
# On success the result lands in .device-results/api-android-<sha>.json.
set -euo pipefail

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
adb=("$ANDROID_HOME/platform-tools/adb")
[ -z "${1:-}" ] || adb+=(-s "$1")
package="com.insidepics.mltesthost"

root="$(cd "$(dirname "$0")/.." && pwd)"
host="$root/test-apps/host"
cd "$host"
[ -d android ] || CI=1 pnpm exec expo prebuild -p android --no-install

(cd android && ./gradlew --no-daemon -q assembleRelease)
"${adb[@]}" install -r android/app/build/outputs/apk/release/app-release.apk > /dev/null
"${adb[@]}" logcat -c
"${adb[@]}" shell am force-stop "$package"
"${adb[@]}" shell monkey -p "$package" -c android.intent.category.LAUNCHER 1 > /dev/null

log="$(mktemp)"
for _ in $(seq 1 120); do
  sleep 5
  "${adb[@]}" logcat -d -s ReactNativeJS:V > "$log"
  grep -q 'API_DONE' "$log" && break
done
grep -q 'API_DONE' "$log" || {
  echo "No results from the device within 10 minutes. Last log lines:" >&2
  tail -20 "$log" >&2
  exit 1
}

results="$root/.device-results"
mkdir -p "$results"
sha="$(git -C "$root" rev-parse HEAD)"
dirty="$(git -C "$root" status --porcelain | wc -l | tr -d ' ')"
name="api-android-$sha.json"
[ "$dirty" = 0 ] || name="api-android-$sha-partial.json"
sed -n 's/.*API_RESULT //p' "$log" | node -e '
  const results = require("fs").readFileSync(0, "utf8").trim().split("\n").map(JSON.parse);
  const failed = results.filter((r) => !r.passed);
  for (const r of results) console.log(`${r.passed ? "✓" : "✗"} ${r.name}${r.passed ? "" : `\n    ${r.error}`}`);
  console.log(`\n${results.length - failed.length} passed, ${failed.length} failed`);
  require("fs").writeFileSync(process.argv[1], JSON.stringify({
    sha: process.argv[2], dirty: process.argv[3] !== "0", passed: failed.length === 0, results,
  }, null, 2));
  process.exit(failed.length ? 1 : 0);
' "$results/$name" "$sha" "$dirty"
