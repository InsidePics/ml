package insidepics.testsupport

import android.graphics.Bitmap
import java.nio.ByteBuffer

/** A software ARGB_8888 bitmap's bytes (R, G, B, A, premultiplied), read
 *  directly: the reference the code under test is compared with. */
fun Bitmap.bytes(): ByteArray {
  val readable = if (config == Bitmap.Config.ARGB_8888) this else copy(Bitmap.Config.ARGB_8888, false)
  val buffer = ByteBuffer.allocate(readable.width * readable.height * 4)
  readable.copyPixelsToBuffer(buffer)
  return buffer.array()
}

/** Mean absolute difference of two equal-length byte arrays, 0–255;
 *  infinite when their lengths differ. */
fun meanDifference(a: ByteArray, b: ByteArray): Double {
  if (a.size != b.size || a.isEmpty()) return Double.POSITIVE_INFINITY
  var sum = 0L
  for (i in a.indices) sum += kotlin.math.abs((a[i].toInt() and 0xFF) - (b[i].toInt() and 0xFF))
  return sum.toDouble() / a.size
}

/** The bitmap as 32×32 greyscale, for comparing pictures that went through
 *  different compressions: a wrong turn is far off, recompression is not. */
fun Bitmap.thumbnail(): ByteArray {
  val small = Bitmap.createScaledBitmap(this, 32, 32, true).bytes()
  return ByteArray(32 * 32) { i ->
    val r = small[i * 4].toInt() and 0xFF
    val g = small[i * 4 + 1].toInt() and 0xFF
    val b = small[i * 4 + 2].toInt() and 0xFF
    ((r * 299 + g * 587 + b * 114) / 1000).toByte()
  }
}
