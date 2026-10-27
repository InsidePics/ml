import type { TEXT_SCRIPTS } from './textQuality';

// --- Geometry ---------------------------------------------------------------
//
// Every image is analysed UPRIGHT (EXIF orientation applied), and
// `imageWidth`/`imageHeight` are its upright size.
//
// ML Kit's own results use ML Kit's frame: normalized 0-1 of the upright
// image, TOP-left origin. Faces alone follow Apple Vision's conventions
// (bottom-left origin, landmarks normalized to the face box, radians), because
// they feed the one face pipeline both platforms share.

/** A rectangle, normalized 0-1, top-left origin. */
export type MlKitRect = { x: number; y: number; width: number; height: number };

// --- Faces (Apple Vision's `FaceObservation` contract) ----------------------

/** A face box in Vision's frame: normalized 0-1, BOTTOM-left origin. */
export type NormalizedRect = {
  x: number;
  y: number;
  width: number;
  height: number;
};

export type NormalizedPoint = { x: number; y: number };

export type FaceLandmarkRegion = NormalizedPoint[];

/** The Vision regions ML Kit can supply. `leftEye` is the IMAGE-left eye, as
 *  in Vision; `outerLips[0]`/`[6]` are the image-left/-right mouth corners. */
export type FaceLandmarks = {
  faceContour?: FaceLandmarkRegion;
  leftEye?: FaceLandmarkRegion;
  rightEye?: FaceLandmarkRegion;
  leftEyebrow?: FaceLandmarkRegion;
  rightEyebrow?: FaceLandmarkRegion;
  nose?: FaceLandmarkRegion;
  noseCrest?: FaceLandmarkRegion;
  medianLine?: FaceLandmarkRegion;
  outerLips?: FaceLandmarkRegion;
  innerLips?: FaceLandmarkRegion;
  leftPupil?: FaceLandmarkRegion;
  rightPupil?: FaceLandmarkRegion;
};

/** One face in Vision's frame: bottom-left origin box, landmarks normalized
 *  to the box, angles in radians (roll counter-clockwise positive). */
export type FaceObservation = {
  boundingBox: NormalizedRect;
  /** ML Kit reports no score: always 1. */
  confidence: number;
  roll?: number;
  yaw?: number;
  pitch?: number;
  quality?: number;
  landmarks?: FaceLandmarks;
};

// --- ML Kit results ----------------------------------------------------------

/** The bundled Text Recognition v2 recognizers. Latin always runs; the
 *  others only when its read suggests another script (`textQuality.ts`). */
export type MlKitTextScript = (typeof TEXT_SCRIPTS)[number];

/** Text Recognition v2: the read of the best-fitting bundled recognizer.
 *  `text` holds its lines, newline-separated. */
export type MlKitTextBlock = { text: string; boundingBox: MlKitRect };
export type MlKitText = { text: string; blocks: MlKitTextBlock[] };

/** Image Labeling (bundled base model) and Object Detection labels. */
export type MlKitLabel = { text: string; confidence: number; index: number };

/** Barcode Scanning; `format` is a `ML_KIT_BARCODE_FORMATS` name. */
export type MlKitBarcode = {
  rawValue: string | null;
  format: string;
  boundingBox: MlKitRect;
};

/** Pose Detection: one person, 33 landmarks. `type` is the camel-cased
 *  `PoseLandmark` name (`leftShoulder`); `z` is ML Kit's depth, in the
 *  same scale as `x` (image-width-normalized). */
export type MlKitPoseLandmark = {
  type: string;
  x: number;
  y: number;
  z: number;
  inFrameLikelihood: number;
};
export type MlKitPose = { landmarks: MlKitPoseLandmark[] };

/** Object Detection (bundled base model, multiple objects, classified). */
export type MlKitObject = {
  boundingBox: MlKitRect;
  trackingId: number | null;
  labels: MlKitLabel[];
};

/** Entity Extraction over the recognized text. `type` is the camel-cased
 *  `Entity.TYPE_*` name (`phone`, `dateTime`, `url`, ...); payment cards and
 *  IBANs are not kept. */
export type MlKitEntity = { type: string; value: string };

/** Everything `analyzeImage` runs, in one pass over one decode. */
export type MlKitAnalysisResult = {
  imageWidth: number;
  imageHeight: number;
  text: MlKitText;
  labels: MlKitLabel[];
  barcodes: MlKitBarcode[];
  poses: MlKitPose[];
  objects: MlKitObject[];
  /** Null when the entity model could not be made available (not yet
   *  downloaded, no Wi-Fi): unknown, not "found nothing". */
  entities: MlKitEntity[] | null;
};
