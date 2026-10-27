import ExpoModulesCore
import UIKit

/// Model inputs from any Expo image handle (`SharedRef<UIImage>`: one made by
/// expo-image-manipulator, expo-image, or this module's `warp`). Only small
/// results reach JS: a tensor, a number, a histogram, or a new handle.
public class ExpoImageMlToolsModule: Module {
  public func definition() -> ModuleDefinition {
    Name("ExpoImageMlTools")

    Function("size") { (image: SharedRef<UIImage>) -> [String: Int] in
      let ui = image.ref
      return [
        "width": Int((ui.size.width * ui.scale).rounded()),
        "height": Int((ui.size.height * ui.scale).rounded()),
      ]
    }

    AsyncFunction("toTensor") { (image: SharedRef<UIImage>, options: TensorOptions, promise: Promise) in
      guard let fit = Fit(rawValue: options.fit), let filter = Filter(rawValue: options.filter),
        let layout = Layout(rawValue: options.layout), options.width > 0, options.height > 0,
        options.mean.count == 3, options.std.count == 3, !options.std.contains(0)
      else {
        return promise.reject("ERR_ARGUMENT", "Invalid tensor options")
      }
      Self.withPixels(image, promise) { rgba in
        ImageMath.bytes(
          ImageMath.tensor(
            rgba, width: options.width, height: options.height, fit: fit, filter: filter,
            mean: options.mean, std: options.std, layout: layout))
      }
    }

    AsyncFunction("warp") { (image: SharedRef<UIImage>, matrix: [Double], width: Int, height: Int, promise: Promise) in
      guard matrix.count == 6, width > 0, height > 0 else {
        return promise.reject("ERR_ARGUMENT", "warp needs a 6-value matrix and a positive size")
      }
      Self.withPixels(image, promise) { rgba in
        let warped = ImageMath.warp(rgba, matrix, width: width, height: height)
        guard let out = PixelBacked.make(warped) else { throw WarpFailure() }
        return ImageHandle(out)
      }
    }

    AsyncFunction("sharpness") { (image: SharedRef<UIImage>, promise: Promise) in
      Self.withPixels(image, promise) { ImageMath.sharpness($0) }
    }

    AsyncFunction("histogram") { (image: SharedRef<UIImage>, bins: Int, promise: Promise) in
      guard bins > 0 else { return promise.reject("ERR_ARGUMENT", "histogram needs a bin") }
      Self.withPixels(image, promise) { ImageMath.bytes(ImageMath.histogram($0, bins: bins)) }
    }
  }

  private struct WarpFailure: Error {}

  /// `build` over the handle's pixels, off the JS thread, one call at a time:
  /// a converted photo is ~48 MB at 12 MP, and concurrent calls would each
  /// hold one.
  private static func withPixels(
    _ image: SharedRef<UIImage>, _ promise: Promise, _ build: @escaping (RGBAImage) throws -> Any
  ) {
    let ui = image.ref
    queue.async {
      autoreleasepool {
        guard let rgba = Pixels.rgba(ui) else {
          return promise.reject("ERR_PIXELS", "Could not read the image's pixels")
        }
        do {
          promise.resolve(try build(rgba))
        } catch {
          promise.reject("ERR_IMAGE_ML_TOOLS", "Could not build the result: \(error)")
        }
      }
    }
  }

  private static let queue = DispatchQueue(label: "expo.modules.imagemltools", qos: .userInitiated)
}

/// The handle `warp` returns: Expo's image type, so every module that takes
/// an image takes it.
final class ImageHandle: SharedRef<UIImage> {
  override var nativeRefType: String { "image" }

  /// Its pixels, so JS's garbage collector weighs the handle by them.
  override func getAdditionalMemoryPressure() -> Int {
    Int(ref.size.width * ref.scale * ref.size.height * ref.scale) * 4
  }
}

struct TensorOptions: Record {
  @Field var width: Int = 0
  @Field var height: Int = 0
  @Field var fit: String = "cover"
  @Field var filter: String = "bilinear"
  @Field var mean: [Double] = [0, 0, 0]
  @Field var std: [Double] = [1, 1, 1]
  @Field var layout: String = "nchw"
}
