import CoreGraphics
import Foundation
import ImageIO

/// A fixture decoded upright with ImageIO (the EXIF orientation applied while
/// decoding, full resolution), and its size: the images the suites analyse.
/// The modules themselves take a caller's handle; each suite checks its own
/// handle path separately.
func fixtureImage(_ name: String) -> (CGImage, CGFloat, CGFloat)? {
  decodeUpright(path: FixturePaths.path(name))
}

/// Any image file decoded the same way.
func decodeUpright(path: String) -> (CGImage, CGFloat, CGFloat)? {
  let url = URL(fileURLWithPath: path)
  guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
  let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
  let image: CGImage?
  if (props?[kCGImagePropertyOrientation] as? UInt32 ?? 1) == 1 {
    image = CGImageSourceCreateImageAtIndex(source, 0, nil)
  } else {
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
    ]
    image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
  }
  return image.map { ($0, CGFloat($0.width), CGFloat($0.height)) }
}
