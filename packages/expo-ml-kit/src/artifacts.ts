/**
 * The Google ML Kit releases each feature runs, per platform: the Android
 * artifacts (`android/build.gradle`) and the iOS pods (`ios/ExpoMlKit.podspec`).
 * The `mlKitArtifacts` test pins both files to this table, so a release
 * changes here first and on purpose.
 *
 * Bundled models only (the model ships in the app), so a result names the
 * model that produced it: a Play services model could update underneath.
 * Entity extraction is the one exception the SDK allows no way around: its
 * base detector is bundled, its per-language model downloads at first use.
 *
 * A caller that versions stored results bumps its own version when an entry
 * here changes what a feature returns.
 */
export const ML_KIT_ARTIFACTS = {
  text: {
    android: [
      'com.google.mlkit:text-recognition:16.0.1',
      'com.google.mlkit:text-recognition-chinese:16.0.1',
      'com.google.mlkit:text-recognition-devanagari:16.0.1',
      'com.google.mlkit:text-recognition-japanese:16.0.1',
      'com.google.mlkit:text-recognition-korean:16.0.1',
    ],
    ios: [
      'MLKitTextRecognition 7.0.0',
      'MLKitTextRecognitionChinese 6.0.0',
      'MLKitTextRecognitionDevanagari 6.0.0',
      'MLKitTextRecognitionJapanese 6.0.0',
      'MLKitTextRecognitionKorean 6.0.0',
    ],
  },
  labels: {
    android: ['com.google.mlkit:image-labeling:17.0.9'],
    ios: ['MLKitImageLabeling 8.0.0'],
  },
  barcodes: {
    android: ['com.google.mlkit:barcode-scanning:17.3.0'],
    ios: ['MLKitBarcodeScanning 8.0.0'],
  },
  poses: {
    android: ['com.google.mlkit:pose-detection:18.0.0-beta5'],
    ios: ['MLKitPoseDetection 1.0.0-beta16'],
  },
  objects: {
    android: ['com.google.mlkit:object-detection:17.0.2'],
    ios: ['MLKitObjectDetection 8.0.0'],
  },
  entities: {
    android: ['com.google.mlkit:entity-extraction:16.0.0-beta6'],
    ios: ['MLKitEntityExtraction 1.0.0-beta15'],
  },
  faces: {
    android: ['com.google.mlkit:face-detection:16.1.7'],
    ios: ['MLKitFaceDetection 8.0.0'],
  },
} as const satisfies Record<
  string,
  { android: readonly string[]; ios: readonly string[] }
>;

export type MlKitFeature = keyof typeof ML_KIT_ARTIFACTS;

/**
 * The `Barcode.FORMAT_*` names the bundled scanner reports (without the
 * prefix), as a barcode's `format`. A format outside this list is dropped on
 * the device. QR's is `QR_CODE`.
 */
export const ML_KIT_BARCODE_FORMATS: ReadonlySet<string> = new Set([
  'AZTEC',
  'CODABAR',
  'CODE_39',
  'CODE_93',
  'CODE_128',
  'DATA_MATRIX',
  'EAN_8',
  'EAN_13',
  'ITF',
  'PDF417',
  'QR_CODE',
  'UPC_A',
  'UPC_E',
]);
