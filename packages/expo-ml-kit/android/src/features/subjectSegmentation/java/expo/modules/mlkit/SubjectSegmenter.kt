package expo.modules.mlkit

import android.content.Context
import android.graphics.Bitmap
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.segmentation.subject.SubjectSegmentation
import com.google.mlkit.vision.segmentation.subject.SubjectSegmenterOptions
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder
import expo.modules.kotlin.sharedobjects.SharedRef

/**
 * Subject Segmentation (Android only): the image's foreground, and each
 * subject in it, as `MlKitMask`s. Its model is a Google Play services module
 * the device downloads: [PlayModules] says whether it is there, and installs
 * it.
 */
object SubjectSegmenter {
  private val foregroundOnly by lazy {
    SubjectSegmentation.getClient(SubjectSegmenterOptions.Builder().enableForegroundConfidenceMask().build())
  }
  private val withSubjects by lazy {
    SubjectSegmentation.getClient(
      SubjectSegmenterOptions.Builder()
        .enableForegroundConfidenceMask()
        .enableMultipleSubjects(
          SubjectSegmenterOptions.SubjectResultOptions.Builder().enableConfidenceMask().build()
        )
        .build()
    )
  }

  /** The client whose module the readiness and install calls are about. */
  val module get() = foregroundOnly

  /**
   * The foreground's mask, the image's size, and with `subjects` each
   * subject's: its box (normalized, top-left origin) and its mask, the box's
   * size. Rejects with `ERR_ML_KIT_MODULE_MISSING` while the module is not on
   * the device, rather than waiting for its download.
   */
  fun segment(context: Context, bitmap: Bitmap, subjects: Boolean, promise: Promise) {
    PlayModules.whenReady(context, module, "Subject segmentation", promise) {
      MlKitCalls.onQueue(promise) { AnalysisBitmap.analyze(bitmap) { segment(it, subjects) } }
    }
  }

  /** [segment] on the analysis thread, the module known to be there. */
  fun segment(image: InputImage, subjects: Boolean): Map<String, Any> {
    val result = awaitDetector((if (subjects) withSubjects else foregroundOnly).process(image))
    val foreground = result.foregroundConfidenceMask
      ?: throw IllegalStateException("Subject segmentation returned no foreground mask")
    return mapOf(
      "foreground" to Masks.fromConfidences(foreground, image.width, image.height),
      "subjects" to (if (subjects) result.subjects else emptyList()).map { subject ->
        val mask = subject.confidenceMask ?: throw IllegalStateException("Subject segmentation returned no subject mask")
        mapOf(
          "boundingBox" to Geometry.rect(
            subject.startX.toDouble(), subject.startY.toDouble(),
            (subject.startX + subject.width).toDouble(), (subject.startY + subject.height).toDouble(),
            image.width, image.height,
          ),
          "mask" to Masks.fromConfidences(mask, subject.width, subject.height),
        )
      },
    )
  }
}

object SubjectSegmentationFeature : MlKitFeature {
  override val name = "subjectSegmentation"

  override fun define(module: ModuleDefinitionBuilder) {
    module.AsyncFunction("isSubjectSegmentationModuleReady") { promise: Promise ->
      PlayModules.isReady(MlKitHost.context, SubjectSegmenter.module, promise)
    }
    module.AsyncFunction("downloadSubjectSegmentationModule") { promise: Promise ->
      PlayModules.install(MlKitHost.context, SubjectSegmenter.module, promise)
    }
    module.AsyncFunction("segmentSubjects") { image: SharedRef<Bitmap>, subjects: Boolean, promise: Promise ->
      SubjectSegmenter.segment(MlKitHost.context, image.ref, subjects, promise)
    }
  }
}
