package expo.modules.mlkit

import android.graphics.Bitmap
import com.google.mlkit.vision.common.InputImage
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * A caller's image as ML Kit is handed it (`InputImage.fromBitmap(bitmap, 0)`):
 * a software ARGB_8888 bitmap, its longer side capped at [MAX_SIDE]. A Bitmap
 * carries no orientation, so a handle's pixels are already upright. Results
 * are normalized, so the cap changes no coordinate, only the work.
 */
object AnalysisBitmap {
  const val MAX_SIDE = 2048

  /** The size `w`×`h` is analysed at: itself, or scaled to [MAX_SIDE]. */
  fun cappedSize(w: Int, h: Int): Pair<Int, Int> {
    val longer = max(w, h)
    if (longer <= MAX_SIDE) return w to h
    val scale = MAX_SIDE.toDouble() / longer
    return max(1, (w * scale).roundToInt()) to max(1, (h * scale).roundToInt())
  }

  /** `source` itself when ML Kit can read it as it is, else a copy the
   *  caller recycles (never `source`, which the handle owns). A hardware or
   *  10-bit bitmap is copied to ARGB_8888 first. */
  fun prepare(source: Bitmap): Bitmap {
    require(!source.isRecycled) { "The image was released" }
    val readable =
      if (source.config == Bitmap.Config.ARGB_8888) source
      else source.copy(Bitmap.Config.ARGB_8888, false)
    val (w, h) = cappedSize(readable.width, readable.height)
    if (w == readable.width && h == readable.height) return readable
    val scaled = Bitmap.createScaledBitmap(readable, w, h, true)
    if (readable !== source) readable.recycle()
    return scaled
  }

  /** `run` over `source` as ML Kit is handed it; a copy made for it is
   *  recycled after, `source` never. */
  fun <T> analyze(source: Bitmap, run: (InputImage) -> T): T {
    val bitmap = prepare(source)
    try {
      return run(InputImage.fromBitmap(bitmap, 0))
    } finally {
      if (bitmap !== source) bitmap.recycle()
    }
  }
}
