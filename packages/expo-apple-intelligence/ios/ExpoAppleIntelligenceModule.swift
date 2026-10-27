import ExpoModulesCore
import UIKit
import Vision

/// Apple's on-device intelligence on an Expo image handle (`SharedRef<UIImage>`,
/// from expo-image-manipulator or any module that makes one): Vision, plus
/// Foundation Models, SpeechAnalyzer and Image Playground, which take text
/// or audio.
public class ExpoAppleIntelligenceModule: Module {
  public func definition() -> ModuleDefinition {
    Name("ExpoAppleIntelligence")

    // MARK: - Batch analysis

    AsyncFunction("analyzeImage") { (image: SharedRef<UIImage>, promise: Promise) in
      guard let cgImage = VisionHelpers.upright(image.ref) else {
        return promise.reject("ERR_IMAGE", "The image has no pixels to read")
      }
      Task.detached(priority: .userInitiated) {
        do {
          promise.resolve(try await VisionBatch.analyze(cgImage))
        } catch {
          promise.reject("ERR_ANALYSIS", error.localizedDescription)
        }
      }
    }

    // MARK: - Individual functions

    AsyncFunction("detectFaces") { (image: SharedRef<UIImage>, promise: Promise) in
      Self.runVision(image, promise: promise) { handler in
        try VisionProcessors.detectFaces(handler)
      }
    }

    AsyncFunction("recognizeText") { (image: SharedRef<UIImage>, promise: Promise) in
      Self.runVision(image, promise: promise) { handler in
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        try handler.perform([req])
        return VisionProcessors.processText(req.results ?? [])
      }
    }

    AsyncFunction("classifyImage") { (image: SharedRef<UIImage>, promise: Promise) in
      Self.runVision(image, promise: promise) { handler in
        let req = VNClassifyImageRequest()
        try handler.perform([req])
        return VisionProcessors.processClassification(req.results ?? [])
      }
    }

    AsyncFunction("detectBarcodes") { (image: SharedRef<UIImage>, promise: Promise) in
      Self.runVision(image, promise: promise) { handler in
        let req = VNDetectBarcodesRequest()
        try handler.perform([req])
        return VisionProcessors.processBarcodes(req.results ?? [])
      }
    }

    AsyncFunction("detectBodyPoses") { (image: SharedRef<UIImage>, promise: Promise) in
      Self.runVision(image, promise: promise) { handler in
        let req = VNDetectHumanBodyPoseRequest()
        try handler.perform([req])
        return VisionProcessors.processBodyPoses(req.results ?? [])
      }
    }

    AsyncFunction("detectHandPoses") { (image: SharedRef<UIImage>, promise: Promise) in
      Self.runVision(image, promise: promise) { handler in
        let req = VNDetectHumanHandPoseRequest()
        req.maximumHandCount = 4
        try handler.perform([req])
        return VisionProcessors.processHandPoses(req.results ?? [])
      }
    }

    AsyncFunction("generateFeaturePrint") { (image: SharedRef<UIImage>, promise: Promise) in
      Self.runVision(image, promise: promise) { handler in
        let req = VNGenerateImageFeaturePrintRequest()
        try handler.perform([req])
        return VisionProcessors.processFeaturePrint(req.results?.first) as Any
      }
    }

    AsyncFunction("calculateAesthetics") { (image: SharedRef<UIImage>, promise: Promise) in
      guard #available(iOS 18.0, macOS 15.0, *) else {
        promise.resolve(nil)
        return
      }
      Self.runVision(image, promise: promise) { handler in
        let req = VNCalculateImageAestheticsScoresRequest()
        try handler.perform([req])
        return VisionModern.processAesthetics(req.results) as Any
      }
    }

    AsyncFunction("detectSaliency") { (image: SharedRef<UIImage>, promise: Promise) in
      Self.runVision(image, promise: promise) { handler in
        let aReq = VNGenerateAttentionBasedSaliencyImageRequest()
        let oReq = VNGenerateObjectnessBasedSaliencyImageRequest()
        try handler.perform([aReq, oReq])
        return [
          "attentionRegions": VisionProcessors.processSaliency(aReq.results ?? []),
          "objectnessRegions": VisionProcessors.processSaliency(oReq.results ?? []),
        ]
      }
    }

