import { describe, expect, it, vi } from 'vitest';

import FEATURES from '../features.json';
import { ML_KIT_FEATURES, type MlKitFeature } from '../index';

/**
 * The Android-only suites' native module: every feature linked, and every
 * function a mock resolving its own name until a test says else. Each suite
 * mocks `expo` to read `holder.module`.
 */
export type NativeMock = Record<string, ReturnType<typeof vi.fn>> & {
  isAvailable: boolean;
  features: MlKitFeature[];
};

export function linkEveryFeature(holder: { module: unknown }): NativeMock {
  const mod = {
    isAvailable: true,
    features: [...ML_KIT_FEATURES],
  } as NativeMock;
  holder.module = new Proxy(mod, {
    get: (target, key: string) =>
      (target[key] ??= vi.fn().mockResolvedValue(key) as never),
  });
  return mod;
}

/** Each feature's call is refused where the build leaves it out, saying
 *  it is Android-only, and reaches native once linked. */
export function describeAndroidOnly(
  calls: Partial<Record<MlKitFeature, () => Promise<unknown>>>,
  mod: () => NativeMock
) {
  const entries = Object.entries(calls) as [MlKitFeature, () => unknown][];
  describe('Android-only features', () => {
    it.each(entries)('%s is Android-only and off by default', (feature) => {
      expect(FEATURES[feature].ios).toEqual([]);
      expect(FEATURES[feature].default).toBe(false);
    });

    it.each(entries)(
      'refuses %s where it is not linked, saying so',
      async (feature, call) => {
        mod().features = mod().features.filter((name) => name !== feature);
        await expect(call()).rejects.toMatchObject({
          code: 'ERR_ML_KIT_FEATURE',
          message: expect.stringMatching(
            new RegExp(`'${feature}'.*runs on Android only`)
          ),
        });
      }
    );

    it.each(entries)('calls %s natively once linked', (_, call) =>
      expect(call()).resolves.toBeDefined()
    );
  });
}
