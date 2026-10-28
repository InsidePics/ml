package expo.modules.mlkit

import android.graphics.Bitmap
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.label.ImageLabel
import com.google.mlkit.vision.label.ImageLabeler
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.defaults.ImageLabelerOptions
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder
import expo.modules.kotlin.sharedobjects.SharedRef

/** Image Labeling, bundled base model: `analyzeImage`'s labels at ML Kit's
 *  default 0.5 threshold, and `labelImage` at the caller's. */
object LabelAnalyzer {
  private val labelers = mutableMapOf<Float, ImageLabeler>()

  private fun labeler(threshold: Float): ImageLabeler = synchronized(labelers) {
    labelers.getOrPut(threshold) {
      ImageLabeling.getClient(ImageLabelerOptions.Builder().setConfidenceThreshold(threshold).build())
    }
  }

  fun label(image: InputImage, threshold: Float = 0.5f): List<Map<String, Any>> =
    awaitDetector(labeler(threshold).process(image)).map(::json)

  /** `MlKitLabel`, as the custom labeler and Object Detection write it too. */
  fun json(label: ImageLabel): Map<String, Any> =
    mapOf("text" to label.text, "confidence" to label.confidence.toDouble(), "index" to label.index)
}

object LabelsFeature : MlKitFeature {
  override val name = "labels"
  override val imageModels = listOf(ImageModel("mlKitLabels", "labels") { LabelAnalyzer.label(it) })

  override fun define(module: ModuleDefinitionBuilder) {
    module.AsyncFunction("labelImage") { image: SharedRef<Bitmap>, options: Map<String, Any?>, promise: Promise ->
      val threshold = (options["confidenceThreshold"] as? Number)?.toFloat() ?: 0.5f
      MlKitCalls.withImage(image, promise) { LabelAnalyzer.label(it, threshold) }
    }
  }
}
