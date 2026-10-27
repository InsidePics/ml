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
    let text = try XCTUnwrap(analyze("text.jpg", ["mlKitLabels"])["text"] as? [String: Any])
    XCTAssertEqual(text["text"] as? String, "")
    XCTAssertEqual((text["blocks"] as? [Any])?.count, 0)
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
      let reads = try MlKitAnalyzer.recognize(image, scripts: [sample.script])
      let read = (reads.first?["text"] as? String ?? "").replacingOccurrences(of: " ", with: "")
      XCTAssertTrue(
        read.contains(sample.text.replacingOccurrences(of: " ", with: "")),
        "\(sample.script) read \"\(read)\" for \"\(sample.text)\"")
    }
  }

  func testRecognize_returnsOneReadPerScriptInOrder() throws {
    let reads = try MlKitAnalyzer.recognize(image("text.jpg"), scripts: ["latin", "korean"])
    XCTAssertEqual(reads.count, 2)
    // The CJK and Devanagari models read Latin text too.
    for read in reads {
      XCTAssertTrue((read["text"] as? String ?? "").uppercased().contains("WARNING"))
    }
  }

  func testRecognize_rejectsAnUnknownScript() throws {
    XCTAssertThrowsError(try MlKitAnalyzer.recognize(image("text.jpg"), scripts: ["klingon"]))
  }

  // MARK: - Helpers

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
