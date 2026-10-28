import ExpoModulesCore
import UIKit

/// Where the module's calls run. Analyses share one queue: a decoded photo
/// and a model's working memory at a time, and ML Kit's synchronous
/// `results(in:)` must not run on main. Work that waits on the network or
/// the user (a model download) never takes that queue: it settles its
/// promise from ML Kit's own completion handler.
enum MlKitCalls {
  private struct UnreadableImage: Error {}

  private static let queue = DispatchQueue(label: "expo.modules.mlkit", qos: .utility)

  /// `onQueue` over the handle's image, prepared for ML Kit (`AnalysisImage`).
  static func withImage(
    _ image: SharedRef<UIImage>, _ promise: Promise, _ body: @escaping (UIImage) throws -> Any
  ) {
    let source = image.ref
    onQueue(promise) {
      guard let prepared = AnalysisImage.prepare(source) else { throw UnreadableImage() }
      return try body(prepared)
    }
  }

  /// Resolve with `body`'s result on the analysis queue.
  static func onQueue(_ promise: Promise, _ body: @escaping () throws -> Any) {
    queue.async {
      autoreleasepool {
        do {
          promise.resolve(try body())
        } catch is UnreadableImage {
          promise.reject("ERR_IMAGE", "The image has no pixels to read")
        } catch {
          promise.reject("ERR_ML_KIT", error.localizedDescription)
        }
      }
    }
  }
}
