import Foundation

/// Decoded RGBA pixels, row-major, `width * height * 4` bytes: 8 bits per
/// channel, alpha premultiplied last.
struct RGBAImage {
  let width: Int
  let height: Int
  let pixels: [UInt8]
}

/// How `tensor` fits the image to the output: `cover` scales it to fill and
/// center-crops the overflow; `stretch` scales each axis on its own.
enum Fit: String { case cover, stretch }
enum Filter: String { case nearest, bilinear }
enum Layout: String { case nchw, nhwc }

/// Model inputs from RGBA. Pure arithmetic in a fixed order (Double where it
/// computes, Float where it stores), so Android's `ImageMath.kt` produces the
/// same bits from the same pixels; the shared `fixtures/expected` hashes pin
/// both. Change an operation here and there, together, on purpose.
enum ImageMath {

  // MARK: - Tensor

  /// The image resampled to `width`×`height` and normalized per channel as
  /// `(v / 255 - mean) / std`, RGB, alpha dropped: `[1, 3, h, w]` planar
  /// (`nchw`) or `[1, h, w, 3]` interleaved (`nhwc`).
  static func tensor(
    _ image: RGBAImage, width: Int, height: Int, fit: Fit, filter: Filter,
    mean: [Double], std: [Double], layout: Layout
  ) -> [Float] {
    let outW = Double(width)
    let outH = Double(height)
    var scaleX = outW / Double(image.width)
    var scaleY = outH / Double(image.height)
    var cropX = 0.0
    var cropY = 0.0
    if fit == .cover {
      let scale = max(scaleX, scaleY)
      scaleX = scale
      scaleY = scale
      cropX = ((jsRound(Double(image.width) * scale) - outW) / 2).rounded(.down)
      cropY = ((jsRound(Double(image.height) * scale) - outH) / 2).rounded(.down)
    }
    let plane = width * height
    var out = [Float](repeating: 0, count: 3 * plane)
    var rgb = [Double](repeating: 0, count: 3)
    image.pixels.withUnsafeBufferPointer { px in
      for y in 0..<height {
        for x in 0..<width {
          if filter == .nearest {
            let sx = nearestIndex(Double(x) + cropX, scale: scaleX, limit: image.width)
            let sy = nearestIndex(Double(y) + cropY, scale: scaleY, limit: image.height)
            let i = (sy * image.width + sx) * 4
            for ch in 0..<3 { rgb[ch] = Double(px[i + ch]) }
          } else {
            let sx = (Double(x) + cropX + 0.5) / scaleX - 0.5
            let sy = (Double(y) + cropY + 0.5) / scaleY - 0.5
            bilinear(px, image, sx, sy, &rgb)
          }
          for ch in 0..<3 {
            let value = Float((rgb[ch] / 255 - mean[ch]) / std[ch])
            let index = layout == .nchw ? ch * plane + y * width + x : (y * width + x) * 3 + ch
            out[index] = value
          }
        }
      }
    }
    return out
  }

  /// `min(floor(p / scale), limit - 1)`, never negative.
  private static func nearestIndex(_ p: Double, scale: Double, limit: Int) -> Int {
    max(0, min(Int((p / scale).rounded(.down)), limit - 1))
  }

  /// RGB at (`x`, `y`) by bilinear interpolation, edges clamped.
  private static func bilinear(
    _ px: UnsafeBufferPointer<UInt8>, _ image: RGBAImage, _ x: Double, _ y: Double,
    _ rgb: inout [Double]
  ) {
    let cx = min(max(x, 0), Double(image.width - 1))
    let cy = min(max(y, 0), Double(image.height - 1))
    let x0 = Int(cx.rounded(.down))
    let y0 = Int(cy.rounded(.down))
    let x1 = min(x0 + 1, image.width - 1)
    let y1 = min(y0 + 1, image.height - 1)
    let fx = cx - Double(x0)
    let fy = cy - Double(y0)
    for ch in 0..<3 {
      let v00 = Double(px[(y0 * image.width + x0) * 4 + ch])
      let v01 = Double(px[(y0 * image.width + x1) * 4 + ch])
      let v10 = Double(px[(y1 * image.width + x0) * 4 + ch])
      let v11 = Double(px[(y1 * image.width + x1) * 4 + ch])
      let top: Double = v00 * (1 - fx) + v01 * fx
      let bottom: Double = v10 * (1 - fx) + v11 * fx
      rgb[ch] = top * (1 - fy) + bottom * fy
    }
  }

  // MARK: - Warp

