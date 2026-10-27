#if !targetEnvironment(simulator)
import Foundation
import MLKitCommon
import MLKitEntityExtraction

/// Entity Extraction over the recognized text (English model), as Android's
/// `EntityAnalyzer.kt` runs it. The base detector is bundled; the language
/// model downloads at first use, on Wi-Fi only. Until it is on the device the
/// result is nil — "unknown", which the app leaves unrecorded and retries —
/// never an empty list, which would read as "no entities".
enum EntityAnalyzer {
  private static let extractor = EntityExtractor.entityExtractor(
    options: EntityExtractorOptions(modelIdentifier: .english))
  private static let lock = NSLock()
  /// nil: no download yet or the last one failed; false: one in flight.
  private static var ready: Bool?

  /// Whether the model is on the device. A download just started is waited
  /// for briefly — an already-present model settles at once, so the first
  /// photo of a session is not left unknown — and otherwise only checked:
  /// off Wi-Fi it never settles, and this module's one queue is shared.
  private static func modelReady() -> Bool {
    lock.lock()
    let state = ready
    if state == nil { ready = false }
    lock.unlock()
    if let state { return state }
    let done = DispatchSemaphore(value: 0)
    extractor.downloadModelIfNeeded(
      with: ModelDownloadConditions(allowsCellularAccess: false, allowsBackgroundDownloading: true)
    ) { error in
      lock.lock()
      ready = error == nil ? true : nil
      lock.unlock()
      done.signal()
    }
    _ = done.wait(timeout: .now() + 2)
    lock.lock()
    defer { lock.unlock() }
    return ready == true
  }

  /// The entities in `text`; nil while the language model is not on the
  /// device yet. Text with nothing in it has no entities either way.
  static func extract(_ text: String) -> [[String: String]]? {
    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }
    if !modelReady() { return nil }
    // A box per call: a callback that lands after the wait gave up writes
    // into this call's box, never a later call's.
    final class Box { var value: [[String: String]]? }
    let box = Box()
    let done = DispatchSemaphore(value: 0)
    extractor.annotateText(text) { annotations, error in
      if error == nil {
        let source = text as NSString
        let found = (annotations ?? []).flatMap { annotation in
          annotation.entities.compactMap { entity -> [String: String]? in
            guard let type = MlKitNames.entityTypes[entity.entityType] else { return nil }
            return ["type": type, "value": source.substring(with: annotation.range)]
          }
        }
        lock.lock()
        box.value = found
        lock.unlock()
      }
      done.signal()
    }
    guard done.wait(timeout: .now() + 30) == .success else { return nil }
    lock.lock()
    defer { lock.unlock() }
    return box.value
  }
}
#endif
