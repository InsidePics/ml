import { beforeEach, describe, expect, it, vi } from 'vitest';

import {
  analyzeImage,
  DEFAULT_ML_KIT_FEATURES,
  detectBarcodes,
  detectFaces,
  isMlKitAvailable,
  MlKitError,
  type ImageRef,
} from '../index';
import { OTHER_TEXT_SCRIPTS } from '../textQuality';

// The binding `requireOptionalNativeModule` returns, read through on every
// access so each test can swap the module under it (null: not linked).
const native = vi.hoisted(() => ({
  module: null as Record<string, unknown> | null,
}));
vi.mock('expo', () => ({
  requireOptionalNativeModule: () =>
    new Proxy({}, { get: (_, key: string) => native.module?.[key] }),
}));

/** An image handle, as expo-image-manipulator returns one. */
const photo = { width: 4, height: 3 } as unknown as ImageRef;
const read = (...lines: string[]) => ({ text: lines.join('\n'), blocks: [] });
const analysis = (text = read()) => ({
  imageWidth: 10,
  imageHeight: 10,
  text,
  labels: [],
  barcodes: [],
  poses: [],
  objects: [],
});

const nativeModule = () => ({
  isAvailable: true,
  features: [...DEFAULT_ML_KIT_FEATURES] as string[],
  analyzeImage: vi.fn().mockResolvedValue(analysis()),
  recognizeText: vi.fn().mockResolvedValue([]),
  extractEntities: vi.fn().mockResolvedValue([]),
  detectFaces: vi.fn().mockResolvedValue([{ confidence: 1 }]),
  detectBarcodes: vi.fn().mockResolvedValue([{ format: 'QR_CODE' }]),
});
let mod: ReturnType<typeof nativeModule>;
const unlink = (feature: string) => {
  mod.features = mod.features.filter((name) => name !== feature);
};
beforeEach(() => {
  mod = nativeModule();
  native.module = mod;
});

describe('analyzeImage', () => {
  it('reads clean Latin text once and finds entities in it', async () => {
    mod.analyzeImage.mockResolvedValueOnce(analysis(read('Call 555 0101')));
    mod.extractEntities.mockResolvedValueOnce([
      { type: 'phone', value: '555 0101' },
    ]);
    const result = await analyzeImage(photo, ['mlKitText', 'mlKitEntities']);
    expect(mod.analyzeImage).toHaveBeenCalledWith(photo, [
      'mlKitText',
      'mlKitEntities',
    ]);
    expect(mod.recognizeText).not.toHaveBeenCalled();
    expect(mod.extractEntities).toHaveBeenCalledWith('Call 555 0101');
    expect(result.entities).toEqual([{ type: 'phone', value: '555 0101' }]);
  });

  it('tries the other scripts on a junk read and keeps the best', async () => {
    mod.analyzeImage.mockResolvedValueOnce(
      analysis(read('QorvR Ultmo -K7XB', 'PpAt9 zz3Qe'))
    );
    const chinese = read('营业时间 周一至周五');
    mod.recognizeText.mockResolvedValueOnce([chinese, read(), read(), read()]);
    const result = await analyzeImage(photo, ['mlKitText', 'mlKitEntities']);
    expect(mod.recognizeText).toHaveBeenCalledWith(photo, OTHER_TEXT_SCRIPTS);
    expect(result.text).toBe(chinese);
    expect(mod.extractEntities).toHaveBeenCalledWith('营业时间 周一至周五');
  });

  it('keeps the Latin read when the other scripts fail', async () => {
    const latin = read('QorvR Ultmo -K7XB', 'PpAt9 zz3Qe');
    mod.analyzeImage.mockResolvedValueOnce(analysis(latin));
    mod.recognizeText.mockRejectedValueOnce(new Error('out of memory'));
    const result = await analyzeImage(photo, ['mlKitText']);
    expect(result.text).toBe(latin);
  });

  it('fails the pass when entity extraction fails, as any model does', async () => {
    mod.analyzeImage.mockResolvedValueOnce(analysis(read('Call 555 0101')));
    mod.extractEntities.mockRejectedValueOnce(new Error('model gone'));
    await expect(analyzeImage(photo, ['mlKitEntities'])).rejects.toThrow(
      'model gone'
    );
  });

  it('finds no entities in junk, without asking the extractor', async () => {
    mod.analyzeImage.mockResolvedValueOnce(analysis(read('7', 'FF', 'SE7')));
    const result = await analyzeImage(photo, ['mlKitEntities']);
    expect(mod.extractEntities).not.toHaveBeenCalled();
    expect(result.entities).toEqual([]);
  });

  it('keeps "unknown" entities while the model is not on the device', async () => {
    mod.analyzeImage.mockResolvedValueOnce(analysis(read('Call 555 0101')));
    mod.extractEntities.mockResolvedValueOnce(null);
    const result = await analyzeImage(photo, ['mlKitEntities']);
    expect(result.entities).toBeNull();
  });

  it('runs no text pass when neither text nor entities are due', async () => {
    // Native reads no text it was not asked for.
    mod.analyzeImage.mockResolvedValueOnce(analysis());
    const result = await analyzeImage(photo, ['mlKitLabels']);
    expect(mod.recognizeText).not.toHaveBeenCalled();
    expect(mod.extractEntities).not.toHaveBeenCalled();
    expect(result.entities).toEqual([]);
  });
});

