#if !targetEnvironment(simulator)
import ExpoModulesCore
import UIKit
#if canImport(MLKitVision)
import MLKitVision
#endif

/// The module's functions, one per feature call, each compiled only where
/// its feature's pod is linked (`ExpoMlKitModule.definition` lists them).
/// Image calls run on the analysis queue over the prepared image
/// (`MlKitCalls.withImage`); text calls on the same queue; downloads settle
/// from ML Kit's completion handlers.
extension ExpoMlKitModule {
  #if canImport(MLKitVision)
  static func analyzeImage() -> AnyDefinition {
    AsyncFunction("analyzeImage") { (image: SharedRef<UIImage>, models: [String], promise: Promise) in
      MlKitCalls.withImage(image, promise) { try MlKitAnalyzer.analyze($0, models: Set(models)) }
    }
  }

  /// `run` over the image as ML Kit takes it, and its size.
  static func onImage(
    _ image: SharedRef<UIImage>, _ promise: Promise, _ run: @escaping (VisionImage, CGSize) throws -> Any
  ) {
    MlKitCalls.withImage(image, promise) { try run(MlKitAnalyzer.visionImage($0), $0.size) }
  }
  #endif

  #if canImport(MLKitTextRecognition)
  static func recognizeText() -> AnyDefinition {
    AsyncFunction("recognizeText") { (image: SharedRef<UIImage>, scripts: [String], promise: Promise) in
      MlKitCalls.withImage(image, promise) { try TextAnalyzer.recognize($0, scripts: scripts) }
    }
  }
  #endif

  #if canImport(MLKitImageLabeling)
  static func labelImage() -> AnyDefinition {
    AsyncFunction("labelImage") { (image: SharedRef<UIImage>, options: [String: Any], promise: Promise) in
      let threshold = (options["confidenceThreshold"] as? NSNumber)?.floatValue ?? 0.5
      onImage(image, promise) { vision, _ in try LabelAnalyzer.label(vision, threshold: threshold) }
    }
  }
  #endif

  #if canImport(MLKitImageLabelingCustom)
  static func labelImageCustom() -> AnyDefinition {
    AsyncFunction("labelImageCustom") { (image: SharedRef<UIImage>, options: [String: Any], promise: Promise) in
      onImage(image, promise) { vision, _ in try CustomModels.label(vision, options) }
    }
  }
  #endif

  #if canImport(MLKitObjectDetection)
  static func detectObjects() -> AnyDefinition {
    AsyncFunction("detectObjects") { (image: SharedRef<UIImage>, options: [String: Any], promise: Promise) in
      let multiple = options["multipleObjects"] as? Bool ?? true
      let classify = options["classify"] as? Bool ?? true
      onImage(image, promise) {
        try ObjectAnalyzer.detect($0, $1, multiple: multiple, classify: classify)
      }
    }
  }
  #endif

  #if canImport(MLKitObjectDetectionCustom)
  static func detectObjectsCustom() -> AnyDefinition {
    AsyncFunction("detectObjectsCustom") { (image: SharedRef<UIImage>, options: [String: Any], promise: Promise) in
      onImage(image, promise) { try CustomModels.detect($0, $1, options) }
    }
  }
  #endif

  #if canImport(MLKitBarcodeScanning)
  static func detectBarcodes() -> AnyDefinition {
    AsyncFunction("detectBarcodes") { (image: SharedRef<UIImage>, formats: [String]?, promise: Promise) in
      onImage(image, promise) { try BarcodeAnalyzer.scan($0, $1, formats: formats) }
    }
  }
  #endif

  #if canImport(MLKitPoseDetection)
  static func detectPose() -> AnyDefinition {
    AsyncFunction("detectPose") { (image: SharedRef<UIImage>, promise: Promise) in
      onImage(image, promise) { try PoseAnalyzer.detect($0, $1) }
    }
  }
  #endif

  #if canImport(MLKitPoseDetectionAccurate)
  static func detectPoseAccurate() -> AnyDefinition {
    AsyncFunction("detectPoseAccurate") { (image: SharedRef<UIImage>, promise: Promise) in
      onImage(image, promise) { try PoseAnalyzer.detect($0, $1, with: AccuratePoseAnalyzer.detector) }
    }
  }
  #endif

  #if canImport(MLKitFaceDetection)
  // Vision's `FaceObservation` shape, as Android's `FaceMapping.kt` writes.
  static func detectFaces() -> AnyDefinition {
    AsyncFunction("detectFaces") { (image: SharedRef<UIImage>, options: [String: Any], promise: Promise) in
      let parsed = FaceAnalyzer.Options(options)
      MlKitCalls.withImage(image, promise) { try FaceAnalyzer.detect($0, options: parsed) }
    }
  }
  #endif

  #if canImport(MLKitSegmentationSelfie)
  static func segmentSelfie() -> AnyDefinition {
    AsyncFunction("segmentSelfie") { (image: SharedRef<UIImage>, options: [String: Any], promise: Promise) in
      let rawSize = options["rawSizeMask"] as? Bool ?? false
      onImage(image, promise) { vision, _ in
        try SelfieSegmentationAnalyzer.segment(vision, rawSize: rawSize)
      }
    }
  }
  #endif
}
#endif
