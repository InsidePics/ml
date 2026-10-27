# Shared by the iOS device scripts: generates test-apps/host/ios if needed,
# copies the fixtures into each pod (CocoaPods bundles nothing through a link
# or from outside a pod), has autolinking add the pods' test specs, installs.
# Source it from a script in scripts/; it leaves the shell in the host.
root="$(cd "$(dirname "$0")/.." && pwd)"
host="$root/test-apps/host"
# Pod name → its directory under packages/.
pods=(
  "ExpoAppleIntelligence:expo-apple-ml"
  "ExpoMlKit:expo-ml-kit"
  "ExpoImageMlTools:expo-image-ml-tools"
)

# CocoaPods bundles no resource from outside a pod or through a link: copy
# the fixtures into each pod's Tests/Fixtures (git-ignored) first.
for entry in "${pods[@]}"; do
  dir="${entry##*:}"
  rm -rf "$root/packages/$dir/ios/Tests/Fixtures"
  cp -R "$root/fixtures" "$root/packages/$dir/ios/Tests/Fixtures"
done

cd "$host"
[ -d ios ] || CI=1 pnpm exec expo prebuild -p ios --no-install

# From prebuild's Podfile every run, so the edit never stacks. For XCTest
# (IOS_HOST_MODE=tests, the default), our pods leave autolinking and are
# declared again with their test specs (autolinking adds none, and its
# includeTests would pull in Expo's own). For the JS API app
# (IOS_HOST_MODE=app), plain autolinking, which registers every module.
[ -f ios/Podfile.prebuild ] || cp ios/Podfile ios/Podfile.prebuild
cp ios/Podfile.prebuild ios/Podfile
if [ "${IOS_HOST_MODE:-tests}" = tests ]; then
  excluded=""
  declared=""
  for entry in "${pods[@]}"; do
    pod="${entry%%:*}"
    dir="${entry##*:}"
    excluded+="\"$dir\", "
    declared+="  pod \"$pod\", :path => \"../../../packages/$dir/ios\", :testspecs => [\"${pod}Tests\"]\\
"
  done
  sed -i '' -E "s|^  use_expo_modules!.*$|  use_expo_modules!(exclude: [${excluded%, }])\\
${declared}|" ios/Podfile
fi
(cd ios && pod install)

