#if !targetEnvironment(simulator)
import CoreGraphics
import Foundation
import MLKitBarcodeScanning
import MLKitEntityExtraction
import MLKitImageLabeling
import MLKitObjectDetection
import MLKitPoseDetection
import MLKitTextRecognition
import MLKitTextRecognitionChinese
import MLKitTextRecognitionCommon
import MLKitTextRecognitionDevanagari
import MLKitTextRecognitionJapanese
import MLKitTextRecognitionKorean
import MLKitVision
import UIKit

/// ML Kit's image models over one upright image, in the wire shape
/// `ExpoMlKit.types.ts` declares — the same Android's `ExpoMlKitModule.kt`
/// writes. Boxes are normalized to the image, top-left origin. Only the
/// detectors `models` (`mlKit*` cell ids) need run. Text is the Latin
/// recognizer's; which other scripts read the photo, which read is kept and
/// where entities are found is decided in TS (`src/textQuality.ts`), the same
/// on every platform.
enum MlKitAnalyzer {
  /// The recognizer for an `MlKitTextScript` name, the same names Android
  /// uses. Each is built on its first use (`static let` is lazy): most
  /// photos never need a non-Latin one. ML Kit iOS reports no line
  /// confidence, so TS judges every read from its text alone.
  private static func textRecognizer(_ script: String) -> TextRecognizer? {
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
  private static let labeler = ImageLabeler.imageLabeler(options: ImageLabelerOptions())
  private static let barcodeScanner = BarcodeScanner.barcodeScanner()
  private static let poseDetector: PoseDetector = {
    let options = PoseDetectorOptions()
    options.detectorMode = .singleImage
    return PoseDetector.poseDetector(options: options)
  }()
  private static let objectDetector: ObjectDetector = {
    let options = ObjectDetectorOptions()
    options.detectorMode = .singleImage
    options.shouldEnableMultipleObjects = true
    options.shouldEnableClassification = true
    return ObjectDetector.objectDetector(options: options)
  }()

  static func analyze(_ image: UIImage, models: Set<String>) throws -> [String: Any] {
    let size = image.size
    let vision = visionImage(image)
    let wantsText = models.contains("mlKitText") || models.contains("mlKitEntities")
    func due(_ model: String, _ run: () throws -> Any) rethrows -> Any {
      models.contains(model) ? try run() : [Any]()
    }
    return [
      "imageWidth": Int(size.width),
      "imageHeight": Int(size.height),
      "text": wantsText ? try text(vision, size, script: "latin") : ["text": "", "blocks": [Any]()],
      "labels": try due("mlKitLabels") { try labels(vision) },
      "barcodes": try due("mlKitBarcodes") { try barcodes(vision, size) },
      "poses": try due("mlKitPoses") { try poses(vision, size) },
      "objects": try due("mlKitObjects") { try objects(vision, size) },
    ]
  }

  /// Each of `scripts`' recognizers over the one image, in order.
  static func recognize(_ image: UIImage, scripts: [String]) throws -> [[String: Any]] {
    let vision = visionImage(image)
    return try scripts.map { try text(vision, image.size, script: $0) }
  }

  /// `image` for ML Kit, upright (`UprightImage` applied the orientation).
  static func visionImage(_ image: UIImage) -> VisionImage {
    let vision = VisionImage(image: image)
    vision.orientation = .up
    return vision
  }

  private static func text(_ image: VisionImage, _ size: CGSize, script: String) throws
    -> [String: Any]
  {
    guard let recognizer = textRecognizer(script) else {
      throw NSError(domain: "ExpoMlKit", code: 1, userInfo: [
        NSLocalizedDescriptionKey: "Unknown script \(script)",
      ])
    }
    let read = try recognizer.results(in: image)
    return [
      "text": read.text,
      "blocks": read.blocks.map {
        ["text": $0.text, "boundingBox": rect($0.frame, size)] as [String: Any]
      },
    ]
  }

  /// A frame in image pixels, normalized, top-left origin.
  static func rect(_ frame: CGRect, _ size: CGSize) -> [String: Double] {
    [
      "x": Double(frame.minX / size.width),
      "y": Double(frame.minY / size.height),
      "width": Double(frame.width / size.width),
      "height": Double(frame.height / size.height),
    ]
  }

  private static func labels(_ image: VisionImage) throws -> [[String: Any]] {
    try labeler.results(in: image).map {
      ["text": $0.text, "confidence": Double($0.confidence), "index": $0.index]
    }
  }

  static func barcodes(_ image: VisionImage, _ size: CGSize) throws -> [[String: Any]] {
    try barcodeScanner.results(in: image).compactMap { code in
      guard let format = MlKitNames.barcodeFormat(code.format) else { return nil }
      return [
        "rawValue": code.rawValue as Any? ?? NSNull(),
        "format": format,
        "boundingBox": rect(code.frame, size),
      ]
    }
  }

  /// Zero poses or one; `x`/`z` over the width, `y` over the height.
  private static func poses(_ image: VisionImage, _ size: CGSize) throws -> [[String: Any]] {
    try poseDetector.results(in: image).prefix(1).compactMap { pose in
      if pose.landmarks.isEmpty { return nil }
      return [
        "landmarks": pose.landmarks.map { landmark in
          [
            "type": MlKitNames.poseLandmarks[landmark.type] ?? "unknown",
            "x": Double(landmark.position.x / size.width),
            "y": Double(landmark.position.y / size.height),
            "z": Double(landmark.position.z / size.width),
            "inFrameLikelihood": Double(landmark.inFrameLikelihood),
          ] as [String: Any]
        }
      ]
    }
  }

  private static func objects(_ image: VisionImage, _ size: CGSize) throws -> [[String: Any]] {
    try objectDetector.results(in: image).map { object in
      [
        "boundingBox": rect(object.frame, size),
        "trackingId": object.trackingID?.intValue as Any? ?? NSNull(),
        "labels": object.labels.map {
          ["text": $0.text, "confidence": Double($0.confidence), "index": $0.index]
            as [String: Any]
        },
      ]
    }
  }
}
#endif
