import { requireOptionalNativeModule } from 'expo';
import type { SharedRef } from 'expo-modules-core/types';

import type {
  MlKitAnalysisResult,
  MlKitText,
  MlKitTextScript,
} from './ExpoMlKit.types';
import { ML_KIT_ARTIFACTS, type MlKitFeature } from './artifacts';

/** Any Expo image handle: from expo-image-manipulator, expo-image, or
 *  expo-image-ml-tools' `warp`. */
export type ImageRef = SharedRef<'image'>;
type Image = ImageRef;

/**
 * The native module's functions, each defined only where its feature is
 * linked. Each area's file (`faces.ts`, `barcodes.ts`, ...) declares its own
 * here, by interface merging, beside the typed calls it exports.
 */
export interface ExpoMlKitFunctions {
  /** The linked image models over the one image; text by the Latin
   *  recognizer. A part not asked for is left out. No entities: they are
   *  found in TS-chosen text (`entities.ts`). */
  analyzeImage(
    image: Image,
    models: readonly string[]
  ): Promise<Partial<Omit<MlKitAnalysisResult, 'entities'>>>;
  /** The given scripts' recognizers over the one image, in order. */
  recognizeText(
    image: Image,
    scripts: readonly MlKitTextScript[]
  ): Promise<MlKitText[]>;
}

export type ExpoMlKitNative = Partial<ExpoMlKitFunctions> & {
  /** False where the module is linked but ML Kit is not (an iOS simulator:
   *  Google ships no simulator build of the iOS models). */
  readonly isAvailable: boolean;
  /** The `features.json` features linked into this build. */
  readonly features: readonly MlKitFeature[];
};

/**
 * The native module (Android and iOS), or null where it is not linked: on
 * web importing this never throws (`requireNativeModule` would), and only a
 * call does.
 */
const ExpoMlKit = requireOptionalNativeModule<ExpoMlKitNative>('ExpoMlKit');
export default ExpoMlKit;

/** Why an ML Kit call could not run: `ERR_ML_KIT_UNAVAILABLE` (no ML Kit
 *  here: web, an iOS simulator) or `ERR_ML_KIT_FEATURE` (the feature is not
 *  linked into this build). Native failures reject with their own codes. */
export class MlKitError extends Error {
  constructor(
    readonly code: 'ERR_ML_KIT_UNAVAILABLE' | 'ERR_ML_KIT_FEATURE',
    message: string
  ) {
    super(message);
    this.name = 'MlKitError';
  }
}

/** Whether ML Kit runs here, and with `feature`, whether that feature is
 *  linked into this build too. */
export function hasFeature(feature?: MlKitFeature): boolean {
  return (
    ExpoMlKit?.isAvailable === true &&
    (!feature || ExpoMlKit.features.includes(feature))
  );
}

/**
 * The native `fn`, once every one of `features` is linked, or a thrown
 * `MlKitError` saying why it cannot run: the one gate every call goes
 * through.
 */
export function nativeFunction<K extends keyof ExpoMlKitFunctions>(
  fn: K,
  ...features: MlKitFeature[]
): ExpoMlKitFunctions[K] {
  if (!ExpoMlKit?.isAvailable) {
    throw new MlKitError(
      'ERR_ML_KIT_UNAVAILABLE',
      'ML Kit is not available here (web, or an iOS simulator)'
    );
  }
  for (const feature of features) {
    if (ExpoMlKit.features.includes(feature)) continue;
    const androidOnly = ML_KIT_ARTIFACTS[feature].ios.length === 0;
    throw new MlKitError(
      'ERR_ML_KIT_FEATURE',
      `ML Kit's '${feature}' is not linked into this build: ` +
        (androidOnly ? 'it runs on Android only, where ' : '') +
        `add it to the expo-ml-kit config plugin's \`features\` and rebuild`
    );
  }
  const found = ExpoMlKit[fn];
  if (!found) throw new Error(`ExpoMlKit has no native ${fn}`);
  return found.bind(ExpoMlKit) as ExpoMlKitFunctions[K];
}
