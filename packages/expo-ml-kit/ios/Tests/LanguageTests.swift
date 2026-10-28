import XCTest
@testable import ExpoMlKit

#if !targetEnvironment(simulator)

/// Language Identification and Smart Reply, the bundled text models.
/// Android's `LanguageTests.kt`, test for test.
final class LanguageTests: MlKitTestCase {

  func testIdentify_namesTheLanguageOfASentence() throws {
    XCTAssertEqual(try background { try LanguageIdAnalyzer.identify("Wo ist der Bahnhof, bitte?", threshold: nil) }, "de")
    XCTAssertEqual(try background { try LanguageIdAnalyzer.identify("駅はどこですか", threshold: nil) }, "ja")
    XCTAssertEqual(try background { try LanguageIdAnalyzer.identify("", threshold: nil) }, "und")
  }

  func testIdentify_ranksThePossibleLanguages() throws {
    let possible = try background {
      try LanguageIdAnalyzer.possible("Ceci est une phrase en français.", threshold: 0.01)
    }
    XCTAssertEqual(possible.first?["language"] as? String, "fr")
    let confidences = possible.compactMap { $0["confidence"] as? Double }
    XCTAssertEqual(confidences, confidences.sorted(by: >))
  }

  func testSmartReply_suggestsRepliesToTheLastRemoteMessage() throws {
    let now = Date().timeIntervalSince1970 * 1000
    let result = try background {
      try SmartReplyAnalyzer.suggest([
        ["text": "Hey, are you coming to dinner tonight?", "timestamp": now - 60_000, "userId": "friend"],
      ])
    }
    XCTAssertEqual(result["status"] as? String, "success")
    XCTAssertFalse((result["suggestions"] as? [String] ?? []).isEmpty, "\(result)")
  }

  func testSmartReply_repliesToNothingInAnUnsupportedLanguage() throws {
    let result = try background {
      try SmartReplyAnalyzer.suggest([
        ["text": "Kommst du heute Abend zum Essen?", "timestamp": Date().timeIntervalSince1970 * 1000, "userId": "friend"],
      ])
    }
    XCTAssertEqual(result["status"] as? String, "notSupportedLanguage")
    XCTAssertEqual((result["suggestions"] as? [String])?.count, 0)
  }
}
#endif
