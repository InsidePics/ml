import XCTest
import Vision
@testable import ExpoAppleIntelligence

/// Faces and text on the fixtures.
final class FaceAndTextTests: VisionTestCase {

  // MARK: - Face detection

  func testDetectFaces_findsFaceInPortrait() throws {
    try XCTSkipIf(isSimulator, "Face detection requires Neural Engine")
    guard let (cgImage, _, _) = loadFixture("face.jpg") else {
      XCTFail("Could not load face.jpg fixture")
      return
    }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let lReq = VNDetectFaceLandmarksRequest()
    let qReq = VNDetectFaceCaptureQualityRequest()
    try handler.perform([lReq, qReq])

    let faces = VisionProcessors.processFaces(
      landmarks: lReq.results ?? [],
      quality: qReq.results ?? []
    )

    XCTAssertGreaterThanOrEqual(faces.count, 1, "Should detect at least 1 face in portrait")

    let face = faces[0]
    let bbox = face["boundingBox"] as! [String: Double]
    XCTAssertGreaterThan(bbox["width"]!, 0, "Face bbox should have positive width")
    XCTAssertGreaterThan(bbox["height"]!, 0, "Face bbox should have positive height")

    // Landmarks should be a dict of region name → point arrays
    let landmarks = face["landmarks"] as! [String: Any]
    XCTAssertNotNil(landmarks["leftEye"], "Should have leftEye region")
    XCTAssertNotNil(landmarks["rightEye"], "Should have rightEye region")
    XCTAssertNotNil(landmarks["nose"], "Should have nose region")

    let confidence = face["confidence"] as! Double
    XCTAssertGreaterThan(confidence, 0.5, "Face confidence should be high for clear portrait")
  }

  func testDetectFaces_noFacesInLandscape() throws {
    try XCTSkipIf(isSimulator, "Face detection requires Neural Engine")
    guard let (cgImage, _, _) = loadFixture("landscape.jpg") else {
      XCTFail("Could not load landscape.jpg fixture")
      return
    }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let lReq = VNDetectFaceLandmarksRequest()
    try handler.perform([lReq])

    let faces = VisionProcessors.processFaces(
      landmarks: lReq.results ?? [],
      quality: []
    )

    XCTAssertEqual(faces.count, 0, "Should not detect faces in landscape photo")
  }

  // MARK: - Text recognition

  func testRecognizeText_findsTextInDocument() throws {
    guard let (cgImage, _, _) = loadFixture("document.jpg") else {
      XCTFail("Could not load document.jpg fixture")
      return
    }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = .accurate
    try handler.perform([req])

    let result = VisionProcessors.processText(
      req.results ?? []
    )

    XCTAssertGreaterThan(result.count, 0, "Should recognize text in document image")

    let obs = result[0]
    let bbox = obs["boundingBox"] as! [String: Double]
    XCTAssertGreaterThan(bbox["width"]!, 0, "Text bbox should have positive width")

    let candidates = obs["candidates"] as! [[String: Any]]
    XCTAssertGreaterThan(candidates.count, 0, "Should have at least 1 candidate")
    XCTAssertNotNil(candidates[0]["string"] as? String)
    XCTAssertNotNil(candidates[0]["confidence"] as? Double)
  }

  func testRecognizeText_noTextInLandscape() throws {
    guard let (cgImage, _, _) = loadFixture("landscape.jpg") else {
      XCTFail("Could not load landscape.jpg fixture")
      return
    }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = .accurate
    try handler.perform([req])

    let result = VisionProcessors.processText(
      req.results ?? []
    )

    // Landscape may have no text at all
    if result.count > 0 {
      let totalText = result.compactMap { ($0["candidates"] as? [[String: Any]])?.first?["string"] as? String }.joined()
      XCTAssertLessThan(totalText.count, 20, "Landscape should have minimal text")
    }
  }

  // MARK: - Face detection detail tests

