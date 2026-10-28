#if canImport(MLKitSegmentationSelfie) && !targetEnvironment(simulator)
import CoreVideo
import Foundation
import MLKitSegmentationCommon
import MLKitSegmentationSelfie
import MLKitVision

/// Selfie Segmentation (bundled): how likely each pixel is a person, as an
/// `MlKitMask` at the image's size, or the model's own (`rawSizeMask`) — as
/// Android's `SelfieSegmentationFeature.kt`.
enum SelfieSegmentationAnalyzer {
  private static let lock = NSLock()
  private static var segmenters: [Bool: Segmenter] = [:]

  private static func segmenter(rawSize: Bool) -> Segmenter {
    lock.lock()
    defer { lock.unlock() }
    if let found = segmenters[rawSize] { return found }
    let options = SelfieSegmenterOptions()
    options.segmenterMode = .singleImage
    options.shouldEnableRawSizeMask = rawSize
    let made = Segmenter.segmenter(options: options)
    segmenters[rawSize] = made
    return made
  }

  static func segment(_ image: VisionImage, rawSize: Bool) throws -> [String: Any] {
    let mask = try segmenter(rawSize: rawSize).results(in: image)
    return Masks.fromConfidences(mask.buffer)
  }
}

/// A segmentation model's per-pixel confidences (one Float32 channel) as
/// `MlKitMask`: Android's `Masks.kt`, byte for byte.
enum Masks {
  static func fromConfidences(_ buffer: CVPixelBuffer) -> [String: Any] {
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    let width = CVPixelBufferGetWidth(buffer)
    let height = CVPixelBufferGetHeight(buffer)
    let stride = CVPixelBufferGetBytesPerRow(buffer)
    var bytes = Data(count: width * height)
    if let base = CVPixelBufferGetBaseAddress(buffer) {
      bytes.withUnsafeMutableBytes { (out: UnsafeMutableRawBufferPointer) in
        for y in 0..<height {
          let row = (base + y * stride).assumingMemoryBound(to: Float32.self)
          for x in 0..<width {
            out[y * width + x] = UInt8((min(max(row[x], 0), 1) * 255).rounded())
          }
        }
      }
    }
    return ["width": width, "height": height, "data": bytes]
  }
}
#endif
