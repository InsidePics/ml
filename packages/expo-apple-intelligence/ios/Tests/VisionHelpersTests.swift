import XCTest
@testable import ExpoAppleIntelligence
#if canImport(UIKit)
import CoreImage
import UIKit
#endif

final class VisionHelpersTests: XCTestCase {

  // MARK: - rawRect

  func testRawRect_serializesNormalizedRect() {
    let rect = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
    let result = VisionHelpers.rawRect(rect)

    XCTAssertEqual(result["x"]!, 0.25, accuracy: 0.001)
    XCTAssertEqual(result["y"]!, 0.25, accuracy: 0.001)
    XCTAssertEqual(result["width"]!, 0.5, accuracy: 0.001)
    XCTAssertEqual(result["height"]!, 0.5, accuracy: 0.001)
  }

  func testRawRect_fullImageBox() {
    let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
    let result = VisionHelpers.rawRect(rect)

    XCTAssertEqual(result["x"]!, 0.0, accuracy: 0.001)
    XCTAssertEqual(result["y"]!, 0.0, accuracy: 0.001)
    XCTAssertEqual(result["width"]!, 1.0, accuracy: 0.001)
    XCTAssertEqual(result["height"]!, 1.0, accuracy: 0.001)
  }

  func testRawRect_zeroSizeBox() {
    let rect = CGRect(x: 0.5, y: 0.5, width: 0, height: 0)
    let result = VisionHelpers.rawRect(rect)

    XCTAssertEqual(result["x"]!, 0.5, accuracy: 0.001)
    XCTAssertEqual(result["y"]!, 0.5, accuracy: 0.001)
    XCTAssertEqual(result["width"]!, 0.0, accuracy: 0.001)
    XCTAssertEqual(result["height"]!, 0.0, accuracy: 0.001)
  }

  // MARK: - rawPoint

  func testRawPoint_serializesNormalizedPoint() {
    let point = CGPoint(x: 0.5, y: 0.75)
    let result = VisionHelpers.rawPoint(point)

    XCTAssertEqual(result["x"]!, 0.5, accuracy: 0.001)
    XCTAssertEqual(result["y"]!, 0.75, accuracy: 0.001)
  }

  func testRawPoint_originPoint() {
    let point = CGPoint(x: 0, y: 0)
    let result = VisionHelpers.rawPoint(point)

    XCTAssertEqual(result["x"]!, 0.0, accuracy: 0.001)
    XCTAssertEqual(result["y"]!, 0.0, accuracy: 0.001)
  }

  func testRawPoint_topRightCorner() {
    let point = CGPoint(x: 1, y: 1)
    let result = VisionHelpers.rawPoint(point)

    XCTAssertEqual(result["x"]!, 1.0, accuracy: 0.001)
    XCTAssertEqual(result["y"]!, 1.0, accuracy: 0.001)
  }

  // MARK: - upright (a handle's image)

  #if canImport(UIKit)
  func testUpright_usesAnUprightImageAsItIs() throws {
    let cgImage = try XCTUnwrap(fixtureImage("face.jpg")?.0)
    let image = UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    XCTAssertTrue(try XCTUnwrap(VisionHelpers.upright(image)) === cgImage)
  }

  func testUpright_measuresAScaledImageInPixels() throws {
    let cgImage = try XCTUnwrap(fixtureImage("face.jpg")?.0)
    let image = UIImage(cgImage: cgImage, scale: 3, orientation: .left)
    let upright = try XCTUnwrap(VisionHelpers.upright(image))
    // .left turns the 400x600 pixels on their side; scale changes nothing.
    XCTAssertEqual(upright.width, 600)
    XCTAssertEqual(upright.height, 400)
  }

  func testUpright_refusesAnImageWithNoPixels() {
    let ciOnly = UIImage(ciImage: CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4)))
    XCTAssertNil(VisionHelpers.upright(ciOnly))
  }
  #endif
}
