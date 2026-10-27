import { describe, expect, it, vi } from 'vitest';

const requireOptionalNativeModule = vi.hoisted(() => vi.fn(() => null));
vi.mock('expo', () => ({ requireOptionalNativeModule }));

import ExpoMlKit from '../ExpoMlKitModule';

describe('the native binding', () => {
  it('is optional: null where the module is not linked, never a throw', () => {
    expect(ExpoMlKit).toBeNull();
    expect(requireOptionalNativeModule).toHaveBeenCalledWith('ExpoMlKit');
  });
});
