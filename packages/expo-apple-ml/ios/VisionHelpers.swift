import CoreGraphics
import Vision

/// Shared helpers: a handle's image upright, and coordinate serialization.
enum VisionHelpers {
  /// Serialize CGRect as-is (normalized 0-1, bottom-left origin).
  static func rawRect(_ rect: CGRect) -> [String: Double] {
    ["x": Double(rect.origin.x), "y": Double(rect.origin.y),
     "width": Double(rect.size.width), "height": Double(rect.size.height)]
  }

  /// Serialize CGPoint as-is (normalized 0-1, bottom-left origin).
  static func rawPoint(_ point: CGPoint) -> [String: Double] {
    ["x": Double(point.x), "y": Double(point.y)]
  }
}

#if canImport(UIKit)
import UIKit

extension VisionHelpers {
  /// A handle's image as Vision analyses it: upright, in pixels. A handle
  /// from expo-image-manipulator is already upright and is used as it is;
  /// any other orientation is applied by one draw, so every box and landmark
  /// is in the frame a viewer shows. Nil for an image without pixels to read
  /// (a CIImage-backed UIImage).
  static func upright(_ image: UIImage) -> CGImage? {
    guard let cgImage = image.cgImage else { return nil }
    if image.imageOrientation == .up { return cgImage }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = false
    let size = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
    return UIGraphicsImageRenderer(size: size, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: size))
    }.cgImage
  }
}
#endif
