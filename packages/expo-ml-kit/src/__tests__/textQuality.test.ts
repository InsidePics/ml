import { describe, expect, it } from 'vitest';

import {
  bestText,
  confidentText,
  isConfidentLine,
  needsOtherScripts,
  textScore,
} from '../textQuality';

/** A recognized text from its lines. Synthetic strings shaped like what a
 *  phone's recognizer returned: no real photo's text is kept here. */
const read = (...lines: string[]) => ({ text: lines.join('\n'), blocks: [] });

describe('isConfidentLine', () => {
  it.each([
    'Scapula Push-Ups (2 sets of 8-12 reps)',
    'MONDAY: PUSH DAY',
    "Superman's (1 set, 60 seconds)",
    '22:50',
    '220V AC',
    'Open 9 to 5',
    '营业时间',
    'ラーメン屋',
    '서울역',
    'नमस्ते दुनिया',
    // CJK runs straight into digits, with no space between.
    '営業時間10:00-22:00',
    '10月25日',
    // The entities extraction is for: emails, URLs, names with digits.
    'Email: info@shop.com',
    'www.example.com',
    'iPhone 15 Pro',
    'Visit eBay',
    'COVID-19 test',
  ])('reads %j as text', (line) => {
    expect(isConfidentLine(line)).toBe(true);
  });

  it.each([
    // Mixed case and digits inside a word: a misread.
    'QorvR Ultmo -K7XB',
    'PpAt9 zz3Qe',
    '5555555L',
    '(02)48871234%)',
    'HoroR -M4CH',
    'RRybto6Mys',
    // Clean but too little to be text on its own, in any script.
    'D',
    'EE',
    'ठ ड ढण',
    '',
  ])('does not read %j as text', (line) => {
    expect(isConfidentLine(line)).toBe(false);
  });
});

describe('confidentText', () => {
  it('keeps only the confident lines, so junk never joins an entity', () => {
    expect(
      confidentText(
        read('Call 555 0101', 'QorvR', 'Ultmo -K7XB', 'OPEN 9 to 5')
      )
    ).toBe('Call 555 0101\nOPEN 9 to 5');
  });

  it('drops a run of tiny lines that would read as an address', () => {
    expect(confidentText(read('7', 'FF', 'QX', '4 E', 'KK', 'SE7', 'B'))).toBe(
      ''
    );
  });
});

describe('needsOtherScripts', () => {
  it('trusts a clean Latin read', () => {
    expect(needsOtherScripts(read('WEDNESDAY: LEG DAY', 'WARM-UP'))).toBe(
      false
    );
  });

  it('retries a mostly-junk read, or one that saw another script', () => {
    expect(needsOtherScripts(read('QorvR Ultmo -K7XB', 'PpAt9 zz3Qe'))).toBe(
      true
    );
    expect(needsOtherScripts(read('Exit 出口'))).toBe(true);
  });

  it('does not retry a read too small to judge', () => {
    expect(needsOtherScripts(read('Qz'))).toBe(false);
    expect(needsOtherScripts(read(''))).toBe(false);
  });
});

describe('bestText', () => {
  it('picks the most well-formed read, Latin on a tie', () => {
    const latin = read('QorvR Ultmo -K7XB');
    const chinese = read('营业时间 周一至周五');
    expect(bestText([latin, chinese])).toBe(chinese);
    expect(textScore(chinese)).toBeGreaterThan(textScore(latin));
    const alsoLatin = read('Open 9 to 5');
    expect(bestText([alsoLatin, read('Open 9 to 5')])).toBe(alsoLatin);
  });

  it('keeps a clean Latin read over stray non-Latin letters', () => {
    const latin = read('Open daily');
    expect(bestText([latin, read('ठ ड ढण')])).toBe(latin);
  });
});
