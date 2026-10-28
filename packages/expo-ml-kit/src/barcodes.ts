import type { MlKitBarcode } from './ExpoMlKit.types';
import { nativeFunction, type ImageRef } from './ExpoMlKitModule';

declare module './ExpoMlKitModule' {
  interface ExpoMlKitFunctions {
    detectBarcodes(image: ImageRef): Promise<MlKitBarcode[]>;
  }
}

/** ML Kit Barcode Scanning alone, without `analyzeImage`'s other parts. */
export async function detectBarcodes(image: ImageRef): Promise<MlKitBarcode[]> {
  return nativeFunction('detectBarcodes', 'barcodes')(image);
}
