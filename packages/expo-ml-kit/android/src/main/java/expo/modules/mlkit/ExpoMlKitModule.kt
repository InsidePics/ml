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
      withImage(image, promise) { MlKitAnalyzer.analyze(it, models.toSet()) }
    }

    AsyncFunction("recognizeText") { image: SharedRef<Bitmap>, scripts: List<String>, promise: Promise ->
      withImage(image, promise) { MlKitAnalyzer.recognize(it, scripts) }
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

  /** [onQueue] over the handle's bitmap, as [AnalysisBitmap.analyze]
   *  hands it to ML Kit. */
  private fun withImage(image: SharedRef<Bitmap>, promise: Promise, run: (InputImage) -> Any) {
    val source = image.ref
    onQueue(promise) { AnalysisBitmap.analyze(source, run) }
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
