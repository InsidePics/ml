#!/usr/bin/env bash
# Runs the pure-Kotlin JUnit tests (ImageMath) on a plain JVM — no Android SDK
# or gradle — against the shared reference iOS checks too:
#
#   pnpm --filter expo-image-ml-tools test:kotlin
#
# Requires kotlinc (brew install kotlin) and a JVM; JUnit comes from the
# repository's scripts/lib/kotlin-jvm-test.sh.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
MAIN="$DIR/../main/java/expo/modules/imagemltools"
TEST="$DIR/java/expo/modules/imagemltools"
ROOT="$(cd "$DIR/../../../../.." && pwd)"
source "$ROOT/scripts/lib/kotlin-jvm-test.sh"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

kotlinc "$MAIN/ImageMath.kt" "$TEST"/*.kt \
  -classpath "$JVM_TEST_CP" -include-runtime -d "$OUT/tests.jar" 2> >(grep -v '^warning' >&2)

java -Dexpected="$ROOT/fixtures/expected/model-inputs.json" -classpath "$OUT/tests.jar:$JVM_TEST_CP" \
  org.junit.runner.JUnitCore expo.modules.imagemltools.ImageMathTests
