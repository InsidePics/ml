import Vision

/// `analyzeImage`: every Vision request this module offers over one upright
/// image, in one pass (one `VNImageRequestHandler`), plus the iOS 26 lens
/// smudge and document reads where available. Free of ExpoModulesCore, so
/// the Mac tests and the device tests call it directly.
enum VisionBatch {
  static func analyze(_ cgImage: CGImage) async throws -> [String: Any] {
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

    let textReq = VNRecognizeTextRequest()
    textReq.recognitionLevel = .accurate
    let classifyReq = VNClassifyImageRequest()
    let barcodeReq = VNDetectBarcodesRequest()
    let bodyPoseReq = VNDetectHumanBodyPoseRequest()
    let handPoseReq = VNDetectHumanHandPoseRequest()
    handPoseReq.maximumHandCount = 4
    let featurePrintReq = VNGenerateImageFeaturePrintRequest()
    let attentionReq = VNGenerateAttentionBasedSaliencyImageRequest()
    let objectnessReq = VNGenerateObjectnessBasedSaliencyImageRequest()
    let animalReq = VNRecognizeAnimalsRequest()
    let rectangleReq = VNDetectRectanglesRequest()
    rectangleReq.maximumObservations = 10
    let horizonReq = VNDetectHorizonRequest()

    var requests: [VNRequest] = [
      textReq, classifyReq, barcodeReq,
      bodyPoseReq, handPoseReq, featurePrintReq, attentionReq, objectnessReq,
      animalReq, rectangleReq, horizonReq,
    ]

    var aestheticsReq: VNRequest? = nil
    if #available(iOS 18.0, macOS 15.0, *) {
      let req = VNCalculateImageAestheticsScoresRequest()
      aestheticsReq = req
      requests.append(req)
    }

    try handler.perform(requests)
    let faces = try VisionProcessors.detectFaces(handler)

    let text = VisionProcessors.processText(textReq.results ?? [])
    let labels = VisionProcessors.processClassification(classifyReq.results ?? [])
    let barcodes = VisionProcessors.processBarcodes(barcodeReq.results ?? [])
    let bodyPoses = VisionProcessors.processBodyPoses(bodyPoseReq.results ?? [])
    let handPoses = VisionProcessors.processHandPoses(handPoseReq.results ?? [])
    let featurePrint = VisionProcessors.processFeaturePrint(featurePrintReq.results?.first)
    let attentionRegions = VisionProcessors.processSaliency(attentionReq.results ?? [])
    let objectnessRegions = VisionProcessors.processSaliency(objectnessReq.results ?? [])
    let animals = VisionProcessors.processAnimals(animalReq.results ?? [])
    let rectangles = VisionProcessors.processRectangles(rectangleReq.results ?? [])
    let horizon = VisionProcessors.processHorizon(horizonReq.results?.first)

    var aesthetics: [String: Any]? = nil
    if #available(iOS 18.0, macOS 15.0, *) {
      aesthetics = VisionModern.processAesthetics(aestheticsReq?.results)
    }

    var result: [String: Any] = [
      "faces": faces, "text": text, "labels": labels, "barcodes": barcodes,
      "bodyPoses": bodyPoses, "handPoses": handPoses, "rectangles": rectangles,
      "animals": animals,
      "featurePrint": featurePrint ?? [:] as [String: Any],
      "aesthetics": aesthetics ?? [:] as [String: Any],
      "saliency": ["attentionRegions": attentionRegions, "objectnessRegions": objectnessRegions],
      "horizon": horizon ?? [:] as [String: Any],
      "lensSmudge": [:] as [String: Any],
      "document": [:] as [String: Any],
      "imageWidth": Double(cgImage.width), "imageHeight": Double(cgImage.height),
    ]
    #if os(iOS)
    result["platform"] = "ios"
    #else
    result["platform"] = "macos"
    #endif
    if #available(iOS 26.0, macOS 26.0, *) {
      if let lensSmudge = await VisionModern.detectLensSmudge(cgImage: cgImage) {
        result["lensSmudge"] = lensSmudge
      }
      if let document = await VisionModern.recognizeDocument(cgImage: cgImage) {
        result["document"] = document
      }
    }
    return result
  }
}
