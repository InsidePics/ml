import { nativeFunction, type ImageRef } from './ExpoMlKitModule';
import type { MlKitGenAiStatus } from './genAi';

/** Each left to the model when unset. */
export type MlKitGenerateOptions = {
  /** An image the prompt is about. */
  image?: ImageRef;
  temperature?: number;
  topK?: number;
  maxOutputTokens?: number;
  /** How many answers to return. */
  candidateCount?: number;
  seed?: number;
};

export type MlKitGenerateCandidate = {
  text: string;
  /** `maxTokens`: cut at `maxOutputTokens`. */
  finishReason: 'stop' | 'maxTokens' | 'other';
};

type Generate = Omit<MlKitGenerateOptions, 'image'>;

declare module './ExpoMlKitModule' {
  interface ExpoMlKitFunctions {
    getGenerativeModelStatus(): Promise<MlKitGenAiStatus>;
    downloadGenerativeModel(): Promise<void>;
    generateContent(
      prompt: string,
      image: ImageRef | null,
      options: Generate
    ): Promise<MlKitGenerateCandidate[]>;
  }
}

/** The GenAI Prompt API's status (`MlKitGenAiStatus`). */
export async function getGenerativeModelStatus(): Promise<MlKitGenAiStatus> {
  return nativeFunction('getGenerativeModelStatus', 'genAiPrompt')();
}

/** Downloads the Prompt API's model; resolves once it is on the device. */
export async function downloadGenerativeModel(): Promise<void> {
  return nativeFunction('downloadGenerativeModel', 'genAiPrompt')();
}

/** ML Kit GenAI Prompt (Android only): Gemini Nano's answers to `prompt`,
 *  about `options.image` when given; one unless `candidateCount` asks for
 *  more. */
export async function generateContent(
  prompt: string,
  options: MlKitGenerateOptions = {}
): Promise<MlKitGenerateCandidate[]> {
  const { image, ...generation } = options;
  return nativeFunction('generateContent', 'genAiPrompt')(
    prompt,
    image ?? null,
    generation
  );
}
