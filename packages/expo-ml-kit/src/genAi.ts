import { nativeFunction, type ImageRef } from './ExpoMlKitModule';

/**
 * Where a GenAI feature (Gemini Nano, through Android's AICore) stands on
 * this device. A GenAI call that cannot run rejects with
 * `ERR_ML_KIT_GENAI_UNAVAILABLE` rather than waiting; one that fails in the
 * model, with `ERR_ML_KIT_GENAI`.
 */
export type MlKitGenAiStatus =
  /** Runs now. */
  | 'available'
  /** Runs once its model is on the device (the feature's download call). */
  | 'downloadable'
  /** Its model is on its way. */
  | 'downloading'
  /** Never runs here: no AICore, or no Gemini Nano for this device. */
  | 'unavailable';

/** The languages the text features take; summarization takes `en`, `ja`
 *  and `ko`. */
export type MlKitGenAiLanguage = 'en' | 'ja' | 'ko' | 'de' | 'fr' | 'it' | 'es';

export type MlKitSummarizerOptions = {
  /** `article` (the default) or `conversation` (a chat's messages). */
  inputType?: 'article' | 'conversation';
  outputType?: 'oneBullet' | 'twoBullets' | 'threeBullets';
  language?: 'en' | 'ja' | 'ko';
  /** Cut input past the model's limit instead of rejecting it. */
  autoTruncate?: boolean;
};

export type MlKitProofreaderOptions = {
  /** `keyboard` (typed, the default) or `voice` (dictated). */
  inputType?: 'keyboard' | 'voice';
  language?: MlKitGenAiLanguage;
};

export type MlKitRewriterOptions = {
  style?:
    | 'elaborate'
    | 'emojify'
    | 'shorten'
    | 'friendly'
    | 'professional'
    | 'rephrase';
  language?: MlKitGenAiLanguage;
};

type Summarize = Required<MlKitSummarizerOptions>;
type Proofread = Required<MlKitProofreaderOptions>;
type Rewrite = Required<MlKitRewriterOptions>;

declare module './ExpoMlKitModule' {
  interface ExpoMlKitFunctions {
    getSummarizerStatus(options: Summarize): Promise<MlKitGenAiStatus>;
    downloadSummarizer(options: Summarize): Promise<void>;
    summarize(text: string, options: Summarize): Promise<string>;
    getProofreaderStatus(options: Proofread): Promise<MlKitGenAiStatus>;
    downloadProofreader(options: Proofread): Promise<void>;
    proofread(text: string, options: Proofread): Promise<string[]>;
    getRewriterStatus(options: Rewrite): Promise<MlKitGenAiStatus>;
    downloadRewriter(options: Rewrite): Promise<void>;
    rewrite(text: string, options: Rewrite): Promise<string[]>;
    getImageDescriberStatus(): Promise<MlKitGenAiStatus>;
    downloadImageDescriber(): Promise<void>;
    describeImage(image: ImageRef): Promise<string>;
  }
}

const summarizer = (o: MlKitSummarizerOptions): Summarize => ({
  inputType: o.inputType ?? 'article',
  outputType: o.outputType ?? 'oneBullet',
  language: o.language ?? 'en',
  autoTruncate: o.autoTruncate ?? false,
});
const proofreader = (o: MlKitProofreaderOptions): Proofread => ({
  inputType: o.inputType ?? 'keyboard',
  language: o.language ?? 'en',
});
const rewriter = (o: MlKitRewriterOptions): Rewrite => ({
  style: o.style ?? 'rephrase',
  language: o.language ?? 'en',
});

/** GenAI Summarization's status for these options (each language is its
 *  own model). */
export async function getSummarizerStatus(
  options: MlKitSummarizerOptions = {}
): Promise<MlKitGenAiStatus> {
  return nativeFunction(
    'getSummarizerStatus',
    'genAiSummarization'
  )(summarizer(options));
}

/** Downloads Summarization's model; resolves once it is on the device. */
export async function downloadSummarizer(
  options: MlKitSummarizerOptions = {}
): Promise<void> {
  return nativeFunction(
    'downloadSummarizer',
    'genAiSummarization'
  )(summarizer(options));
}

/** ML Kit GenAI Summarization (Android only): `text` as bullets, one per
 *  line. */
export async function summarize(
  text: string,
  options: MlKitSummarizerOptions = {}
): Promise<string> {
  return nativeFunction('summarize', 'genAiSummarization')(
    text,
    summarizer(options)
  );
}

export async function getProofreaderStatus(
  options: MlKitProofreaderOptions = {}
): Promise<MlKitGenAiStatus> {
  return nativeFunction(
    'getProofreaderStatus',
    'genAiProofreading'
  )(proofreader(options));
}

export async function downloadProofreader(
  options: MlKitProofreaderOptions = {}
): Promise<void> {
  return nativeFunction(
    'downloadProofreader',
    'genAiProofreading'
  )(proofreader(options));
}

/** ML Kit GenAI Proofreading (Android only): `text` corrected, as one or
 *  more suggestions, best first. */
export async function proofread(
  text: string,
  options: MlKitProofreaderOptions = {}
): Promise<string[]> {
  return nativeFunction('proofread', 'genAiProofreading')(
    text,
    proofreader(options)
  );
}

export async function getRewriterStatus(
  options: MlKitRewriterOptions = {}
): Promise<MlKitGenAiStatus> {
  return nativeFunction(
    'getRewriterStatus',
    'genAiRewriting'
  )(rewriter(options));
}

export async function downloadRewriter(
  options: MlKitRewriterOptions = {}
): Promise<void> {
  return nativeFunction(
    'downloadRewriter',
    'genAiRewriting'
  )(rewriter(options));
}

/** ML Kit GenAI Rewriting (Android only): `text` in `style` (`rephrase` by
 *  default), as one or more suggestions, best first. */
export async function rewrite(
  text: string,
  options: MlKitRewriterOptions = {}
): Promise<string[]> {
  return nativeFunction('rewrite', 'genAiRewriting')(text, rewriter(options));
}

export async function getImageDescriberStatus(): Promise<MlKitGenAiStatus> {
  return nativeFunction('getImageDescriberStatus', 'genAiImageDescription')();
}

export async function downloadImageDescriber(): Promise<void> {
  return nativeFunction('downloadImageDescriber', 'genAiImageDescription')();
}

/** ML Kit GenAI Image Description (Android only): a short English
 *  description of `image`. */
export async function describeImage(image: ImageRef): Promise<string> {
  return nativeFunction('describeImage', 'genAiImageDescription')(image);
}
