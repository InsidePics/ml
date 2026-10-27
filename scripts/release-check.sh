#!/usr/bin/env bash
# What publishing a release tag requires (`.github/workflows/publish.yml`):
#
#   bash scripts/release-check.sh <dir>@<version> <sha>
#
# The tag must name a package directory and its package.json version, and
# its commit must be on main. Device runs are required only for the native
# code the release changes since the package's previous tag (all of it when
# there is none): Android by the workflow's own emulator job, which this
# script asks for (`android=true` in $GITHUB_OUTPUT); iOS, for the packages in
# IPHONE_ONLY, by a passing `device/ios` status on the commit, which only an
# iPhone run posts. The gate's macOS Swift run covers the rest of iOS.
set -euo pipefail

tag="$1"
sha="$2"
dir="${tag%@*}"
version="${tag##*@}"
fail() { echo "$1" >&2; exit 1; }

# What only an iPhone tests: ML Kit has no macOS build at all, and Apple's
# models, Neural Engine and image decoder differ on a Mac. expo-image-ml-tools'
# iOS code is the arithmetic the macOS run checks bit for bit.
IPHONE_ONLY=(expo-ml-kit expo-apple-ml)

[ -f "packages/$dir/package.json" ] || fail "no packages/$dir"
actual="$(node -p "require('./packages/$dir/package.json').version")"
[ "$actual" = "$version" ] || fail "tag $version, package.json $actual"
git merge-base --is-ancestor "$sha" origin/main || fail "$sha is not on main"

previous="$(git tag --list "$dir@*" --sort=-v:refname | grep -vx "$tag" | head -1 || true)"
changed() { # platform
  local path="packages/$dir/$1"
  [ -d "$path" ] || return 1
  [ -z "$previous" ] && return 0
  ! git diff --quiet "$previous" "$sha" -- "$path"
}

echo "Previous release: ${previous:-none}"
needs_iphone() { [[ " ${IPHONE_ONLY[*]} " == *" $dir "* ]]; }
if changed ios && needs_iphone; then
  state="$(gh api "repos/{owner}/{repo}/commits/$sha/statuses" \
    --jq '[.[] | select(.context == "device/ios")][0].state')"
  [ "$state" = success ] || fail "iOS code changed: an iPhone run must pass on $sha (device/ios: ${state:-missing}); run pnpm test:device:ios on it"
  echo "iOS code changed: iPhone run passed"
elif changed ios; then
  echo "iOS code changed: the gate's macOS run covers it"
else
  echo "iOS code unchanged: no iPhone run needed"
fi
android=false
if changed android; then android=true; echo "Android code changed: the emulator job runs"; else echo "Android code unchanged: no emulator run"; fi

out="${GITHUB_OUTPUT:-/dev/stdout}"
{ echo "dir=$dir"; echo "android=$android"; } >> "$out"
