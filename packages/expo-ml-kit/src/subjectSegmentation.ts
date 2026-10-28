import type { MlKitRect } from './ExpoMlKit.types';
import { nativeFunction, type ImageRef } from './ExpoMlKitModule';
import type { MlKitMask } from './masks';

/** One subject (a person, pet or thing) the segmenter separated. */
export type MlKitSubject = {
  /** Where its mask lies in the image, normalized, top-left origin. */
  boundingBox: MlKitRect;
  /** Its confidence over its box: the box's size in pixels. */
  mask: MlKitMask;
};

export type MlKitSubjectSegmentation = {
  /** Every subject together, at the image's size. */
  foreground: MlKitMask;
  /** Each subject alone; empty unless `subjects` was asked for. */
  subjects: MlKitSubject[];
};

export type MlKitSubjectSegmentationOptions = {
  /** Each subject's own mask and box, besides the foreground's. */
  subjects?: boolean;
};

declare module './ExpoMlKitModule' {
  interface ExpoMlKitFunctions {
    isSubjectSegmentationModuleReady(): Promise<boolean>;
    downloadSubjectSegmentationModule(): Promise<void>;
    segmentSubjects(
      image: ImageRef,
      subjects: boolean
    ): Promise<MlKitSubjectSegmentation>;
  }
}

/** Whether subject segmentation's model, a Google Play services module, is
 *  on the device. */
export async function isSubjectSegmentationModuleReady(): Promise<boolean> {
  return nativeFunction(
    'isSubjectSegmentationModuleReady',
    'subjectSegmentation'
  )();
}

/** Downloads subject segmentation's Play services module, resolving once it
 *  is installed (at once when it already is). */
export async function downloadSubjectSegmentationModule(): Promise<void> {
  return nativeFunction(
    'downloadSubjectSegmentationModule',
    'subjectSegmentation'
  )();
}

/**
 * ML Kit Subject Segmentation (Android only): the image's foreground, and
 * with `subjects` each subject's mask. Rejects with
 * `ERR_ML_KIT_MODULE_MISSING` while the model's module is not on the device
 * (`downloadSubjectSegmentationModule`), rather than waiting for it.
 */
export async function segmentSubjects(
  image: ImageRef,
  options: MlKitSubjectSegmentationOptions = {}
): Promise<MlKitSubjectSegmentation> {
  return nativeFunction('segmentSubjects', 'subjectSegmentation')(
    image,
    options.subjects ?? false
  );
}
