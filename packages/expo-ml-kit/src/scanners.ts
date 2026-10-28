import { nativeFunction } from './ExpoMlKitModule';
import type { MlKitBarcodeValue } from './barcodes';

export type MlKitCodeScannerOptions = {
  /** Only these `ML_KIT_BARCODE_FORMATS` (every one when left out). */
  formats?: readonly string[];
  /** A button to type the code in when it will not scan. */
  allowManualInput?: boolean;
  /** Zoom in on a code that is far away. */
  autoZoom?: boolean;
};

export type MlKitDocumentFormat = 'jpeg' | 'pdf';

export type MlKitDocumentScannerOptions = {
  /** The most pages one scan takes (no limit when left out). */
  pageLimit?: number;
  /** What the scan returns: page images, a PDF, or both (`['jpeg']`). */
  formats?: readonly MlKitDocumentFormat[];
  /** `base`: crop and rotate; `baseWithFilter`: and filters; `full` (the
   *  default): and ML clean-up (stains, fingers). */
  mode?: 'base' | 'baseWithFilter' | 'full';
  /** Pages may also come from the photo library. */
  galleryImport?: boolean;
};

/** A finished scan: the app's cache holds its files (`file://` or
 *  `content://` URIs) until it moves them. */
export type MlKitDocumentScan = {
  /** Each page's JPEG, with `'jpeg'` among `formats`; else empty. */
  pages: { uri: string }[];
  /** The PDF of every page, with `'pdf'` among `formats`; else null. */
  pdf: { uri: string; pageCount: number } | null;
};

declare module './ExpoMlKitModule' {
  interface ExpoMlKitFunctions {
    scanCode(options: {
      formats: readonly string[];
      allowManualInput: boolean;
      autoZoom: boolean;
    }): Promise<MlKitBarcodeValue | null>;
    scanDocument(
      options: MlKitDocumentScannerOptions
    ): Promise<MlKitDocumentScan | null>;
  }
}

/**
 * Google's code scanner (Android only): a Play services screen that reads
 * one code with the camera, without the app asking for the camera
 * permission. Resolves with its value (no box: there is no image), or null
 * when the user leaves without one.
 */
export async function scanCode(
  options: MlKitCodeScannerOptions = {}
): Promise<MlKitBarcodeValue | null> {
  return nativeFunction(
    'scanCode',
    'codeScanner'
  )({
    formats: options.formats ?? [],
    allowManualInput: options.allowManualInput ?? false,
    autoZoom: options.autoZoom ?? false,
  });
}

/**
 * Google's document scanner (Android only): a Play services screen that
 * finds, crops and cleans up pages with the camera, without the camera
 * permission. Resolves with the scan, or null when the user leaves without
 * one.
 */
export async function scanDocument(
  options: MlKitDocumentScannerOptions = {}
): Promise<MlKitDocumentScan | null> {
  return nativeFunction(
    'scanDocument',
    'documentScanner'
  )({
    pageLimit: options.pageLimit ?? 0,
    formats: options.formats ?? ['jpeg'],
    mode: options.mode ?? 'full',
    galleryImport: options.galleryImport ?? false,
  });
}
