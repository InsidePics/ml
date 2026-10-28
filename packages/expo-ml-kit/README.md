# expo-ml-kit

Google ML Kit for Expo and React Native, on Android and iOS: text recognition
(OCR), image labeling, barcode and QR code scanning, pose detection, object
detection, face detection, selfie segmentation, entity extraction, language
identification, Smart Reply, translation and digital ink recognition, with
custom TensorFlow Lite models for labeling and object detection. Android also
gets face mesh and the GenAI APIs (Gemini Nano).

Every feature is opt-in, so an app links only the models it uses.

## Install

```sh
npx expo install expo-ml-kit expo-image-manipulator
```

Add the config plugin to `app.json`, then rebuild the native app (a
development build; it does not run in Expo Go):

```json
{
  "expo": {
    "plugins": [
      ["expo-ml-kit", { "features": ["text", "barcodes", "translate"] }]
    ]
  }
}
```

`features` lists what to link (`"all"` links everything). Without it you get
the defaults: `text`, `labels`, `barcodes`, `poses`, `objects`, `entities`
and `faces`. A call into a feature the build left out rejects with an
`MlKitError` whose code is `ERR_ML_KIT_FEATURE`, and `isMlKitAvailable(feature)`
lets you check ahead. Change `features`, then prebuild and rebuild.

The plugin also raises Android's `minSdkVersion` to 26 and unlinks ML Kit from
iOS simulator builds, for which Google ships none. On a simulator
`isMlKitAvailable()` is `false` and every call rejects with
`ERR_ML_KIT_UNAVAILABLE`.

## Features

| Feature              | Calls                                                                                            | Model                   |
| -------------------- | ------------------------------------------------------------------------------------------------ | ----------------------- |
| `text`               | `recognizeText`, `analyzeImage` (`mlKitText`)                                                    | bundled                 |
| `labels`             | `labelImage`, `analyzeImage` (`mlKitLabels`)                                                     | bundled                 |
| `customLabels`       | `labelImage(image, { model })`                                                                   | yours (`.tflite`)       |
| `barcodes`           | `detectBarcodes`, `analyzeImage` (`mlKitBarcodes`)                                               | bundled                 |
| `poses`              | `detectPose`, `analyzeImage` (`mlKitPoses`)                                                      | bundled                 |
| `posesAccurate`      | `detectPose(image, { model: 'accurate' })`                                                       | bundled                 |
| `objects`            | `detectObjects`, `analyzeImage` (`mlKitObjects`)                                                 | bundled                 |
| `customObjects`      | `detectObjects(image, { model })`                                                                | yours (`.tflite`)       |
| `faces`              | `detectFaces`                                                                                    | bundled                 |
| `selfieSegmentation` | `segmentSelfie`                                                                                  | bundled                 |
| `entities`           | `extractEntities`, `analyzeImage` (`mlKitEntities`), entity model calls                          | downloaded per language |
| `languageId`         | `identifyLanguage`, `identifyPossibleLanguages`                                                  | bundled                 |
| `smartReply`         | `suggestReplies`                                                                                 | bundled                 |
| `translate`          | `translate`, `downloadTranslationModel`, `deleteTranslationModel`, `downloadedTranslationModels` | downloaded per language |
| `digitalInk`         | `recognizeInk`, `downloadInkModel`, `deleteInkModel`, `isInkModelDownloaded`                     | downloaded per language |

### Android only

| Feature                 | Calls                                                                    | Model                |
| ----------------------- | ------------------------------------------------------------------------ | -------------------- |
| `faceMesh`              | `detectFaceMesh`: 468 points, triangles, contours                        | bundled              |
| `genAiSummarization`    | `summarize`, `getSummarizerStatus`, `downloadSummarizer`                 | Gemini Nano (AICore) |
| `genAiProofreading`     | `proofread`, `getProofreaderStatus`, `downloadProofreader`               | Gemini Nano (AICore) |
| `genAiRewriting`        | `rewrite`, `getRewriterStatus`, `downloadRewriter`                       | Gemini Nano (AICore) |
| `genAiImageDescription` | `describeImage`, `getImageDescriberStatus`, `downloadImageDescriber`     | Gemini Nano (AICore) |
| `genAiPrompt`           | `generateContent`, `getGenerativeModelStatus`, `downloadGenerativeModel` | Gemini Nano (AICore) |

The GenAI features run only on devices with AICore (recent
Pixel and Galaxy flagships); elsewhere their status is `unavailable` and
calls reject with `ERR_ML_KIT_GENAI_UNAVAILABLE`. `genai-prompt` is pinned
to 1.0.0-beta2: later releases need a newer Kotlin than React Native's.
ML Kit's GenAI speech recognition is not included, because its alpha needs
that newer Kotlin too.

`ML_KIT_ARTIFACTS` lists the Google release each feature links on each
platform, and `ML_KIT_BARCODE_FORMATS` the barcode format names. If you store
versioned results, bump your version when either changes.

## Use

```ts
import { ImageManipulator } from 'expo-image-manipulator';
import * as MlKit from 'expo-ml-kit';

const photo = await ImageManipulator.manipulate(uri).renderAsync();
try {
  if (MlKit.isMlKitAvailable('text')) {
    const result = await MlKit.analyzeImage(photo, [
      'mlKitText',
      'mlKitBarcodes',
    ]);
    const faces = await MlKit.detectFaces(photo, { classify: true });
  }
} finally {
  photo.release();
}
```

Every image call takes an Expo image handle (`ImageRef`) from
`expo-image-manipulator`, `expo-image`, or `expo-image-ml-tools`' `warp`. The
image is analysed upright, its longer side capped at 2048 px. A path or a
released handle is refused. Boxes and points are normalized (0 to 1) with a
top-left origin. Faces are the exception: they follow Apple Vision's
`FaceObservation`, with a bottom-left origin.

- `analyzeImage(image, models)` runs several models over one decode. Text is
  read with the Latin recognizer, and also with the Chinese, Devanagari,
  Japanese and Korean ones when the Latin read suggests another script; the
  most well-formed read wins. Entities are extracted from that text's
  confident lines only.
- Text reads come back as blocks, lines and elements, each with its box,
  corners and recognized languages. Android adds symbols, confidences and
  angles; ML Kit iOS has none of these.
- Barcodes carry their parsed value: Wi-Fi, URL, email, phone, SMS, geo,
  contact, calendar event or driver licence.
- Masks (`MlKitMask`) hold one byte per pixel, the confidence scaled to 0–255.
  `maskCoverage` and `maskConfidence` read them.
- Calls that need a downloaded model (translation and digital ink) reject with
  `ERR_ML_KIT_MODEL` when it is missing; download it first. Entity extraction
  instead answers `null` ("unknown") until its model has downloaded, on Wi-Fi.

## Known limitations

- **Objects**: ML Kit's object detector finds prominent objects, not animals:
  it boxes nothing in a dog lying in grass, whose image labels still say Dog.
- **Faces**: with faces down to 5% of the image allowed, ML Kit can box a face
  twice; a face whose box lies at least 80% inside a larger face's is dropped.
- **Entities**: payment card numbers and IBANs are never returned. For an
  amount like "$12.50", Android reports `fractionalPart` 50 and iOS reports 5.
- **Still images only**: ML Kit's stream modes (camera frames, tracking IDs
  across frames) are not wrapped.
- **Firebase-hosted custom models** are not supported; pass a local `.tflite`.

## Licence

MIT. Uses Google ML Kit, under
[Google's ML Kit terms](https://developers.google.com/ml-kit/terms).
