#!/usr/bin/env bash
# Runs the pure-Kotlin JUnit tests (FaceMapping, Geometry) on a plain JVM —
# no Android SDK or gradle needed, because those files have no Android
# imports (expo-image-decode's run-jvm.sh does the same). The ML Kit
# detectors themselves need a device.
#
#   pnpm --filter @insidepics/expo-ml-kit test:kotlin
#   RECORD_FIXTURE=1 pnpm --filter @insidepics/expo-ml-kit test:kotlin
#
# Requires: kotlinc (brew install kotlin) and a JVM; JUnit comes from
# the repository's scripts/lib/kotlin-jvm-test.sh.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
MAIN="$DIR/../main/java/expo/modules/mlkit"
TEST="$DIR/java/expo/modules/mlkit"
ROOT="$(cd "$DIR/../../../../.." && pwd)"
source "$ROOT/scripts/lib/kotlin-jvm-test.sh"
CP="$JVM_TEST_CP"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

kotlinc "$MAIN/FaceMapping.kt" "$MAIN/Geometry.kt" "$TEST"/*.kt \
  -classpath "$CP" -include-runtime -d "$OUT/tests.jar" 2> >(grep -v '^warning' >&2)

java -DfaceFixture="$DIR/fixtures/face.json" -classpath "$OUT/tests.jar:$CP" \
  org.junit.runner.JUnitCore \
  expo.modules.mlkit.FaceMappingTests expo.modules.mlkit.GeometryTests
