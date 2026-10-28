import UIKit
import XCTest
@testable import ExpoMlKit

#if !targetEnvironment(simulator)

/// Barcodes, labels, objects and pose through `analyzeImage`, and the one
/// decode it shares between them.
final class SceneTests: MlKitTestCase {

  private let everyModel: Set<String> = [
    "mlKitText", "mlKitLabels", "mlKitBarcodes", "mlKitPoses", "mlKitObjects",
  ]

  // MARK: - Barcodes

  func testBarcodes_readTheQRCode() throws {
    let codes = try barcodes("qrcode.jpg")
    let qr = try XCTUnwrap(codes.first { $0["format"] as? String == "QR_CODE" }, "\(codes)")
    XCTAssertFalse((qr["rawValue"] as? String ?? "").isEmpty, "QR payload")
    assertUnitRect(qr["boundingBox"], "QR box")
  }

  func testBarcodes_readTheEAN13Label() throws {
    let codes = try barcodes("barcode.jpg")
    let ean = try XCTUnwrap(codes.first { $0["format"] as? String == "EAN_13" }, "\(codes)")
    XCTAssertEqual(ean["rawValue"] as? String, "2404105001722")
    assertUnitRect(ean["boundingBox"], "EAN-13 box")
  }

  func testBarcodes_findNoneInALandscape() throws {
    XCTAssertEqual(try barcodes("landscape.jpg").count, 0)
  }

  // MARK: - Labels and objects

  func testLabels_nameTheDog() throws {
    let labels = try XCTUnwrap(analyze("animal.jpg", ["mlKitLabels"])["labels"] as? [[String: Any]])
    let names = labels.compactMap { $0["text"] as? String }
    XCTAssertTrue(names.contains("Dog"), "labels: \(names)")
    for label in labels {
      let confidence = try XCTUnwrap(label["confidence"] as? Double)
      XCTAssertTrue((0...1).contains(confidence))
      XCTAssertNotNil(label["index"] as? Int)
    }
  }

  func testObjects_boxThePeople() throws {
    let objects = try XCTUnwrap(
      analyze("body.jpg", ["mlKitObjects"])["objects"] as? [[String: Any]])
    XCTAssertGreaterThanOrEqual(objects.count, 1)
    for object in objects {
      assertUnitRect(object["boundingBox"], "object box")
      XCTAssertNotNil(object["labels"] as? [[String: Any]])
    }
  }

  /// Known limitation, pinned: ML Kit's object detector boxes nothing in the
  /// lying dog, in any of its modes, though its labels name the dog. If this
  /// fails, Google's model has changed: look, then move the dog to the test
  /// above.
  func testObjects_boxNoDogLyingInGrass() throws {
    let result = try analyze("animal.jpg", ["mlKitObjects", "mlKitLabels"])
    XCTAssertEqual((result["objects"] as? [[String: Any]])?.count, 0)
    let labels = try XCTUnwrap(result["labels"] as? [[String: Any]])
    XCTAssertTrue(labels.contains { $0["text"] as? String == "Dog" }, "\(labels)")
  }

  // MARK: - Pose

  func testPose_findsAllThirtyThreeLandmarks() throws {
    let poses = try XCTUnwrap(analyze("body.jpg", ["mlKitPoses"])["poses"] as? [[String: Any]])
    XCTAssertEqual(poses.count, 1, "single-person pose")
    let landmarks = try XCTUnwrap(poses.first?["landmarks"] as? [[String: Any]])
    XCTAssertEqual(landmarks.count, 33)
    let types = Set(landmarks.compactMap { $0["type"] as? String })
    XCTAssertEqual(types.count, 33, "each landmark named once")
    XCTAssertFalse(types.contains("unknown"))
    XCTAssertTrue(types.isSuperset(of: ["nose", "leftShoulder", "rightAnkle", "leftFootIndex"]))
    for landmark in landmarks {
      let likelihood = try XCTUnwrap(landmark["inFrameLikelihood"] as? Double)
      XCTAssertTrue((0...1).contains(likelihood))
    }
  }

  func testPose_findsNobodyInALandscape() throws {
    let poses = try XCTUnwrap(analyze("landscape.jpg", ["mlKitPoses"])["poses"] as? [Any])
    XCTAssertEqual(poses.count, 0)
  }

  // MARK: - One pass

  func testAnalyze_runsOnlyTheModelsAsked() throws {
    let result = try analyze("animal.jpg", ["mlKitLabels"])
    XCTAssertFalse((result["labels"] as? [Any] ?? []).isEmpty)
    // Left out, not empty: TS fills in the parts not asked for.
    for key in ["text", "barcodes", "poses", "objects"] {
      XCTAssertNil(result[key], "\(key) not run")
    }
  }

  func testAnalyze_reportsTheUprightSizeWithEveryModel() throws {
    let result = try analyze("face-orientation-6.jpg", everyModel)
    XCTAssertEqual(result["imageWidth"] as? Int, 400)
    XCTAssertEqual(result["imageHeight"] as? Int, 600)
    for key in ["text", "labels", "barcodes", "poses", "objects"] {
      XCTAssertNotNil(result[key], "missing \(key)")
    }
  }

  private func barcodes(_ name: String) throws -> [[String: Any]] {
    try XCTUnwrap(analyze(name, ["mlKitBarcodes"])["barcodes"] as? [[String: Any]])
  }
}
#endif
