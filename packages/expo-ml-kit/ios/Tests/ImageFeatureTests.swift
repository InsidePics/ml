import MLKitVision
import UIKit
import XCTest
@testable import ExpoMlKit

#if !targetEnvironment(simulator)

/// The image features beyond `analyzeImage`'s defaults: the full text
/// structure, face classification, label and object options, the accurate
/// pose model, custom models and selfie segmentation. Android's
/// `ImageFeatureTests.kt`, test for test.
final class ImageFeatureTests: MlKitTestCase {

  private func on<T>(_ name: String, _ run: @escaping (UIImage) throws -> T) throws -> T {
    let picture = try image(name)
    return try background { try run(picture) }
  }

  private func vision<T>(_ name: String, _ run: @escaping (VisionImageArgs) throws -> T) throws -> T {
    try on(name) { try run((MlKitAnalyzer.visionImage($0), $0.size)) }
  }

  private var model: [String: Any] { ["path": FixturePaths.path("mobilenet-v1-metadata.tflite")] }

  func testText_readsLinesAndElements() throws {
    let text = try on("text.jpg") { try TextAnalyzer.recognize($0, scripts: ["latin"]) }[0]
    let blocks = try XCTUnwrap(text["blocks"] as? [[String: Any]])
    let lines = blocks.flatMap { $0["lines"] as? [[String: Any]] ?? [] }
    XCTAssertFalse(lines.isEmpty)
    let elements = lines.flatMap { $0["elements"] as? [[String: Any]] ?? [] }
    let word = try XCTUnwrap(elements.first { $0["text"] as? String == "WARNING" }, "\(elements)")
    assertUnitRect(word["boundingBox"], "word box")
    XCTAssertEqual((word["cornerPoints"] as? [Any])?.count, 4)
    XCTAssertTrue((word["recognizedLanguages"] as? [String] ?? []).contains("en"), "\(word)")
  }

  func testFaces_scoreTheSmileAndOpenEyesWhenAsked() throws {
    let plain = try XCTUnwrap(detectFaces("face.jpg").first)
    XCTAssertNil(plain["smilingProbability"])
    var options = FaceAnalyzer.Options()
    options.classify = true
    let face = try XCTUnwrap(try on("face.jpg") { try FaceAnalyzer.detect($0, options: options) }.first)
    XCTAssertGreaterThan(try XCTUnwrap(face["smilingProbability"] as? Double), 0.5)
    XCTAssertGreaterThan(try XCTUnwrap(face["leftEyeOpenProbability"] as? Double), 0.5)
    XCTAssertGreaterThan(try XCTUnwrap(face["rightEyeOpenProbability"] as? Double), 0.5)
  }

  func testLabels_honourTheThreshold() throws {
    let all = try vision("animal.jpg") { try LabelAnalyzer.label($0.0, threshold: 0.1) }
    let sure = try vision("animal.jpg") { try LabelAnalyzer.label($0.0, threshold: 0.8) }
    XCTAssertGreaterThan(all.count, sure.count)
    XCTAssertTrue(all.allSatisfy { ($0["confidence"] as? Double ?? 0) >= 0.1 })
  }

  func testObjects_findOneUnlabelledWhenAsked() throws {
    let one = try vision("body.jpg") { try ObjectAnalyzer.detect($0.0, $0.1, multiple: false, classify: false) }
    XCTAssertEqual(one.count, 1)
    XCTAssertEqual((one[0]["labels"] as? [Any])?.count, 0)
  }

  func testAccuratePoseModel_findsTheSamePerson() throws {
    let accurate = try vision("body.jpg") {
      try PoseAnalyzer.detect($0.0, $0.1, with: AccuratePoseAnalyzer.detector)
    }
    let landmarks = try XCTUnwrap(accurate.first?["landmarks"] as? [[String: Any]])
    XCTAssertEqual(landmarks.count, 33)
    let base = try XCTUnwrap(try vision("body.jpg") { try PoseAnalyzer.detect($0.0, $0.1) }.first?["landmarks"] as? [[String: Any]])
    func noseX(_ list: [[String: Any]]) -> Double { list.first { $0["type"] as? String == "nose" }?["x"] as? Double ?? -1 }
    XCTAssertEqual(noseX(base), noseX(landmarks), accuracy: 0.05)
  }

  func testCustomClassifier_labelsTheDog() throws {
    let options: [String: Any] = ["model": model, "confidenceThreshold": 0.1]
    let labels = try vision("animal.jpg") { try CustomModels.label($0.0, options) }
    XCTAssertTrue(labels.contains { ($0["text"] as? String ?? "").localizedCaseInsensitiveContains("shepherd") }, "\(labels)")
  }

  func testCustomClassifier_labelsTheDetectedObjects() throws {
    let options: [String: Any] = ["model": model, "confidenceThreshold": 0.1]
    let objects = try vision("body.jpg") { try CustomModels.detect($0.0, $0.1, options) }
    XCTAssertFalse(objects.isEmpty)
    XCTAssertTrue(objects.contains { !($0["labels"] as? [Any] ?? []).isEmpty }, "\(objects)")
  }

  func testMissingModelFile_isRefused() {
    XCTAssertThrowsError(try CustomModels.path(["model": ["path": "/nowhere/model.tflite"]]))
  }

  func testSelfieSegmentation_masksThePerson() throws {
    let mask = try vision("body.jpg") { try SelfieSegmentationAnalyzer.segment($0.0, rawSize: false) }
    let bytes = try XCTUnwrap(mask["data"] as? Data)
    XCTAssertEqual(bytes.count, (mask["width"] as? Int ?? 0) * (mask["height"] as? Int ?? 0))
    let inside = Double(bytes.filter { $0 >= 128 }.count) / Double(bytes.count)
    XCTAssertTrue((0.05...0.9).contains(inside), "person share \(inside)")
    let empty = try vision("landscape.jpg") { try SelfieSegmentationAnalyzer.segment($0.0, rawSize: false) }
    let emptyBytes = try XCTUnwrap(empty["data"] as? Data)
    XCTAssertLessThan(Double(emptyBytes.filter { $0 >= 128 }.count) / Double(emptyBytes.count), inside)
  }
}

typealias VisionImageArgs = (VisionImage, CGSize)
#endif
