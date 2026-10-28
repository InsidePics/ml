package expo.modules.mlkit

import java.nio.FloatBuffer
import kotlin.math.roundToInt

/**
 * A segmentation model's per-pixel confidences as `MlKitMask`: one byte per
 * pixel, row-major, 0-255 for confidence 0-1 — a quarter of the floats'
 * size, and the precision a mask is drawn or thresholded at. Selfie and
 * subject segmentation both write it; `ios/Masks.swift` is the iOS side.
 */
object Masks {
  fun fromConfidences(confidences: FloatBuffer, width: Int, height: Int): Map<String, Any> {
    confidences.rewind()
    val bytes = ByteArray(width * height) { (confidences.get().coerceIn(0f, 1f) * 255f).roundToInt().toByte() }
    return mapOf("width" to width, "height" to height, "data" to bytes)
  }
}
