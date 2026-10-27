package expo.modules.imagemltools

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.ColorSpace
import android.os.Build
import java.nio.ByteBuffer

/**
 * A handle's bitmap as [ImageMath] reads it, and back: premultiplied 8-bit
 * sRGB RGBA bytes, as `ios/Pixels.swift` reads a handle on iOS.
 */
object Pixels {
  /** The bitmap's pixels. A hardware or non-ARGB bitmap (Glide hands back
   *  either), or one in another colour space (a Display P3 photo), is drawn
   *  into a readable sRGB ARGB_8888 one first. */
  fun rgba(bitmap: Bitmap): RgbaImage {
    require(!bitmap.isRecycled) { "The image was released" }
    val readable = if (isReadableSrgb(bitmap)) bitmap else redraw(bitmap)
    try {
      val buffer = ByteBuffer.allocate(readable.width * readable.height * 4)
      // ARGB_8888 copies out as R, G, B, A bytes, premultiplied.
      readable.copyPixelsToBuffer(buffer)
      return RgbaImage(readable.width, readable.height, buffer.array())
    } finally {
      if (readable !== bitmap) readable.recycle()
    }
  }

  /** `image` as an sRGB ARGB_8888 bitmap, its bytes as they are. */
  fun bitmap(image: RgbaImage): Bitmap {
    val bitmap = Bitmap.createBitmap(image.width, image.height, Bitmap.Config.ARGB_8888)
    bitmap.copyPixelsFromBuffer(ByteBuffer.wrap(image.pixels))
    return bitmap
  }

  // Before Android 8 every bitmap is sRGB, and colour spaces cannot be named.
  private fun isReadableSrgb(bitmap: Bitmap): Boolean =
    bitmap.config == Bitmap.Config.ARGB_8888 &&
      (Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
        (bitmap.colorSpace ?: ColorSpace.get(ColorSpace.Named.SRGB)) == ColorSpace.get(ColorSpace.Named.SRGB))

  private fun redraw(bitmap: Bitmap): Bitmap {
    val out =
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        Bitmap.createBitmap(
          bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888, true, ColorSpace.get(ColorSpace.Named.SRGB),
        )
      } else {
        Bitmap.createBitmap(bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888)
      }
    // A software canvas cannot draw a hardware bitmap; a copy can be read.
    val hardware = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && bitmap.config == Bitmap.Config.HARDWARE
    val source = if (hardware) bitmap.copy(Bitmap.Config.ARGB_8888, false) else bitmap
    Canvas(out).drawBitmap(source, 0f, 0f, null)
    if (source !== bitmap) source.recycle()
    return out
  }
}
