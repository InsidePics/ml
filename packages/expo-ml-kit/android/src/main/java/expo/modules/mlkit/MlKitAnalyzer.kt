package expo.modules.mlkit

import com.google.mlkit.vision.common.InputImage

/** The module's multi-model calls, over an image [AnalysisBitmap] made:
 *  `ios/MlKitAnalyzer.swift`'s Android side. */
object MlKitAnalyzer {
  /** The detectors `models` (`mlKit*` cell ids) need, over one image; any
   *  other model's part is empty. Text is the Latin recognizer's; entities
   *  are TS's to find (`extractEntities`) in the text it settles on. */
  fun analyze(image: InputImage, models: Set<String>): Map<String, Any> {
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

  /** One read per script, in the order asked. */
  fun recognize(image: InputImage, scripts: List<String>): List<Map<String, Any>> =
    scripts.map { TextAnalyzer.recognize(image, it) }
}
