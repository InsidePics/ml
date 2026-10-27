# @insidepics/expo-image-ml-tools

Model inputs from an Expo image handle, built natively and identical on
Android and iOS: tensors, face alignment, sharpness and luminance histograms.
The photo's pixels never enter JavaScript; only the result does.

## Install

```sh
npx expo install @insidepics/expo-image-ml-tools expo-image-manipulator
```

Rebuild the native app afterwards (a development build; not Expo Go).

## Use

```ts
import { ImageManipulator } from 'expo-image-manipulator';
import {
  imageSize,
  similarityTransform,
  toTensor,
  warp,
} from '@insidepics/expo-image-ml-tools';

const photo = await ImageManipulator.manipulate(uri).renderAsync();
try {
  // A CLIP-style input: shorter side to 256, centre-cropped, normalized.
  const clip = await toTensor(photo, {
    width: 256,
    height: 256,
    mean: [0.485, 0.456, 0.406],
    std: [0.229, 0.224, 0.225],
  });

  // A face aligned onto a model's five-point template (pixels).
  const { width, height } = imageSize(photo);
  const points = landmarks.map(([x, y]) => [x * width, y * height] as const);
  const matrix = similarityTransform(points, TEMPLATE_112);
  if (matrix) {
    const face = await warp(photo, matrix, 112, 112);
    try {
      const input = await toTensor(face, {
        width: 112,
        height: 112,
        fit: 'stretch',
      });
    } finally {
      face.release();
    }
  }
} finally {
  photo.release();
}
```

| Function                             | Returns                                                                                                                                                                                     |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `imageSize(image)`                   | The upright size in pixels.                                                                                                                                                                 |
| `toTensor(image, options)`           | `Float32Array`, `3 × width × height`, RGB. `fit` `cover` (default) or `stretch`; `filter` `bilinear` (default) or `nearest`; per-channel `mean`/`std`; `layout` `nchw` (default) or `nhwc`. |
| `warp(image, matrix, width, height)` | A new image handle: `matrix · source`, bilinear, transparent black outside. Release it when done.                                                                                           |
| `similarityTransform(from, to)`      | The least-squares similarity (rotation, uniform scale, shift) taking `from` onto `to`, or `null` when degenerate. Pure TS.                                                                  |
| `sharpness(image)`                   | Variance of the Laplacian of the Rec.601 grey; higher is sharper.                                                                                                                           |
| `histogram(image, bins)`             | The Rec.601 luminance histogram in `bins` bins, summing to 1.                                                                                                                               |

The arithmetic is the same on both platforms: the repository's parity suite
checks these functions bit for bit against a recorded reference. The decode
is each platform's own; a recorded colour grid checks that colour, gamma and
orientation agree, though individual pixels can differ by a decoder's
rounding.

## Licence

MIT.
