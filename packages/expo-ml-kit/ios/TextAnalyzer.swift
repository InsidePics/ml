#if canImport(MLKitTextRecognition) && !targetEnvironment(simulator)
import CoreGraphics
import Foundation
import MLKitTextRecognition
import MLKitTextRecognitionChinese
import MLKitTextRecognitionCommon
import MLKitTextRecognitionDevanagari
import MLKitTextRecognitionJapanese
import MLKitTextRecognitionKorean
import MLKitVision
import UIKit

/// Text Recognition v2, one bundled recognizer per script, as Android's
/// `TextAnalyzer.kt`. Which run, and which read is kept, is decided in TS
/// (`src/textQuality.ts`) the same on every platform.
enum TextAnalyzer {
  /// The recognizer for an `MlKitTextScript` name, the same names Android
  /// uses. Each is built on its first use (`static let` is lazy): most
  /// photos never need a non-Latin one. ML Kit iOS reports no line
  /// confidence, so TS judges every read from its text alone.
  private static func recognizer(_ script: String) -> TextRecognizer? {
    switch script {
    case "latin": return latin
    case "chinese": return chinese
    case "devanagari": return devanagari
    case "japanese": return japanese
    case "korean": return korean
    default: return nil
    }
  }
  private static let latin = TextRecognizer.textRecognizer(options: TextRecognizerOptions())
  private static let chinese = TextRecognizer.textRecognizer(
    options: ChineseTextRecognizerOptions())
  private static let devanagari = TextRecognizer.textRecognizer(
    options: DevanagariTextRecognizerOptions())
  private static let japanese = TextRecognizer.textRecognizer(
    options: JapaneseTextRecognizerOptions())
  private static let korean = TextRecognizer.textRecognizer(options: KoreanTextRecognizerOptions())

  /// Each of `scripts`' recognizers over the one image, in order.
  static func recognize(_ image: UIImage, scripts: [String]) throws -> [[String: Any]] {
    let vision = MlKitAnalyzer.visionImage(image)
    return try scripts.map { try read(vision, image.size, script: $0) }
  }

  /// The `script` recognizer's read: the full text and its blocks.
  static func read(_ image: VisionImage, _ size: CGSize, script: String) throws -> [String: Any] {
    guard let recognizer = recognizer(script) else {
      throw NSError(domain: "ExpoMlKit", code: 1, userInfo: [
        NSLocalizedDescriptionKey: "Unknown script \(script)",
      ])
    }
    let text = try recognizer.results(in: image)
    return [
      "text": text.text,
      "blocks": text.blocks.map {
        ["text": $0.text, "boundingBox": MlKitAnalyzer.rect($0.frame, size)] as [String: Any]
      },
    ]
  }
}
#endif
