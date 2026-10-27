# InsidePics/ml

On-device ML for Expo apps, as small native modules that share one image
handle (Expo's `SharedRef<'image'>`: a `UIImage` on iOS, a `Bitmap` on
Android):

- `packages/expo-apple-ml`: Apple Vision, Foundation Models,
  SpeechAnalyzer, Image Playground (iOS).
- `packages/expo-ml-kit`: Google ML Kit image analysis (Android and iOS).
- `packages/expo-image-ml-tools`: model inputs from an image handle (tensor,
  warp, sharpness, histogram), identical bytes on both platforms.

Nothing here knows about any particular app's models: sizes, means, face
templates and model files are the caller's.

## Rules

- **File length: 300 lines hard (250 soft), tests included**, for every
  source language (TS, Swift, Kotlin, shell). `pnpm lines` checks.
- **Dependencies via `pnpm add` only**; never hand-edit dependency lists.
- **No `Co-Authored-By` lines** in commits.
- Feature branch, then PR. Never push to `main`, never publish by hand.
- One path per behaviour: no compatibility shims or parallel code paths.

## Gates (local until the repo is public)

| Command                              | What                                                                         | When                                 |
| ------------------------------------ | ---------------------------------------------------------------------------- | ------------------------------------ |
| `pnpm gate`                          | lint, format, line limits, types, TS tests, Kotlin JVM tests, Swift on macOS | pre-push hook, every PR              |
| `pnpm test:device:ios <udid> <team>` | every package's XCTests on an iPhone, one host app                           | every PR touching native or fixtures |
| `pnpm test:android`                  | every package's instrumented tests on an emulator                            | every PR touching native or fixtures |

A full, clean, passing device or emulator run writes
`.device-results/<platform>-<sha>.json` and posts it to GitHub as the commit
status `device/ios` or `device/android` (`scripts/report-device-results.sh`;
for a run made before the push, push and run it by hand).

Skips are allowed only where the platform cannot run the code (the iOS
simulator has no ML Kit and no Neural Engine). A test that cannot reach what
it checks (a model download, a fixture) fails; it never skips.

## Releasing

Bump the package's `version`, merge to `main`, then tag that commit
`<directory>@<version>` (e.g. `expo-ml-kit@0.2.0`) and push the tag.
`.github/workflows/publish.yml` checks that the commit is on `main` and
carries both device statuses, runs the gate, and publishes through npm
trusted publishing. Nothing is published from a laptop, except a new
package's first version: npm trusts a workflow only for a package that
exists (then add the trusted publisher in the package's npm settings).

## Fixtures

Shared by every package's native tests: `fixtures/`, each file's source and
licence in `fixtures/FIXTURES.md`. Expected results are JSON beside them and
change only through the `--record` mode of the test scripts, reviewed in the
PR diff.
