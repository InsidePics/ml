import type { FaceObservation } from './ExpoMlKit.types';
import { nativeFunction, type ImageRef } from './ExpoMlKitModule';

export type MlKitFaceOptions = {
  /** `accurate` (default) or `fast`. */
  performance?: 'accurate' | 'fast';
  /** Score smiles and open eyes (default false: a second model's work). */
  classify?: boolean;
  /** The smallest face to find, as a share of the image's width (default
   *  0.05, down from ML Kit's 0.1, for group photos' small faces). */
  minFaceSize?: number;
};

/** A face as Apple Vision describes one, plus what ML Kit alone scores.
 *  With `classify`: probabilities 0-1, the eyes named like Vision's
 *  landmarks (`leftEye*` is the IMAGE-left eye). */
export type MlKitFaceObservation = FaceObservation & {
  smilingProbability?: number;
  leftEyeOpenProbability?: number;
  rightEyeOpenProbability?: number;
};

declare module './ExpoMlKitModule' {
  interface ExpoMlKitFunctions {
    /** Vision's `FaceObservation` shape, the same on both platforms. */
    detectFaces(
      image: ImageRef,
      options: MlKitFaceOptions
    ): Promise<MlKitFaceObservation[]>;
  }
}

/** ML Kit Face Detection, as Apple Vision `FaceObservation`s — the same
 *  shape on Android and iOS, so faces from either detector feed one face
 *  pipeline. Both detectors box one face in one place (the cross-detector
 *  device suite), so a caller can pair them by overlap. */
export async function detectFaces(
  image: ImageRef,
  options: MlKitFaceOptions = {}
): Promise<MlKitFaceObservation[]> {
  return nativeFunction('detectFaces', 'faces')(image, options);
}
