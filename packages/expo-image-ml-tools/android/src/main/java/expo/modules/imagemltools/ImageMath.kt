package expo.modules.imagemltools

import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Decoded RGBA pixels, row-major, `width * height * 4` bytes: 8 bits per
 *  channel, alpha premultiplied last. */
class RgbaImage(val width: Int, val height: Int, val pixels: ByteArray)

enum class Fit { COVER, STRETCH }
enum class Filter { NEAREST, BILINEAR }
enum class Layout { NCHW, NHWC }

/**
 * Model inputs from RGBA — `ios/ImageMath.swift`, operation for operation:
 * Double where it computes, Float where it stores, the same order of
 * additions, rounding half away from zero. The same pixels give the same
 * bits on both platforms (`ImageMathTests`, against the shared
 * `fixtures/expected` hashes). Pure Kotlin, so the JVM tests run it as shipped.
 */
object ImageMath {
  private fun u8(b: Byte): Double = (b.toInt() and 0xFF).toDouble()

  /** Nearest, ties away from zero (JS `Math.round` for non-negative values). */
  private fun jsRound(v: Double): Double = Math.round(v).toDouble()

  /** `(v / 255 - mean) / std` per RGB channel, resampled to `width`×`height`:
   *  `[1, 3, h, w]` planar (NCHW) or `[1, h, w, 3]` interleaved (NHWC). */
  fun tensor(
    image: RgbaImage, width: Int, height: Int, fit: Fit, filter: Filter,
    mean: DoubleArray, std: DoubleArray, layout: Layout,
  ): FloatArray {
    val outW = width.toDouble()
    val outH = height.toDouble()
    var scaleX = outW / image.width
    var scaleY = outH / image.height
    var cropX = 0.0
    var cropY = 0.0
    if (fit == Fit.COVER) {
      val scale = maxOf(scaleX, scaleY)
      scaleX = scale
      scaleY = scale
      cropX = Math.floor((jsRound(image.width * scale) - outW) / 2)
      cropY = Math.floor((jsRound(image.height * scale) - outH) / 2)
    }
    val plane = width * height
    val out = FloatArray(3 * plane)
    val rgb = DoubleArray(3)
    val px = image.pixels
    for (y in 0 until height) {
      for (x in 0 until width) {
        if (filter == Filter.NEAREST) {
          val sx = nearestIndex(x + cropX, scaleX, image.width)
          val sy = nearestIndex(y + cropY, scaleY, image.height)
          val i = (sy * image.width + sx) * 4
          for (ch in 0 until 3) rgb[ch] = u8(px[i + ch])
        } else {
          bilinear(image, (x + cropX + 0.5) / scaleX - 0.5, (y + cropY + 0.5) / scaleY - 0.5, rgb)
        }
        for (ch in 0 until 3) {
          val value = ((rgb[ch] / 255 - mean[ch]) / std[ch]).toFloat()
          out[if (layout == Layout.NCHW) ch * plane + y * width + x else (y * width + x) * 3 + ch] = value
        }
      }
    }
    return out
  }

  private fun nearestIndex(p: Double, scale: Double, limit: Int): Int =
    maxOf(0, minOf(Math.floor(p / scale).toInt(), limit - 1))

  private fun bilinear(image: RgbaImage, x: Double, y: Double, rgb: DoubleArray) {
    val cx = minOf(maxOf(x, 0.0), (image.width - 1).toDouble())
    val cy = minOf(maxOf(y, 0.0), (image.height - 1).toDouble())
    val x0 = Math.floor(cx).toInt()
    val y0 = Math.floor(cy).toInt()
    val x1 = minOf(x0 + 1, image.width - 1)
    val y1 = minOf(y0 + 1, image.height - 1)
    val fx = cx - x0
    val fy = cy - y0
    val px = image.pixels
    for (ch in 0 until 3) {
      val v00 = u8(px[(y0 * image.width + x0) * 4 + ch])
      val v01 = u8(px[(y0 * image.width + x1) * 4 + ch])
      val v10 = u8(px[(y1 * image.width + x0) * 4 + ch])
      val v11 = u8(px[(y1 * image.width + x1) * 4 + ch])
      val top = v00 * (1 - fx) + v01 * fx
      val bottom = v10 * (1 - fx) + v11 * fx
      rgb[ch] = top * (1 - fy) + bottom * fy
    }
  }

