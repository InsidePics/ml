#!/usr/bin/env bash
# Every package's instrumented tests (android/src/androidTest) on an Android
# emulator or device, built through test-apps/host's Gradle project, where
# the Expo module plugin resolves:
#
#   pnpm test:android [adb-serial]          (the only device when omitted)
#   ONLY=insidepics-expo-ml-kit pnpm test:android …   (one package; not a gate run)
#
# Each package's suite is its own test APK, with the repository's fixtures as
# assets. On success the result lands in .device-results/android-<sha>.json,
# which a release requires.
#
# The Android 17 (API 37) emulator image needs two things to stay up:
# - `hw.gps=no` in the AVD's config.ini: its GNSS driver hangs the system
#   server at boot, and the watchdog restarts it every minute;
# - `emulator -avd <name> -no-window -gpu swiftshader_indirect`: with the
#   host GPU, the emulator itself aborts mid-run.
set -euo pipefail

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
[ -z "${1:-}" ] || export ANDROID_SERIAL="$1"
device="${ANDROID_SERIAL:-$("$ANDROID_HOME/platform-tools/adb" get-serialno)}"
projects=(insidepics-expo-image-ml-tools insidepics-expo-ml-kit)

root="$(cd "$(dirname "$0")/.." && pwd)"
host="$root/test-apps/host"
cd "$host"
[ -d android ] || CI=1 pnpm exec expo prebuild -p android --no-install

results="$root/.device-results"
mkdir -p "$results"
sha="$(git -C "$root" rev-parse HEAD)"
dirty="$(git -C "$root" status --porcelain | wc -l | tr -d ' ')"
status=0
for project in "${projects[@]}"; do
  [ -z "${ONLY:-}" ] || [ "$ONLY" = "$project" ] || continue
  rm -rf "$root/packages/${project#insidepics-}/android/build/outputs/androidTest-results"
  (cd android && ./gradlew --no-daemon -q ":$project:connectedDebugAndroidTest") || status=1
done

out="$results/android-$sha.json"
# A run of uncommitted code, or of one package, proves no commit.
[ "$dirty" = 0 ] && [ -z "${ONLY:-}" ] || out="$results/android-$sha-partial.json"
# JUnit XML from each package's run: every test with its outcome.
python3 - "$root" "$out" "$sha" "$dirty" "$device" "$status" <<'EOF'
import glob, json, sys, xml.etree.ElementTree as ET
root, out, sha, dirty, device, status = sys.argv[1:]
suites, failed = {}, 0
for path in sorted(glob.glob(f"{root}/packages/*/android/build/outputs/androidTest-results/connected/**/*.xml", recursive=True)):
    package = path.split("/packages/")[1].split("/")[0]
    for case in ET.parse(path).getroot().iter("testcase"):
        problem = case.find("failure") if case.find("failure") is not None else case.find("error")
        outcome = "skipped" if case.find("skipped") is not None else "failed" if problem is not None else "passed"
        name = f"{case.get('classname').split('.')[-1]}.{case.get('name')}"
        suites.setdefault(package, []).append({"test": name, "outcome": outcome})
        failed += outcome == "failed"
        mark = {"passed": "✓", "failed": "✗", "skipped": "-"}[outcome]
        print(f"{mark} {package} {name}")
        if problem is not None:
            print("    " + (problem.text or "").strip().split("\n")[0][:300])
total = sum(len(cases) for cases in suites.values())
passed = status == "0" and failed == 0 and total > 0
print(f"\n{total - failed} of {total} passed")
json.dump({"sha": sha, "dirty": dirty != "0", "passed": passed, "device": device, "suites": suites},
          open(out, "w"), indent=2)
print(f"Result: {out}")
sys.exit(0 if passed else 1)
EOF
