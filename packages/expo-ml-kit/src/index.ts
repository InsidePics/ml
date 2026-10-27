import type {
  FaceObservation,
  MlKitAnalysisResult,
  MlKitBarcode,
  MlKitText,
} from './ExpoMlKit.types';
import ExpoMlKit, { type ExpoMlKitNative } from './ExpoMlKitModule';
import {
  bestText,
  confidentText,
  needsOtherScripts,
  OTHER_TEXT_SCRIPTS,
} from './textQuality';

export * from './ExpoMlKit.types';
export * from './artifacts';

/**
 * Whether ML Kit can analyse on this device: the module is linked and its
 * models are (not on an iOS simulator, where Google ships no build).
 */
export function isMlKitAvailable(): boolean {
  return ExpoMlKit?.isAvailable === true;
}

function native(): ExpoMlKitNative {
  if (!ExpoMlKit) {
    throw new Error('ExpoMlKit is not available on this platform');
  }
  return ExpoMlKit;
}

/**
 * The ML Kit image models `models` names (`mlKit*` cell ids) over an upright
 * decode of `path`; any other model's result comes back empty. The same on
 * every platform, because the text choices are made here, in TS:
 *
 * - Text is the Latin recognizer's, unless its read suggests another script
 *   (`needsOtherScripts`): then the other bundled recognizers read the photo
 *   too and the most well-formed read wins (`bestText`).
 * - Entities are found only in that text's confident lines
 *   (`confidentText`), so junk lines never become an "address". Asking for
 *   them runs text recognition too.
 */
export async function analyzeImage(
  path: string,
  models: readonly string[]
): Promise<MlKitAnalysisResult> {
  const module = native();
  const analysis = await module.analyzeImage(path, models);
  // Text not asked for comes back empty, which never needs another script.
  let text: MlKitText = analysis.text;
  if (needsOtherScripts(text)) {
    // A second look, not the result: when it fails, the Latin read and every
    // other model's stand rather than the whole pass being lost and retried.
    const others = await module
      .recognizeText(path, OTHER_TEXT_SCRIPTS)
      .catch((): MlKitText[] => []);
    text = bestText([text, ...others]);
  }
  const entityText = models.includes('mlKitEntities')
    ? confidentText(text)
    : '';
  const entities = entityText ? await module.extractEntities(entityText) : [];
  return { ...analysis, text, entities };
}

/** ML Kit Face Detection, as Apple Vision `FaceObservation`s — the same
 *  shape on Android and iOS, so faces from either detector feed one face
 *  pipeline. Both detectors box one face in one place (the cross-detector
 *  device suite), so a caller can pair them by overlap. */
export function detectFaces(path: string): Promise<FaceObservation[]> {
  return native().detectFaces(path);
}

/** ML Kit Barcode Scanning alone, for the QR reader where Apple Vision is
 *  not present (implemented natively on Android). */
export function detectBarcodes(path: string): Promise<MlKitBarcode[]> {
  return native().detectBarcodes(path);
}
