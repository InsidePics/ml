import ExpoModulesCore
import UIKit

/// Google ML Kit on an Expo image handle (`SharedRef<UIImage>`) on iOS: the
/// same functions, in the same shapes, Android's `ExpoMlKitModule.kt` serves,
/// so a caller handles both platforms alike. Only the enabled features'
/// functions are defined (`MlKitFeatures`): each feature's file defines its
/// own in an extension of this module, listed here under its `canImport`. TS
/// reports a call to any other as a feature the app did not enable, or one
/// Android alone has.
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

    #if !targetEnvironment(simulator)
    #if canImport(MLKitVision)
    Self.analyzeImage()
    #endif
    #if canImport(MLKitTextRecognition)
    Self.recognizeText()
    #endif
    #if canImport(MLKitImageLabeling)
    Self.labelImage()
    #endif
    #if canImport(MLKitImageLabelingCustom)
    Self.labelImageCustom()
    #endif
    #if canImport(MLKitObjectDetection)
    Self.detectObjects()
    #endif
    #if canImport(MLKitObjectDetectionCustom)
    Self.detectObjectsCustom()
    #endif
    #if canImport(MLKitBarcodeScanning)
    Self.detectBarcodes()
    #endif
    #if canImport(MLKitPoseDetection)
    Self.detectPose()
    #endif
    #if canImport(MLKitPoseDetectionAccurate)
    Self.detectPoseAccurate()
    #endif
    #if canImport(MLKitFaceDetection)
    Self.detectFaces()
    #endif
    #if canImport(MLKitSegmentationSelfie)
    Self.segmentSelfie()
    #endif
    #if canImport(MLKitEntityExtraction)
    Self.extractEntities()
    Self.downloadEntityModel()
    Self.deleteEntityModel()
    Self.downloadedEntityModels()
    #endif
    #if canImport(MLKitLanguageID)
    Self.identifyLanguage()
    Self.identifyPossibleLanguages()
    #endif
    #if canImport(MLKitSmartReply)
    Self.suggestReplies()
    #endif
    #endif
  }
}
