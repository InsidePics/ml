package expo.modules.mlkit

import com.google.mlkit.vision.common.InputImage

/** `analyzeImage` over an image [AnalysisBitmap] made:
 *  `ios/MlKitAnalyzer.swift`'s Android side. */
object MlKitAnalyzer {
  /** The enabled features' image models `models` (`mlKit*` ids) names, over
   *  one image; TS refuses a model whose feature is not enabled and fills in
   *  the parts not asked for. Entities are TS's to find (`extractEntities`) in
   *  the text it settles on, so asking for them runs text recognition. */
  fun analyze(image: InputImage, models: Set<String>): Map<String, Any> {
    val wanted = if ("mlKitEntities" in models) models + "mlKitText" else models
    val result = mutableMapOf<String, Any>("imageWidth" to image.width, "imageHeight" to image.height)
    for (model in ENABLED_FEATURES.flatMap { it.imageModels }) {
      if (model.id in wanted) result[model.key] = model.run(image)
    }
    return result
  }
}
