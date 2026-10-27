import { requireOptionalNativeModule } from 'expo';
import type { SharedRef } from 'expo-modules-core/types';

import type {
  FaceObservation,
  MlKitAnalysisResult,
  MlKitBarcode,
  MlKitEntity,
  MlKitText,
  MlKitTextScript,
} from './ExpoMlKit.types';

/** The native module's raw surface; `index.ts` is the typed API. */
export interface ExpoMlKitNative {
  /** False where the module is linked but ML Kit is not (an iOS simulator:
   *  Google ships no simulator build of the iOS models). */
  readonly isAvailable: boolean;
  /** The image models over the one image; text by the Latin recognizer. No
   *  entities: they are found in TS-chosen text (`extractEntities`). */
  analyzeImage(
    image: SharedRef<'image'>,
    models: readonly string[]
  ): Promise<Omit<MlKitAnalysisResult, 'entities'>>;
  /** The given scripts' recognizers over the one image, in order. */
  recognizeText(
    image: SharedRef<'image'>,
    scripts: readonly MlKitTextScript[]
  ): Promise<MlKitText[]>;
  /** Entities in `text`; null while the language model is not on the
   *  device yet ("unknown", never "none"). */
  extractEntities(text: string): Promise<MlKitEntity[] | null>;
  detectFaces(image: SharedRef<'image'>): Promise<FaceObservation[]>;
  detectBarcodes(image: SharedRef<'image'>): Promise<MlKitBarcode[]>;
}

/**
 * The native module (Android and iOS), or null where it is not linked: on
 * web importing this never throws (`requireNativeModule` would), and only a
 * call does.
 */
export default requireOptionalNativeModule<ExpoMlKitNative>('ExpoMlKit');
