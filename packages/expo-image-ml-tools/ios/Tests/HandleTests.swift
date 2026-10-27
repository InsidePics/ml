#if canImport(UIKit)
import ImageIO
import UIKit
import XCTest
@testable import ExpoImageMlTools

/// A handle's pixels on iOS: however the UIImage was made (orientation left
/// for UIKit to apply, or already upright), the tools read it upright, pixel
/// for pixel. Against the InsidePics app's old decode (ImageIO decoding and
/// rotating in one step) the pixels are identical except for rotated HEIC,
/// which ImageIO decodes slightly differently on that path.
final class HandleTests: XCTestCase {

  private let orientations = [1, 3, 6, 8].flatMap { tag in
    ["jpg", "heic"].map { "face-orientation-\(tag).\($0)" }
  }

  func testUIImageWithOrientation_readsUprightPixelForPixel() throws {
    for name in orientations + ["face.jpg", "text.jpg"] {
      let read = try XCTUnwrap(loaded(name).flatMap(Pixels.rgba), name)
      let rotated = try XCTUnwrap(rotatedDecode(name), name)
      XCTAssertEqual(read.width, rotated.width, name)
      XCTAssertEqual(read.height, rotated.height, name)
      XCTAssertEqual(sha256(Data(read.pixels)), sha256(Data(rotated.pixels)), "\(name) pixels")
    }
  }

  func testAgainstTheOldDecode_onlyRotatedHEICDiffers_andBarely() throws {
    for name in orientations + ["face.jpg", "text.jpg"] {
      let read = try XCTUnwrap(loaded(name).flatMap(Pixels.rgba), name)
      let old = try XCTUnwrap(uprightCGImage(name).flatMap(Pixels.rgba), name)
      let rotatedHEIC = name.hasSuffix(".heic") && !name.contains("-1.")
      let mean = meanDifference(read.pixels, old.pixels)
      if rotatedHEIC {
        XCTAssertLessThan(mean, 1, "\(name): mean difference \(mean) of 255")
      } else {
        XCTAssertEqual(mean, 0, name)
      }
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
    for name in ["face.jpg", "face-orientation-6.jpg", "animal.jpg"] {
      let read = try XCTUnwrap(loaded(name).flatMap(Pixels.rgba), name)
      let direct = try XCTUnwrap(uprightCGImage(name).flatMap(Pixels.rgba), name)
      let clip = { (rgba: RGBAImage) in
        ImageMath.tensor(
          rgba, width: 256, height: 256, fit: .cover, filter: .nearest,
          mean: expected.clipMean, std: expected.clipStd, layout: .nchw)
      }
      XCTAssertEqual(sha256(clip(read)), sha256(clip(direct)), name)
    }
  }

  // MARK: - Helpers

  /// The fixture as UIImage(data:) loads it: EXIF orientation kept as
  /// `imageOrientation`, as a loader that leaves it to UIKit does.
  private func loaded(_ name: String) throws -> UIImage? {
    UIImage(data: try Data(contentsOf: URL(fileURLWithPath: FixturePaths.path(name))))
  }

  /// A plain ImageIO decode turned upright by an exact quarter-turn draw.
  private func rotatedDecode(_ name: String) -> RGBAImage? {
    let url = URL(fileURLWithPath: FixturePaths.path(name))
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return nil }
    let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    let tag = props?[kCGImagePropertyOrientation] as? Int ?? 1
    let sideways = tag == 6 || tag == 8
    let w = sideways ? image.height : image.width
    let h = sideways ? image.width : image.height
    return Pixels.draw(width: w, height: h) { ctx in
      switch tag {
      case 3: ctx.translateBy(x: CGFloat(w), y: CGFloat(h)); ctx.rotate(by: .pi)
      case 6: ctx.translateBy(x: 0, y: CGFloat(h)); ctx.rotate(by: -.pi / 2)
      case 8: ctx.translateBy(x: CGFloat(w), y: 0); ctx.rotate(by: .pi / 2)
      default: break
      }
      ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
  }

  private func meanDifference(_ a: [UInt8], _ b: [UInt8]) -> Double {
    guard a.count == b.count, !a.isEmpty else { return .infinity }
    return zip(a, b).reduce(0.0) { $0 + abs(Double($1.0) - Double($1.1)) } / Double(a.count)
  }
}
#endif
