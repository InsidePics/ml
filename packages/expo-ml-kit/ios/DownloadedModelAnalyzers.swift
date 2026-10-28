import Foundation
#if !targetEnvironment(simulator) && (canImport(MLKitTranslate) || canImport(MLKitDigitalInkRecognition))
import MLKitCommon
#endif
#if canImport(MLKitTranslate) && !targetEnvironment(simulator)
import MLKitTranslate
#endif
#if canImport(MLKitDigitalInkRecognition) && !targetEnvironment(simulator)
import MLKitDigitalInkRecognition
#endif

/// A model the call needs is not on the device: `ERR_ML_KIT_MODEL`.
struct ModelMissing: LocalizedError {
  let errorDescription: String?
}


#if canImport(MLKitTranslate) && !targetEnvironment(simulator)
/// On-device Translation, as Android's `TranslateFeature.kt`: models
/// download when the caller asks; a translation whose models are missing
/// fails with `ModelMissing` rather than starting a download nobody chose.
enum TranslateAnalyzer {
  static func language(_ tag: String) throws -> TranslateLanguage {
    let language = TranslateLanguage(rawValue: tag)
    guard TranslateLanguage.allLanguages().contains(language) else {
      throw ModelMissing(errorDescription: "ML Kit does not translate \(tag)")
    }
    return language
  }

  static func remote(_ tag: String) throws -> TranslateRemoteModel {
    TranslateRemoteModel.translateRemoteModel(language: try language(tag))
  }

  static func conditions(wifiOnly: Bool) -> ModelDownloadConditions {
    ModelDownloadConditions(allowsCellularAccess: !wifiOnly, allowsBackgroundDownloading: true)
  }

  private static let lock = NSLock()
  private static var translators: [String: Translator] = [:]

  static func translator(_ from: String, _ to: String) throws -> Translator {
    let options = TranslatorOptions(sourceLanguage: try language(from), targetLanguage: try language(to))
    lock.lock()
    defer { lock.unlock() }
    if let found = translators["\(from)>\(to)"] { return found }
    let made = Translator.translator(options: options)
    translators["\(from)>\(to)"] = made
    return made
  }

  /// Both ends' models on the device (English's always is).
  static func modelsReady(_ from: String, _ to: String) throws -> Bool {
    let downloaded = ModelManager.modelManager().downloadedTranslateModels.map(\.language)
    return try [from, to].map(language).allSatisfy { $0 == .english || downloaded.contains($0) }
  }

  static func translate(
    _ text: String, _ options: [String: Any], _ done: @escaping (Result<String, Error>) -> Void
  ) throws {
    guard let from = options["from"] as? String, let to = options["to"] as? String else {
      throw ModelMissing(errorDescription: "Translation needs `from` and `to`")
    }
    let translator = try translator(from, to)
    let run = {
      translator.translate(text) { result, error in
        if let result { done(.success(result)) } else { done(.failure(error ?? ModelMissing(errorDescription: "No translation"))) }
      }
    }
    if options["downloadIfNeeded"] as? Bool ?? false {
      let wifiOnly = options["wifiOnly"] as? Bool ?? true
      translator.downloadModelIfNeeded(with: conditions(wifiOnly: wifiOnly)) { error in
        if let error { done(.failure(error)) } else { run() }
      }
    } else if try modelsReady(from, to) {
      run()
    } else {
      done(.failure(ModelMissing(errorDescription: "Translation model for \(from) or \(to) is not downloaded")))
    }
  }
}
#endif

#if canImport(MLKitDigitalInkRecognition) && !targetEnvironment(simulator)
/// Digital Ink Recognition, as Android's `DigitalInkFeature.kt`.
enum DigitalInkAnalyzer {
  static func model(_ tag: String) throws -> DigitalInkRecognitionModel {
    guard let id = DigitalInkRecognitionModelIdentifier(forLanguageTag: tag) else {
      throw ModelMissing(errorDescription: "No ink model for \(tag)")
    }
    return DigitalInkRecognitionModel(modelIdentifier: id)
  }

  private static let lock = NSLock()
  private static var recognizers: [String: DigitalInkRecognizer] = [:]

  private static func recognizer(_ tag: String) throws -> DigitalInkRecognizer {
    let options = DigitalInkRecognizerOptions(model: try model(tag))
    lock.lock()
    defer { lock.unlock() }
    if let found = recognizers[tag] { return found }
    let made = DigitalInkRecognizer.digitalInkRecognizer(options: options)
    recognizers[tag] = made
    return made
  }

  /// `MlKitInkStroke`s as ML Kit's ink.
  static func ink(_ strokes: [[[String: Any]]]) -> Ink {
    Ink(strokes: strokes.map { points in
      Stroke(points: points.map { p in
        let x = Float((p["x"] as? NSNumber)?.doubleValue ?? 0)
        let y = Float((p["y"] as? NSNumber)?.doubleValue ?? 0)
        if let t = p["t"] as? NSNumber { return StrokePoint(x: x, y: y, t: t.intValue) }
        return StrokePoint(x: x, y: y)
      })
    })
  }

  static func recognize(
    _ strokes: [[[String: Any]]], _ options: [String: Any],
    _ done: @escaping (Result<[[String: Any]], Error>) -> Void
  ) throws {
    guard let tag = options["language"] as? String else {
      throw ModelMissing(errorDescription: "No ink model language")
    }
    guard ModelManager.modelManager().isModelDownloaded(try model(tag)) else {
      return done(.failure(ModelMissing(errorDescription: "Ink model \(tag) is not downloaded")))
    }
    var area: WritingArea?
    if let size = options["writingArea"] as? [String: Any],
      let w = size["width"] as? NSNumber, let h = size["height"] as? NSNumber
    {
      area = WritingArea(width: w.floatValue, height: h.floatValue)
    }
    let context = DigitalInkRecognitionContext(preContext: options["preContext"] as? String ?? "", writingArea: area)
    try recognizer(tag).recognize(ink: ink(strokes), context: context) { result, error in
      guard let result else { return done(.failure(error ?? ModelMissing(errorDescription: "No reading"))) }
      done(.success(result.candidates.map { ["text": $0.text, "score": $0.score?.doubleValue as Any? ?? NSNull()] }))
    }
  }
}
#endif
