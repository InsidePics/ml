package expo.modules.mlkit

import android.graphics.Bitmap
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.segmentation.Segmentation
import com.google.mlkit.vision.segmentation.Segmenter
import com.google.mlkit.vision.segmentation.selfie.SelfieSegmenterOptions
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder
import expo.modules.kotlin.sharedobjects.SharedRef

/** Selfie Segmentation (bundled): how likely each pixel is a person, as an
 *  `MlKitMask` at the image's size, or the model's own (`rawSizeMask`). */
object SelfieSegmentationFeature : MlKitFeature {
  override val name = "selfieSegmentation"

  private val segmenters = mutableMapOf<Boolean, Segmenter>()

  private fun segmenter(rawSize: Boolean): Segmenter = synchronized(segmenters) {
    segmenters.getOrPut(rawSize) {
      val options = SelfieSegmenterOptions.Builder().setDetectorMode(SelfieSegmenterOptions.SINGLE_IMAGE_MODE)
      if (rawSize) options.enableRawSizeMask()
      Segmentation.getClient(options.build())
    }
  }

  fun segment(image: InputImage, rawSize: Boolean): Map<String, Any> {
    val mask = awaitDetector(segmenter(rawSize).process(image))
    return Masks.fromConfidences(mask.buffer.asFloatBuffer(), mask.width, mask.height)
  }

  override fun define(module: ModuleDefinitionBuilder) {
    module.AsyncFunction("segmentSelfie") { image: SharedRef<Bitmap>, options: Map<String, Any?>, promise: Promise ->
      val rawSize = options["rawSizeMask"] as? Boolean ?: false
      MlKitCalls.withImage(image, promise) { segment(it, rawSize) }
    }
  }
}
