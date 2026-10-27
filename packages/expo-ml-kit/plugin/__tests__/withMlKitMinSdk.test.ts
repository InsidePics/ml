import { describe, expect, it } from 'vitest';

import { MIN_SDK, raiseMinSdk } from '../withMlKitMinSdk.cjs';

const prop = (value: string) => ({
  type: 'property',
  key: 'android.minSdkVersion',
  value,
});

describe('raiseMinSdk', () => {
  it('adds the minimum entity extraction needs when none is set', () => {
    expect(raiseMinSdk([])).toEqual([prop(String(MIN_SDK))]);
    expect(MIN_SDK).toBe(26);
  });

  it('raises a lower minimum', () => {
    expect(raiseMinSdk([prop('24')])).toEqual([prop('26')]);
  });

  it('never lowers a higher one, and leaves other properties alone', () => {
    const other = { type: 'property', key: 'hermesEnabled', value: 'true' };
    expect(raiseMinSdk([other, prop('29')])).toEqual([other, prop('29')]);
  });
});
