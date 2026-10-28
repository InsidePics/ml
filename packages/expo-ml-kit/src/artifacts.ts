import CATALOGUE from './features.json';

const FEATURES = CATALOGUE.features;

/**
 * The ML Kit features this module wraps, and the Google releases each links
 * on each platform. `features.json` is the one table: `android/build.gradle`
 * and `ios/ExpoMlKit.podspec` read it too, and link a feature's artifacts
 * only when the app enables the feature (the config plugin's `features`;
 * `DEFAULT_ML_KIT_FEATURES` when it names none). A feature with no iOS pods
 * is Android-only.
 *
 * Models are bundled (they ship in the app), so a result names the model that
 * produced it, except where ML Kit offers no bundled model: entity
 * extraction's, translation's and digital ink's per-language models download
 * at first use, and the `play-services-*` features (subject segmentation, the
 * document and code scanners) and the GenAI ones (Gemini Nano, through
 * AICore) run models Google Play services keeps up to date.
 *
 * The GenAI pins are the newest releases React Native's Kotlin (2.1) can
 * read: `genai-prompt` after 1.0.0-beta2 is built with Kotlin 2.3 and 2.4.
 *
 * A caller that versions stored results bumps its own version when an entry
 * here changes what a feature returns.
 */
export const ML_KIT_ARTIFACTS: Readonly<
  Record<MlKitFeature, { android: readonly string[]; ios: readonly string[] }>
> = FEATURES;

export type MlKitFeature = keyof typeof FEATURES;

/** What the module links whatever the features: the common runtime and
 *  image type every feature builds on. */
export const ML_KIT_CORE_ARTIFACTS = CATALOGUE.core;

/** Every feature, in `features.json`'s order. */
export const ML_KIT_FEATURES = Object.keys(FEATURES) as MlKitFeature[];

/** The features an app gets when its config plugin entry names none. */
export const DEFAULT_ML_KIT_FEATURES: readonly MlKitFeature[] =
  ML_KIT_FEATURES.filter((feature) => FEATURES[feature].default);

/**
 * The `Barcode.FORMAT_*` names the bundled scanner reports (without the
 * prefix), as a barcode's `format`. A format outside this list is dropped on
 * the device. QR's is `QR_CODE`.
 */
export const ML_KIT_BARCODE_FORMATS: ReadonlySet<string> = new Set([
  'AZTEC',
  'CODABAR',
  'CODE_39',
  'CODE_93',
  'CODE_128',
  'DATA_MATRIX',
  'EAN_8',
  'EAN_13',
  'ITF',
  'PDF417',
  'QR_CODE',
  'UPC_A',
  'UPC_E',
]);
