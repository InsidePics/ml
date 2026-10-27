package insidepics.testsupport

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Matrix
import android.media.ExifInterface
import androidx.test.platform.app.InstrumentationRegistry
import com.bumptech.glide.Glide
import com.bumptech.glide.load.engine.DiskCacheStrategy

/**
 * The repository's `fixtures/`, bundled as the test APK's assets (each
 * package's `build.gradle`), for every package's instrumented tests: the
 * Android side of `test-support/ios`.
 */
object Fixtures {
  private val context get() = InstrumentationRegistry.getInstrumentation().context

  fun bytes(name: String): ByteArray = context.assets.open(name).use { it.readBytes() }

  fun text(name: String): String = String(bytes(name))

  /**
   * The fixture as an app's image handle holds it: expo-image-manipulator
   * loads through expo-image-loader's `ImageLoaderService.
   * loadImageForManipulationFromURL`, which is this Glide call (an asset
   * URL normalized to `file:///android_asset/`). Glide applies the EXIF
   * orientation. Blocks, so never on the main thread.
   */
  fun handle(name: String): Bitmap =
    Glide.with(context)
      .asBitmap()
      .diskCacheStrategy(DiskCacheStrategy.NONE)
      .skipMemoryCache(true)
      .load("file:///android_asset/$name")
      .submit()
      .get()

  /** A plain decode (no orientation applied) turned upright by an exact
   *  quarter-turn: what [handle] must equal, pixel for pixel. */
  fun rotatedDecode(name: String): Bitmap {
    val data = bytes(name)
    val raw = BitmapFactory.decodeByteArray(data, 0, data.size, BitmapFactory.Options().apply {
      inPreferredConfig = Bitmap.Config.ARGB_8888
    })
    val tag = ExifInterface(data.inputStream())
      .getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
    val degrees = when (tag) {
      ExifInterface.ORIENTATION_ROTATE_180 -> 180
      ExifInterface.ORIENTATION_ROTATE_90 -> 90
      ExifInterface.ORIENTATION_ROTATE_270 -> 270
      else -> return raw
    }
    val sideways = degrees != 180
    val out = Bitmap.createBitmap(
      if (sideways) raw.height else raw.width,
      if (sideways) raw.width else raw.height,
      Bitmap.Config.ARGB_8888,
    )
    val turn = Matrix().apply {
      postRotate(degrees.toFloat())
      when (degrees) {
        90 -> postTranslate(raw.height.toFloat(), 0f)
        180 -> postTranslate(raw.width.toFloat(), raw.height.toFloat())
        270 -> postTranslate(0f, raw.width.toFloat())
      }
    }
    Canvas(out).drawBitmap(raw, turn, null)
    raw.recycle()
    return out
  }

  /** Every orientation fixture: EXIF 1, 3, 6 and 8, JPEG and HEIC, each of
   *  `face.jpg` stored turned and tagged to be shown upright. */
  val orientations = listOf(1, 3, 6, 8).flatMap { tag ->
    listOf("jpg", "heic").map { "face-orientation-$tag.$it" }
  }
}
