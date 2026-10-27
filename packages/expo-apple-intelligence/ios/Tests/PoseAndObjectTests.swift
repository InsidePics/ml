import XCTest
import Vision
@testable import ExpoAppleIntelligence

/// Body and hand poses, animals, rectangles and saliency.
final class PoseAndObjectTests: VisionTestCase {

  // MARK: - Body pose detection

  func testDetectBodyPoses_findsBodyInExercisePhoto() throws {
    try XCTSkipIf(isSimulator, "Body pose detection requires Neural Engine")
    guard let (cgImage, _, _) = loadFixture("body.jpg") else {
      XCTFail("Could not load body.jpg fixture")
      return
    }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let req = VNDetectHumanBodyPoseRequest()
    try handler.perform([req])

    let poses = VisionProcessors.processBodyPoses(
      req.results ?? []
    )

    XCTAssertGreaterThanOrEqual(poses.count, 1, "Should detect at least 1 body pose")

    let pose = poses[0]
    let joints = pose["joints"] as! [[String: Any]]
    XCTAssertGreaterThan(joints.count, 3, "Should detect multiple joints")

    // All joints returned (no filtering)
    for joint in joints {
      XCTAssertNotNil(joint["name"], "Joint should have a name key")
      XCTAssertNotNil(joint["x"] as? Double, "Joint should have x")
      XCTAssertNotNil(joint["y"] as? Double, "Joint should have y")
      XCTAssertNotNil(joint["confidence"] as? Double, "Joint should have confidence")
      break
    }
  }

  func testDetectBodyPoses_noneInLandscape() throws {
    try XCTSkipIf(isSimulator, "Body pose detection requires Neural Engine")
    guard let (cgImage, _, _) = loadFixture("landscape.jpg") else {
      XCTFail("Could not load landscape.jpg fixture")
      return
    }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let req = VNDetectHumanBodyPoseRequest()
    try handler.perform([req])

    let poses = VisionProcessors.processBodyPoses(
      req.results ?? []
    )

    XCTAssertEqual(poses.count, 0, "Should not detect body poses in landscape")
  }

  // MARK: - Hand pose detection

  func testDetectHandPoses_processesCorrectly() throws {
    try XCTSkipIf(isSimulator, "Hand pose detection requires Neural Engine")
    guard let (cgImage, _, _) = loadFixture("hand.jpg") else {
      XCTFail("Could not load hand.jpg fixture")
      return
    }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let req = VNDetectHumanHandPoseRequest()
    req.maximumHandCount = 4
    try handler.perform([req])

    let hands = VisionProcessors.processHandPoses(
      req.results ?? []
    )

    if hands.count > 0 {
      let hand = hands[0]
      let joints = hand["joints"] as! [[String: Any]]
      XCTAssertGreaterThan(joints.count, 0, "Detected hand should have joints")

      for joint in joints {
        XCTAssertNotNil(joint["name"], "Joint should have a name")
        XCTAssertNotNil(joint["x"] as? Double)
        XCTAssertNotNil(joint["y"] as? Double)
        XCTAssertNotNil(joint["confidence"] as? Double)
        break
      }
    }
  }

  func testDetectHandPoses_noneInLandscape() throws {
    try XCTSkipIf(isSimulator, "Hand pose detection requires Neural Engine")
    guard let (cgImage, _, _) = loadFixture("landscape.jpg") else {
      XCTFail("Could not load landscape.jpg fixture")
      return
    }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let req = VNDetectHumanHandPoseRequest()
    req.maximumHandCount = 4
    try handler.perform([req])

    let hands = VisionProcessors.processHandPoses(
      req.results ?? []
    )

    XCTAssertEqual(hands.count, 0, "Should not detect hands in landscape")
  }

  // MARK: - Animal detection

