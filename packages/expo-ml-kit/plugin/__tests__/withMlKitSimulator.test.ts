import fs from 'fs';
import { afterEach, describe, expect, it, vi } from 'vitest';

import withMlKitSimulator, {
  applyMlKitSimulatorHook,
  patchPodfile,
} from '../withMlKitSimulator.cjs';

const PODFILE =
  "target 'App' do\n  post_install do |installer|\n    react_native_post_install(installer)\n  end\nend\n";

afterEach(() => {
  vi.restoreAllMocks();
});

describe('applyMlKitSimulatorHook', () => {
  it('defines the unlink helper and calls it from post_install', () => {
    const out = applyMlKitSimulatorHook(PODFILE);
    expect(out.startsWith('# [expo-ml-kit] ML Kit')).toBe(true);
    expect(out).toContain('def expo_ml_kit_unlink_on_simulator');
    expect(out).toContain(
      'post_install do |installer|\n    expo_ml_kit_unlink_on_simulator(installer)\n'
    );
    // Only simulator builds lose ML Kit; device builds keep every framework.
    expect(out).toContain("attributes['OTHER_LDFLAGS[sdk=iphoneos*]']");
    expect(out).toContain("name.start_with?('MLKit') || name == 'MLImage'");
    // ...and an Apple Silicon simulator keeps its arm64 build.
    expect(out).toContain(
      "attributes.delete('EXCLUDED_ARCHS[sdk=iphonesimulator*]')"
    );
  });

  it('is idempotent', () => {
    const once = applyMlKitSimulatorHook(PODFILE);
    expect(applyMlKitSimulatorHook(once)).toBe(once);
  });

  it('refuses a Podfile it cannot hook into', () => {
    expect(() => applyMlKitSimulatorHook("target 'X' do\nend\n")).toThrow(
      /post_install/
    );
  });
});

describe('patchPodfile', () => {
  it('rewrites the generated Podfile in place', () => {
    vi.spyOn(fs, 'readFileSync').mockReturnValue(PODFILE);
    const write = vi.spyOn(fs, 'writeFileSync').mockImplementation(() => {});
    const cfg = { modRequest: { platformProjectRoot: '/ios' } };
    expect(patchPodfile(cfg as never)).toBe(cfg);
    expect(write).toHaveBeenCalledWith(
      '/ios/Podfile',
      applyMlKitSimulatorHook(PODFILE)
    );
  });

  it('is registered as an iOS dangerous mod', () => {
    const config = withMlKitSimulator({ name: 'x', slug: 'x' } as never);
    expect(config).toBeDefined();
  });
});
