import Foundation
#if canImport(MLKitLanguageID) && !targetEnvironment(simulator)
import MLKitLanguageID
#endif
#if canImport(MLKitSmartReply) && !targetEnvironment(simulator)
import MLKitSmartReply
#endif

/// ML Kit's callback APIs, answered synchronously on the module's analysis
/// queue: the models are bundled, so the answer comes at once, and ML Kit
/// delivers it on the main queue, which this wait never holds.
enum Callbacks {
  /// A call's answer, written by its callback.
  private final class Box<T> {
    var value: T?
    var error: Error?
  }

  static func wait<T>(_ start: (@escaping (T?, Error?) -> Void) -> Void) throws -> T {
    let box = Box<T>()
    let done = DispatchSemaphore(value: 0)
    start { value, error in
      box.value = value
      box.error = error
      done.signal()
    }
    guard done.wait(timeout: .now() + 30) == .success else {
      throw NSError(domain: "ExpoMlKit", code: 4, userInfo: [NSLocalizedDescriptionKey: "ML Kit did not answer"])
    }
    if let error = box.error { throw error }
    guard let value = box.value else {
      throw NSError(domain: "ExpoMlKit", code: 4, userInfo: [NSLocalizedDescriptionKey: "ML Kit gave no result"])
    }
    return value
  }
}

#if canImport(MLKitLanguageID) && !targetEnvironment(simulator)
/// Language Identification (bundled), as Android's `LanguageIdFeature.kt`.
enum LanguageIdAnalyzer {
  private static func identifier(_ threshold: Float?) -> LanguageIdentification {
    guard let threshold else { return LanguageIdentification.languageIdentification() }
    return LanguageIdentification.languageIdentification(
      options: LanguageIdentificationOptions(confidenceThreshold: threshold))
  }

  static func identify(_ text: String, threshold: Float?) throws -> String {
    try Callbacks.wait { identifier(threshold).identifyLanguage(for: text, completion: $0) }
  }

  static func possible(_ text: String, threshold: Float?) throws -> [[String: Any]] {
    let found: [IdentifiedLanguage] = try Callbacks.wait {
      identifier(threshold).identifyPossibleLanguages(for: text, completion: $0)
    }
    return found.map { ["language": $0.languageTag, "confidence": Double($0.confidence)] }
  }
}
#endif

#if canImport(MLKitSmartReply) && !targetEnvironment(simulator)
/// Smart Reply (bundled, English), as Android's `SmartReplyFeature.kt`.
enum SmartReplyAnalyzer {
  private static func message(_ raw: [String: Any]) throws -> TextMessage {
    guard let text = raw["text"] as? String, let time = raw["timestamp"] as? NSNumber else {
      throw NSError(domain: "ExpoMlKit", code: 5, userInfo: [
        NSLocalizedDescriptionKey: "A message needs its text and timestamp",
      ])
    }
    let user = raw["userId"] as? String
    return TextMessage(
      text: text, timestamp: time.doubleValue / 1000, userID: user ?? "local", isLocalUser: user == nil)
  }

  static func suggest(_ messages: [[String: Any]]) throws -> [String: Any] {
    let conversation = try messages.map(message)
    let result: SmartReplySuggestionResult = try Callbacks.wait {
      SmartReply.smartReply().suggestReplies(for: conversation, completion: $0)
    }
    let status: String
    switch result.status {
    case .success: status = "success"
    case .notSupportedLanguage: status = "notSupportedLanguage"
    default: status = "noReply"
    }
    return ["status": status, "suggestions": result.suggestions.map(\.text)]
  }
}
#endif
