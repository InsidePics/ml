package expo.modules.mlkit

import android.graphics.Bitmap
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.objects.DetectedObject
import com.google.mlkit.vision.objects.ObjectDetection
import com.google.mlkit.vision.objects.ObjectDetector
import com.google.mlkit.vision.objects.defaults.ObjectDetectorOptions
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder
import expo.modules.kotlin.sharedobjects.SharedRef

/** Object Detection, bundled base model: up to five objects, classified into
 *  its coarse categories (fashion good, food, home good, place, plant). */
object ObjectAnalyzer {
  private val detectors = mutableMapOf<Pair<Boolean, Boolean>, ObjectDetector>()

  private fun detector(multiple: Boolean, classify: Boolean): ObjectDetector = synchronized(detectors) {
    detectors.getOrPut(multiple to classify) {
      val options = ObjectDetectorOptions.Builder().setDetectorMode(ObjectDetectorOptions.SINGLE_IMAGE_MODE)
      if (multiple) options.enableMultipleObjects()
      if (classify) options.enableClassification()
      ObjectDetection.getClient(options.build())
    }
  }

  fun detect(image: InputImage, multiple: Boolean = true, classify: Boolean = true): List<Map<String, Any?>> =
    awaitDetector(detector(multiple, classify).process(image)).map { json(it, image) }

  /** `MlKitObject`, as the custom detector writes it too. */
  fun json(obj: DetectedObject, image: InputImage): Map<String, Any?> = mapOf(
    "boundingBox" to obj.boundingBox.normalizedIn(image),
    "trackingId" to obj.trackingId,
    "labels" to obj.labels.map {
      mapOf("text" to it.text, "confidence" to it.confidence.toDouble(), "index" to it.index)
    },
  )
}

object ObjectsFeature : MlKitFeature {
  override val name = "objects"
  override val imageModels = listOf(ImageModel("mlKitObjects", "objects") { ObjectAnalyzer.detect(it) })

  override fun define(module: ModuleDefinitionBuilder) {
    module.AsyncFunction("detectObjects") { image: SharedRef<Bitmap>, options: Map<String, Any?>, promise: Promise ->
      val multiple = options["multipleObjects"] as? Boolean ?: true
      val classify = options["classify"] as? Boolean ?: true
      MlKitCalls.withImage(image, promise) { ObjectAnalyzer.detect(it, multiple, classify) }
    }
  }
}