  /** Bilinear backward warp through `m` = `[a, b, tx, c, d, ty]`; a sample
   *  whose 2×2 neighbourhood leaves the image stays transparent black. */
  fun warp(image: RgbaImage, m: DoubleArray, outW: Int, outH: Int): RgbaImage {
    val out = ByteArray(outW * outH * 4)
    val (a, b, tx) = Triple(m[0], m[1], m[2])
    val (c, d, ty) = Triple(m[3], m[4], m[5])
    val det = a * d - b * c
    if (Math.abs(det) < 1e-10) return RgbaImage(outW, outH, out)
    val ia = d / det
    val ib = -b / det
    val ic = -c / det
    val id = a / det
    val srcW = image.width.toDouble()
    val srcH = image.height.toDouble()
    val px = image.pixels
    for (oy in 0 until outH) {
      for (ox in 0 until outW) {
        val dx = ox - tx
        val dy = oy - ty
        val srcX = ia * dx + ib * dy
        val srcY = ic * dx + id * dy
        val x0 = Math.floor(srcX)
        val y0 = Math.floor(srcY)
        // Bounds in Double first: NaN fails every comparison and is skipped.
        if (!(x0 >= 0 && x0 + 1 < srcW && y0 >= 0 && y0 + 1 < srcH)) continue
        val fx = srcX - x0
        val fy = srcY - y0
        val row0 = y0.toInt() * image.width
        val row1 = row0 + image.width
        val col0 = x0.toInt()
        val outIdx = (oy * outW + ox) * 4
        for (ch in 0 until 4) {
          val w00 = u8(px[(row0 + col0) * 4 + ch]) * (1 - fx) * (1 - fy)
          val w01 = u8(px[(row0 + col0 + 1) * 4 + ch]) * fx * (1 - fy)
          val w10 = u8(px[(row1 + col0) * 4 + ch]) * (1 - fx) * fy
          val w11 = u8(px[(row1 + col0 + 1) * 4 + ch]) * fx * fy
          out[outIdx + ch] = jsRound(w00 + w01 + w10 + w11).toInt().toByte()
        }
      }
    }
    return RgbaImage(outW, outH, out)
  }

  /** Variance of the 4-neighbour Laplacian over Rec.601 grey (stored as
   *  Float); 0 below 3×3. Higher is sharper. */
  fun sharpness(image: RgbaImage): Double {
    val width = image.width
    val height = image.height
    if (width < 3 || height < 3) return 0.0
    val px = image.pixels
    val gray = FloatArray(width * height) { i -> luma(px[i * 4], px[i * 4 + 1], px[i * 4 + 2]).toFloat() }
    var sum = 0.0
    var sumSq = 0.0
    var count = 0
    for (y in 1 until height - 1) {
      for (x in 1 until width - 1) {
        val up = gray[(y - 1) * width + x].toDouble()
        val down = gray[(y + 1) * width + x].toDouble()
        val left = gray[y * width + (x - 1)].toDouble()
        val right = gray[y * width + (x + 1)].toDouble()
        val center = 4 * gray[y * width + x].toDouble()
        val lap = up + down + left + right - center
        sum += lap
        sumSq += lap * lap
        count++
      }
    }
    val mean = sum / count
    return sumSq / count - mean * mean
  }

  /** Rec.601 luminance histogram in `bins` bins, normalized to sum to 1. */
  fun histogram(image: RgbaImage, bins: Int): FloatArray {
    val hist = FloatArray(bins)
    val total = image.width * image.height
    val px = image.pixels
    for (i in 0 until total) {
      val lum = luma(px[i * 4], px[i * 4 + 1], px[i * 4 + 2])
      hist[minOf(Math.floor(lum / 256 * bins).toInt(), bins - 1)] += 1f
    }
    for (i in 0 until bins) hist[i] = (hist[i].toDouble() / total).toFloat()
    return hist
  }

  /** Floats as little-endian bytes, which JS views as a Float32Array. */
  fun bytes(floats: FloatArray): ByteArray {
    val buffer = ByteBuffer.allocate(floats.size * 4).order(ByteOrder.LITTLE_ENDIAN)
    buffer.asFloatBuffer().put(floats)
    return buffer.array()
  }

  /** `0.299 R + 0.587 G + 0.114 B`, summed left to right. */
  private fun luma(r: Byte, g: Byte, b: Byte): Double = 0.299 * u8(r) + 0.587 * u8(g) + 0.114 * u8(b)
}
