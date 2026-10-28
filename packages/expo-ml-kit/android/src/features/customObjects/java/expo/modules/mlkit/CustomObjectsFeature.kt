package expo.modules.mlkit

import android.graphics.Bitmap
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.objects.ObjectDetection
import com.google.mlkit.vision.objects.ObjectDetector
import com.google.mlkit.vision.objects.custom.CustomObjectDetectorOptions
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder
import expo.modules.kotlin.sharedobjects.SharedRef

/** Object Detection with the caller's TensorFlow Lite classifier
 *  (`MlKitCustomModel`) labelling each object: a detector per model file
 *  and options, kept. */
object CustomObjectsFeature : MlKitFeature {
  override val name = "customObjects"

  private data class Key(val path: String, val multiple: Boolean, val classify: Boolean, val threshold: Float, val max: Int)

  private val detectors = mutableMapOf<Key, ObjectDetector>()

  private fun detector(key: Key): ObjectDetector = synchronized(detectors) {
    detectors.getOrPut(key) {
      val options = CustomObjectDetectorOptions.Builder(CustomModels.local(key.path))
        .setDetectorMode(CustomObjectDetectorOptions.SINGLE_IMAGE_MODE)
        .setClassificationConfidenceThreshold(key.threshold)
        .setMaxPerObjectLabelCount(key.max)
      if (key.multiple) options.enableMultipleObjects()
      if (key.classify) options.enableClassification()
      ObjectDetection.getClient(options.build())
    }
  }

  /** `detectObjects` with `options.model` (`MlKitObjectOptions`). */
  fun detect(image: InputImage, options: Map<String, Any?>): List<Map<String, Any?>> {
    val key = Key(
      CustomModels.path(options),
      options["multipleObjects"] as? Boolean ?: true,
      options["classify"] as? Boolean ?: true,
      (options["confidenceThreshold"] as? Number)?.toFloat() ?: 0.5f,
      (options["maxLabelsPerObject"] as? Number)?.toInt() ?: 10,
    )
    return awaitDetector(detector(key).process(image)).map { ObjectAnalyzer.json(it, image) }
  }

  override fun define(module: ModuleDefinitionBuilder) {
    module.AsyncFunction("detectObjectsCustom") { image: SharedRef<Bitmap>, options: Map<String, Any?>, promise: Promise ->
      MlKitCalls.withImage(image, promise) { detect(it, options) }
    }
  }
}
