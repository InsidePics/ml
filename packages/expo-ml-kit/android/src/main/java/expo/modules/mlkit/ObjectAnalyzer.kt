package expo.modules.mlkit

import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.objects.ObjectDetection
import com.google.mlkit.vision.objects.defaults.ObjectDetectorOptions

/** Object Detection, bundled base model: up to five objects, classified into
 *  its coarse categories (fashion good, food, home good, place, plant). */
object ObjectAnalyzer {
  private val detector by lazy {
    ObjectDetection.getClient(
      ObjectDetectorOptions.Builder()
        .setDetectorMode(ObjectDetectorOptions.SINGLE_IMAGE_MODE)
        .enableMultipleObjects()
        .enableClassification()
        .build()
    )
  }

  fun detect(image: InputImage): List<Map<String, Any?>> =
    awaitDetector(detector.process(image)).map { obj ->
      val box = obj.boundingBox
      mapOf(
        "boundingBox" to box.normalizedIn(image),
        "trackingId" to obj.trackingId,
        "labels" to obj.labels.map {
          mapOf("text" to it.text, "confidence" to it.confidence.toDouble(), "index" to it.index)
        },
      )
    }
}
