#if !targetEnvironment(simulator) && (canImport(MLKitTranslate) || canImport(MLKitDigitalInkRecognition))
import ExpoModulesCore
import Foundation
import MLKitCommon
#if canImport(MLKitTranslate)
import MLKitTranslate
#endif
#if canImport(MLKitDigitalInkRecognition)
import MLKitDigitalInkRecognition
#endif

/// The module's functions for the features whose models download:
/// Translation and Digital Ink. Each settles its promise from ML Kit's
/// completion handler, never holding the analysis queue.
extension ExpoMlKitModule {
  /// Resolve with the result, or reject: a missing model as
  /// `ERR_ML_KIT_MODEL`, anything else as `ERR_ML_KIT`.
  static func answer<T>(_ promise: Promise) -> (Result<T, Error>) -> Void {
    { result in
      switch result {
      case .success(let value): promise.resolve(value)
      case .failure(let error as ModelMissing): promise.reject("ERR_ML_KIT_MODEL", error.localizedDescription)
      case .failure(let error): promise.reject("ERR_ML_KIT", error.localizedDescription)
      }
    }
  }

  /// `start`, rejecting what it throws before it hands over.
  static func starting(_ promise: Promise, _ start: () throws -> Void) {
    do { try start() } catch { answer(promise)(Result<Void, Error>.failure(error)) }
  }

  static func modelDone(_ promise: Promise) -> (Error?) -> Void {
    { error in
      if let error { promise.reject("ERR_ML_KIT", error.localizedDescription) } else { promise.resolve(nil) }
    }
  }

  #if canImport(MLKitTranslate)
  static func translate() -> AnyDefinition {
    AsyncFunction("translate") { (text: String, options: [String: Any], promise: Promise) in
      starting(promise) { try TranslateAnalyzer.translate(text, options, answer(promise)) }
    }
  }

  static func downloadTranslationModel() -> AnyDefinition {
    AsyncFunction("downloadTranslationModel") { (tag: String, wifiOnly: Bool, promise: Promise) in
      starting(promise) {
        let model = try TranslateAnalyzer.remote(tag)
        let progress = ModelManager.modelManager().download(
          model, conditions: TranslateAnalyzer.conditions(wifiOnly: wifiOnly))
        DownloadWatch.until(model, progress, modelDone(promise))
      }
    }
  }

  static func deleteTranslationModel() -> AnyDefinition {
    AsyncFunction("deleteTranslationModel") { (tag: String, promise: Promise) in
      starting(promise) {
        ModelManager.modelManager().deleteDownloadedModel(try TranslateAnalyzer.remote(tag), completion: modelDone(promise))
      }
    }
  }

  static func downloadedTranslationModels() -> AnyDefinition {
    AsyncFunction("downloadedTranslationModels") { () -> [String] in
      ModelManager.modelManager().downloadedTranslateModels.map(\.language.rawValue)
    }
  }
  #endif

  #if canImport(MLKitDigitalInkRecognition)
  static func recognizeInk() -> AnyDefinition {
    AsyncFunction("recognizeInk") { (strokes: [[[String: Any]]], options: [String: Any], promise: Promise) in
      starting(promise) { try DigitalInkAnalyzer.recognize(strokes, options, answer(promise)) }
    }
  }

  static func downloadInkModel() -> AnyDefinition {
    AsyncFunction("downloadInkModel") { (tag: String, wifiOnly: Bool, promise: Promise) in
      starting(promise) {
        let model = try DigitalInkAnalyzer.model(tag)
        let conditions = ModelDownloadConditions(allowsCellularAccess: !wifiOnly, allowsBackgroundDownloading: true)
        let progress = ModelManager.modelManager().download(model, conditions: conditions)
        DownloadWatch.until(model, progress, modelDone(promise))
      }
    }
  }

  static func deleteInkModel() -> AnyDefinition {
    AsyncFunction("deleteInkModel") { (tag: String, promise: Promise) in
      starting(promise) {
        ModelManager.modelManager().deleteDownloadedModel(try DigitalInkAnalyzer.model(tag), completion: modelDone(promise))
      }
    }
  }

  static func isInkModelDownloaded() -> AnyDefinition {
    AsyncFunction("isInkModelDownloaded") { (tag: String) throws -> Bool in
      ModelManager.modelManager().isModelDownloaded(try DigitalInkAnalyzer.model(tag))
    }
  }
  #endif
}

/// ML Kit iOS reports a `ModelManager.download` only through notifications
/// (`mlkitModelDownloadDidSucceed` / `DidFail`) naming the model: this waits
/// for the one about `model`, then calls `done` once.
enum DownloadWatch {
  static func until(_ model: RemoteModel, _ progress: Progress, _ done: @escaping (Error?) -> Void) {
    if ModelManager.modelManager().isModelDownloaded(model) { return done(nil) }
    let center = NotificationCenter.default
    var tokens: [NSObjectProtocol] = []
    let lock = NSLock()
    var finished = false
    func finish(_ error: Error?) {
      lock.lock()
      let first = !finished
      finished = true
      lock.unlock()
      guard first else { return }
      tokens.forEach(center.removeObserver)
      done(error)
    }
    let about = { (note: Notification) in
      (note.userInfo?[ModelDownloadUserInfoKey.remoteModel.rawValue] as? RemoteModel)?.name == model.name
    }
    tokens.append(center.addObserver(forName: .mlkitModelDownloadDidSucceed, object: nil, queue: nil) {
      if about($0) { finish(nil) }
    })
    tokens.append(center.addObserver(forName: .mlkitModelDownloadDidFail, object: nil, queue: nil) { note in
      guard about(note) else { return }
      finish(note.userInfo?[ModelDownloadUserInfoKey.error.rawValue] as? Error
        ?? ModelMissing(errorDescription: "The model download failed"))
    })
  }
}
#endif
