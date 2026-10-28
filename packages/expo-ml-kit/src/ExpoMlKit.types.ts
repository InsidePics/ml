import type { MlKitBarcode } from './barcodes';
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

/** A point, normalized 0-1 of the upright image, top-left origin. */
export type MlKitPoint = { x: number; y: number };

/** What every level of a text read has: its text, box, corners (clockwise
 *  from the top-left; tilted text's box is axis-aligned, its corners are
 *  not) and the BCP-47 languages ML Kit recognized in it. */
type MlKitTextPart = {
  text: string;
  boundingBox: MlKitRect;
  cornerPoints: MlKitPoint[];
  recognizedLanguages: string[];
};

/** A character. Android only: ML Kit iOS reads no deeper than elements. */
export type MlKitTextSymbol = MlKitTextPart & {
  confidence: number;
  angle: number;
};

/** A word. `confidence` (0-1) and `angle` (degrees, clockwise) are
 *  Android's; iOS reports neither. */
export type MlKitTextElement = MlKitTextPart & {
  confidence?: number;
  angle?: number;
  symbols?: MlKitTextSymbol[];
};

export type MlKitTextLine = MlKitTextPart & {
  confidence?: number;
  angle?: number;
  elements: MlKitTextElement[];
};

/** A paragraph-like block of lines. */
export type MlKitTextBlock = MlKitTextPart & { lines: MlKitTextLine[] };

/** Text Recognition v2: one recognizer's read. `text` holds its lines,
 *  newline-separated. */
export type MlKitText = { text: string; blocks: MlKitTextBlock[] };

/** Image Labeling (bundled base model) and Object Detection labels. */
export type MlKitLabel = { text: string; confidence: number; index: number };

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

/** Entity Extraction's types, the camel-cased `Entity.TYPE_*` names. Payment
 *  cards and IBANs are never returned: the numbers are in the text already,
 *  and a labelled, searchable copy would only make them easier to harvest. */
export type MlKitEntityType =
  | 'address'
  | 'dateTime'
  | 'email'
  | 'flightNumber'
  | 'isbn'
  | 'money'
  | 'phone'
  | 'trackingNumber'
  | 'url';

/** One entity in the text: its span (`start`/`end`, UTF-16 offsets, as JS
 *  indexes strings) and, for the types ML Kit parses, its parsed value. */
export type MlKitEntity = {
  type: MlKitEntityType;
  value: string;
  start: number;
  end: number;
  /** `dateTime`: the instant (ms since the epoch) and how precise it is. */
  dateTime?: {
    timestamp: number;
    granularity:
      | 'year'
      | 'month'
      | 'week'
      | 'day'
      | 'hour'
      | 'minute'
      | 'second'
      | 'unknown';
  };
  /** `money`: the amount in parts, and the currency as written. The parts
   *  are ML Kit's own, which differ on one point: for "$12.50" Android gives
   *  `fractionalPart` 50, iOS 5 (it drops trailing zeros). Read `value` where
   *  that matters. */
  money?: { integerPart: number; fractionalPart: number; currency: string };
  /** `flightNumber`: IATA airline code and number. */
  flightNumber?: { airlineCode: string; flightNumber: string };
  /** `isbn`: the normalized ISBN. */
  isbn?: string;
  /** `trackingNumber`: the parcel carrier (camel-cased) and number. */
  trackingNumber?: { carrier: string; number: string };
};

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
