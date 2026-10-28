import type { MlKitText, MlKitTextScript } from './ExpoMlKit.types';
import { nativeFunction, type ImageRef } from './ExpoMlKitModule';

/**
 * One Text Recognition v2 recognizer's read of `image`: blocks, lines,
 * elements (and on Android symbols), each with its box, corners and
 * recognized languages. `analyzeImage`'s `mlKitText` chooses the script
 * itself; this reads with the one asked for (default `latin`, which also
 * reads most European languages).
 */
export async function recognizeText(
  image: ImageRef,
  script: MlKitTextScript = 'latin'
): Promise<MlKitText> {
  const [read] = await nativeFunction('recognizeText', 'text')(image, [script]);
  if (!read) throw new Error(`No read from the ${script} recognizer`);
  return read;
}
