import XCTest
@testable import ExpoMlKit

#if !targetEnvironment(simulator)

/// Entity Extraction downloads each language's model at first use. The suite
/// waits for those downloads, and FAILS if one never lands: an extractor that
/// silently stays "unknown" is the failure this checks for. Android's
/// `EntityTests.kt`, test for test.
final class EntityTests: MlKitTestCase {

  private static let downloadTimeout: TimeInterval = 180

  private let text = """
    Call +1 650-253-0000 or write to info@example.com.
    Visit https://example.com before March 3, 2027 at 10am.
    1600 Amphitheatre Parkway, Mountain View, CA 94043
    It costs $12.50 on flight LX 38, tracked as 1Z204E380338943508.
    """

  func testExtract_findsEachKindKeptWithItsSpan() throws {
    let entities = try extractOnceReady(text)
    let types = Set(entities.compactMap { $0["type"] as? String })
    for kind in ["phone", "email", "url", "dateTime", "address", "money", "flightNumber", "trackingNumber"] {
      XCTAssertTrue(types.contains(kind), "missing \(kind) in \(entities)")
    }
    let source = text as NSString
    for entity in entities {
      let start = try XCTUnwrap(entity["start"] as? Int)
      let end = try XCTUnwrap(entity["end"] as? Int)
      XCTAssertEqual(entity["value"] as? String, source.substring(with: NSRange(location: start, length: end - start)))
    }
  }

  func testExtract_parsesTheValuesItKnows() throws {
    let byType = Dictionary(try extractOnceReady(text).map { ($0["type"] as? String ?? "", $0) }) { a, _ in a }
    let money = try XCTUnwrap(byType["money"]?["money"] as? [String: Any])
    XCTAssertEqual(money["integerPart"] as? Int, 12)
    XCTAssertEqual(money["fractionalPart"] as? Int, 50)
    let flight = try XCTUnwrap(byType["flightNumber"]?["flightNumber"] as? [String: Any])
    XCTAssertEqual(flight["airlineCode"] as? String, "LX")
    XCTAssertEqual(flight["flightNumber"] as? String, "38")
    let parcel = try XCTUnwrap(byType["trackingNumber"]?["trackingNumber"] as? [String: Any])
    XCTAssertEqual(parcel["carrier"] as? String, "ups")
    let date = try XCTUnwrap(byType["dateTime"]?["dateTime"] as? [String: Any])
    XCTAssertGreaterThan(try XCTUnwrap(date["timestamp"] as? Double), 1.7e12)
    XCTAssertTrue(["hour", "minute"].contains(date["granularity"] as? String ?? ""), "\(date)")
  }

  func testExtract_keepsOnlyTheTypesAsked() throws {
    let entities = try extractOnceReady(text, ["types": ["email", "url"]])
    XCTAssertEqual(Set(entities.compactMap { $0["type"] as? String }), ["email", "url"])
  }

  func testExtract_readsAnotherLanguageWithItsOwnModel() throws {
    let entities = try extractOnceReady(
      "Rufen Sie mich morgen um 15 Uhr an: +49 30 1234567", ["language": "de"])
    XCTAssertTrue(entities.contains { $0["type"] as? String == "phone" }, "\(entities)")
  }

  func testExtract_findsNothingInPlainWords() throws {
    XCTAssertEqual(try extractOnceReady("A quiet afternoon by the lake").count, 0)
  }

  func testExtract_answersEmptyForBlankTextWithoutTheModel() throws {
    XCTAssertEqual(try background { try EntityAnalyzer.extract("  \n ") }?.count, 0)
  }

  /// `extract` answers nil while the model is downloading; poll (off the
  /// main thread, which delivers the download's callback) until it answers,
  /// or fail.
  private func extractOnceReady(_ text: String, _ options: [String: Any] = [:]) throws
    -> [[String: Any]]
  {
    let found = try background(timeout: Self.downloadTimeout + 30) { () -> [[String: Any]]? in
      let deadline = Date().addingTimeInterval(Self.downloadTimeout)
      while Date() < deadline {
        if let entities = try EntityAnalyzer.extract(text, options: options) { return entities }
        Thread.sleep(forTimeInterval: 2)
      }
      return nil
    }
    return try XCTUnwrap(
      found, "The entity model did not download within \(Int(Self.downloadTimeout)) s (Wi-Fi?)")
  }
}
#endif
