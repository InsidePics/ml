#if canImport(MLKitVision) && !targetEnvironment(simulator)
import CoreGraphics
import Foundation
import MLKitVision
import UIKit

/// `analyzeImage`: the enabled features' image models over one upright image,
/// in the wire shape `ExpoMlKit.types.ts` declares — the same Android's
/// `MlKitAnalyzer.kt` writes. Boxes are normalized to the image, top-left
/// origin. TS refuses a model whose feature is not linked and fills in the
/// parts not asked for. Entities are TS's to find in the text it settles on,
/// so asking for them runs text recognition.
enum MlKitAnalyzer {
  static func analyze(_ image: UIImage, models: Set<String>) throws -> [String: Any] {
    let size = image.size
    let vision = visionImage(image)
    let wanted = models.contains("mlKitEntities") ? models.union(["mlKitText"]) : models
    var result: [String: Any] = ["imageWidth": Int(size.width), "imageHeight": Int(size.height)]
    for model in MlKitFeatures.imageModels where wanted.contains(model.id) {
      result[model.key] = try model.run(vision, size)
    }
    return result
  }

  /// `image` for ML Kit; `AnalysisImage` made it upright.
  static func visionImage(_ image: UIImage) -> VisionImage {
    let vision = VisionImage(image: image)
    vision.orientation = .up
    return vision
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

  /// A point in image pixels, normalized, top-left origin: `MlKitPoint`.
  static func point(_ point: CGPoint, _ size: CGSize) -> [String: Double] {
    ["x": Double(point.x / size.width), "y": Double(point.y / size.height)]
  }

  /// A label as Image Labeling and Object Detection both report it.
  static func label(text: String, confidence: Float, index: Int) -> [String: Any] {
    ["text": text, "confidence": Double(confidence), "index": index]
  }
}

/// One `analyzeImage` model: its `mlKit*` id, the result key it fills and
/// the run over the call's one decode.
struct ImageModel {
  let id: String
  let key: String
  let run: (VisionImage, CGSize) throws -> Any
}
#endif
