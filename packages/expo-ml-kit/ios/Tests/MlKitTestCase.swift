import UIKit
import XCTest
@testable import ExpoMlKit

#if !targetEnvironment(simulator)

/// Shared by the ML Kit suites. Google ships no simulator build of ML Kit and
/// the module compiles it out there, so the suites exist on a device only:
/// `pnpm test:device:ios` runs them on an iPhone.
class MlKitTestCase: XCTestCase {

  /// The fixture as the module sees a caller's handle: UIImage(data:)
  /// (the EXIF orientation left for UIKit), prepared by `AnalysisImage`.
  func image(_ name: String, file: StaticString = #filePath, line: UInt = #line) throws
    -> UIImage
  {
    try XCTUnwrap(
      loadedImage(name).flatMap(AnalysisImage.prepare), "Could not prepare \(name)",
      file: file, line: line)
  }

  /// `work` on a background queue, as the module runs it: ML Kit refuses
  /// the main thread, where XCTest runs. The main run loop keeps turning
  /// meanwhile, so a callback ML Kit delivers on main (a model download)
  /// still lands.
  func background<T>(timeout: TimeInterval = 300, _ work: @escaping () throws -> T) throws -> T {
    var result: Result<T, Error>?
    let done = expectation(description: "background work")
    DispatchQueue.global(qos: .userInitiated).async {
      result = Result { try work() }
      done.fulfill()
    }
    wait(for: [done], timeout: timeout)
    return try XCTUnwrap(result, "timed out").get()
  }

  /// The fixture as the module's `analyzeImage` returns it, for `models`.
  func analyze(_ name: String, _ models: Set<String>) throws -> [String: Any] {
    let picture = try image(name)
    return try background { try MlKitAnalyzer.analyze(picture, models: models) }
  }

  /// ML Kit's faces in the fixture, as the module's `detectFaces` returns them.
  func detectFaces(_ name: String) throws -> [[String: Any]] {
    let picture = try image(name)
    return try background { try FaceAnalyzer.detect(picture) }
  }

  /// `scripts`' reads of `picture`, as the module's `recognizeText` returns them.
  func recognize(_ picture: UIImage, _ scripts: [String]) throws -> [[String: Any]] {
    try background { try TextAnalyzer.recognize(picture, scripts: scripts) }
  }

  /// A normalized rect (`x`, `y`, `width`, `height`) inside the unit square.
  func assertUnitRect(
    _ value: Any?, _ message: String, file: StaticString = #filePath, line: UInt = #line
  ) {
    guard let rect = value as? [String: Double],
      let x = rect["x"], let y = rect["y"], let w = rect["width"], let h = rect["height"]
    else {
      return XCTFail("\(message): not a rect: \(String(describing: value))", file: file, line: line)
    }
    let slack = 0.01
    XCTAssertGreaterThan(w, 0, message, file: file, line: line)
    XCTAssertGreaterThan(h, 0, message, file: file, line: line)
    XCTAssertGreaterThanOrEqual(x, -slack, message, file: file, line: line)
    XCTAssertGreaterThanOrEqual(y, -slack, message, file: file, line: line)
    XCTAssertLessThanOrEqual(x + w, 1 + slack, message, file: file, line: line)
    XCTAssertLessThanOrEqual(y + h, 1 + slack, message, file: file, line: line)
  }
}
#endif

/// The fixture as UIImage(data:) loads it, orientation kept as
/// `imageOrientation`.
func loadedImage(_ name: String) throws -> UIImage? {
  UIImage(data: try Data(contentsOf: URL(fileURLWithPath: FixturePaths.path(name))))
}

/// `image` as an iPhone camera photo decodes: 8-bit Display P3 pixels of
/// `size`, stored turned a quarter and tagged `.right` to be shown upright
/// (or, `turned` false, stored upright).
func wideColourPhoto(_ image: UIImage, size: CGSize, turned: Bool = true) -> UIImage? {
  let stored = turned ? CGSize(width: size.height, height: size.width) : size
  guard let space = CGColorSpace(name: CGColorSpace.displayP3),
    let source = image.cgImage,
    let ctx = CGContext(
      data: nil, width: Int(stored.width), height: Int(stored.height), bitsPerComponent: 8,
      bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
  else { return nil }
  if turned {
    // Turned a quarter anticlockwise; `.right` turns it back.
    ctx.translateBy(x: stored.width, y: 0)
    ctx.rotate(by: .pi / 2)
  }
  ctx.draw(source, in: CGRect(origin: .zero, size: size))
  return ctx.makeImage().map {
    UIImage(cgImage: $0, scale: 1, orientation: turned ? .right : .up)
  }
}
