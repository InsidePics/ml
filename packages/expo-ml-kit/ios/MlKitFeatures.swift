/// The `src/features.json` features linked into this build: the podspec links
/// a feature's pods only when the app enables it (`expoMlKit.features` in
/// Podfile.properties.json), and each feature's code compiles only where its
/// pod can be imported. On a simulator, where ML Kit is unlinked, none is.
enum MlKitFeatures {
  static let enabled: [String] = {
    var names: [String] = []
    #if !targetEnvironment(simulator)
    #if canImport(MLKitTextRecognition)
    names.append("text")
    #endif
    #if canImport(MLKitImageLabeling)
    names.append("labels")
    #endif
    #if canImport(MLKitBarcodeScanning)
    names.append("barcodes")
    #endif
    #if canImport(MLKitPoseDetection)
    names.append("poses")
    #endif
    #if canImport(MLKitObjectDetection)
    names.append("objects")
    #endif
    #if canImport(MLKitEntityExtraction)
    names.append("entities")
    #endif
    #if canImport(MLKitFaceDetection)
    names.append("faces")
    #endif
    #if canImport(MLKitPoseDetectionAccurate)
    names.append("posesAccurate")
    #endif
    #if canImport(MLKitImageLabelingCustom)
    names.append("customLabels")
    #endif
    #if canImport(MLKitObjectDetectionCustom)
    names.append("customObjects")
    #endif
    #if canImport(MLKitSegmentationSelfie)
    names.append("selfieSegmentation")
    #endif
    #if canImport(MLKitLanguageID)
    names.append("languageId")
    #endif
    #if canImport(MLKitSmartReply)
    names.append("smartReply")
    #endif
    #if canImport(MLKitTranslate)
    names.append("translate")
    #endif
    #if canImport(MLKitDigitalInkRecognition)
    names.append("digitalInk")
    #endif
    #endif
    return names
  }()
}

#if canImport(MLKitVision) && !targetEnvironment(simulator)
extension MlKitFeatures {
  /// The enabled features' `analyzeImage` models.
  static let imageModels: [ImageModel] = {
    var models: [ImageModel] = []
    #if canImport(MLKitTextRecognition)
    models.append(ImageModel(id: "mlKitText", key: "text") {
      try TextAnalyzer.read($0, $1, script: "latin")
    })
    #endif
    #if canImport(MLKitImageLabeling)
    models.append(ImageModel(id: "mlKitLabels", key: "labels") { image, _ in
      try LabelAnalyzer.label(image)
    })
    #endif
    #if canImport(MLKitBarcodeScanning)
    models.append(ImageModel(id: "mlKitBarcodes", key: "barcodes") {
      try BarcodeAnalyzer.scan($0, $1)
    })
    #endif
    #if canImport(MLKitPoseDetection)
    models.append(ImageModel(id: "mlKitPoses", key: "poses") { try PoseAnalyzer.detect($0, $1) })
    #endif
    #if canImport(MLKitObjectDetection)
    models.append(ImageModel(id: "mlKitObjects", key: "objects") { try ObjectAnalyzer.detect($0, $1) })
    #endif
    return models
  }()
}
#endif
