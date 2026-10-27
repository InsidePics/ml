package expo.modules.mlkit

import android.graphics.Bitmap
import com.google.mlkit.vision.common.InputImage
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import expo.modules.kotlin.sharedobjects.SharedRef
import java.util.concurrent.Executors

/**
 * Google ML Kit image analysis on an Expo image handle (`SharedRef<Bitmap>`,
 * from expo-image-manipulator or any module that makes one), the Android
 * counterpart of `ios/ExpoMlKitModule.swift`. Every call runs its detectors
 * on the caller's one decode ([AnalysisBitmap]). Results follow
 * `src/ExpoMlKit.types.ts`.
 */
class ExpoMlKitModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("ExpoMlKit")

    // Every Android device has the bundled models.
    Constant("isAvailable") { true }

    AsyncFunction("analyzeImage") { image: SharedRef<Bitmap>, models: List<String>, promise: Promise ->
      withImage(image, promise) { analyze(it, models.toSet()) }
    }

    AsyncFunction("recognizeText") { image: SharedRef<Bitmap>, scripts: List<String>, promise: Promise ->
      withImage(image, promise) { input -> scripts.map { TextAnalyzer.recognize(input, it) } }
    }

    // No image: the text TS chose, its confident lines only.
    AsyncFunction("extractEntities") { text: String, promise: Promise ->
      onQueue(promise) { EntityAnalyzer.extract(text) }
    }

    AsyncFunction("detectFaces") { image: SharedRef<Bitmap>, promise: Promise ->
      withImage(image, promise) { FaceAnalyzer.detect(it) }
    }

    AsyncFunction("detectBarcodes") { image: SharedRef<Bitmap>, promise: Promise ->
      withImage(image, promise) { BarcodeAnalyzer.scan(it) }
    }
  }

  /** The detectors `models` (`mlKit*` cell ids) need, over one image; any
   *  other model's part is empty. Text is the Latin recognizer's; entities
   *  are TS's to find (`extractEntities`) in the text it settles on. */
  private fun analyze(image: InputImage, models: Set<String>): Map<String, Any> {
    fun <T> ifDue(model: String, empty: T, run: () -> T): T = if (model in models) run() else empty
    val wantsText = "mlKitText" in models || "mlKitEntities" in models
    return mapOf(
      "imageWidth" to image.width,
      "imageHeight" to image.height,
      "text" to if (wantsText) TextAnalyzer.recognize(image, "latin")
        else mapOf("text" to "", "blocks" to emptyList<Any>()),
      "labels" to ifDue("mlKitLabels", emptyList()) { LabelAnalyzer.label(image) },
      "barcodes" to ifDue("mlKitBarcodes", emptyList()) { BarcodeAnalyzer.scan(image) },
      "poses" to ifDue("mlKitPoses", emptyList()) { PoseAnalyzer.detect(image) },
      "objects" to ifDue("mlKitObjects", emptyList()) { ObjectAnalyzer.detect(image) },
    )
  }

  /** [onQueue] over the handle's bitmap, prepared for ML Kit; a copy made
   *  for it is recycled, the handle's own bitmap never. */
  private fun withImage(image: SharedRef<Bitmap>, promise: Promise, run: (InputImage) -> Any) {
    val source = image.ref
    onQueue(promise) {
      val bitmap = AnalysisBitmap.prepare(source)
      try {
        run(InputImage.fromBitmap(bitmap, 0))
      } finally {
        if (bitmap !== source) bitmap.recycle()
      }
    }
  }

  /** Resolve with `run`'s result off the calling thread: ML Kit's
   *  `Tasks.await` must not run on the main thread. */
  private fun onQueue(promise: Promise, run: () -> Any?) {
    queue.execute {
      try {
        promise.resolve(run())
      } catch (e: Throwable) {
        // Throwable: an OutOfMemoryError escaping this thread would kill the
        // app instead of rejecting one call.
        promise.reject("ERR_ML_KIT", e.message ?: "ML Kit analysis failed", e)
      }
    }
  }

  private companion object {
    val queue = Executors.newSingleThreadExecutor()
  }
}
