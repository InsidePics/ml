import XCTest
@testable import ExpoMlKit
#if !targetEnvironment(simulator)
import MLKitCommon
import MLKitTranslate

/// Translation and Digital Ink, whose models download: the suite downloads
/// them and FAILS if a download never lands. Android's
/// `DownloadedModelTests.kt`, test for test.
final class DownloadedModelTests: MlKitTestCase {

  /// `start` answered through its callback, waited for here.
  private func answer<T>(_ timeout: TimeInterval = 300, _ start: (@escaping (Result<T, Error>) -> Void) throws -> Void)
    throws -> T
  {
    var result: Result<T, Error>?
    let done = expectation(description: "answer")
    try start { result = $0; done.fulfill() }
    wait(for: [done], timeout: timeout)
    return try XCTUnwrap(result, "no answer").get()
  }

  func testTranslate_translatesOnceBothModelsAreThere() throws {
    let options: [String: Any] = ["from": "en", "to": "de", "downloadIfNeeded": true, "wifiOnly": false]
    let translated: String = try answer { try TranslateAnalyzer.translate("Good morning, my friend", options, $0) }
    XCTAssertTrue(translated.localizedCaseInsensitiveContains("Guten Morgen"), translated)
    XCTAssertTrue(ModelManager.modelManager().downloadedTranslateModels.contains { $0.language == .german })
  }

  func testTranslate_refusesAPairWhoseModelIsMissing() throws {
    let model = try TranslateAnalyzer.remote("is")
    let _: Bool = try answer(60) { done in
      ModelManager.modelManager().deleteDownloadedModel(model) { _ in done(.success(true)) }
    }
    let options: [String: Any] = ["from": "en", "to": "is"]
    XCTAssertThrowsError(try answer { (done: @escaping (Result<String, Error>) -> Void) in
      try TranslateAnalyzer.translate("Hello", options, done)
    }) { XCTAssertTrue($0 is ModelMissing, "\($0)") }
  }

  func testInk_readsTheHandwrittenWord() throws {
    let data = try Data(contentsOf: URL(fileURLWithPath: FixturePaths.path("ink-cat.json")))
    let fixture = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    let strokes = try XCTUnwrap(fixture["strokes"] as? [[[String: Any]]])
    let model = try DigitalInkAnalyzer.model("en-US")
    let progress = ModelManager.modelManager().download(
      model, conditions: ModelDownloadConditions(allowsCellularAccess: true, allowsBackgroundDownloading: true))
    let _: Bool = try answer { done in
      DownloadWatch.until(model, progress) { error in done(error.map { .failure($0) } ?? .success(true)) }
    }
    let options: [String: Any] = ["language": "en-US", "writingArea": fixture["writingArea"] ?? [:]]
    let candidates: [[String: Any]] = try answer { try DigitalInkAnalyzer.recognize(strokes, options, $0) }
    XCTAssertTrue(
      candidates.prefix(3).contains { ($0["text"] as? String)?.lowercased() == "cat" }, "\(candidates)")
  }

  func testInk_refusesAnUnknownModel() {
    XCTAssertThrowsError(try DigitalInkAnalyzer.model("not-a-language-xx"))
  }
}
#endif
