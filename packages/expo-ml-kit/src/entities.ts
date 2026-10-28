import type { MlKitEntity, MlKitEntityType } from './ExpoMlKit.types';
import { nativeFunction } from './ExpoMlKitModule';

/** The languages Entity Extraction has models for (BCP-47). */
export const ML_KIT_ENTITY_LANGUAGES = [
  'ar',
  'de',
  'en',
  'es',
  'fr',
  'it',
  'ja',
  'ko',
  'nl',
  'pl',
  'pt',
  'ru',
  'th',
  'tr',
  'zh',
] as const;
export type MlKitEntityLanguage = (typeof ML_KIT_ENTITY_LANGUAGES)[number];

export type MlKitEntityOptions = {
  /** The text's language (default `en`): its model downloads at first use. */
  language?: MlKitEntityLanguage;
  /** Only these types (every kept type when left out). */
  types?: readonly MlKitEntityType[];
  /** What relative dates ("tomorrow at 5") resolve against: ms since the
   *  epoch (default now) and an IANA time zone (default the device's). */
  referenceTime?: number;
  timeZone?: string;
  /** A BCP-47 locale for ambiguous formats (`en-GB` reads 1/2 as 1 Feb). */
  locale?: string;
};

type NativeOptions = Omit<MlKitEntityOptions, 'language'> & {
  language: MlKitEntityLanguage;
};

declare module './ExpoMlKitModule' {
  interface ExpoMlKitFunctions {
    /** Null while the language model is not on the device yet. */
    extractEntities(
      text: string,
      options?: NativeOptions
    ): Promise<MlKitEntity[] | null>;
    downloadEntityModel(
      language: MlKitEntityLanguage,
      wifiOnly: boolean
    ): Promise<void>;
    deleteEntityModel(language: MlKitEntityLanguage): Promise<void>;
    downloadedEntityModels(): Promise<MlKitEntityLanguage[]>;
  }
}

/**
 * Entity Extraction over `text`: addresses, dates and times, emails, flight
 * numbers, ISBNs, amounts of money, phone numbers, parcel tracking numbers
 * and URLs, each with its span and parsed value. Null — "unknown", never "no
 * entities" — while the language's model is not on the device: ML Kit
 * starts its download (Wi-Fi only) at the first call; `downloadEntityModel`
 * fetches it ahead.
 */
export async function extractEntities(
  text: string,
  options: MlKitEntityOptions = {}
): Promise<MlKitEntity[] | null> {
  return nativeFunction('extractEntities', 'entities')(text, {
    ...options,
    language: options.language ?? 'en',
  });
}

/** Fetch `language`'s entity model now; resolves once it is on the device.
 *  `wifiOnly` (default true) waits for Wi-Fi rather than use mobile data. */
export async function downloadEntityModel(
  language: MlKitEntityLanguage,
  { wifiOnly = true }: { wifiOnly?: boolean } = {}
): Promise<void> {
  return nativeFunction('downloadEntityModel', 'entities')(language, wifiOnly);
}

export async function deleteEntityModel(
  language: MlKitEntityLanguage
): Promise<void> {
  return nativeFunction('deleteEntityModel', 'entities')(language);
}

/** The languages whose entity models are on the device. */
export async function downloadedEntityModels(): Promise<MlKitEntityLanguage[]> {
  return nativeFunction('downloadedEntityModels', 'entities')();
}
