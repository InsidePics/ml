import UIKit
import Vision
import XCTest
@testable import ExpoAppleIntelligence
@testable import ExpoMlKit

#if !targetEnvironment(simulator)

/// Apple Vision and ML Kit, run as the two modules run them, must put one
/// face in one place: a caller pairs their faces by overlap, so a box or eye
/// in the wrong frame shows one person twice. Checked under every
/// orientation, where a frame mistake hides.
final class CrossDetectorTests: MlKitTestCase {

  private var names: [String] {
    ["face.jpg"] + [1, 3, 6, 8].flatMap { tag in
      ["jpg", "heic"].map { "face-orientation-\(tag).\($0)" }
    }
  }

  func testBothDetectors_boxTheSameFace() throws {
    for name in names {
      let (apple, mlKit) = try faces(name)
      let a = try box(apple)
      let m = try box(mlKit)
      XCTAssertTrue(isSameFace(a, m), "\(name): Apple \(a) vs ML Kit \(m)")
    }
  }

  func testBothDetectors_placeTheEyesTogether() throws {
    for name in names {
      let (apple, mlKit) = try faces(name)
      let a = try eyesInImage(apple)
      let m = try eyesInImage(mlKit)
      for (label, p, q) in [("left", a.left, m.left), ("right", a.right, m.right)] {
        XCTAssertEqual(p.x, q.x, accuracy: 0.03, "\(name) \(label) eye x")
        XCTAssertEqual(p.y, q.y, accuracy: 0.03, "\(name) \(label) eye y")
      }
    }
  }

  // MARK: - Helpers

  /// Each module's single face from one handle, as a caller passes the same
  /// image to both (here UIImage(data:), its orientation left for UIKit).
  private func faces(_ name: String) throws -> ([String: Any], [String: Any]) {
    let handle = try XCTUnwrap(loadedImage(name), name)
    let cgImage = try XCTUnwrap(VisionHelpers.upright(handle), name)
    let apple = try VisionProcessors.detectFaces(VNImageRequestHandler(cgImage: cgImage, options: [:]))
    let mlKit = try detectFaces(name)
    XCTAssertEqual(apple.count, 1, "\(name): Apple faces")
    XCTAssertEqual(mlKit.count, 1, "\(name): ML Kit faces")
    return (try XCTUnwrap(apple.first), try XCTUnwrap(mlKit.first))
  }

  /// One face when IoU ≥ 0.5, or when the smaller box lies ≥ 80 % inside
  /// the larger and is ≥ a quarter of its area (ML Kit's box takes in more
  /// of the head than Apple's).
  private func isSameFace(_ a: CGRect, _ b: CGRect) -> Bool {
    let inter = a.intersection(b)
    let i = inter.isNull ? 0 : inter.width * inter.height
    let areaA = a.width * a.height
    let areaB = b.width * b.height
    let iou = i / (areaA + areaB - i)
    if iou >= 0.5 { return true }
    let smaller = min(areaA, areaB)
    return i / smaller >= 0.8 && smaller / max(areaA, areaB) >= 0.25
  }
}
#endif
