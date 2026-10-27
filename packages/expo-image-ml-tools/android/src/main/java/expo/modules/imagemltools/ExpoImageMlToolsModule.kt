package expo.modules.imagemltools

import android.graphics.Bitmap
import expo.modules.kotlin.AppContext
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import expo.modules.kotlin.records.Field
import expo.modules.kotlin.records.Record
import expo.modules.kotlin.sharedobjects.SharedRef
import java.nio.ByteBuffer
import java.util.concurrent.Executors

class TensorOptions : Record {
  @Field val width: Int = 0
  @Field val height: Int = 0
  @Field val fit: String = "cover"
  @Field val filter: String = "bilinear"
  @Field val mean: List<Double> = listOf(0.0, 0.0, 0.0)
  @Field val std: List<Double> = listOf(1.0, 1.0, 1.0)
  @Field val layout: String = "nchw"
}

/**
 * Model inputs from any Expo image handle (`SharedRef<Bitmap>`: one made by
 * expo-image-manipulator, expo-image, or [warp]) — the Android side of
 * `ios/ExpoImageMlToolsModule.swift`, with the same surface and bits. Only
 * small results reach JS.
 */
class ExpoImageMlToolsModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("ExpoImageMlTools")

    Function("size") { image: SharedRef<Bitmap> ->
      mapOf("width" to image.ref.width, "height" to image.ref.height)
    }

    AsyncFunction("toTensor") { image: SharedRef<Bitmap>, options: TensorOptions, promise: Promise ->
      val fit = enumOrNull<Fit>(options.fit)
      val filter = enumOrNull<Filter>(options.filter)
      val layout = enumOrNull<Layout>(options.layout)
      if (fit == null || filter == null || layout == null || options.width <= 0 || options.height <= 0 ||
        options.mean.size != 3 || options.std.size != 3 || options.std.contains(0.0)
      ) {
        return@AsyncFunction promise.reject("ERR_ARGUMENT", "Invalid tensor options", null)
      }
      withPixels(image, promise) { rgba ->
        ImageMath.bytes(
          ImageMath.tensor(
            rgba, options.width, options.height, fit, filter,
            options.mean.toDoubleArray(), options.std.toDoubleArray(), layout,
          )
        )
      }
    }

    AsyncFunction("warp") { image: SharedRef<Bitmap>, matrix: List<Double>, width: Int, height: Int, promise: Promise ->
      if (matrix.size != 6 || width <= 0 || height <= 0) {
        return@AsyncFunction promise.reject("ERR_ARGUMENT", "warp needs a 6-value matrix and a positive size", null)
      }
      withPixels(image, promise) { rgba ->
        val warped = ImageMath.warp(rgba, matrix.toDoubleArray(), width, height)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        bitmap.copyPixelsFromBuffer(ByteBuffer.wrap(warped.pixels))
        ImageHandle(bitmap, appContext)
      }
    }

    AsyncFunction("sharpness") { image: SharedRef<Bitmap>, promise: Promise ->
      withPixels(image, promise) { ImageMath.sharpness(it) }
    }

    AsyncFunction("histogram") { image: SharedRef<Bitmap>, bins: Int, promise: Promise ->
      if (bins <= 0) return@AsyncFunction promise.reject("ERR_ARGUMENT", "histogram needs a bin", null)
      withPixels(image, promise) { ImageMath.bytes(ImageMath.histogram(it, bins)) }
    }
  }

  private inline fun <reified T : Enum<T>> enumOrNull(name: String): T? =
    enumValues<T>().firstOrNull { it.name.equals(name, ignoreCase = true) }

  /** `build` over the handle's pixels, off the JS thread, one call at a time
   *  (a 12 MP copy is ~48 MB of heap). */
  private fun withPixels(image: SharedRef<Bitmap>, promise: Promise, build: (RgbaImage) -> Any?) {
    val bitmap = image.ref
    executor.execute {
      try {
        promise.resolve(build(rgba(bitmap)))
      } catch (e: Throwable) {
        promise.reject("ERR_IMAGE_ML_TOOLS", e.message ?: e.toString(), e)
      }
    }
  }

  /** The bitmap as premultiplied RGBA bytes. A hardware or non-ARGB bitmap
   *  (Glide hands back either) is copied to a readable ARGB_8888 one first. */
  private fun rgba(bitmap: Bitmap): RgbaImage {
    val readable =
      if (bitmap.config == Bitmap.Config.ARGB_8888) bitmap
      else bitmap.copy(Bitmap.Config.ARGB_8888, false)
    try {
      val buffer = ByteBuffer.allocate(readable.width * readable.height * 4)
      // ARGB_8888 copies out as R, G, B, A bytes, premultiplied.
      readable.copyPixelsToBuffer(buffer)
      return RgbaImage(readable.width, readable.height, buffer.array())
    } finally {
      if (readable !== bitmap) readable.recycle()
    }
  }

  private val executor = Executors.newSingleThreadExecutor()
}

/** The handle [warp] returns: Expo's image type, so every module that takes
 *  an image takes it. */
class ImageHandle(bitmap: Bitmap, appContext: AppContext) : SharedRef<Bitmap>(bitmap, appContext) {
  override val nativeRefType: String = "image"

  override fun getAdditionalMemoryPressure(): Int = ref.allocationByteCount
}
