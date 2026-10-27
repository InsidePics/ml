#!/usr/bin/env bash
# Shared by the local Expo modules' `android/src/test/run-jvm.sh`: puts JUnit
# + Hamcrest on `JVM_TEST_CP` (fetched once from Maven Central, sha256-pinned,
# cached) for compiling and running pure-Kotlin tests on a plain JVM, no
# Android SDK or gradle. Requires curl and shasum. Source it, don't run it.
JVM_TEST_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/insidepics-jvm-tests"
mkdir -p "$JVM_TEST_CACHE"

jvm_test_fetch() { # name url sha256
  local jar="$JVM_TEST_CACHE/$1"
  if [ ! -f "$jar" ]; then
    curl -fsSL -o "$jar" "$2"
  fi
  echo "$3  $jar" | shasum -a 256 -c - > /dev/null || {
    echo "checksum mismatch for $1" >&2
    rm -f "$jar"
    exit 1
  }
}

jvm_test_fetch junit-4.13.2.jar \
  https://repo1.maven.org/maven2/junit/junit/4.13.2/junit-4.13.2.jar \
  8e495b634469d64fb8acfa3495a065cbacc8a0fff55ce1e31007be4c16dc57d3
jvm_test_fetch hamcrest-core-1.3.jar \
  https://repo1.maven.org/maven2/org/hamcrest/hamcrest-core/1.3/hamcrest-core-1.3.jar \
  66fdef91e9739348df7a096aa384a5685f4e875584cce89386a7a47251c4d8e9

JVM_TEST_CP="$JVM_TEST_CACHE/junit-4.13.2.jar:$JVM_TEST_CACHE/hamcrest-core-1.3.jar"
