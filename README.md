# InsidePics ML

On-device machine learning for Expo apps: small native modules that share
one decoded image.

| Package                                                                   | What                                                                       | Platforms             |
| ------------------------------------------------------------------------- | -------------------------------------------------------------------------- | --------------------- |
| [`@insidepics/expo-apple-intelligence`](packages/expo-apple-intelligence) | Apple Vision, Foundation Models, SpeechAnalyzer, Image Playground          | iOS                   |
| [`@insidepics/expo-ml-kit`](packages/expo-ml-kit)                         | Google ML Kit: text, labels, barcodes, poses, objects, entities, faces     | Android, iOS (device) |
| [`@insidepics/expo-image-ml-tools`](packages/expo-image-ml-tools)         | Model inputs from an image: tensors, face alignment, sharpness, histograms | Android, iOS          |

## One image, every model

Each module takes an Expo image handle (`SharedRef<'image'>`, exported as
`ImageRef`). Decode a photo once, upright, and hand the same handle to every
model; the pixels stay native and never cross into JavaScript:

```ts
import { ImageManipulator } from 'expo-image-manipulator';
import * as MlKit from '@insidepics/expo-ml-kit';
import { toTensor } from '@insidepics/expo-image-ml-tools';

const photo = await ImageManipulator.manipulate(uri).renderAsync();
try {
  const scene = await MlKit.analyzeImage(photo, ['mlKitLabels', 'mlKitText']);
  const clip = await toTensor(photo, { width: 256, height: 256 });
} finally {
  photo.release();
}
```

Nothing here knows any app's models: sizes, means, face templates and model
files are the caller's.

## Developing

```sh
pnpm install
pnpm gate                                  # lint, format, types, TS, Kotlin (JVM), Swift (macOS)
pnpm test:device:ios <udid> <team>         # every package's XCTests on an iPhone
pnpm test:android [serial]                 # every package's instrumented tests on an emulator
pnpm test:api:ios <udid> <team>            # the JS API through Expo's bridge, on an iPhone
pnpm test:api:android                      # the same on Android
```

`AGENTS.md` holds the rules (300-line files, `pnpm add` only, feature branch
and PR). The emulator needs `hw.gps=no` and software rendering; see the header
of `scripts/test-android.sh`.

A full, clean, passing device run posts its result to GitHub as the commit
status `device/ios` or `device/android`. For a run made before the commit was
pushed, push and run `bash scripts/report-device-results.sh <ios|android> <sha>`.

## Releasing

Packages are published to npm by GitHub Actions, never from a laptop:

1. Bump the package's `version` in a PR and merge it to `main`.
2. Run both device suites on that `main` commit (they post `device/ios` and
   `device/android`).
3. Tag the commit `<package directory>@<version>` and push the tag:

   ```sh
   git tag expo-ml-kit@0.2.0 <sha> && git push origin expo-ml-kit@0.2.0
   ```

`.github/workflows/publish.yml` then checks that the tag matches the version,
that the commit is on `main` and carries both device statuses, runs the gate,
builds the package and publishes it. npm trusts the workflow (trusted
publishing), so there is no token, and every version carries provenance: a
signed link to the commit that built it.

**A new package** must exist on npm before npm can trust the workflow for it,
so its first version is the one manual publish, by a maintainer, from a clean
`main`:

```sh
cd packages/<package> && CI=1 pnpm build && npm publish
```

Then, on npmjs.com, the package's Settings → Trusted Publisher: GitHub
Actions, repository `InsidePics/ml`, workflow `publish.yml`.

**`@insidepics/expo-apple-intelligence`** came from the archived
`InsidePics/expo-apple-intelligence` repository (0.1.0–0.3.1). From 0.4.0 it is
built here: its `repository` and podspec `source` name this repository, and
its npm trusted publisher names `InsidePics/ml` / `publish.yml`.

## Fixtures

The native tests share `fixtures/`. They are not covered by this
repository's MIT licence: each file's source, author and licence are in
[`fixtures/FIXTURES.md`](fixtures/FIXTURES.md).

## Licence

MIT © INSP LLC, except `fixtures/` (see above).
