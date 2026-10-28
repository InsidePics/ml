import type { SharedRef } from 'expo-modules-core/types';

import type {
  FaceObservation,
  MlKitAnalysisResult,
  MlKitBarcode,
  MlKitText,
} from './ExpoMlKit.types';
import type { MlKitFeature } from './artifacts';
import { hasFeature, nativeFunction } from './ExpoMlKitModule';
import {
  bestText,
  confidentText,
  needsOtherScripts,
  OTHER_TEXT_SCRIPTS,
} from './textQuality';

export * from './ExpoMlKit.types';
export * from './artifacts';
export { MlKitError } from './ExpoMlKitModule';

/** Any Expo image handle: from expo-image-manipulator, expo-image, or
 *  expo-image-ml-tools' `warp`. */
export type ImageRef = SharedRef<'image'>;

/**
 * Whether ML Kit can run here: the module is linked and its models are (not
 * on an iOS simulator, where Google ships no build). With a `feature`,
 * whether that feature is linked into this build too (the config plugin's
 * `features`; Android-only features never are on iOS).
 */
export function isMlKitAvailable(feature?: MlKitFeature): boolean {
  return hasFeature(feature);
}

/** `analyzeImage`'s models, by the feature that runs each. */
const IMAGE_MODELS: Readonly<Record<string, MlKitFeature>> = {
  mlKitText: 'text',
  mlKitLabels: 'labels',
  mlKitBarcodes: 'barcodes',
  mlKitPoses: 'poses',
  mlKitObjects: 'objects',
  mlKitEntities: 'entities',
};

/**
 * The ML Kit image models `models` names (`mlKit*` cell ids) over `image`,
 * an Expo image handle (expo-image-manipulator's, or any module's); a model
 * not asked for, or unknown, comes back empty, and one whose feature is not
 * linked rejects (`MlKitError`). The same on every platform, because the text
 * choices are made here, in TS:
 *
 * - Text is the Latin recognizer's, unless its read suggests another script
 *   (`needsOtherScripts`): then the other bundled recognizers read the photo
 *   too and the most well-formed read wins (`bestText`).
 * - Entities are found only in that text's confident lines
 *   (`confidentText`), so junk lines never become an "address". Asking for
 *   them runs text recognition too.
 */
export async function analyzeImage(
  image: ImageRef,
  models: readonly string[]
): Promise<MlKitAnalysisResult> {
  const features = new Set(
    models.flatMap((model) => IMAGE_MODELS[model] ?? [])
  );
  const analysis = features.size
    ? await nativeFunction('analyzeImage', ...features)(image, models)
    : {};
  // Text not asked for comes back empty, which never needs another script.
  let text: MlKitText = analysis.text ?? { text: '', blocks: [] };
  if (needsOtherScripts(text)) {
    // A second look, not the result: when it fails, the Latin read and every
    // other model's stand rather than the whole pass being lost and retried.
    const others = await nativeFunction('recognizeText', 'text')(
      image,
      OTHER_TEXT_SCRIPTS
    ).catch((): MlKitText[] => []);
    text = bestText([text, ...others]);
  }
  const entityText = features.has('entities') ? confidentText(text) : '';
  const entities = entityText
    ? await nativeFunction('extractEntities', 'entities')(entityText)
    : [];
  return {
    imageWidth: analysis.imageWidth ?? 0,
    imageHeight: analysis.imageHeight ?? 0,
    labels: [],
    barcodes: [],
    poses: [],
    objects: [],
    ...analysis,
    text,
    entities,
  };
}

/** ML Kit Face Detection, as Apple Vision `FaceObservation`s — the same
 *  shape on Android and iOS, so faces from either detector feed one face
 *  pipeline. Both detectors box one face in one place (the cross-detector
 *  device suite), so a caller can pair them by overlap. */
export async function detectFaces(image: ImageRef): Promise<FaceObservation[]> {
  return nativeFunction('detectFaces', 'faces')(image);
}

/** ML Kit Barcode Scanning alone, without `analyzeImage`'s other parts. */
export async function detectBarcodes(image: ImageRef): Promise<MlKitBarcode[]> {
  return nativeFunction('detectBarcodes', 'barcodes')(image);
}
