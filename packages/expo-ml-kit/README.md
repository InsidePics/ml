# expo-ml-kit

Google ML Kit's on-device image analysis for Expo and React Native: text
recognition (OCR), image labeling, barcode and QR code scanning, pose
detection, object detection, entity extraction, and face detection, on
Android and iOS. It covers ML Kit's photo analysis; ML Kit's segmentation,
document scanner, digital ink, translation, smart reply and GenAI APIs are
not included. Every model runs on the device with a bundled model (no Play services
download), except entity extraction's per-language model, which ML Kit
downloads at first use.

## Install

```sh
npx expo install expo-ml-kit expo-image-manipulator
```

Add the config plugin to `app.json`, then rebuild the native app (a
development build; it does not run in Expo Go):

```json
{ "expo": { "plugins": ["expo-ml-kit"] } }
```

The plugin raises Android's `minSdkVersion` to 26 (entity extraction's
minimum) and unlinks ML Kit from iOS simulator builds, for which Google ships
none. On a simulator `isMlKitAvailable()` is `false`.

## Use

```ts
import { ImageManipulator } from 'expo-image-manipulator';
import * as MlKit from 'expo-ml-kit';

const photo = await ImageManipulator.manipulate(uri).renderAsync();
try {
  if (MlKit.isMlKitAvailable()) {
    const result = await MlKit.analyzeImage(photo, [
      'mlKitText',
      'mlKitLabels',
      'mlKitBarcodes',
    ]);
    const faces = await MlKit.detectFaces(photo);
  }
} finally {
  photo.release();
}
```

Every function takes an Expo image handle (`ImageRef`): from
`expo-image-manipulator`, `expo-image`, or `expo-image-ml-tools`'
`warp`. The image is analysed upright, its longer side capped at 2048 px; a
path or a released handle is refused.

| Function                      | Returns                                                                                          |
| ----------------------------- | ------------------------------------------------------------------------------------------------ |
| `isMlKitAvailable()`          | Whether the module and its models are linked here.                                               |
| `analyzeImage(image, models)` | The models asked for, in one pass: `text`, `labels`, `barcodes`, `poses`, `objects`, `entities`. |
| `detectFaces(image)`          | Faces as Apple Vision `FaceObservation`s: one shape for both platforms' detectors.               |
| `detectBarcodes(image)`       | Barcodes alone.                                                                                  |

`models` are `mlKitText`, `mlKitLabels`, `mlKitBarcodes`, `mlKitPoses`,
`mlKitObjects` and `mlKitEntities`; any other model's result comes back
empty. Text is read with the Latin recognizer, and with the Chinese,
Devanagari, Japanese and Korean ones when the Latin read suggests another
script; the most well-formed read wins. Entities are extracted from that
text's confident lines only.

`ML_KIT_ARTIFACTS` lists the Google release each feature runs on each
platform, and `ML_KIT_BARCODE_FORMATS` the barcode format names: a caller that
versions stored results bumps its version when either changes.

## Known limitations

- **Objects**: ML Kit's object detector finds prominent objects, not animals:
  it boxes nothing in a dog lying in grass, whose image labels still say Dog.
- **Faces**: with faces down to 5% of the image allowed, ML Kit can box a face
  twice; a face whose box lies at least 80% inside a larger face's is dropped.

## Licence

MIT. Uses Google ML Kit, under
[Google's ML Kit terms](https://developers.google.com/ml-kit/terms).