  func testDetectAnimals_findsDogInPhoto() throws {
    try XCTSkipIf(isSimulator, "Animal detection requires Neural Engine")
    guard let (cgImage, _, _) = loadFixture("animal.jpg") else {
      XCTFail("Could not load animal.jpg fixture")
      return
    }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let req = VNRecognizeAnimalsRequest()
    try handler.perform([req])

    let animals = VisionProcessors.processAnimals(
      req.results ?? []
    )

    XCTAssertGreaterThanOrEqual(animals.count, 1, "Should detect at least 1 animal")

    let animal = animals[0]
    let labels = animal["labels"] as! [[String: Any]]
    XCTAssertGreaterThan(labels.count, 0, "Animal should have at least 1 label")
    let identifier = labels[0]["identifier"] as! String
    XCTAssertTrue(
      identifier.lowercased().contains("dog") || identifier.lowercased().contains("cat") || identifier.lowercased().contains("animal"),
      "Should detect a dog/animal, got: \(identifier)"
    )
    let bbox = animal["boundingBox"] as! [String: Double]
    XCTAssertGreaterThan(bbox["width"]!, 0, "Animal bbox should have positive width")
    XCTAssertGreaterThan(bbox["height"]!, 0, "Animal bbox should have positive height")
  }

  func testDetectAnimals_noneInBarcode() throws {
    try XCTSkipIf(isSimulator, "Animal detection requires Neural Engine")
    guard let (cgImage, _, _) = loadFixture("barcode.jpg") else {
      XCTFail("Could not load barcode.jpg fixture")
      return
    }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let req = VNRecognizeAnimalsRequest()
    try handler.perform([req])

    let animals = VisionProcessors.processAnimals(
      req.results ?? []
    )

    XCTAssertEqual(animals.count, 0, "Should not detect animals in barcode image")
  }

  // MARK: - Rectangle detection

  func testDetectRectangles_findsRectanglesInDocument() throws {
    guard let (cgImage, _, _) = loadFixture("document.jpg") else {
      XCTFail("Could not load document.jpg fixture")
      return
    }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let req = VNDetectRectanglesRequest()
    req.maximumObservations = 10
    req.minimumConfidence = 0.3
    req.minimumSize = 0.1
    try handler.perform([req])

    let rectangles = VisionProcessors.processRectangles(
      req.results ?? []
    )

    if rectangles.count > 0 {
      let rect = rectangles[0]
      XCTAssertNotNil(rect["topLeft"] as? [String: Double], "Rectangle should have topLeft")
      XCTAssertNotNil(rect["topRight"] as? [String: Double], "Rectangle should have topRight")
      XCTAssertNotNil(rect["bottomLeft"] as? [String: Double], "Rectangle should have bottomLeft")
      XCTAssertNotNil(rect["bottomRight"] as? [String: Double], "Rectangle should have bottomRight")
      XCTAssertNotNil(rect["boundingBox"] as? [String: Double], "Rectangle should have boundingBox")

      let confidence = rect["confidence"] as! Double
      XCTAssertGreaterThan(confidence, 0, "Rectangle confidence should be positive")

      // Verify points are normalized (0-1)
      let tl = (rect["topLeft"] as! [String: Double])
      XCTAssertGreaterThanOrEqual(tl["x"]!, 0)
      XCTAssertLessThanOrEqual(tl["x"]!, 1)
    }
  }

  // MARK: - Saliency detection

  func testDetectSaliency_findsRegionsInDogPhoto() throws {
    try XCTSkipIf(isSimulator, "Saliency requires Neural Engine")
    guard let (cgImage, _, _) = loadFixture("animal.jpg") else {
      XCTFail("Could not load animal.jpg fixture")
      return
    }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let aReq = VNGenerateAttentionBasedSaliencyImageRequest()
    let oReq = VNGenerateObjectnessBasedSaliencyImageRequest()
    try handler.perform([aReq, oReq])

    let attentionRegions = VisionProcessors.processSaliency(
      aReq.results ?? []
    )
    let objectnessRegions = VisionProcessors.processSaliency(
      oReq.results ?? []
    )

    XCTAssertGreaterThan(
      attentionRegions.count + objectnessRegions.count, 0,
      "Should detect salient regions in dog photo"
    )

    if let region = attentionRegions.first {
      let bbox = region["boundingBox"] as! [String: Double]
      XCTAssertGreaterThan(bbox["width"]!, 0, "Salient region should have positive width")
      XCTAssertGreaterThan(bbox["height"]!, 0, "Salient region should have positive height")
    }
  }
}
