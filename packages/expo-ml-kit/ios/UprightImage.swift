import CoreGraphics
import Foundation
import ImageIO
import UIKit

/// A photo decoded UPRIGHT (EXIF orientation applied) for ML Kit, its longer
/// side capped at `maxSide` — the frame Apple Vision and `expo-model-inputs`
/// see, and the cap Android's `UprightBitmap` uses. Results are normalized,
/// so the cap changes no coordinate, only the work.
///
/// The UIImage is made at scale 1 and orientation `.up`, so ML Kit's frames
/// come back in PIXELS of this image; at scale 2 or 3 they would be points.
enum UprightImage {
  static let maxSide = 2048

  static func decode(_ path: String) -> UIImage? {
    let url: URL
    if path.hasPrefix("file://") {
      guard let parsed = URL(string: path) else { return nil }
      url = parsed
    } else {
      url = URL(fileURLWithPath: path)
    }
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    // The thumbnail API is ImageIO's way to apply the orientation and scale
    // in one decode.
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxSide,
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else { return nil }
    return UIImage(cgImage: image, scale: 1, orientation: .up)
  }
}
