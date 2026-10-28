package expo.modules.mlkit

import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.common.MlKitException
import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.common.model.RemoteModelManager
import com.google.mlkit.vision.digitalink.recognition.DigitalInkRecognition
import com.google.mlkit.vision.digitalink.recognition.DigitalInkRecognitionModel
import com.google.mlkit.vision.digitalink.recognition.DigitalInkRecognitionModelIdentifier
import com.google.mlkit.vision.digitalink.recognition.DigitalInkRecognizer
import com.google.mlkit.vision.digitalink.recognition.DigitalInkRecognizerOptions
import com.google.mlkit.vision.digitalink.recognition.Ink
import com.google.mlkit.vision.digitalink.recognition.RecognitionContext
import com.google.mlkit.vision.digitalink.recognition.WritingArea
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder

/**
 * Digital Ink Recognition: handwriting, emoji, sketches and shapes from
 * strokes. Each model (a language tag, or ML Kit's `zxx-*` ones) downloads
 * when the caller asks; recognizing with a missing one rejects with
 * `ERR_ML_KIT_MODEL`. Calls settle from their tasks, off the analysis thread.
 */
object DigitalInkFeature : MlKitFeature {
  override val name = "digitalInk"

  private val models get() = RemoteModelManager.getInstance()

  fun model(tag: String): DigitalInkRecognitionModel {
    val id = try {
      DigitalInkRecognitionModelIdentifier.fromLanguageTag(tag)
    } catch (e: MlKitException) {
      null
    } ?: throw IllegalArgumentException("No ink model for $tag")
    return DigitalInkRecognitionModel.builder(id).build()
  }

  private val recognizers = mutableMapOf<String, DigitalInkRecognizer>()

  private fun recognizer(tag: String): DigitalInkRecognizer = synchronized(recognizers) {
    recognizers.getOrPut(tag) { DigitalInkRecognition.getClient(DigitalInkRecognizerOptions.builder(model(tag)).build()) }
  }

  /** `MlKitInkStroke`s as ML Kit's ink. */
  fun ink(strokes: List<List<Map<String, Any?>>>): Ink {
    val ink = Ink.builder()
    for (points in strokes) {
      val stroke = Ink.Stroke.builder()
      for (p in points) {
        val x = (p["x"] as Number).toFloat()
        val y = (p["y"] as Number).toFloat()
        val t = (p["t"] as? Number)?.toLong()
        stroke.addPoint(if (t != null) Ink.Point.create(x, y, t) else Ink.Point.create(x, y))
      }
      ink.addStroke(stroke.build())
    }
    return ink.build()
  }

  /** The candidates for `strokes`, once the model is known to be there. */
  fun recognize(strokes: List<List<Map<String, Any?>>>, options: Map<String, Any?>): Task<List<Map<String, Any?>>> {
    val tag = options["language"] as? String ?: throw IllegalArgumentException("No ink model language")
    val context = RecognitionContext.builder().setPreContext(options["preContext"] as? String ?: "")
    (options["writingArea"] as? Map<*, *>)?.let {
      context.setWritingArea(WritingArea((it["width"] as Number).toFloat(), (it["height"] as Number).toFloat()))
    }
    val ink = ink(strokes)
    return models.isModelDownloaded(model(tag)).onSuccessTask { ready ->
      if (ready != true) Tasks.forException(MlKitException("Ink model $tag is not downloaded", MlKitException.NOT_FOUND))
      else recognizer(tag).recognize(ink, context.build()).continueWith { task ->
        task.result.candidates.map { mapOf("text" to it.text, "score" to it.score?.toDouble()) }
      }
    }
  }

  override fun define(module: ModuleDefinitionBuilder) {
    module.AsyncFunction("recognizeInk") { strokes: List<List<Map<String, Any?>>>, options: Map<String, Any?>, promise: Promise ->
      recognize(strokes, options)
        .addOnSuccessListener { promise.resolve(it) }
        .addOnFailureListener { e ->
          val missing = e is MlKitException && e.errorCode == MlKitException.NOT_FOUND
          promise.reject(if (missing) "ERR_ML_KIT_MODEL" else "ERR_ML_KIT", e.message ?: "Ink recognition failed", e)
        }
    }

    module.AsyncFunction("downloadInkModel") { tag: String, wifiOnly: Boolean, promise: Promise ->
      val conditions = DownloadConditions.Builder().apply { if (wifiOnly) requireWifi() }.build()
      MlKitCalls.settle(promise, models.download(model(tag), conditions)) { null }
    }

    module.AsyncFunction("deleteInkModel") { tag: String, promise: Promise ->
      MlKitCalls.settle(promise, models.deleteDownloadedModel(model(tag))) { null }
    }

    module.AsyncFunction("isInkModelDownloaded") { tag: String, promise: Promise ->
      MlKitCalls.settle(promise, models.isModelDownloaded(model(tag))) { it }
    }
  }
}
