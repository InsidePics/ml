package expo.modules.mlkit

import android.graphics.Bitmap
import com.google.mlkit.vision.pose.PoseDetection
import com.google.mlkit.vision.pose.accurate.AccuratePoseDetectorOptions
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder
import expo.modules.kotlin.sharedobjects.SharedRef

/** Pose Detection's accurate model (bundled), single-image mode: the same
 *  33 landmarks as `poses`, steadier and slower. */
object PosesAccurateFeature : MlKitFeature {
  override val name = "posesAccurate"

  val detector by lazy {
    PoseDetection.getClient(
      AccuratePoseDetectorOptions.Builder().setDetectorMode(AccuratePoseDetectorOptions.SINGLE_IMAGE_MODE).build()
    )
  }

  override fun define(module: ModuleDefinitionBuilder) {
    module.AsyncFunction("detectPoseAccurate") { image: SharedRef<Bitmap>, promise: Promise ->
      MlKitCalls.withImage(image, promise) { PoseAnalyzer.detect(it, detector) }
    }
  }
}
