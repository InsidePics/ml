import { nativeFunction } from './ExpoMlKitModule';

/** The languages ML Kit translates between (BCP-47), each pair through
 *  English: both ends' models must be on the device. */
export const ML_KIT_TRANSLATE_LANGUAGES = [
  'af',
  'ar',
  'be',
  'bg',
  'bn',
  'ca',
  'cs',
  'cy',
  'da',
  'de',
  'el',
  'en',
  'eo',
  'es',
  'et',
  'fa',
  'fi',
  'fr',
  'ga',
  'gl',
  'gu',
  'he',
  'hi',
  'hr',
  'ht',
  'hu',
  'id',
  'is',
  'it',
  'ja',
  'ka',
  'kn',
  'ko',
  'lt',
  'lv',
  'mk',
  'mr',
  'ms',
  'mt',
  'nl',
  'no',
  'pl',
  'pt',
  'ro',
  'ru',
  'sk',
  'sl',
  'sq',
  'sv',
  'sw',
  'ta',
  'te',
  'th',
  'tl',
  'tr',
  'uk',
  'ur',
  'vi',
  'zh',
] as const;
export type MlKitTranslateLanguage =
  (typeof ML_KIT_TRANSLATE_LANGUAGES)[number];

export type MlKitTranslateOptions = {
  from: MlKitTranslateLanguage;
  to: MlKitTranslateLanguage;
  /** Fetch a missing model first (default false: a missing model rejects
   *  with `ERR_ML_KIT_MODEL`, so a caller decides when ~30 MB downloads). */
  downloadIfNeeded?: boolean;
  /** With `downloadIfNeeded`: wait for Wi-Fi (default true). */
  wifiOnly?: boolean;
};

declare module './ExpoMlKitModule' {
  interface ExpoMlKitFunctions {
    translate(text: string, options: MlKitTranslateOptions): Promise<string>;
    downloadTranslationModel(
      language: MlKitTranslateLanguage,
      wifiOnly: boolean
    ): Promise<void>;
    deleteTranslationModel(language: MlKitTranslateLanguage): Promise<void>;
    downloadedTranslationModels(): Promise<MlKitTranslateLanguage[]>;
  }
}

/** On-device Translation of `text` (`from` → `to`). Both languages' models
 *  must be downloaded, or `downloadIfNeeded` set. */
export async function translate(
  text: string,
  options: MlKitTranslateOptions
): Promise<string> {
  return nativeFunction('translate', 'translate')(text, options);
}

/** Fetch `language`'s translation model now; resolves once it is there. */
export async function downloadTranslationModel(
  language: MlKitTranslateLanguage,
  { wifiOnly = true }: { wifiOnly?: boolean } = {}
): Promise<void> {
  return nativeFunction('downloadTranslationModel', 'translate')(
    language,
    wifiOnly
  );
}

export async function deleteTranslationModel(
  language: MlKitTranslateLanguage
): Promise<void> {
  return nativeFunction('deleteTranslationModel', 'translate')(language);
}

/** The languages whose translation models are on the device (English's is
 *  always there). */
export async function downloadedTranslationModels(): Promise<
  MlKitTranslateLanguage[]
> {
  return nativeFunction('downloadedTranslationModels', 'translate')();
}
