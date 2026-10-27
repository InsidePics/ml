#if canImport(UIKit)
import UIKit
import XCTest
@testable import ExpoImageMlTools

/// A handle's pixels on iOS: however the UIImage was made (orientation left
/// for UIKit to apply, or already upright), the tools read the same upright
/// pixels as a direct ImageIO decode, so the inputs equal the app's.
final class HandleTests: XCTestCase {

  private let orientations = [1, 3, 6, 8].flatMap { tag in
    ["jpg", "heic"].map { "face-orientation-\(tag).\($0)" }
  }

  func testUIImageWithOrientation_readsAsTheUprightDecode() throws {
    for name in orientations + ["face.jpg", "text.jpg"] {
      let data = try Data(contentsOf: URL(fileURLWithPath: FixturePaths.path(name)))
      // UIImage(data:) keeps the EXIF orientation as `imageOrientation`, as
      // an image loader that leaves it to UIKit does.
      let loaded = try XCTUnwrap(UIImage(data: data), name)
      let direct = try XCTUnwrap(uprightCGImage(name).flatMap(Pixels.rgba), name)
      let read = try XCTUnwrap(Pixels.rgba(loaded), name)
      XCTAssertEqual(read.width, direct.width, name)
      XCTAssertEqual(read.height, direct.height, name)
      XCTAssertEqual(sha256(Data(read.pixels)), sha256(Data(direct.pixels)), "\(name) pixels")
    }
  }

  func testWarpOutput_readsBackAsItsOwnBytes() throws {
    let crop = ImageMath.warp(patternImage(), [1, 0, -3, 0, 1, -2], width: 16, height: 12)
    let handle = try XCTUnwrap(PixelBacked.make(crop))
    XCTAssertEqual(handle.size, CGSize(width: 16, height: 12))
    XCTAssertEqual(try XCTUnwrap(Pixels.rgba(handle)).pixels, crop.pixels)
    // Drawn rather than read back, the bytes are the same too.
    XCTAssertEqual(try XCTUnwrap(handle.cgImage.flatMap(Pixels.rgba)).pixels, crop.pixels)
  }

  func testInputsFromAHandle_areTheInputsFromTheDecode() throws {
    let expected = try Expected.load()
    for name in ["face.jpg", "face-orientation-6.heic", "animal.jpg"] {
      let data = try Data(contentsOf: URL(fileURLWithPath: FixturePaths.path(name)))
      let read = try XCTUnwrap(UIImage(data: data).flatMap(Pixels.rgba), name)
      let direct = try XCTUnwrap(uprightCGImage(name).flatMap(Pixels.rgba), name)
      let clip = { (rgba: RGBAImage) in
        ImageMath.tensor(
          rgba, width: 256, height: 256, fit: .cover, filter: .nearest,
          mean: expected.clipMean, std: expected.clipStd, layout: .nchw)
      }
      XCTAssertEqual(sha256(clip(read)), sha256(clip(direct)), name)
    }
  }
}
#endif
