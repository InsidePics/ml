import UIKit
import XCTest
@testable import ExpoMlKit

#if !targetEnvironment(simulator)

/// Shared by the ML Kit suites. Google ships no simulator build of ML Kit and
/// the module compiles it out there, so the suites exist on a device only:
/// `pnpm test:device:ios` runs them on an iPhone.
class MlKitTestCase: XCTestCase {

  /// The fixture decoded upright, as the module decodes a caller's photo.
  func image(_ name: String, file: StaticString = #filePath, line: UInt = #line) throws
    -> UIImage
  {
    try XCTUnwrap(
      UprightImage.decode(FixturePaths.path(name)), "Could not decode \(name)",
      file: file, line: line)
  }

  /// The fixture as the module's `analyzeImage` returns it, for `models`.
  func analyze(_ name: String, _ models: Set<String>) throws -> [String: Any] {
    try MlKitAnalyzer.analyze(image(name), models: models)
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
