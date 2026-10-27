import XCTest
import Vision
@testable import ExpoAppleIntelligence

/// Barcodes, classification, feature prints, aesthetics, horizon and the batch pass.
final class ImageAnalysisTests: VisionTestCase {

  // MARK: - Barcode / QR code detection

  func testDetectBarcodes_findsQRCode() throws {
    try XCTSkipIf(isSimulator, "Barcode detection requires Neural Engine")
    let barcodes = try detectBarcodes("qrcode.jpg")

    XCTAssertGreaterThanOrEqual(barcodes.count, 1, "Should detect the QR code on the phone screen")
    if let first = barcodes.first {
      XCTAssertEqual(first["symbology"] as? String, VNBarcodeSymbology.qr.rawValue)
      // Corner points should be present
      XCTAssertNotNil(first["topLeft"] as? [String: Double])
      XCTAssertNotNil(first["topRight"] as? [String: Double])
      XCTAssertNotNil(first["bottomLeft"] as? [String: Double])
      XCTAssertNotNil(first["bottomRight"] as? [String: Double])
    }
  }

  func testDetectBarcodes_readsEAN13Label() throws {
    try XCTSkipIf(isSimulator, "Barcode detection requires Neural Engine")
    let barcodes = try detectBarcodes("barcode.jpg")

    XCTAssertGreaterThanOrEqual(barcodes.count, 1, "Should detect the price label's barcode")
    if let first = barcodes.first {
      XCTAssertEqual(first["symbology"] as? String, VNBarcodeSymbology.ean13.rawValue)
      XCTAssertEqual(first["payloadStringValue"] as? String, "2404105001722")
    }
  }

  private func detectBarcodes(_ fixture: String) throws -> [[String: Any]] {
    guard let (cgImage, _, _) = loadFixture(fixture) else {
      XCTFail("Could not load \(fixture) fixture")
      return []
    }
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let req = VNDetectBarcodesRequest()
    try handler.perform([req])
    return VisionProcessors.processBarcodes(req.results ?? [])
  }

  func testDetectBarcodes_noneInLandscape() throws {
    try XCTSkipIf(isSimulator, "Barcode detection requires Neural Engine")
    guard let (cgImage, _, _) = loadFixture("landscape.jpg") else {
      XCTFail("Could not load landscape.jpg fixture")
      return
    }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let req = VNDetectBarcodesRequest()
    try handler.perform([req])

    let barcodes = VisionProcessors.processBarcodes(
      req.results ?? []
    )

    XCTAssertEqual(barcodes.count, 0, "Should not detect barcodes in landscape")
  }

  // MARK: - Classification

  func testClassifyImage_labelsLandscape() throws {
    try XCTSkipIf(isSimulator, "Classification requires Neural Engine")
    guard let (cgImage, _, _) = loadFixture("landscape.jpg") else {
      XCTFail("Could not load landscape.jpg fixture")
      return
    }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let req = VNClassifyImageRequest()
    try handler.perform([req])

    let labels = VisionProcessors.processClassification(
      req.results ?? []
    )

    XCTAssertGreaterThan(labels.count, 0, "Should produce labels for landscape")

    // All observations returned, unfiltered — find high-confidence nature labels
    let highConfidence = labels.filter { ($0["confidence"] as! Double) >= 0.1 }
    let identifiers = highConfidence.compactMap { $0["identifier"] as? String }
    let hasNatureLabel = identifiers.contains(where: {
      $0.contains("mountain") || $0.contains("landscape") || $0.contains("nature") ||
      $0.contains("outdoor") || $0.contains("sky") || $0.contains("water") ||
      $0.contains("tree") || $0.contains("forest") || $0.contains("river")
    })
    XCTAssertTrue(hasNatureLabel, "Landscape should get nature labels, got: \(identifiers.prefix(10))")
  }

  // MARK: - Feature print

  func testFeaturePrint_differentImagesProduceDifferentVectors() throws {
    try XCTSkipIf(isSimulator, "Feature print requires Neural Engine")

    let facePrint = try XCTUnwrap(
      generateFeaturePrint(fixture: "face.jpg"), "Face image should produce feature print")
    let landscapePrint = try XCTUnwrap(
      generateFeaturePrint(fixture: "landscape.jpg"),
      "Landscape image should produce feature print")

    var distance: Float = 0
    try facePrint.computeDistance(&distance, to: landscapePrint)
    XCTAssertGreaterThan(distance, 1.0, "Face and landscape should be quite different")
  }

  // MARK: - Aesthetics (iOS 18+)

  func testAesthetics_scoresLandscapeHigherThanBarcode() throws {
    try XCTSkipIf(isSimulator, "Aesthetics requires Neural Engine")
    guard #available(iOS 18.0, macOS 15.0, *) else {
      throw XCTSkip("Aesthetics requires iOS 18+")
    }

    let landscapeScore = try XCTUnwrap(
      computeAestheticScore(fixture: "landscape.jpg"), "Landscape should have aesthetic score")
    let barcodeScore = try XCTUnwrap(
      computeAestheticScore(fixture: "barcode.jpg"), "Barcode should have aesthetic score")

    XCTAssertGreaterThan(
      landscapeScore, barcodeScore,
      "Landscape (\(landscapeScore)) should score higher than barcode photo (\(barcodeScore))"
    )
  }

  // MARK: - Horizon

  func testHorizon_detectsAngleInLandscape() throws {
    guard let (cgImage, _, _) = loadFixture("landscape.jpg") else {
      XCTFail("Could not load landscape.jpg fixture")
      return
    }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let req = VNDetectHorizonRequest()
    try handler.perform([req])

    let result = VisionProcessors.processHorizon(req.results?.first as? VNHorizonObservation)
    if let result = result {
      let angle = result["angle"] as! Double
      // Angle in radians — should be within ±π/4
      XCTAssertLessThan(abs(angle), .pi / 4, "Horizon angle should be within ±45°")
    }
  }

  // MARK: - Batch analysis

  func testBatchAnalysis_allRequestsCompleteOnRealImage() throws {
    try XCTSkipIf(isSimulator, "Batch analysis requires Neural Engine")
    guard let (cgImage, _, _) = loadFixture("face.jpg") else {
      XCTFail("Could not load face.jpg fixture")
      return
    }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

    let textReq = VNRecognizeTextRequest()
    textReq.recognitionLevel = .accurate
    let classifyReq = VNClassifyImageRequest()
    let barcodeReq = VNDetectBarcodesRequest()
    let featurePrintReq = VNGenerateImageFeaturePrintRequest()
    let horizonReq = VNDetectHorizonRequest()

    let requests: [VNRequest] = [
      textReq, classifyReq, barcodeReq, featurePrintReq, horizonReq,
    ]

    try handler.perform(requests)

    // Face should be detected, as analyzeImage does it: after the batch
    let faces = try VisionProcessors.detectFaces(handler)
    XCTAssertGreaterThanOrEqual(faces.count, 1, "Batch: should detect face")

    // Classification should return labels
    let labels = VisionProcessors.processClassification(
      classifyReq.results ?? []
    )
    XCTAssertGreaterThan(labels.count, 0, "Batch: should classify image")

    // Feature print should be generated
    let fp = VisionProcessors.processFeaturePrint(
      featurePrintReq.results?.first as? VNFeaturePrintObservation
    )
    XCTAssertNotNil(fp, "Batch: should generate feature print")
  }
}
