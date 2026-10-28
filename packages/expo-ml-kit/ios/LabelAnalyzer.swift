#if canImport(MLKitImageLabeling) && !targetEnvironment(simulator)
import MLKitImageLabeling
import MLKitVision

/// Image Labeling, bundled base model (default 0.5 confidence threshold).
enum LabelAnalyzer {
  private static let labeler = ImageLabeler.imageLabeler(options: ImageLabelerOptions())

  static func label(_ image: VisionImage) throws -> [[String: Any]] {
    try labeler.results(in: image).map {
      MlKitAnalyzer.label(text: $0.text, confidence: $0.confidence, index: $0.index)
    }
  }
}
#endif
