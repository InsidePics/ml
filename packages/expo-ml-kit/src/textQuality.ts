import type { MlKitText } from './ExpoMlKit.types';

/**
 * How much of a recognized text reads as text, judged from the strings
 * alone. ML Kit's text v2 reports a confidence per line and element on
 * Android but none on iOS, so neither platform's is used: this one
 * heuristic decides on both, and the same photo gets the same verdict
 * wherever it is analysed.
 *
 * A line is split on whitespace into tokens, and each token into pieces at
 * `@ . / : -` and where a CJK or Devanagari run meets anything else
 * (`営業時間10:00` is `営業時間`, `10`, `00`). A token reads as text when every
 * piece is well-formed: a lower-case, Capitalized, ALL-CAPS or camel-cased
 * word (`iPhone`, `YouTube`), a number or a short quantity (`115V`), or a
 * non-Latin run. Junk from a Latin recognizer reading another script, or a
 * blurred label, flips case or mixes digits inside a word (`HoroR`, `M4CH`,
 * `RRybto6Mys`). A token of one letter is neither, in any script.
 */

/** The bundled recognizers, Latin first: `MlKitTextScript` is one of these. */
export const TEXT_SCRIPTS = [
  'latin',
  'chinese',
  'devanagari',
  'japanese',
  'korean',
] as const;

/** The recognizers tried after Latin, when its read suggests another
 *  script. One more native call over the same image: the price of deciding
 *  here, the same on every platform, and only paid on photos whose Latin
 *  read fails. */
export const OTHER_TEXT_SCRIPTS = TEXT_SCRIPTS.slice(1);

/** Scripts written a word or more per character. */
const DENSE =
  '\\p{Script=Han}\\p{Script=Hiragana}\\p{Script=Katakana}\\p{Script=Hangul}';
/** Every character the non-Latin recognizers read, and the marks that join
 *  a Japanese run (`ー`, `・`). */
const NON_LATIN_CLASS = `${DENSE}\\p{Script=Devanagari}ー・`;
const NON_LATIN = new RegExp(`[${NON_LATIN_CLASS}]`, 'u');
const DENSE_CHAR = new RegExp(`[${DENSE}]`, 'u');
/** A token's pieces: non-Latin runs, and the rest between separators. */
const PIECES = new RegExp(
  `[${NON_LATIN_CLASS}]+|[^${NON_LATIN_CLASS}@./:\\-–]+`,
  'gu'
);
const NON_LATIN_RUN = new RegExp(`^[${NON_LATIN_CLASS}]+$`, 'u');

const LATIN_WORD =
  '(\\p{Ll}+|\\p{Lu}\\p{Ll}+|\\p{Lu}{2,}|\\p{Ll}?(\\p{Lu}\\p{Ll}{2,})+|\\p{Ll}\\p{Lu}+)';
const WORD = new RegExp(`^${LATIN_WORD}(['’]${LATIN_WORD})*$`, 'u');
const NUMBER = /^[+$€£¥#]?\d+(,\d+)*%?$/u;
/** A quantity and its unit (`115V`, `8GB`, `157K`): a long digit run with
 *  a letter stuck on (`1111111I`) is a misread, not a measure. */
const QUANTITY = /^\d{1,4}\p{L}{1,3}$/u;
const EDGE_PUNCTUATION = /^[\p{P}\p{S}]+|[\p{P}\p{S}]+$/gu;
const MARK = /\p{M}/u;
const LETTER_OR_DIGIT = /[\p{L}\p{N}]/u;

/** A CJK character weighs this many letters: it carries a word's worth of
 *  meaning, so a two-character Chinese word is not "tiny". Devanagari is
 *  alphabetic and weighs as Latin; its vowel signs (marks) weigh nothing. */
const DENSE_CHAR_WEIGHT = 2;
/** A line needs this much well-formed text to count at all: a lone `D` or
 *  `EE` is noise however clean it looks. */
const MIN_LINE_WEIGHT = 3;
/** And this share of its letters and digits in well-formed tokens. */
const MIN_LINE_SHARE = 0.6;

/** A token's weight, and how many letters and digits it has. */
function measure(token: string): { weight: number; chars: number } {
  let weight = 0;
  let chars = 0;
  for (const char of token) {
    if (MARK.test(char) || !LETTER_OR_DIGIT.test(char)) continue;
    chars += 1;
    weight += DENSE_CHAR.test(char) ? DENSE_CHAR_WEIGHT : 1;
  }
  return { weight, chars };
}

function isWellFormedPiece(piece: string): boolean {
  return (
    NON_LATIN_RUN.test(piece) ||
    WORD.test(piece) ||
    NUMBER.test(piece) ||
    QUANTITY.test(piece)
  );
}

/** A line's weight in well-formed tokens, and in all its letters/digits. */
export function lineScore(line: string): { good: number; total: number } {
  let good = 0;
  let total = 0;
  for (const raw of line.split(/\s+/)) {
    const token = raw.replace(EDGE_PUNCTUATION, '');
    const { weight, chars } = measure(token);
    total += weight;
    const pieces = token.match(PIECES) ?? [];
    if (chars > 1 && pieces.every(isWellFormedPiece)) good += weight;
  }
  return { good, total };
}

function isConfident({ good, total }: { good: number; total: number }) {
  return good >= MIN_LINE_WEIGHT && good >= total * MIN_LINE_SHARE;
}

/** Whether a line reads as text: enough of it, mostly well-formed. */
export function isConfidentLine(line: string): boolean {
  return isConfident(lineScore(line));
}

/** A text judged in one pass: its confident lines, their well-formed
 *  weight (what recognizers are compared on), and the weight of it all. */
function scoreText(text: MlKitText): {
  confident: string[];
  good: number;
  total: number;
} {
  const confident: string[] = [];
  let good = 0;
  let total = 0;
  for (const line of text.text.split('\n')) {
    const score = lineScore(line);
    total += score.total;
    if (!isConfident(score)) continue;
    confident.push(line);
    good += score.good;
  }
  return { confident, good, total };
}

/** A text's confident lines only, the input entity extraction reads: an
 *  entity built across junk lines (an "address" out of `9`, `EE`, `NW9`) is
 *  never found because those lines never reach it. */
export function confidentText(text: MlKitText): string {
  return scoreText(text).confident.join('\n');
}

/** How much well-formed text a recognizer read: the weight of its confident
 *  lines. Recognizers are compared on it. */
export function textScore(text: MlKitText): number {
  return scoreText(text).good;
}

/** Below this share of well-formed text, the Latin read is worth checking
 *  against the other scripts' recognizers. */
const RETRY_BELOW_SHARE = 0.5;
/** A text this light (a stray letter or two) is not worth a second pass. */
const RETRY_MIN_WEIGHT = 4;

/**
 * Whether the Latin recognizer's read suggests another script: it saw
 * non-Latin characters, or most of what it read is junk.
 */
export function needsOtherScripts(latin: MlKitText): boolean {
  if (NON_LATIN.test(latin.text)) return true;
  const { good, total } = scoreText(latin);
  return total >= RETRY_MIN_WEIGHT && good < total * RETRY_BELOW_SHARE;
}

/** The best read of several recognizers: the most well-formed text, the
 *  first (Latin) on a tie. */
export function bestText<T extends MlKitText>(reads: readonly T[]): T {
  const first = reads[0];
  if (!first) throw new Error('bestText needs at least one read');
  let best = first;
  let bestScore = textScore(best);
  for (const read of reads.slice(1)) {
    const score = textScore(read);
    if (score > bestScore) [best, bestScore] = [read, score];
  }
  return best;
}
