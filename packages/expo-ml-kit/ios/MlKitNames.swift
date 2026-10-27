#if !targetEnvironment(simulator)
import MLKitBarcodeScanning
import MLKitEntityExtraction
import MLKitPoseDetectionCommon

/// ML Kit's constants as the wire names `ExpoMlKit.types.ts` declares — the
/// same strings Android's analyzers write (`mlKitArtifacts` test pins the
/// tables together), because one model version covers both platforms.
enum MlKitNames {
  /// `ML_KIT_BARCODE_FORMATS`; any other format is dropped.
  static let barcodeFormats: [(BarcodeFormat, String)] = [
    (.aztec, "AZTEC"),
    (.codaBar, "CODABAR"),
    (.code39, "CODE_39"),
    (.code93, "CODE_93"),
    (.code128, "CODE_128"),
    (.dataMatrix, "DATA_MATRIX"),
    (.EAN8, "EAN_8"),
    (.EAN13, "EAN_13"),
    (.ITF, "ITF"),
    (.PDF417, "PDF417"),
    (.qrCode, "QR_CODE"),
    (.UPCA, "UPC_A"),
    (.UPCE, "UPC_E"),
  ]

  static func barcodeFormat(_ format: BarcodeFormat) -> String? {
    barcodeFormats.first { $0.0 == format }?.1
  }

  /// Android's `PoseLandmark` names, camel-cased (iOS calls some differently:
  /// `mouthLeft`, `leftPinkyFinger`, `leftToe`).
  static let poseLandmarks: [PoseLandmarkType: String] = [
    .nose: "nose",
    .leftEyeInner: "leftEyeInner",
    .leftEye: "leftEye",
    .leftEyeOuter: "leftEyeOuter",
    .rightEyeInner: "rightEyeInner",
    .rightEye: "rightEye",
    .rightEyeOuter: "rightEyeOuter",
    .leftEar: "leftEar",
    .rightEar: "rightEar",
    .mouthLeft: "leftMouth",
    .mouthRight: "rightMouth",
    .leftShoulder: "leftShoulder",
    .rightShoulder: "rightShoulder",
    .leftElbow: "leftElbow",
    .rightElbow: "rightElbow",
    .leftWrist: "leftWrist",
    .rightWrist: "rightWrist",
    .leftPinkyFinger: "leftPinky",
    .rightPinkyFinger: "rightPinky",
    .leftIndexFinger: "leftIndex",
    .rightIndexFinger: "rightIndex",
    .leftThumb: "leftThumb",
    .rightThumb: "rightThumb",
    .leftHip: "leftHip",
    .rightHip: "rightHip",
    .leftKnee: "leftKnee",
    .rightKnee: "rightKnee",
    .leftAnkle: "leftAnkle",
    .rightAnkle: "rightAnkle",
    .leftHeel: "leftHeel",
    .rightHeel: "rightHeel",
    .leftToe: "leftFootIndex",
    .rightToe: "rightFootIndex",
  ]

  /// The entity types kept. Payment cards and IBANs are left out, as on
  /// Android: the numbers are in the OCR text already, and a labelled,
  /// searchable copy would only make them easier to harvest.
  static let entityTypes: [EntityType: String] = [
    .address: "address",
    .dateTime: "dateTime",
    .email: "email",
    .flightNumber: "flightNumber",
    .ISBN: "isbn",
    .money: "money",
    .phone: "phone",
    .trackingNumber: "trackingNumber",
    .URL: "url",
  ]
}
#endif
