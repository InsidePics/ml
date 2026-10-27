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
}
