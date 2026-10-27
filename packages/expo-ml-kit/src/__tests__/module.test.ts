import { describe, expect, it, vi } from 'vitest';

import ExpoMlKit from '../ExpoMlKitModule';

const requireOptionalNativeModule = vi.hoisted(() => vi.fn(() => null));
vi.mock('expo', () => ({ requireOptionalNativeModule }));

describe('the native binding', () => {
  it('is optional: null where the module is not linked, never a throw', () => {
    expect(ExpoMlKit).toBeNull();
    expect(requireOptionalNativeModule).toHaveBeenCalledWith('ExpoMlKit');
  });
});
