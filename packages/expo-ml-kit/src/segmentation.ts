import { nativeFunction, type ImageRef } from './ExpoMlKitModule';
import type { MlKitMask } from './masks';

export type MlKitSelfieOptions = {
  /** The model's own mask size (256×256), not scaled to the image: cheaper,
   *  for a caller that scales it anyway. */
  rawSizeMask?: boolean;
};

declare module './ExpoMlKitModule' {
  interface ExpoMlKitFunctions {
    segmentSelfie(
      image: ImageRef,
      options: MlKitSelfieOptions
    ): Promise<MlKitMask>;
  }
}

/** Selfie Segmentation (bundled): how likely each pixel is part of a
 *  person, as a mask over the image. */
export async function segmentSelfie(
  image: ImageRef,
  options: MlKitSelfieOptions = {}
): Promise<MlKitMask> {
  return nativeFunction('segmentSelfie', 'selfieSegmentation')(image, options);
}
