import { describe, expect, it } from 'vitest';

import { DEFAULT_ML_KIT_FEATURES, ML_KIT_FEATURES } from '../../src/artifacts';
import {
  KEY,
  resolveFeatures,
  setGradleFeatures,
} from '../withMlKitFeatures.cjs';

describe('resolveFeatures', () => {
  it('links the defaults when the plugin names none', () => {
    expect(resolveFeatures(undefined)).toEqual(DEFAULT_ML_KIT_FEATURES);
  });

  it("links every feature for 'all'", () => {
    expect(resolveFeatures('all')).toEqual(ML_KIT_FEATURES);
  });

  it('adds what a feature requires, in the catalogue order', () => {
    expect(resolveFeatures(['entities', 'barcodes'])).toEqual([
      'text',
      'barcodes',
      'entities',
    ]);
  });

  it('fails the prebuild on a feature it does not know', () => {
    expect(() => resolveFeatures(['text', 'telepathy'])).toThrow(
      /no feature 'telepathy'/
    );
    expect(() => resolveFeatures('everything')).toThrow(/'all' or a list/);
  });
});

describe('setGradleFeatures', () => {
  const prop = (value: string) => ({ type: 'property', key: KEY, value });

  it('adds the property, or replaces the one a previous prebuild wrote', () => {
    expect(setGradleFeatures([], ['text', 'faces'])).toEqual([
      prop('text,faces'),
    ]);
    const other = { type: 'property', key: 'hermesEnabled', value: 'true' };
    expect(setGradleFeatures([other, prop('text')], ['faces'])).toEqual([
      other,
      prop('faces'),
    ]);
  });
});
