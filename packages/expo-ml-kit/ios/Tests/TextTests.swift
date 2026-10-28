import CoreText
import UIKit
import XCTest
@testable import ExpoMlKit

#if !targetEnvironment(simulator)

/// Text Recognition v2: the Latin read through `analyzeImage`, every bundled
/// script through `recognize`. The non-Latin samples are rendered here with
/// the system's fonts, so no photo of anyone's writing needs a licence.
final class TextTests: MlKitTestCase {

  func testLatin_readsTheSign() throws {
    let text = try XCTUnwrap(analyze("text.jpg", ["mlKitText"])["text"] as? [String: Any])
    let read = (text["text"] as? String ?? "").uppercased()
    for word in ["WARNING", "AMMUNITION", "TESTING", "HARLEY", "NOTICE"] {
      XCTAssertTrue(read.contains(word), "missing \(word) in: \(read)")
    }
    let blocks = try XCTUnwrap(text["blocks"] as? [[String: Any]])
    XCTAssertGreaterThanOrEqual(blocks.count, 2)
    for block in blocks { assertUnitRect(block["boundingBox"], "text block") }
  }

  func testLatin_readsNothingInALandscape() throws {
    let text = try XCTUnwrap(analyze("landscape.jpg", ["mlKitText"])["text"] as? [String: Any])
    XCTAssertEqual((text["text"] as? String)?.trimmingCharacters(in: .whitespaces), "")
  }

  func testText_isSkippedWhenNeitherTextNorEntitiesAreAsked() throws {
    let result = try analyze("text.jpg", ["mlKitLabels"])
    XCTAssertNil(result["text"], "TS fills in the parts not asked for")
    XCTAssertNotNil(result["labels"])
  }

  func testEntities_runTextRecognition() throws {
    let text = try XCTUnwrap(analyze("text.jpg", ["mlKitEntities"])["text"] as? [String: Any])
    XCTAssertFalse((text["text"] as? String ?? "").isEmpty)
  }

  func testEveryScript_readsItsOwnWriting() throws {
    let samples: [(script: String, text: String)] = [
      ("chinese", "你好世界"),
      ("japanese", "こんにちは"),
      ("korean", "안녕하세요"),
      ("devanagari", "नमस्ते दुनिया"),
      ("latin", "Hello World"),
    ]
    for sample in samples {
      let image = try render(sample.text)
      let reads = try recognize(image, [sample.script])
      let read = (reads.first?["text"] as? String ?? "").filter { !$0.isWhitespace }
      let want = sample.text.filter { !$0.isWhitespace }
      // One character of slack: on the iPhone 16 Pro the Devanagari model
      // drops the vowel sign of "दुनिया" in this rendering. A recognizer that
      // cannot read the script misses far more.
      XCTAssertLessThanOrEqual(
        editDistance(Array(read.unicodeScalars), Array(want.unicodeScalars)), 1,
        "\(sample.script) read \"\(read)\" for \"\(sample.text)\"")
    }
  }

  func testRecognize_returnsOneReadPerScriptInOrder() throws {
    let reads = try recognize(image("text.jpg"), ["latin", "korean"])
    XCTAssertEqual(reads.count, 2)
    // The CJK and Devanagari models read Latin text too.
    for read in reads {
      XCTAssertTrue((read["text"] as? String ?? "").uppercased().contains("WARNING"))
    }
  }

  func testRecognize_rejectsAnUnknownScript() throws {
    XCTAssertThrowsError(try recognize(image("text.jpg"), ["klingon"]))
  }

  // MARK: - Helpers

  /// Levenshtein distance, by Unicode scalar (a vowel sign counts as one).
  private func editDistance<T: Equatable>(_ a: [T], _ b: [T]) -> Int {
    var row = Array(0...b.count)
    for i in 1...max(a.count, 1) where !a.isEmpty {
      var previous = row[0]
      row[0] = i
      for j in stride(from: 1, through: b.count, by: 1) {
        let current = row[j]
        row[j] = min(row[j] + 1, row[j - 1] + 1, previous + (a[i - 1] == b[j - 1] ? 0 : 1))
        previous = current
      }
    }
    return a.isEmpty ? b.count : row[b.count]
  }

  /// Black text on white, 96 pt in the system font (which falls back to the
  /// script's own font), padded.
  private func render(_ text: String) throws -> UIImage {
    let font = UIFont.systemFont(ofSize: 96)
    let attributed = NSAttributedString(
      string: text, attributes: [.font: font, .foregroundColor: UIColor.black])
    let size = attributed.size()
    let canvas = CGSize(width: ceil(size.width) + 160, height: ceil(size.height) + 160)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let rendered = UIGraphicsImageRenderer(size: canvas, format: format).image { ctx in
      UIColor.white.setFill()
      ctx.fill(CGRect(origin: .zero, size: canvas))
      attributed.draw(at: CGPoint(x: 80, y: 80))
    }
    return try XCTUnwrap(rendered.cgImage.map { UIImage(cgImage: $0, scale: 1, orientation: .up) })
  }
}
#endif
