#if (canImport(MLKitImageLabelingCustom) || canImport(MLKitObjectDetectionCustom)) && !targetEnvironment(simulator)
import CoreGraphics
import Foundation
import MLKitCommon
import MLKitVision
#if canImport(MLKitImageLabelingCustom)
import MLKitImageLabelingCommon
import MLKitImageLabelingCustom
#endif
#if canImport(MLKitObjectDetectionCustom)
import MLKitObjectDetectionCommon
import MLKitObjectDetectionCustom
#endif

/// Image Labeling and Object Detection with the caller's TensorFlow Lite
/// classifier (`MlKitCustomModel`), as Android's `CustomLabelsFeature.kt` and
/// `CustomObjectsFeature.kt`: a labeler or detector per model and options,
/// kept.
enum CustomModels {
  private static let lock = NSLock()
  private static var made: [String: AnyObject] = [:]

  /// The model file `options.model.path` names: absolute or `file://`.
  static func path(_ options: [String: Any]) throws -> String {
    guard let model = options["model"] as? [String: Any], let raw = model["path"] as? String else {
      throw failure("No custom model given")
    }
    let path = raw.hasPrefix("file://") ? String(raw.dropFirst(7)) : raw
    guard FileManager.default.fileExists(atPath: path) else { throw failure("No model file at \(path)") }
    return path
  }

  private static func failure(_ message: String) -> NSError {
    NSError(domain: "ExpoMlKit", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
  }

  private static func cached<T: AnyObject>(_ key: String, _ make: () -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    if let found = made[key] as? T { return found }
    let created = make()
    made[key] = created
    return created
  }

  private static func number(_ options: [String: Any], _ key: String) -> Double? {
    (options[key] as? NSNumber)?.doubleValue
  }

  #if canImport(MLKitImageLabelingCustom)
  /// `labelImage` with `options.model` (`MlKitLabelOptions`).
  static func label(_ image: VisionImage, _ options: [String: Any]) throws -> [[String: Any]] {
    let path = try path(options)
    let threshold = number(options, "confidenceThreshold") ?? 0.5
    let maxResults = Int(number(options, "maxResults") ?? 10)
    let labeler: ImageLabeler = cached("labels|\(path)|\(threshold)|\(maxResults)") {
      let settings = CustomImageLabelerOptions(localModel: LocalModel(path: path))
      settings.confidenceThreshold = NSNumber(value: threshold)
      settings.maxResultCount = maxResults
      return ImageLabeler.imageLabeler(options: settings)
    }
    return try labeler.results(in: image).map {
      MlKitAnalyzer.label(text: $0.text, confidence: $0.confidence, index: $0.index)
    }
  }
  #endif

  #if canImport(MLKitObjectDetectionCustom)
  /// `detectObjects` with `options.model` (`MlKitObjectOptions`).
  static func detect(_ image: VisionImage, _ size: CGSize, _ options: [String: Any]) throws
    -> [[String: Any]]
  {
    let path = try path(options)
    let multiple = options["multipleObjects"] as? Bool ?? true
    let classify = options["classify"] as? Bool ?? true
    let threshold = number(options, "confidenceThreshold") ?? 0.5
    let maxLabels = Int(number(options, "maxLabelsPerObject") ?? 10)
    let key = "objects|\(path)|\(multiple)|\(classify)|\(threshold)|\(maxLabels)"
    let detector: ObjectDetector = cached(key) {
      let settings = CustomObjectDetectorOptions(localModel: LocalModel(path: path))
      settings.detectorMode = .singleImage
      settings.shouldEnableMultipleObjects = multiple
      settings.shouldEnableClassification = classify
      settings.classificationConfidenceThreshold = NSNumber(value: threshold)
      settings.maxPerObjectLabelCount = maxLabels
      return ObjectDetector.objectDetector(options: settings)
    }
    return try detector.results(in: image).map { object in
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
}
#endif
