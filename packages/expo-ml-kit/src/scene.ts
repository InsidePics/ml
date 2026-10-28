import type { MlKitLabel, MlKitObject, MlKitPose } from './ExpoMlKit.types';
import { nativeFunction, type ImageRef } from './ExpoMlKitModule';

/**
 * A TensorFlow Lite model of the caller's, for Image Labeling or Object
 * Detection: an image classifier with metadata (labels), as ML Kit's custom
 * model guide describes. `path` is an absolute path or `file://` URI on the
 * device (download or copy it there first).
 */
export type MlKitCustomModel = { path: string };

export type MlKitLabelOptions = {
  /** Labels below this confidence (0-1) are dropped (default 0.5). */
  confidenceThreshold?: number;
  /** A custom model instead of the bundled base model (`customLabels`). */
  model?: MlKitCustomModel;
  /** With a custom model: at most this many labels (default 10). */
  maxResults?: number;
};

export type MlKitObjectOptions = {
  /** Up to five objects (default), or only the most prominent one. */
  multipleObjects?: boolean;
  /** Label each object (default true). */
  classify?: boolean;
  /** A custom classifier instead of the base model's five coarse
   *  categories (`customObjects`). */
  model?: MlKitCustomModel;
  /** With a custom model: labels below this confidence are dropped, and at
   *  most this many are kept per object. */
  confidenceThreshold?: number;
  maxLabelsPerObject?: number;
};

export type MlKitPoseOptions = {
  /** `base` (default; fast) or `accurate` (`posesAccurate`; slower, steadier
   *  landmarks). */
  model?: 'base' | 'accurate';
};

declare module './ExpoMlKitModule' {
  interface ExpoMlKitFunctions {
    labelImage(
      image: ImageRef,
      options: MlKitLabelOptions
    ): Promise<MlKitLabel[]>;
    labelImageCustom(
      image: ImageRef,
      options: MlKitLabelOptions
    ): Promise<MlKitLabel[]>;
    detectObjects(
      image: ImageRef,
      options: MlKitObjectOptions
    ): Promise<MlKitObject[]>;
    detectObjectsCustom(
      image: ImageRef,
      options: MlKitObjectOptions
    ): Promise<MlKitObject[]>;
    detectPose(image: ImageRef): Promise<MlKitPose[]>;
    detectPoseAccurate(image: ImageRef): Promise<MlKitPose[]>;
  }
}

/** Image Labeling: what the image shows, from the bundled base model's 400+
 *  labels or the caller's own model. */
export async function labelImage(
  image: ImageRef,
  options: MlKitLabelOptions = {}
): Promise<MlKitLabel[]> {
  return options.model
    ? nativeFunction('labelImageCustom', 'customLabels')(image, options)
    : nativeFunction('labelImage', 'labels')(image, options);
}

/** Object Detection: the prominent objects' boxes, each labelled. */
export async function detectObjects(
  image: ImageRef,
  options: MlKitObjectOptions = {}
): Promise<MlKitObject[]> {
  return options.model
    ? nativeFunction('detectObjectsCustom', 'customObjects')(image, options)
    : nativeFunction('detectObjects', 'objects')(image, options);
}

/** Pose Detection: zero people or one, 33 landmarks. */
export async function detectPose(
  image: ImageRef,
  options: MlKitPoseOptions = {}
): Promise<MlKitPose[]> {
  return options.model === 'accurate'
    ? nativeFunction('detectPoseAccurate', 'posesAccurate')(image)
    : nativeFunction('detectPose', 'poses')(image);
}
