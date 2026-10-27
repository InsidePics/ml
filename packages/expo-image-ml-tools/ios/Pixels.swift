import CoreGraphics
import Foundation

/// An image's pixels as `ImageMath` reads them: drawn upright into an 8-bit,
/// DeviceRGB, premultiplied-last buffer. A photo in another colour space or
/// depth (an iPhone's Display P3, a 10-bit HEIC) is converted here, so the
/// same photo gives the same model input whichever module decoded it.
enum Pixels {
  static func rgba(_ image: CGImage) -> RGBAImage? {
    draw(width: image.width, height: image.height) { ctx in
      ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
  }

  /// A buffer of `width`×`height` that `paint` fills; nil if CoreGraphics
  /// cannot make the context.
  static func draw(width: Int, height: Int, _ paint: (CGContext) -> Void) -> RGBAImage? {
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
      guard
        let ctx = CGContext(
          data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
          bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { return false }
      paint(ctx)
      return true
    }
    return drawn ? RGBAImage(width: width, height: height, pixels: pixels) : nil
  }

  /// `rgba` as a CGImage over the same bytes' layout, for a handle.
  static func cgImage(_ rgba: RGBAImage) -> CGImage? {
    guard let provider = CGDataProvider(data: Data(rgba.pixels) as CFData) else { return nil }
    return CGImage(
      width: rgba.width, height: rgba.height, bitsPerComponent: 8, bitsPerPixel: 32,
      bytesPerRow: rgba.width * 4, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
      provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
  }
}

#if canImport(UIKit)
import UIKit

extension Pixels {
  /// A UIImage's pixels upright. An image already `.up` is drawn as its
  /// CGImage; any other orientation is applied while drawing, so a handle
  /// whose loader left the EXIF orientation unapplied still reads upright.
  static func rgba(_ image: UIImage) -> RGBAImage? {
    if let ref = image as? PixelBacked { return ref.rgba }
    guard let cgImage = image.cgImage else { return nil }
    if image.imageOrientation == .up { return rgba(cgImage) }
    let width = Int((image.size.width * image.scale).rounded())
    let height = Int((image.size.height * image.scale).rounded())
    return draw(width: width, height: height) { ctx in
      // UIKit draws top-down; CoreGraphics' origin is bottom-left.
      ctx.translateBy(x: 0, y: CGFloat(height))
      ctx.scaleBy(x: 1, y: -1)
      UIGraphicsPushContext(ctx)
      image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
      UIGraphicsPopContext()
    }
  }
}

/// A UIImage that keeps the exact pixels it was made from (a warp's output),
/// so reading it back is those bytes, not a redraw.
final class PixelBacked: UIImage {
  private(set) var rgba = RGBAImage(width: 0, height: 0, pixels: [])

  static func make(_ rgba: RGBAImage) -> PixelBacked? {
    guard let cgImage = Pixels.cgImage(rgba) else { return nil }
    let image = PixelBacked(cgImage: cgImage, scale: 1, orientation: .up)
    image.rgba = rgba
    return image
  }
}
#endif
