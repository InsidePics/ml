#if canImport(MLKitObjectDetection) && !targetEnvironment(simulator)
import CoreGraphics
import Foundation
import MLKitObjectDetection
import MLKitObjectDetectionCommon
import MLKitVision

/// Object Detection, bundled base model: up to five objects, classified into
/// its coarse categories (fashion good, food, home good, place, plant).
enum ObjectAnalyzer {
  private static let lock = NSLock()
  private static var detectors: [[Bool]: ObjectDetector] = [:]

  private static func detector(multiple: Bool, classify: Bool) -> ObjectDetector {
    lock.lock()
    defer { lock.unlock() }
    if let found = detectors[[multiple, classify]] { return found }
    let options = ObjectDetectorOptions()
    options.detectorMode = .singleImage
    options.shouldEnableMultipleObjects = multiple
    options.shouldEnableClassification = classify
    let made = ObjectDetector.objectDetector(options: options)
    detectors[[multiple, classify]] = made
    return made
  }

  static func detect(
    _ image: VisionImage, _ size: CGSize, multiple: Bool = true, classify: Bool = true
  ) throws -> [[String: Any]] {
    try detector(multiple: multiple, classify: classify).results(in: image).map { json($0, size) }
  }

  /// `MlKitObject`, as the custom detector writes it too.
  static func json(_ object: Object, _ size: CGSize) -> [String: Any] {
    [
      "boundingBox": MlKitAnalyzer.rect(object.frame, size),
      "trackingId": object.trackingID?.intValue as Any? ?? NSNull(),
      "labels": object.labels.map {
        MlKitAnalyzer.label(text: $0.text, confidence: $0.confidence, index: $0.index)
      },
    ]
  }
}
#endif
