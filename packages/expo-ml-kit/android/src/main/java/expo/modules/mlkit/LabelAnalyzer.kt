package expo.modules.mlkit

import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.defaults.ImageLabelerOptions

/** Image Labeling, bundled base model (default 0.5 confidence threshold). */
object LabelAnalyzer {
  private val labeler by lazy { ImageLabeling.getClient(ImageLabelerOptions.DEFAULT_OPTIONS) }

  fun label(image: InputImage): List<Map<String, Any>> =
    awaitDetector(labeler.process(image)).map {
      mapOf("text" to it.text, "confidence" to it.confidence.toDouble(), "index" to it.index)
    }
}
