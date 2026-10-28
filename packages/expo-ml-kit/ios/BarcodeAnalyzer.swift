#if canImport(MLKitBarcodeScanning) && !targetEnvironment(simulator)
import CoreGraphics
import Foundation
import MLKitBarcodeScanning
import MLKitVision

/// Barcode Scanning, bundled model, every format: `analyzeImage`'s part and
/// `detectBarcodes`, as Android's `BarcodeAnalyzer.kt`.
enum BarcodeAnalyzer {
  private static let scanner = BarcodeScanner.barcodeScanner()

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

  static func scan(_ image: VisionImage, _ size: CGSize) throws -> [[String: Any]] {
    try scanner.results(in: image).compactMap { code in
      guard let format = barcodeFormat(code.format) else { return nil }
      return [
        "rawValue": code.rawValue as Any? ?? NSNull(),
        "format": format,
        "boundingBox": MlKitAnalyzer.rect(code.frame, size),
      ]
    }
  }
}
#endif
