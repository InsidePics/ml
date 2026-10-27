import ImageIO
import UIKit
import XCTest
@testable import ExpoMlKit

/// `UprightImage` hands ML Kit the frame a viewer shows: EXIF orientation
/// applied, pixel scale 1, the longer side capped. Pure ImageIO, so this
/// suite runs on a simulator too. The `face-orientation-*` fixtures are
/// `face.jpg` stored rotated under each tag (`scripts/make-orientation-fixtures.swift`).
final class ImageDecodeTests: XCTestCase {

  private let tags = [1, 3, 6, 8]
  private let formats = ["jpg", "heic"]

  func testDecode_appliesEveryOrientationTag() throws {
    let reference = try decode("face.jpg")
    for tag in tags {
      for format in formats {
        let name = "face-orientation-\(tag).\(format)"
        let image = try decode(name)
        XCTAssertEqual(image.size, CGSize(width: 400, height: 600), name)
        XCTAssertEqual(image.scale, 1, name)
        XCTAssertEqual(image.imageOrientation, .up, name)
        // Recompressed, so close rather than equal; a wrong rotation is far.
        XCTAssertLessThan(meanDifference(image, reference), 12, "\(name) is not upright")
      }
    }
  }

  func testDecode_capsTheLongerSide() throws {
    let path = try writeSolidImage(width: 4000, height: 3000)
    let image = try XCTUnwrap(UprightImage.decode(path))
    XCTAssertEqual(image.size, CGSize(width: 2048, height: 1536))
    XCTAssertEqual(image.scale, 1)
  }

  func testDecode_acceptsAFileURL() throws {
    let path = FixturePaths.path("face.jpg")
    let image = try XCTUnwrap(UprightImage.decode(URL(fileURLWithPath: path).absoluteString))
    XCTAssertEqual(image.size, CGSize(width: 400, height: 600))
  }

  func testDecode_returnsNilForAMissingFile() {
    XCTAssertNil(UprightImage.decode("/nonexistent/photo.jpg"))
  }

  // MARK: - Helpers

  private func decode(_ name: String) throws -> UIImage {
    try XCTUnwrap(UprightImage.decode(FixturePaths.path(name)), "Could not decode \(name)")
  }

  /// Mean absolute difference of 32×32 greyscale thumbnails, 0–255.
  private func meanDifference(_ a: UIImage, _ b: UIImage) -> Double {
    let pa = grey(a)
    let pb = grey(b)
    return zip(pa, pb).reduce(0) { $0 + abs(Double($1.0) - Double($1.1)) } / Double(pa.count)
  }

  private func grey(_ image: UIImage) -> [UInt8] {
    let side = 32
    var pixels = [UInt8](repeating: 0, count: side * side)
    pixels.withUnsafeMutableBytes { buffer in
      let ctx = CGContext(
        data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
        bytesPerRow: side, space: CGColorSpaceCreateDeviceGray(),
        bitmapInfo: CGImageAlphaInfo.none.rawValue)!
      ctx.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: side, height: side))
    }
    return pixels
  }

  private func writeSolidImage(width: Int, height: Int) throws -> String {
    let ctx = try XCTUnwrap(
      CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
    ctx.setFillColor(UIColor.gray.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("large-\(UUID().uuidString).jpg")
    let dest = try XCTUnwrap(
      CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil))
    CGImageDestinationAddImage(dest, try XCTUnwrap(ctx.makeImage()), nil)
    XCTAssertTrue(CGImageDestinationFinalize(dest))
    addTeardownBlock { try? FileManager.default.removeItem(at: url) }
    return url.path
  }
}