  /// Bilinear backward warp through the affine `m` = `[a, b, tx, c, d, ty]`
  /// (output = m · source); a sample whose 2×2 neighbourhood leaves the
  /// image stays transparent black.
  static func warp(_ image: RGBAImage, _ m: [Double], width outW: Int, height outH: Int)
    -> RGBAImage
  {
    var out = [UInt8](repeating: 0, count: outW * outH * 4)
    let (a, b, tx, c, d, ty) = (m[0], m[1], m[2], m[3], m[4], m[5])
    let det = a * d - b * c
    if abs(det) < 1e-10 { return RGBAImage(width: outW, height: outH, pixels: out) }
    let ia = d / det
    let ib = -b / det
    let ic = -c / det
    let id = a / det
    let srcW = Double(image.width)
    let srcH = Double(image.height)
    image.pixels.withUnsafeBufferPointer { px in
      for oy in 0..<outH {
        for ox in 0..<outW {
          let dx = Double(ox) - tx
          let dy = Double(oy) - ty
          let srcX = ia * dx + ib * dy
          let srcY = ic * dx + id * dy
          let x0 = srcX.rounded(.down)
          let y0 = srcY.rounded(.down)
          // Bounds in Double first: a NaN or huge coordinate must not reach Int().
          guard x0 >= 0, x0 + 1 < srcW, y0 >= 0, y0 + 1 < srcH else { continue }
          let fx = srcX - x0
          let fy = srcY - y0
          let row0 = Int(y0) * image.width
          let row1 = row0 + image.width
          let col0 = Int(x0)
          let outIdx = (oy * outW + ox) * 4
          for ch in 0..<4 {
            let w00: Double = Double(px[(row0 + col0) * 4 + ch]) * (1 - fx) * (1 - fy)
            let w01: Double = Double(px[(row0 + col0 + 1) * 4 + ch]) * fx * (1 - fy)
            let w10: Double = Double(px[(row1 + col0) * 4 + ch]) * (1 - fx) * fy
            let w11: Double = Double(px[(row1 + col0 + 1) * 4 + ch]) * fx * fy
            let value: Double = w00 + w01 + w10 + w11
            out[outIdx + ch] = UInt8(jsRound(value))
          }
        }
      }
    }
    return RGBAImage(width: outW, height: outH, pixels: out)
  }

  // MARK: - Statistics

  /// Variance of the 4-neighbour Laplacian over Rec.601 grey (stored as
  /// Float). Higher is sharper; 0 below 3×3.
  static func sharpness(_ image: RGBAImage) -> Double {
    let width = image.width
    let height = image.height
    if width < 3 || height < 3 { return 0 }
    let n = width * height
    var gray = [Float](repeating: 0, count: n)
    image.pixels.withUnsafeBufferPointer { px in
      for i in 0..<n { gray[i] = Float(luma(px[i * 4], px[i * 4 + 1], px[i * 4 + 2])) }
    }
    var sum = 0.0
    var sumSq = 0.0
    var count = 0
    gray.withUnsafeBufferPointer { g in
      for y in 1..<(height - 1) {
        for x in 1..<(width - 1) {
          let up = Double(g[(y - 1) * width + x])
          let down = Double(g[(y + 1) * width + x])
          let left = Double(g[y * width + (x - 1)])
          let right = Double(g[y * width + (x + 1)])
          let center: Double = 4 * Double(g[y * width + x])
          let lap: Double = up + down + left + right - center
          sum += lap
          sumSq += lap * lap
          count += 1
        }
      }
    }
    let mean = sum / Double(count)
    return sumSq / Double(count) - mean * mean
  }

  /// Rec.601 luminance histogram in `bins` bins, normalized to sum to 1.
  static func histogram(_ image: RGBAImage, bins: Int) -> [Float] {
    var hist = [Float](repeating: 0, count: bins)
    let total = image.width * image.height
    image.pixels.withUnsafeBufferPointer { px in
      for i in 0..<total {
        let lum = luma(px[i * 4], px[i * 4 + 1], px[i * 4 + 2])
        hist[min(Int((lum / 256 * Double(bins)).rounded(.down)), bins - 1)] += 1
      }
    }
    for i in 0..<bins { hist[i] = Float(Double(hist[i]) / Double(total)) }
    return hist
  }

  /// Floats as their little-endian bytes, which JS views as a Float32Array.
  static func bytes(_ floats: [Float]) -> Data { floats.withUnsafeBytes { Data($0) } }

  /// `0.299 R + 0.587 G + 0.114 B`, summed left to right.
  private static func luma(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> Double {
    let red: Double = 0.299 * Double(r)
    let green: Double = 0.587 * Double(g)
    let blue: Double = 0.114 * Double(b)
    return red + green + blue
  }

  /// Nearest, ties away from zero (JS `Math.round` for non-negative values).
  private static func jsRound(_ value: Double) -> Double {
    value.rounded(.toNearestOrAwayFromZero)
  }
}