describe('expo-ml-kit', () => {
  it('forwards faces and barcodes to the native module', async () => {
    await expect(detectFaces(photo)).resolves.toEqual([{ confidence: 1 }]);
    await expect(detectBarcodes(photo)).resolves.toEqual([
      { format: 'QR_CODE' },
    ]);
  });

  it('is available only where the module says its models are', () => {
    expect(isMlKitAvailable()).toBe(true);
    expect(isMlKitAvailable('faces')).toBe(true);
    unlink('faces');
    expect(isMlKitAvailable('faces')).toBe(false);
    mod.isAvailable = false;
    expect(isMlKitAvailable()).toBe(false);
    expect(isMlKitAvailable('text')).toBe(false);
    native.module = null;
    expect(isMlKitAvailable()).toBe(false);
  });

  it('rejects on a call, not on import, where the module is not linked', async () => {
    native.module = null;
    await expect(analyzeImage(photo, ['mlKitText'])).rejects.toMatchObject({
      code: 'ERR_ML_KIT_UNAVAILABLE',
    });
    await expect(detectFaces(photo)).rejects.toThrow(/not available/);
    await expect(detectBarcodes(photo)).rejects.toBeInstanceOf(MlKitError);
  });

  it('rejects a call into a feature the build left out, saying how to add it', async () => {
    unlink('barcodes');
    await expect(detectBarcodes(photo)).rejects.toMatchObject({
      code: 'ERR_ML_KIT_FEATURE',
      message: expect.stringMatching(/'barcodes'.*`features`/),
    });
    await expect(
      analyzeImage(photo, ['mlKitText', 'mlKitBarcodes'])
    ).rejects.toMatchObject({ code: 'ERR_ML_KIT_FEATURE' });
    expect(mod.analyzeImage).not.toHaveBeenCalled();
  });

  it('runs no native pass for models it does not know', async () => {
    const result = await analyzeImage(photo, ['someOtherModel']);
    expect(mod.analyzeImage).not.toHaveBeenCalled();
    expect(result).toMatchObject({ labels: [], entities: [], objects: [] });
  });

  it('fills in the parts native leaves out', async () => {
    mod.analyzeImage.mockResolvedValueOnce({ imageWidth: 4, imageHeight: 3 });
    const result = await analyzeImage(photo, ['mlKitLabels']);
    expect(result).toEqual({
      imageWidth: 4,
      imageHeight: 3,
      text: { text: '', blocks: [] },
      labels: [],
      barcodes: [],
      poses: [],
      objects: [],
      entities: [],
    });
  });
});
