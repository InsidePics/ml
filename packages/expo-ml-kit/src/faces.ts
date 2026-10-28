import type { FaceObservation } from './ExpoMlKit.types';
import { nativeFunction, type ImageRef } from './ExpoMlKitModule';

declare module './ExpoMlKitModule' {
  interface ExpoMlKitFunctions {
    /** Vision's `FaceObservation` shape, the same on both platforms. */
    detectFaces(image: ImageRef): Promise<FaceObservation[]>;
  }
}

/** ML Kit Face Detection, as Apple Vision `FaceObservation`s — the same
 *  shape on Android and iOS, so faces from either detector feed one face
 *  pipeline. Both detectors box one face in one place (the cross-detector
 *  device suite), so a caller can pair them by overlap. */
export async function detectFaces(image: ImageRef): Promise<FaceObservation[]> {
  return nativeFunction('detectFaces', 'faces')(image);
}
