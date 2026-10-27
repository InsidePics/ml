import UIKit
import XCTest
@testable import ExpoMlKit

#if !targetEnvironment(simulator)

/// ML Kit's faces in Apple Vision's `FaceObservation` frame: box normalized
/// with a bottom-left origin, landmarks normalized to the box, `leftEye` the
/// image-left eye, `outerLips[0]`/`[6]` the image-left/-right mouth corners.
final class FaceTests: MlKitTestCase {

  func testDetect_findsTheFaceWithItsLandmarks() throws {
    let faces = try detectFaces("face.jpg")
    XCTAssertEqual(faces.count, 1, "face.jpg holds one face")
    let face = try XCTUnwrap(faces.first)
    assertUnitRect(face["boundingBox"], "face box")

    let landmarks = try XCTUnwrap(face["landmarks"] as? [String: [[String: Double]]])
    for region in ["leftEye", "rightEye", "nose", "outerLips"] {
      let points = try XCTUnwrap(landmarks[region], "missing \(region)")
      XCTAssertFalse(points.isEmpty, region)
      for point in points {
        XCTAssertTrue((-0.1...1.1).contains(point["x"] ?? -1), "\(region) x in the box")
        XCTAssertTrue((-0.1...1.1).contains(point["y"] ?? -1), "\(region) y in the box")
      }
    }
    let lips = try XCTUnwrap(landmarks["outerLips"])
    XCTAssertGreaterThanOrEqual(lips.count, 7, "corners at 0 and 6")
  }

  func testDetect_putsTheImageLeftEyeLeftAndTheEyesAboveTheMouth() throws {
    let face = try XCTUnwrap(detectFaces("face.jpg").first)
    let landmarks = try XCTUnwrap(face["landmarks"] as? [String: [[String: Double]]])
    let left = try XCTUnwrap(landmarks["leftEye"]?.first)
    let right = try XCTUnwrap(landmarks["rightEye"]?.first)
    let lips = try XCTUnwrap(landmarks["outerLips"])
    XCTAssertLessThan(left["x"]!, right["x"]!, "leftEye is the image-left eye")
    XCTAssertLessThan(lips[0]["x"]!, lips[6]["x"]!, "outerLips[0] is the image-left corner")
    // Bottom-left origin: up is a larger y.
    XCTAssertGreaterThan(left["y"]!, lips[0]["y"]!, "eyes above the mouth")
  }

  func testDetect_placesTheEyesWhereTheyAreInThePhoto() throws {
    // face.jpg (400×600): the eyes sit near (141, 209) and (231, 213) px,
    // top-left origin.
    let face = try XCTUnwrap(detectFaces("face.jpg").first)
    let eyes = try eyesInImage(face)
    XCTAssertEqual(eyes.left.x, 141 / 400, accuracy: 0.03)
    XCTAssertEqual(eyes.left.y, 209 / 600, accuracy: 0.03)
    XCTAssertEqual(eyes.right.x, 231 / 400, accuracy: 0.03)
    XCTAssertEqual(eyes.right.y, 213 / 600, accuracy: 0.03)
  }

  func testDetect_findsTheSameFaceUnderEveryOrientation() throws {
    let reference = try box(detectFaces("face.jpg").first)
    for tag in [1, 3, 6, 8] {
      for format in ["jpg", "heic"] {
        let name = "face-orientation-\(tag).\(format)"
        let faces = try detectFaces(name)
        XCTAssertEqual(faces.count, 1, name)
        let found = try box(faces.first)
        XCTAssertEqual(found.minX, reference.minX, accuracy: 0.02, name)
        XCTAssertEqual(found.minY, reference.minY, accuracy: 0.02, name)
        XCTAssertEqual(found.width, reference.width, accuracy: 0.02, name)
        XCTAssertEqual(found.height, reference.height, accuracy: 0.02, name)
      }
    }
  }

  func testDetect_findsNoFaceInALandscape() throws {
    XCTAssertEqual(try detectFaces("landscape.jpg").count, 0)
  }

  func testDetect_reportsHeadAnglesInRadians() throws {
    let face = try XCTUnwrap(detectFaces("face.jpg").first)
    for angle in ["roll", "yaw", "pitch"] {
      let value = try XCTUnwrap(face[angle] as? Double, "missing \(angle)")
      XCTAssertLessThan(abs(value), .pi / 2, "\(angle) in radians, near upright")
    }
  }
}

/// A face's box as a CGRect (Vision's frame).
func box(_ face: [String: Any]?) throws -> CGRect {
  let rect = try XCTUnwrap(face?["boundingBox"] as? [String: Double], "no box")
  return CGRect(x: rect["x"]!, y: rect["y"]!, width: rect["width"]!, height: rect["height"]!)
}

/// The eyes in image coordinates, normalized, TOP-left origin.
func eyesInImage(_ face: [String: Any]) throws -> (left: CGPoint, right: CGPoint) {
  let frame = try box(face)
  let landmarks = try XCTUnwrap(face["landmarks"] as? [String: [[String: Double]]])
  // A region's points are box-relative with a bottom-left origin; the eye is
  // their centre (one point from ML Kit, a contour from Vision).
  func point(_ region: String) throws -> CGPoint {
    let all = try XCTUnwrap(landmarks[region], "no \(region)")
    XCTAssertFalse(all.isEmpty, region)
    let x = all.reduce(0) { $0 + ($1["x"] ?? 0) } / Double(max(all.count, 1))
    let y = all.reduce(0) { $0 + ($1["y"] ?? 0) } / Double(max(all.count, 1))
    return CGPoint(
      x: frame.minX + x * frame.width, y: 1 - (frame.minY + y * frame.height))
  }
  return (try point("leftEye"), try point("rightEye"))
}
#endif
