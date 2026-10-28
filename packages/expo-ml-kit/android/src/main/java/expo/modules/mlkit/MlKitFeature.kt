package expo.modules.mlkit

import android.content.Context
import android.graphics.Bitmap
import com.google.mlkit.vision.common.InputImage
import expo.modules.kotlin.Promise
import expo.modules.kotlin.exception.CodedException
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinitionBuilder
import expo.modules.kotlin.sharedobjects.SharedRef
import java.util.concurrent.Executors

/**
 * One ML Kit feature (`src/features.json`), compiled in only when the app
 * enables it: its code lives in `src/features/<name>/java`, and build.gradle
 * lists the enabled ones in `ENABLED_FEATURES`. The module serves exactly
 * what they define, so a call into a feature the app left out finds no
 * function, which the TS side reports as "not enabled".
 */
interface MlKitFeature {
  /** Its `features.json` key. */
  val name: String

  /** The `analyzeImage` models it runs. */
  val imageModels: List<ImageModel> get() = emptyList()

  /** Its own module functions. */
  fun define(module: ModuleDefinitionBuilder) {}
}

/** One `analyzeImage` model: its `mlKit*` id, the result key it fills and
 *  the run over the call's one decode. */
class ImageModel(val id: String, val key: String, val run: (InputImage) -> Any)

/**
 * Where the module's calls run. Analyses share one thread: a decoded photo
 * and a model's working memory at a time, and ML Kit's `Tasks.await` must not
 * run on the main thread. Work that waits on the network or the user (a
 * model download, a scanner screen) never takes that thread: it settles its
 * promise from the task's own listener ([settle]).
 */
object MlKitCalls {
  private val queue = Executors.newSingleThreadExecutor()

  /** Resolve with `run`'s result on the analysis thread. */
  fun onQueue(promise: Promise, run: () -> Any?) {
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

  /** [onQueue] over the handle's bitmap, as [AnalysisBitmap.analyze] hands
   *  it to ML Kit. */
  fun withImage(image: SharedRef<Bitmap>, promise: Promise, run: (InputImage) -> Any?) {
    val source = image.ref
    onQueue(promise) { AnalysisBitmap.analyze(source, run) }
  }

  /** Settle `promise` from `task`'s listener, off the analysis thread. */
  fun <T> settle(promise: Promise, task: com.google.android.gms.tasks.Task<T>, map: (T) -> Any?) {
    task.addOnSuccessListener { value ->
      try {
        promise.resolve(map(value))
      } catch (e: Throwable) {
        promise.reject("ERR_ML_KIT", e.message ?: "ML Kit failed", e)
      }
    }.addOnFailureListener { e ->
      promise.reject("ERR_ML_KIT", e.message ?: "ML Kit failed", e)
    }
  }
}

/**
 * The running module, for the features that need more than an image: an
 * application context for a client (GenAI). Read at call time, never kept.
 */
object MlKitHost {
  @Volatile internal var module: Module? = null

  val context: Context
    get() = module?.appContext?.reactContext?.applicationContext
      ?: throw CodedException("ERR_ML_KIT", "The ML Kit module is not running", null)
}
