#if canImport(MLKitBarcodeScanning) && !targetEnvironment(simulator)
import CoreGraphics
import Foundation
import MLKitBarcodeScanning
import MLKitVision

/// Barcode Scanning, bundled model, every format: `analyzeImage`'s part and
/// `detectBarcodes`, as Android's `BarcodeAnalyzer.kt`.
enum BarcodeAnalyzer {
  private static let everyFormat = BarcodeScanner.barcodeScanner()

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

  /// The codes in `image`, every format or only `formats` (names from
  /// `ML_KIT_BARCODE_FORMATS`; fewer formats scan faster).
  static func scan(_ image: VisionImage, _ size: CGSize, formats: [String]? = nil) throws
    -> [[String: Any]]
  {
    try scanner(formats).results(in: image).compactMap { code -> [String: Any]? in
      guard let format = barcodeFormat(code.format) else { return nil }
      var out = BarcodeValues.fields(code, format: format)
      out["boundingBox"] = MlKitAnalyzer.rect(code.frame, size)
      out["cornerPoints"] = (code.cornerPoints ?? []).map {
        MlKitAnalyzer.point($0.cgPointValue, size)
      }
      return out
    }
  }

  private static let lock = NSLock()
  private static var scanners: [[String]: BarcodeScanner] = [:]

  private static func scanner(_ formats: [String]?) throws -> BarcodeScanner {
    guard let formats, !formats.isEmpty else { return everyFormat }
    let key = formats.sorted()
    var wanted: BarcodeFormat = []
    for name in key {
      guard let format = barcodeFormats.first(where: { $0.1 == name })?.0 else {
        throw NSError(domain: "ExpoMlKit", code: 1, userInfo: [
          NSLocalizedDescriptionKey: "Unknown barcode format \(name)",
        ])
      }
      wanted.insert(format)
    }
    lock.lock()
    defer { lock.unlock() }
    if let found = scanners[key] { return found }
    let made = BarcodeScanner.barcodeScanner(options: BarcodeScannerOptions(formats: wanted))
    scanners[key] = made
    return made
  }
}
#endif
