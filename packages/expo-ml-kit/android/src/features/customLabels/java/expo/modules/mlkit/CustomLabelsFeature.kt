package expo.modules.mlkit

import android.graphics.Bitmap
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.label.ImageLabeler
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.custom.CustomImageLabelerOptions
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder
import expo.modules.kotlin.sharedobjects.SharedRef

/** Image Labeling with the caller's TensorFlow Lite classifier
 *  (`MlKitCustomModel`): a labeler per model file and options, kept. */
object CustomLabelsFeature : MlKitFeature {
  override val name = "customLabels"

  private val labelers = mutableMapOf<Triple<String, Float, Int>, ImageLabeler>()

  private fun labeler(path: String, threshold: Float, maxResults: Int): ImageLabeler = synchronized(labelers) {
    labelers.getOrPut(Triple(path, threshold, maxResults)) {
      ImageLabeling.getClient(
        CustomImageLabelerOptions.Builder(CustomModels.local(path))
          .setConfidenceThreshold(threshold)
          .setMaxResultCount(maxResults)
          .build()
      )
    }
  }

  /** `labelImage` with `options.model` (`MlKitLabelOptions`). */
  fun label(image: InputImage, options: Map<String, Any?>): List<Map<String, Any>> {
    val path = CustomModels.path(options)
    val threshold = (options["confidenceThreshold"] as? Number)?.toFloat() ?: 0.5f
    val maxResults = (options["maxResults"] as? Number)?.toInt() ?: 10
    return awaitDetector(labeler(path, threshold, maxResults).process(image)).map(LabelAnalyzer::json)
  }

  override fun define(module: ModuleDefinitionBuilder) {
    module.AsyncFunction("labelImageCustom") { image: SharedRef<Bitmap>, options: Map<String, Any?>, promise: Promise ->
      MlKitCalls.withImage(image, promise) { label(it, options) }
    }
  }
}