  func testDetectFaces_returnsQualityAndAngles() throws {
    try XCTSkipIf(isSimulator, "Face detection requires Neural Engine")
    guard let (cgImage, _, _) = loadFixture("face.jpg") else {
      XCTFail("Could not load face.jpg fixture")
      return
    }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let lReq = VNDetectFaceLandmarksRequest()
    let qReq = VNDetectFaceCaptureQualityRequest()
    try handler.perform([lReq, qReq])

    let faces = VisionProcessors.processFaces(
      landmarks: lReq.results ?? [],
      quality: qReq.results ?? []
    )

    XCTAssertGreaterThanOrEqual(faces.count, 1)
    let face = faces[0]

    if let quality = face["quality"] as? Double {
      XCTAssertGreaterThanOrEqual(quality, 0.0, "Quality should be >= 0")
      XCTAssertLessThanOrEqual(quality, 1.0, "Quality should be <= 1")
    }

    // Angles in radians
    if let roll = face["roll"] as? Double {
      XCTAssertLessThan(abs(roll), .pi, "Roll should be within ±π")
    }
    if let yaw = face["yaw"] as? Double {
      XCTAssertLessThan(abs(yaw), .pi, "Yaw should be within ±π")
    }

    // Landmarks should have named regions with point arrays
    let landmarks = face["landmarks"] as! [String: Any]
    if let leftEye = landmarks["leftEye"] as? [[String: Double]] {
      XCTAssertGreaterThan(leftEye.count, 0, "leftEye should have points")
      // Points are normalized to face bounding box (0-1 range)
      for pt in leftEye {
        XCTAssertGreaterThanOrEqual(pt["x"]!, 0)
        XCTAssertLessThanOrEqual(pt["x"]!, 1)
        XCTAssertGreaterThanOrEqual(pt["y"]!, 0)
        XCTAssertLessThanOrEqual(pt["y"]!, 1)
      }
    }
  }

  // MARK: - Text recognition detail tests

  func testRecognizeText_observationStructureIsCorrect() throws {
    guard let (cgImage, _, _) = loadFixture("document.jpg") else {
      XCTFail("Could not load document.jpg fixture")
      return
    }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = .accurate
    try handler.perform([req])

    let result = VisionProcessors.processText(
      req.results ?? []
    )

    XCTAssertGreaterThan(result.count, 0, "Should have text observations")

    let obs = result[0]
    let bbox = obs["boundingBox"] as! [String: Double]
    XCTAssertGreaterThan(bbox["width"]!, 0)
    XCTAssertGreaterThan(bbox["height"]!, 0)
    // Normalized coords should be 0-1
    XCTAssertGreaterThanOrEqual(bbox["x"]!, 0)
    XCTAssertLessThanOrEqual(bbox["x"]!, 1)

    XCTAssertNotNil(obs["confidence"] as? Double)

    let candidates = obs["candidates"] as! [[String: Any]]
    XCTAssertGreaterThan(candidates.count, 0, "Should have at least one candidate")
    XCTAssertNotNil(candidates[0]["string"] as? String)
    XCTAssertNotNil(candidates[0]["confidence"] as? Double)
  }

  // NOTE: DetectLensSmudgeRequest crashes when called from XCTest bundle context
  // on iOS 26. The API works correctly from the app itself.

  // MARK: - Enhanced document recognition (iOS 26+)

  func testRecognizeDocument_extractsTableFromInvoice() throws {
    try XCTSkipIf(isSimulator, "Document recognition requires Neural Engine")
    guard #available(iOS 26.0, macOS 26.0, *) else {
      throw XCTSkip("Document recognition requires iOS 26+")
    }

    guard let (cgImage, _, _) = loadFixture("invoice.jpg") else {
      XCTFail("Could not load invoice.jpg fixture")
      return
    }

    let expectation = XCTestExpectation(description: "Document recognition")
    Task {
      let result = await VisionModern.recognizeDocument(cgImage: cgImage)
      guard let result else {
        XCTFail("Should recognize document in invoice image")
        expectation.fulfill()
        return
      }

      let paragraphs = result["paragraphs"] as! [[String: Any]]
      XCTAssertGreaterThan(paragraphs.count, 0, "Should find paragraphs in invoice")

      let para = paragraphs[0]
      XCTAssertNotNil(para["text"] as? String, "Paragraph should have text")
      XCTAssertNotNil(para["boundingBox"] as? [String: Double], "Paragraph should have boundingBox")
      XCTAssertNotNil(para["detectedData"] as? [[String: Any]], "Paragraph should have detectedData array")

      let tables = result["tables"] as! [[String: Any]]
      if tables.count > 0 {
        let table = tables[0]
        let cells = table["cells"] as! [[String: Any]]
        XCTAssertGreaterThan(cells.count, 0, "Table should have cells")
        let cell = cells[0]
        XCTAssertNotNil(cell["text"] as? String, "Cell should have text")
        XCTAssertNotNil(cell["row"] as? Int, "Cell should have row index")
        XCTAssertNotNil(cell["column"] as? Int, "Cell should have column index")
      }

      _ = result["lists"] as! [[String: Any]]
      _ = result["barcodes"] as! [[String: Any]]

      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 30.0)
  }

  // MARK: - Error handling tests

  func testLoadImage_invalidPath_returnsNil() {
    let result = VisionHelpers.loadImage("/nonexistent/totally/fake/image.jpg")
    XCTAssertNil(result, "Loading nonexistent image should return nil")
  }
}
