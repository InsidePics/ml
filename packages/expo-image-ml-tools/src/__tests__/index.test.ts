import { beforeEach, describe, expect, it, vi } from 'vitest';

import {
  histogram,
  imageSize,
  sharpness,
  toTensor,
  warp,
  type ImageRef,
} from '../index';

const native = vi.hoisted(() => ({ module: null as unknown }));
vi.mock('../ExpoImageMlToolsModule', () => ({
  get default() {
    return native.module;
  },
}));

const image = { width: 4, height: 3 } as unknown as ImageRef;
const floatBytes = (values: number[]) =>
  new Uint8Array(new Float32Array(values).buffer);

const nativeModule = () => ({
  size: vi.fn().mockReturnValue({ width: 4, height: 3 }),
  toTensor: vi
    .fn()
    .mockResolvedValue(floatBytes(new Array(3 * 2 * 2).fill(0.5))),
  warp: vi.fn().mockResolvedValue({ width: 2, height: 2 }),
  sharpness: vi.fn().mockResolvedValue(12.5),
  histogram: vi.fn().mockResolvedValue(floatBytes([0.25, 0.75])),
});
let mod: ReturnType<typeof nativeModule>;
beforeEach(() => {
  mod = nativeModule();
  native.module = mod;
});

describe('toTensor', () => {
  it('fills every default the native side reads', async () => {
    const tensor = await toTensor(image, { width: 2, height: 2 });
    expect(mod.toTensor).toHaveBeenCalledWith(image, {
      width: 2,
      height: 2,
      fit: 'cover',
      filter: 'bilinear',
      mean: [0, 0, 0],
      std: [1, 1, 1],
      layout: 'nchw',
    });
    expect(tensor).toBeInstanceOf(Float32Array);
    expect(Array.from(tensor)).toEqual(new Array(12).fill(0.5));
  });

  it('passes the caller’s options through', async () => {
    await toTensor(image, {
      width: 2,
      height: 2,
      fit: 'stretch',
      filter: 'nearest',
      mean: [0.5, 0.5, 0.5],
      std: [0.5, 0.5, 0.5],
      layout: 'nhwc',
    });
    expect(mod.toTensor.mock.calls[0]![1]).toMatchObject({
      fit: 'stretch',
      filter: 'nearest',
      layout: 'nhwc',
      std: [0.5, 0.5, 0.5],
    });
  });

  it('refuses a size that is not a positive whole number', async () => {
    await expect(toTensor(image, { width: 0, height: 2 })).rejects.toThrow();
    await expect(toTensor(image, { width: 2.5, height: 2 })).rejects.toThrow();
    expect(mod.toTensor).not.toHaveBeenCalled();
  });

  it('refuses a native answer of the wrong length rather than padding it', async () => {
    mod.toTensor.mockResolvedValue(floatBytes([1, 2, 3]));
    await expect(toTensor(image, { width: 2, height: 2 })).rejects.toThrow(
      /12 Float32/
    );
  });
});

describe('the other tools', () => {
  it('forward to the native module', async () => {
    expect(imageSize(image)).toEqual({ width: 4, height: 3 });
    expect(await sharpness(image)).toBe(12.5);
    expect(Array.from(await histogram(image, 2))).toEqual([0.25, 0.75]);
    const matrix = [1, 0, 0, 0, 1, 0] as const;
    expect(await warp(image, matrix, 2, 2)).toEqual({ width: 2, height: 2 });
    expect(mod.warp).toHaveBeenCalledWith(image, matrix, 2, 2);
  });

  it('refuses a histogram without a whole number of bins', async () => {
    await expect(histogram(image, 0)).rejects.toThrow();
    await expect(histogram(image, 1.5)).rejects.toThrow();
  });

  it('say so plainly where the module is not linked', async () => {
    native.module = null;
    expect(() => imageSize(image)).toThrow(/not available/);
  });
});
