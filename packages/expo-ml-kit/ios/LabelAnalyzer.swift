#if canImport(MLKitImageLabeling) && !targetEnvironment(simulator)
import Foundation
import MLKitImageLabeling
import MLKitImageLabelingCommon
import MLKitVision

/// Image Labeling, bundled base model: `analyzeImage`'s labels at ML Kit's
/// default 0.5 threshold, and `labelImage` at the caller's.
enum LabelAnalyzer {
  private static let lock = NSLock()
  private static var labelers: [Float: ImageLabeler] = [:]

  private static func labeler(_ threshold: Float) -> ImageLabeler {
    lock.lock()
    defer { lock.unlock() }
    if let found = labelers[threshold] { return found }
    let options = ImageLabelerOptions()
    options.confidenceThreshold = NSNumber(value: threshold)
    let made = ImageLabeler.imageLabeler(options: options)
    labelers[threshold] = made
    return made
  }

  static func label(_ image: VisionImage, threshold: Float = 0.5) throws -> [[String: Any]] {
    try labeler(threshold).results(in: image).map(json)
  }

  /// `MlKitLabel`, as the custom labeler writes it too.
  static func json(_ label: ImageLabel) -> [String: Any] {
    MlKitAnalyzer.label(text: label.text, confidence: label.confidence, index: label.index)
  }
}
#endif
