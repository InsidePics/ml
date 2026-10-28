#if canImport(MLKitObjectDetection) && !targetEnvironment(simulator)
import CoreGraphics
import Foundation
import MLKitObjectDetection
import MLKitVision

/// Object Detection, bundled base model: up to five objects, classified into
/// its coarse categories (fashion good, food, home good, place, plant).
enum ObjectAnalyzer {
  private static let detector: ObjectDetector = {
    let options = ObjectDetectorOptions()
    options.detectorMode = .singleImage
    options.shouldEnableMultipleObjects = true
    options.shouldEnableClassification = true
    return ObjectDetector.objectDetector(options: options)
  }()

  static func detect(_ image: VisionImage, _ size: CGSize) throws -> [[String: Any]] {
    try detector.results(in: image).map { object in
      [
        "boundingBox": MlKitAnalyzer.rect(object.frame, size),
        "trackingId": object.trackingID?.intValue as Any? ?? NSNull(),
        "labels": object.labels.map {
          MlKitAnalyzer.label(text: $0.text, confidence: $0.confidence, index: $0.index)
        },
      ]
    }
  }
}
#endif
