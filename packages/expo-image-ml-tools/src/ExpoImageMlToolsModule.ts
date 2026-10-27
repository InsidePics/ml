import { requireOptionalNativeModule } from 'expo';
import type { SharedRef } from 'expo-modules-core/types';

/** The native options record; `index.ts` fills every default. */
export type NativeTensorOptions = {
  width: number;
  height: number;
  fit: 'cover' | 'stretch';
  filter: 'nearest' | 'bilinear';
  mean: readonly number[];
  std: readonly number[];
  layout: 'nchw' | 'nhwc';
};

/** The native module's raw surface; `index.ts` is the typed API. */
export interface ExpoImageMlToolsNative {
  size(image: SharedRef<'image'>): { width: number; height: number };
  toTensor(
    image: SharedRef<'image'>,
    options: NativeTensorOptions
  ): Promise<Uint8Array>;
  warp(
    image: SharedRef<'image'>,
    matrix: readonly number[],
    width: number,
    height: number
  ): Promise<SharedRef<'image'>>;
  sharpness(image: SharedRef<'image'>): Promise<number>;
  histogram(image: SharedRef<'image'>, bins: number): Promise<Uint8Array>;
}

/** Null where the module is not linked (web), so importing never throws. */
export default requireOptionalNativeModule<ExpoImageMlToolsNative>(
  'ExpoImageMlTools'
);
