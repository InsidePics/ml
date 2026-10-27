import CoreGraphics
import UIKit

/// A caller's image as ML Kit is handed it: upright (orientation `.up`),
/// pixel scale 1, its longer side capped at `maxSide`, so ML Kit's frames
/// come back in pixels of this image (at scale 2 or 3 they would be points).
/// A handle from expo-image-manipulator is already upright at scale 1 and
/// passes through untouched; any other orientation, scale or size is drawn
/// once. Results are normalized, so the cap changes no coordinate.
enum AnalysisImage {
  static let maxSide = 2048

  /// The size `size` is analysed at: itself, or scaled to `maxSide`.
  static func cappedSize(_ size: CGSize) -> CGSize {
    let longer = max(size.width, size.height)
    if longer <= CGFloat(maxSide) { return size }
    let scale = CGFloat(maxSide) / longer
    return CGSize(
      width: max(1, (size.width * scale).rounded()), height: max(1, (size.height * scale).rounded()))
  }

  /// Nil for an image without pixels to read (a CIImage-backed UIImage).
  static func prepare(_ image: UIImage) -> UIImage? {
    guard let cgImage = image.cgImage else { return nil }
    let pixels = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
    let target = cappedSize(pixels)
    if image.imageOrientation == .up && target == pixels {
      return image.scale == 1 ? image : UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = false
    let drawn = UIGraphicsImageRenderer(size: target, format: format).image { _ in
      // UIImage.draw applies the orientation.
      image.draw(in: CGRect(origin: .zero, size: target))
    }
    return drawn.cgImage.map { UIImage(cgImage: $0, scale: 1, orientation: .up) }
  }
}
