import { nativeFunction } from './ExpoMlKitModule';

/** A point of a stroke: where (any consistent unit, y down) and, optionally,
 *  when (ms; times help the recognizer). */
export type MlKitInkPoint = { x: number; y: number; t?: number };
/** One touch, finger down to finger up. */
export type MlKitInkStroke = MlKitInkPoint[];

export type MlKitInkOptions = {
  /** The model: a BCP-47 tag (`en-US`, `ja`, ...) or one of ML Kit's
   *  special ones: `zxx-Zsye-x-emoji`, `zxx-Zsym-x-autodraw` (sketches),
   *  `zxx-Zsym-x-shapes`. Download it first (`downloadInkModel`). */
  language: string;
  /** The writing area's size, in the strokes' units: lets the recognizer
   *  tell a lowercase "o" from an uppercase one. */
  writingArea?: { width: number; height: number };
  /** Text just before the ink (up to 20 characters), for context. */
  preContext?: string;
};

/** A reading of the ink, best first; `score` (lower is better) where the
 *  model gives one. */
export type MlKitInkCandidate = { text: string; score: number | null };

declare module './ExpoMlKitModule' {
  interface ExpoMlKitFunctions {
    recognizeInk(
      strokes: readonly MlKitInkStroke[],
      options: MlKitInkOptions
    ): Promise<MlKitInkCandidate[]>;
    downloadInkModel(language: string, wifiOnly: boolean): Promise<void>;
    deleteInkModel(language: string): Promise<void>;
    isInkModelDownloaded(language: string): Promise<boolean>;
  }
}

/** Digital Ink Recognition: handwriting (300+ languages), emoji, sketches or
 *  shapes from strokes. The model must be on the device: a missing one
 *  rejects with `ERR_ML_KIT_MODEL`. */
export async function recognizeInk(
  strokes: readonly MlKitInkStroke[],
  options: MlKitInkOptions
): Promise<MlKitInkCandidate[]> {
  return nativeFunction('recognizeInk', 'digitalInk')(strokes, options);
}

/** Fetch `language`'s ink model now (a few MB to ~20 MB); resolves once it
 *  is there. */
export async function downloadInkModel(
  language: string,
  { wifiOnly = true }: { wifiOnly?: boolean } = {}
): Promise<void> {
  return nativeFunction('downloadInkModel', 'digitalInk')(language, wifiOnly);
}

export async function deleteInkModel(language: string): Promise<void> {
  return nativeFunction('deleteInkModel', 'digitalInk')(language);
}

export async function isInkModelDownloaded(language: string): Promise<boolean> {
  return nativeFunction('isInkModelDownloaded', 'digitalInk')(language);
}