    AsyncFunction("detectAnimals") { (image: SharedRef<UIImage>, promise: Promise) in
      Self.runVision(image, promise: promise) { handler in
        let req = VNRecognizeAnimalsRequest()
        try handler.perform([req])
        return VisionProcessors.processAnimals(req.results ?? [])
      }
    }

    AsyncFunction("detectRectangles") { (image: SharedRef<UIImage>, promise: Promise) in
      Self.runVision(image, promise: promise) { handler in
        let req = VNDetectRectanglesRequest()
        req.maximumObservations = 10
        try handler.perform([req])
        return VisionProcessors.processRectangles(req.results ?? [])
      }
    }

    AsyncFunction("detectHorizon") { (image: SharedRef<UIImage>, promise: Promise) in
      Self.runVision(image, promise: promise) { handler in
        let req = VNDetectHorizonRequest()
        try handler.perform([req])
        return VisionProcessors.processHorizon(req.results?.first) as Any
      }
    }

    AsyncFunction("detectLensSmudge") { (image: SharedRef<UIImage>, promise: Promise) in
      if #available(iOS 26.0, macOS 26.0, *) {
        guard let cgImage = VisionHelpers.upright(image.ref) else {
          return promise.reject("ERR_IMAGE", "The image has no pixels to read")
        }
        Task {
          let result = await VisionModern.detectLensSmudge(cgImage: cgImage)
          promise.resolve(result)
        }
      } else {
        promise.resolve(nil)
      }
    }

    AsyncFunction("recognizeDocument") { (image: SharedRef<UIImage>, promise: Promise) in
      if #available(iOS 26.0, macOS 26.0, *) {
        guard let cgImage = VisionHelpers.upright(image.ref) else {
          return promise.reject("ERR_IMAGE", "The image has no pixels to read")
        }
        Task {
          let result = await VisionModern.recognizeDocument(cgImage: cgImage)
          promise.resolve(result)
        }
      } else {
        promise.resolve(nil)
      }
    }

    // MARK: - Foundation Models (iOS 26+)

    Function("isFoundationModelAvailable") { () -> Bool in
      if #available(iOS 26.0, *) {
        return VisionModern.isFoundationModelAvailable()
      }
      return false
    }

    AsyncFunction("generateText") { (prompt: String, systemPrompt: String?, promise: Promise) in
      if #available(iOS 26.0, *) {
        Task {
          let result = await VisionModern.generateText(prompt: prompt, systemPrompt: systemPrompt)
          promise.resolve(result)
        }
      } else {
        promise.resolve(nil)
      }
    }

    // MARK: - Speech Transcription (iOS 26+)

    AsyncFunction("transcribeAudio") { (audioPath: String, locale: String?, promise: Promise) in
      if #available(iOS 26.0, *) {
        Task {
          let result = await VisionModern.transcribeAudio(audioPath: audioPath, locale: locale)
          promise.resolve(result)
        }
      } else {
        promise.resolve(nil)
      }
    }

    // MARK: - Image Generation (iOS 18.4+)

    AsyncFunction("generateImage") { (prompt: String, style: String?, promise: Promise) in
      if #available(iOS 18.4, *) {
        Task {
          let result = await VisionModern.generateImage(prompt: prompt, style: style)
          promise.resolve(result)
        }
      } else {
        promise.resolve(nil)
      }
    }
  }

  // MARK: - Helper to reduce boilerplate

  /// `work` over the handle's image, upright, off the JS thread.
  private static func runVision(
    _ image: SharedRef<UIImage>,
    promise: Promise,
    work: @escaping (VNImageRequestHandler) throws -> Any
  ) {
    guard let cgImage = VisionHelpers.upright(image.ref) else {
      return promise.reject("ERR_IMAGE", "The image has no pixels to read")
    }
    DispatchQueue.global(qos: .userInitiated).async {
      let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
      do {
        let result = try work(handler)
        promise.resolve(result)
      } catch {
        promise.reject("ERR_VISION", error.localizedDescription)
      }
    }
  }
}
