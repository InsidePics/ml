#!/usr/bin/env bash
# Every package's XCTests on a connected iPhone, hosted by test-apps/host
# (Vision needs the Neural Engine and ML Kit has no simulator build):
#
#   pnpm test:device:ios <device-udid> <team-id>
#   ONLY=ExpoMlKit pnpm test:device:ios …   (one pod's suite; not a gate run)
#   pnpm build:ios                            (compile every suite for a device, run none)
#
# `xcrun xctrace list devices` prints the UDID. Prebuild generates the host's
# ios/; autolinking adds each pod without its test spec, so the Podfile edit
# below re-declares them with it on every run. On success the result lands in
# .device-results/ios-<sha>.json, which a release requires.
set -euo pipefail

if [ "${1:-}" = "--build-only" ]; then
  build_only=1
else
  build_only=0
  udid="${1:?usage: $0 <device-udid> <team-id> | --build-only}"
  team="${2:?usage: $0 <device-udid> <team-id> | --build-only}"
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
host="$root/test-apps/host"
# Pod name → its directory under packages/.
pods=(
  "ExpoAppleIntelligence:expo-apple-intelligence"
  "ExpoMlKit:expo-ml-kit"
)

cd "$host"
[ -d ios ] || CI=1 pnpm exec expo prebuild -p ios --no-install

excluded=""
declared=""
for entry in "${pods[@]}"; do
  pod="${entry%%:*}"
  dir="${entry##*:}"
  excluded+="\"@insidepics/$dir\", "
  declared+="  pod \"$pod\", :path => \"../../../packages/$dir/ios\", :testspecs => [\"${pod}Tests\"]\\
"
done
# From prebuild's Podfile every run, so the edit never stacks.
[ -f ios/Podfile.prebuild ] || cp ios/Podfile ios/Podfile.prebuild
cp ios/Podfile.prebuild ios/Podfile
sed -i '' -E "s|^  use_expo_modules!.*$|  use_expo_modules!(exclude: [${excluded%, }])\\
${declared}|" ios/Podfile
(cd ios && pod install)

if [ $build_only = 1 ]; then
  for entry in "${pods[@]}"; do
    pod="${entry%%:*}"
    xcodebuild build-for-testing -quiet \
      -workspace ios/mltesthost.xcworkspace \
      -scheme "$pod-Unit-${pod}Tests" \
      -destination generic/platform=iOS \
      CODE_SIGNING_ALLOWED=NO
  done
  exit 0
fi

results="$root/.device-results"
mkdir -p "$results"
sha="$(git -C "$root" rev-parse HEAD)"
dirty="$(git -C "$root" status --porcelain | wc -l | tr -d ' ')"
summary=()
status=0
for entry in "${pods[@]}"; do
  pod="${entry%%:*}"
  [ -z "${ONLY:-}" ] || [ "$ONLY" = "$pod" ] || continue
  bundle="$results/ios-$pod.xcresult"
  rm -rf "$bundle"
  # Pods are built unsigned; a bundle loaded on a device must be signed.
  if ! xcodebuild test \
    -workspace ios/mltesthost.xcworkspace \
    -scheme "$pod-Unit-${pod}Tests" \
    -destination "id=$udid" \
    -resultBundlePath "$bundle" \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$team" \
    CODE_SIGN_STYLE=Automatic \
    CODE_SIGNING_ALLOWED=YES \
    CODE_SIGN_IDENTITY="Apple Development"; then
    status=1
  fi
  counts="$(xcrun xcresulttool get test-results summary --path "$bundle" --compact 2>/dev/null || echo '{}')"
  summary+=("\"$pod\": $counts")
done

joined="$(IFS=,; echo "${summary[*]}")"
out="$results/ios-$sha.json"
# A run of uncommitted code, or of one suite, proves no commit.
[ "$dirty" = 0 ] && [ -z "${ONLY:-}" ] || out="$results/ios-$sha-partial.json"
printf '{"sha": "%s", "dirty": %s, "passed": %s, "device": "%s", "suites": {%s}}\n' \
  "$sha" "$([ "$dirty" = 0 ] && echo false || echo true)" \
  "$([ $status = 0 ] && echo true || echo false)" "$udid" "$joined" > "$out"
echo "Result: $out"
exit $status
