package expo.modules.mlkit

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ColorSpace
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import android.os.Build
import java.io.File
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * A photo decoded UPRIGHT — EXIF orientation applied — as ML Kit is handed it
 * (`InputImage.fromBitmap(bitmap, 0)`), so every box and landmark is in the
 * frame `expo-model-inputs` decodes for the face crops and Vision reports on
 * iOS. `InputImage.fromFilePath` is not used: its EXIF handling is not
 * documented. The longer side is capped at [MAX_SIDE]: results are
 * normalized, so the cap changes no coordinate, only the work.
 */
object UprightBitmap {
  const val MAX_SIDE = 2048

  fun decode(path: String): Bitmap {
    val file = File(if (path.startsWith("file://")) Uri.parse(path).path!! else path)
    require(file.exists()) { "No image at $path" }
    val decoded = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) modern(file) else legacy(file)
    // A 10-bit HDR HEIF can decode as RGBA_F16; ML Kit takes 8-bit.
    if (decoded.config == Bitmap.Config.ARGB_8888) return decoded
    return decoded.copy(Bitmap.Config.ARGB_8888, false).also { decoded.recycle() }
  }

  private fun capped(w: Int, h: Int): Pair<Int, Int> {
    val longer = max(w, h)
    if (longer <= MAX_SIDE) return w to h
    val scale = MAX_SIDE.toDouble() / longer
    return max(1, (w * scale).roundToInt()) to max(1, (h * scale).roundToInt())
  }

  // ImageDecoder applies the EXIF orientation itself.
  private fun modern(file: File): Bitmap =
    ImageDecoder.decodeBitmap(ImageDecoder.createSource(file)) { decoder, info, _ ->
      decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
      // The color space expo-model-inputs decodes the face crops in.
      decoder.setTargetColorSpace(ColorSpace.get(ColorSpace.Named.SRGB))
      val (w, h) = capped(info.size.width, info.size.height)
      decoder.setTargetSize(w, h)
    }

  // BitmapFactory ignores EXIF: rotate by hand.
  private fun legacy(file: File): Bitmap {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(file.path, bounds)
    require(bounds.outWidth > 0 && bounds.outHeight > 0) { "Unsupported image ${file.path}" }
    var sample = 1
    while (max(bounds.outWidth, bounds.outHeight) / (sample * 2) >= MAX_SIDE) sample *= 2
    val bitmap = BitmapFactory.decodeFile(
      file.path,
      BitmapFactory.Options().apply {
        inPreferredConfig = Bitmap.Config.ARGB_8888
        inSampleSize = sample
      },
    ) ?: throw IllegalArgumentException("Could not decode ${file.path}")
    val orientation = ExifInterface(file.path)
      .getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
    val m = Matrix()
    when (orientation) {
      ExifInterface.ORIENTATION_ROTATE_90 -> m.postRotate(90f)
      ExifInterface.ORIENTATION_ROTATE_180 -> m.postRotate(180f)
      ExifInterface.ORIENTATION_ROTATE_270 -> m.postRotate(270f)
      ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> m.postScale(-1f, 1f)
      ExifInterface.ORIENTATION_FLIP_VERTICAL -> m.postScale(1f, -1f)
      ExifInterface.ORIENTATION_TRANSPOSE -> { m.postRotate(90f); m.postScale(-1f, 1f) }
      ExifInterface.ORIENTATION_TRANSVERSE -> { m.postRotate(270f); m.postScale(-1f, 1f) }
      else -> return bitmap
    }
    val upright = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, m, true)
    if (upright !== bitmap) bitmap.recycle()
    return upright
  }
}
