package expo.modules.mlkit

/**
 * Pixel rectangles to the wire shapes `ExpoMlKit.types.ts`
 * declares. Pure Kotlin, so the JVM tests run it as shipped.
 */
object Geometry {
  /** A pixel rectangle normalized to the upright image, top-left origin. */
  fun rect(left: Double, top: Double, right: Double, bottom: Double, width: Int, height: Int) =
    mapOf(
      "x" to left / width,
      "y" to top / height,
      "width" to (right - left) / width,
      "height" to (bottom - top) / height,
    )

  /** A pixel rectangle; any orientation of the axes, as long as all agree. */
  data class Box(val left: Double, val top: Double, val right: Double, val bottom: Double) {
    val area get() = maxOf(0.0, right - left) * maxOf(0.0, bottom - top)
  }

  /** The share of a face's box a larger face's box must cover for it to be
   *  that face again. Two people's faces overlap far less, even in a crowd. */
  const val NESTED = 0.8

  /**
   * The indexes of `boxes` that are not the same face found twice: ML Kit's
   * accurate detector, with small faces allowed, can return a second, smaller
   * box mostly inside a face (the lower half of a bespectacled face at
   * 1536×2048). A box covered at least [NESTED] by a larger one is dropped.
   */
  fun outermost(boxes: List<Box>): List<Int> =
    boxes.indices.filter { i ->
      val box = boxes[i]
      boxes.none { other -> other.area > box.area && covered(box, by = other) >= NESTED }
    }

  private fun covered(box: Box, by: Box): Double {
    if (box.area == 0.0) return 1.0
    val overlap = Box(
      maxOf(box.left, by.left), maxOf(box.top, by.top),
      minOf(box.right, by.right), minOf(box.bottom, by.bottom),
    )
    return if (overlap.right <= overlap.left || overlap.bottom <= overlap.top) 0.0
    else overlap.area / box.area
  }
}
