#if !targetEnvironment(simulator)
import ExpoModulesCore
import Foundation
#if canImport(MLKitEntityExtraction)
import MLKitCommon
import MLKitEntityExtraction
#endif

/// The module's text functions (`ModuleFunctions.swift` has the image ones).
extension ExpoMlKitModule {
  #if canImport(MLKitEntityExtraction)
  // Text alone: analyzeImage's (the confident lines TS chose) or a caller's.
  // Nil (unknown) while the language model is not on the device yet.
  static func extractEntities() -> AnyDefinition {
    AsyncFunction("extractEntities") { (text: String, options: [String: Any]?, promise: Promise) in
      MlKitCalls.onQueue(promise) { try EntityAnalyzer.extract(text, options: options ?? [:]) as Any? ?? NSNull() }
    }
  }

  static func downloadEntityModel() -> AnyDefinition {
    AsyncFunction("downloadEntityModel") { (language: String, wifiOnly: Bool, promise: Promise) in
      do {
        try EntityAnalyzer.download(language, wifiOnly: wifiOnly) { error in
          if let error { promise.reject("ERR_ML_KIT_DOWNLOAD", error.localizedDescription) } else { promise.resolve(nil) }
        }
      } catch {
        promise.reject("ERR_ML_KIT", error.localizedDescription)
      }
    }
  }

  static func deleteEntityModel() -> AnyDefinition {
    AsyncFunction("deleteEntityModel") { (language: String, promise: Promise) in
      do {
        let model = EntityExtractorRemoteModel.entityExtractorRemoteModel(identifier: try EntityAnalyzer.model(language))
        ModelManager.modelManager().deleteDownloadedModel(model) { error in
          if let error { promise.reject("ERR_ML_KIT", error.localizedDescription) } else { promise.resolve(nil) }
        }
      } catch {
        promise.reject("ERR_ML_KIT", error.localizedDescription)
      }
    }
  }

  static func downloadedEntityModels() -> AnyDefinition {
    AsyncFunction("downloadedEntityModels") { () -> [String] in
      ModelManager.modelManager().downloadedEntityExtractionModels.map { $0.modelIdentifier.toLanguageTag() }
    }
  }
  #endif

  #if canImport(MLKitLanguageID)
  static func identifyLanguage() -> AnyDefinition {
    AsyncFunction("identifyLanguage") { (text: String, options: [String: Any]?, promise: Promise) in
      let threshold = (options?["confidenceThreshold"] as? NSNumber)?.floatValue
      MlKitCalls.onQueue(promise) { try LanguageIdAnalyzer.identify(text, threshold: threshold) }
    }
  }

  static func identifyPossibleLanguages() -> AnyDefinition {
    AsyncFunction("identifyPossibleLanguages") { (text: String, options: [String: Any]?, promise: Promise) in
      let threshold = (options?["confidenceThreshold"] as? NSNumber)?.floatValue
      MlKitCalls.onQueue(promise) { try LanguageIdAnalyzer.possible(text, threshold: threshold) }
    }
  }
  #endif

  #if canImport(MLKitSmartReply)
  static func suggestReplies() -> AnyDefinition {
    AsyncFunction("suggestReplies") { (messages: [[String: Any]], promise: Promise) in
      MlKitCalls.onQueue(promise) { try SmartReplyAnalyzer.suggest(messages) }
    }
  }
  #endif
}
#endif
