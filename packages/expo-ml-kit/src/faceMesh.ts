import type { MlKitRect } from './ExpoMlKit.types';
import { nativeFunction, type ImageRef } from './ExpoMlKitModule';

/** A mesh point, normalized 0-1 of the upright image, top-left origin;
 *  `z` is depth (smaller is nearer the camera), scaled like `x`. */
export type MlKitFaceMeshPoint = { x: number; y: number; z: number };

/** Face Mesh's named contours (`FaceMesh.*`, camel-cased). Left and right
 *  are the image's: `leftEye` is the subject's right eye. */
export type MlKitFaceMeshContour =
  | 'faceOval'
  | 'leftEyebrowTop'
  | 'leftEyebrowBottom'
  | 'rightEyebrowTop'
  | 'rightEyebrowBottom'
  | 'leftEye'
  | 'rightEye'
  | 'upperLipTop'
  | 'upperLipBottom'
  | 'lowerLipTop'
  | 'lowerLipBottom'
  | 'noseBridge';

/** One face's mesh. With `boundingBoxOnly`, `points`, `triangles` and
 *  `contours` are empty. */
export type MlKitFaceMesh = {
  boundingBox: MlKitRect;
  /** 468 points, in Face Mesh's index order. */
  points: MlKitFaceMeshPoint[];
  /** The mesh's triangles, each three indexes into `points`. */
  triangles: [number, number, number][];
  /** Each contour's points, as indexes into `points`. */
  contours: Partial<Record<MlKitFaceMeshContour, number[]>>;
};

export type MlKitFaceMeshOptions = {
  /** Only the faces' boxes, which is faster. */
  boundingBoxOnly?: boolean;
};

declare module './ExpoMlKitModule' {
  interface ExpoMlKitFunctions {
    detectFaceMesh(
      image: ImageRef,
      boundingBoxOnly: boolean
    ): Promise<MlKitFaceMesh[]>;
  }
}

/** ML Kit Face Mesh Detection (Android only): each face's 468-point mesh,
 *  for faces within about 2 m of the camera. */
export async function detectFaceMesh(
  image: ImageRef,
  options: MlKitFaceMeshOptions = {}
): Promise<MlKitFaceMesh[]> {
  return nativeFunction('detectFaceMesh', 'faceMesh')(
    image,
    options.boundingBoxOnly ?? false
  );
}
