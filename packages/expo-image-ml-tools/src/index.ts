import type { SharedRef } from 'expo-modules-core/types';

import ExpoImageMlTools, {
  type ExpoImageMlToolsNative,
} from './ExpoImageMlToolsModule';
import type { AffineMatrix } from './similarity';

export * from './similarity';

/** Any Expo image handle: from expo-image-manipulator, expo-image, or `warp`. */
export type ImageRef = SharedRef<'image'>;

export type TensorOptions = {
  width: number;
  height: number;
  /** `cover` (default) fills and center-crops; `stretch` scales each axis. */
  fit?: 'cover' | 'stretch';
  /** `bilinear` (default) or `nearest`. */
  filter?: 'nearest' | 'bilinear';
  /** Per channel, RGB: each value becomes `(v / 255 - mean) / std`.
   *  Defaults 0 and 1: values in [0, 1]. */
  mean?: readonly [number, number, number];
  std?: readonly [number, number, number];
  /** `nchw` (default): `[1, 3, h, w]` planar; `nhwc`: `[1, h, w, 3]`. */
  layout?: 'nchw' | 'nhwc';
};

function native(): ExpoImageMlToolsNative {
  if (!ExpoImageMlTools) {
    throw new Error('ExpoImageMlTools is not available on this platform');
  }
  return ExpoImageMlTools;
}

/** `count` Float32 values from the module's little-endian bytes; anything
 *  else throws rather than becoming a tensor of zeros. */
function float32s(bytes: unknown, count: number): Float32Array {
  if (!(bytes instanceof Uint8Array) || bytes.byteLength !== count * 4) {
    throw new Error(`Expected ${count} Float32 values from ExpoImageMlTools`);
  }
  // A copy: an aligned, standalone buffer whatever view Expo hands over.
  return new Float32Array(bytes.slice().buffer);
}

/** The image's size in pixels, upright. */
export function imageSize(image: ImageRef): { width: number; height: number } {
  return native().size(image);
}

/** The image as a model input: resampled to `width`×`height`, normalized,
 *  RGB, as a Float32 tensor of `3 * width * height` values. */
export async function toTensor(
  image: ImageRef,
  options: TensorOptions
): Promise<Float32Array> {
  const { width, height } = options;
  if (!(
    width > 0 &&
    height > 0 &&
    Number.isInteger(width) &&
    Number.isInteger(height)
  )) {
    throw new Error('toTensor needs a positive whole width and height');
  }
  const bytes = await native().toTensor(image, {
    width,
    height,
    fit: options.fit ?? 'cover',
    filter: options.filter ?? 'bilinear',
    mean: options.mean ?? [0, 0, 0],
    std: options.std ?? [1, 1, 1],
    layout: options.layout ?? 'nchw',
  });
  return float32s(bytes, 3 * width * height);
}

/** The image warped through `matrix` (output = matrix · source) into a new
 *  `width`×`height` image, bilinear, transparent black outside the source.
 *  With `similarityTransform`, a face aligned onto a model's template. */
export function warp(
  image: ImageRef,
  matrix: AffineMatrix,
  width: number,
  height: number
): Promise<ImageRef> {
  return native().warp(image, matrix, width, height);
}

/** Variance of the Laplacian of the image's Rec.601 grey: higher is sharper. */
export function sharpness(image: ImageRef): Promise<number> {
  return native().sharpness(image);
}

/** The image's Rec.601 luminance histogram in `bins` bins, summing to 1. */
export async function histogram(
  image: ImageRef,
  bins: number
): Promise<Float32Array> {
  if (!(bins > 0 && Number.isInteger(bins))) {
    throw new Error('histogram needs a positive whole number of bins');
  }
  return float32s(await native().histogram(image, bins), bins);
}
