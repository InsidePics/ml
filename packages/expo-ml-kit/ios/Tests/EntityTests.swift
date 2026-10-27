import XCTest
@testable import ExpoMlKit

#if !targetEnvironment(simulator)

/// Entity Extraction downloads its English model at first use. The suite
/// waits for that download, and FAILS if it never lands: an extractor that
/// silently stays "unknown" is the failure this checks for.
final class EntityTests: MlKitTestCase {

  private static let downloadTimeout: TimeInterval = 180

  func testExtract_findsEachKindKept() throws {
    let text = """
      Call +1 650-253-0000 or write to info@example.com.
      Visit https://example.com before March 3, 2027 at 10am.
      1600 Amphitheatre Parkway, Mountain View, CA 94043
      """
    let entities = try extractOnceReady(text)
    let types = Set(entities.compactMap { $0["type"] })
    for kind in ["phone", "email", "url", "dateTime", "address"] {
      XCTAssertTrue(types.contains(kind), "missing \(kind) in \(entities)")
    }
    for entity in entities {
      let value = try XCTUnwrap(entity["value"])
      XCTAssertTrue(text.contains(value), "\(value) is a span of the text")
    }
  }

  func testExtract_findsNothingInPlainWords() throws {
    XCTAssertEqual(try extractOnceReady("A quiet afternoon by the lake").count, 0)
  }

  func testExtract_answersEmptyForBlankTextWithoutTheModel() throws {
    XCTAssertEqual(try background { EntityAnalyzer.extract("  \n ") }, [])
  }

  /// `extract` answers nil while the model is downloading; poll (off the
  /// main thread, which delivers the download's callback) until it answers,
  /// or fail.
  private func extractOnceReady(_ text: String) throws -> [[String: String]] {
    let found = try background(timeout: Self.downloadTimeout + 30) { () -> [[String: String]]? in
      let deadline = Date().addingTimeInterval(Self.downloadTimeout)
      while Date() < deadline {
        if let entities = EntityAnalyzer.extract(text) { return entities }
        Thread.sleep(forTimeInterval: 2)
      }
      return nil
    }
    return try XCTUnwrap(
      found, "The entity model did not download within \(Int(Self.downloadTimeout)) s (Wi-Fi?)")
  }
}
#endif
