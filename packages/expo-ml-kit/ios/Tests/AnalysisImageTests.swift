import CoreImage
import UIKit
import XCTest
@testable import ExpoMlKit

/// `AnalysisImage` hands ML Kit the frame a viewer shows, at pixel scale 1,
/// the longer side capped, whatever handle the caller passed. No ML Kit
/// here, so this suite runs on a simulator too.
final class AnalysisImageTests: XCTestCase {

  func testPrepare_appliesEveryOrientation() throws {
    let reference = try prepared("face.jpg")
    for tag in [1, 3, 6, 8] {
      for format in ["jpg", "heic"] {
        let name = "face-orientation-\(tag).\(format)"
        let image = try prepared(name)
        XCTAssertEqual(image.size, CGSize(width: 400, height: 600), name)
        XCTAssertEqual(image.scale, 1, name)
        XCTAssertEqual(image.imageOrientation, .up, name)
        // Recompressed, so close rather than equal; a wrong turn is far off.
        XCTAssertLessThan(meanDifference(image, reference), 12, "\(name) is not upright")
      }
    }
  }

  func testPrepare_passesAnUprightHandleThroughUntouched() throws {
    let cgImage = try XCTUnwrap(try loadedImage("face.jpg")?.cgImage)
    let handle = UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    XCTAssertTrue(try XCTUnwrap(AnalysisImage.prepare(handle)) === handle)
  }

  func testPrepare_measuresAScaledImageInPixels() throws {
    let cgImage = try XCTUnwrap(try loadedImage("face.jpg")?.cgImage)
    let retina = UIImage(cgImage: cgImage, scale: 3, orientation: .up)
    let image = try XCTUnwrap(AnalysisImage.prepare(retina))
    XCTAssertEqual(image.size, CGSize(width: 400, height: 600))
    XCTAssertEqual(image.scale, 1)
  }

  func testPrepare_capsTheLongerSide() throws {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let large = UIGraphicsImageRenderer(size: CGSize(width: 4000, height: 3000), format: format)
      .image { ctx in
        UIColor.gray.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 4000, height: 3000))
      }
    let image = try XCTUnwrap(AnalysisImage.prepare(large))
    XCTAssertEqual(image.size, CGSize(width: 2048, height: 1536))
    XCTAssertEqual(image.scale, 1)
  }

  func testCappedSize_neverRoundsAThinImageToNothing() {
    XCTAssertEqual(
      AnalysisImage.cappedSize(CGSize(width: 10000, height: 1)), CGSize(width: 2048, height: 1))
    XCTAssertEqual(
      AnalysisImage.cappedSize(CGSize(width: 300, height: 200)), CGSize(width: 300, height: 200))
  }

  func testPrepare_refusesAnImageWithNoPixels() {
    let ciOnly = UIImage(ciImage: CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 8, height: 8)))
    XCTAssertNil(AnalysisImage.prepare(ciOnly))
  }

  // MARK: - Helpers

  private func prepared(_ name: String) throws -> UIImage {
    try XCTUnwrap(loadedImage(name).flatMap(AnalysisImage.prepare), name)
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
      guard let cgImage = image.cgImage,
        let ctx = CGContext(
          data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
          bytesPerRow: side, space: CGColorSpaceCreateDeviceGray(),
          bitmapInfo: CGImageAlphaInfo.none.rawValue)
      else { return }
      ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
    }
    return pixels
  }
}
