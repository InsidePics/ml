import ExpoModulesCore
import UIKit

/// Google ML Kit on an Expo image handle (`SharedRef<UIImage>`) on iOS: the
/// same functions, in the same shapes, Android's `ExpoMlKitModule.kt` serves,
/// so a caller handles both platforms alike. Only the enabled features'
/// functions are defined (`MlKitFeatures`); TS reports a call to any other as
/// a feature the app did not enable, or one Android alone has.
///
/// Google ships no Apple Silicon simulator build of ML Kit: on a simulator
/// the ML Kit code is compiled out (and unlinked by the config plugin), no
/// function is defined, and `isAvailable` is false, so a caller can plan
/// around it.
public class ExpoMlKitModule: Module {
  #if targetEnvironment(simulator)
  static let isAvailable = false
  #else
  static let isAvailable = true
  #endif

  public func definition() -> ModuleDefinition {
    Name("ExpoMlKit")

    Constant("isAvailable") { Self.isAvailable }
    Constant("features") { MlKitFeatures.enabled }

    #if canImport(MLKitVision) && !targetEnvironment(simulator)
    AsyncFunction("analyzeImage") { (image: SharedRef<UIImage>, models: [String], promise: Promise) in
      MlKitCalls.withImage(image, promise) { try MlKitAnalyzer.analyze($0, models: Set(models)) }
    }
    #endif

    #if canImport(MLKitTextRecognition) && !targetEnvironment(simulator)
    AsyncFunction("recognizeText") { (image: SharedRef<UIImage>, scripts: [String], promise: Promise) in
      MlKitCalls.withImage(image, promise) { try TextAnalyzer.recognize($0, scripts: scripts) }
    }
    #endif

    #if canImport(MLKitEntityExtraction) && !targetEnvironment(simulator)
    // No image: the text TS chose, its confident lines only. Nil (unknown)
    // while the language model is not on the device yet.
    AsyncFunction("extractEntities") { (text: String, promise: Promise) in
      MlKitCalls.onQueue(promise) { EntityAnalyzer.extract(text) as Any? ?? NSNull() }
    }
    #endif

    #if canImport(MLKitFaceDetection) && !targetEnvironment(simulator)
    // Vision's `FaceObservation` shape, as Android's `FaceMapping.kt` writes.
    AsyncFunction("detectFaces") { (image: SharedRef<UIImage>, promise: Promise) in
      MlKitCalls.withImage(image, promise) { try FaceAnalyzer.detect($0) }
    }
    #endif

    #if canImport(MLKitBarcodeScanning) && !targetEnvironment(simulator)
    AsyncFunction("detectBarcodes") {
      (image: SharedRef<UIImage>, formats: [String]?, promise: Promise) in
      MlKitCalls.withImage(image, promise) {
        try BarcodeAnalyzer.scan(MlKitAnalyzer.visionImage($0), $0.size, formats: formats)
      }
    }
    #endif
  }
}
