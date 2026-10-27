import ExpoModulesCore
import UIKit

/// Google ML Kit image analysis on iOS — the same `analyzeImage`,
/// `recognizeText`, `extractEntities` and `detectFaces` Android's
/// `ExpoMlKitModule.kt` serves, in one shape, so a caller handles both
/// platforms alike. On iOS, live barcodes are Apple Vision's job
/// (`expo-apple-intelligence`), so this module has no `detectBarcodes` here.
///
/// Google ships no Apple Silicon simulator build of ML Kit: on a simulator
/// the ML Kit code is compiled out (and unlinked by the config plugin), and
/// `isAvailable` is false, so a caller can plan around it.
public class ExpoMlKitModule: Module {
  #if targetEnvironment(simulator)
  static let isAvailable = false
  #else
  static let isAvailable = true
  #endif

  public func definition() -> ModuleDefinition {
    Name("ExpoMlKit")

    Constant("isAvailable") { Self.isAvailable }

    AsyncFunction("analyzeImage") { (path: String, models: [String], promise: Promise) in
      Self.withImage(path, promise) { try MlKitAnalyzer.analyze($0, models: Set(models)) }
    }

    AsyncFunction("recognizeText") { (path: String, scripts: [String], promise: Promise) in
      Self.withImage(path, promise) { try MlKitAnalyzer.recognize($0, scripts: scripts) }
    }

    // No image: the text TS chose, its confident lines only. Nil (unknown)
    // while the language model is not on the device yet.
    AsyncFunction("extractEntities") { (text: String, promise: Promise) in
      Self.run(promise) { EntityAnalyzer.extract(text) as Any? ?? NSNull() }
    }

    // Vision's `FaceObservation` shape, as Android's `FaceMapping.kt` writes.
    AsyncFunction("detectFaces") { (path: String, promise: Promise) in
      Self.withImage(path, promise) { try FaceAnalyzer.detect($0) }
    }
  }

  private struct DecodeFailure: Error { let path: String }

  /// `run` over `path` decoded upright.
  private static func withImage(
    _ path: String, _ promise: Promise, _ body: @escaping (UIImage) throws -> Any
  ) {
    run(promise) {
      guard let image = UprightImage.decode(path) else { throw DecodeFailure(path: path) }
      return try body(image)
    }
  }

  /// Resolve with `body`'s result on this module's queue: one call at a time
  /// (a decoded photo and the models' working memory each), and ML Kit's
  /// synchronous `results(in:)` must not run on main. On a simulator every
  /// call is refused: there is no ML Kit.
  private static func run(_ promise: Promise, _ body: @escaping () throws -> Any) {
    queue.async {
      #if targetEnvironment(simulator)
      promise.reject("ERR_ML_KIT_UNAVAILABLE", "ML Kit has no iOS simulator build")
      #else
      autoreleasepool {
        do {
          promise.resolve(try body())
        } catch let failure as DecodeFailure {
          promise.reject("ERR_DECODE", "Could not decode image at \(failure.path)")
        } catch {
          promise.reject("ERR_ML_KIT", error.localizedDescription)
        }
      }
      #endif
    }
  }

  private static let queue = DispatchQueue(label: "expo.modules.mlkit", qos: .utility)
}

#if targetEnvironment(simulator)
/// The analyzers' shape where ML Kit is compiled out, so the functions above
/// compile unchanged. Never called: `run` refuses first.
private enum MlKitAnalyzer {
  static func analyze(_: UIImage, models _: Set<String>) throws -> Any { NSNull() }
  static func recognize(_: UIImage, scripts _: [String]) throws -> Any { NSNull() }
}

private enum EntityAnalyzer {
  static func extract(_: String) -> [[String: String]]? { nil }
}

private enum FaceAnalyzer {
  static func detect(_: UIImage) throws -> Any { NSNull() }
}
#endif
