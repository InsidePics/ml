package expo.modules.mlkit

import android.graphics.Bitmap
import android.graphics.PointF
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.Face
import com.google.mlkit.vision.face.FaceContour
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetector
import com.google.mlkit.vision.face.FaceDetectorOptions
import com.google.mlkit.vision.face.FaceLandmark
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder
import expo.modules.kotlin.sharedobjects.SharedRef

/**
 * ML Kit Face Detection, mapped onto Vision's `FaceObservation` by
 * [FaceMapping]. Landmarks (`LANDMARK_MODE_ALL`) are returned for every face,
 * so the five alignment points come from them; contours, which ML Kit only
 * returns for the most prominent faces, fill the other regions best effort.
 */
object FaceAnalyzer {
  /** `MlKitFaceOptions`, as the detector built for them is cached by. */
  data class Options(val fast: Boolean = false, val classify: Boolean = false, val minFaceSize: Float = 0.05f) {
    companion object {
      fun from(map: Map<String, Any?>) = Options(
        fast = map["performance"] == "fast",
        classify = map["classify"] as? Boolean ?: false,
        // Down from 0.1: group photos' small faces, as Vision finds them.
        minFaceSize = (map["minFaceSize"] as? Number)?.toFloat() ?: 0.05f,
      )
    }
  }

  private val detectors = mutableMapOf<Options, FaceDetector>()

  private fun detector(options: Options): FaceDetector = synchronized(detectors) {
    detectors.getOrPut(options) {
      FaceDetection.getClient(
        FaceDetectorOptions.Builder()
          .setPerformanceMode(
            if (options.fast) FaceDetectorOptions.PERFORMANCE_MODE_FAST else FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE
          )
          .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL)
          .setContourMode(FaceDetectorOptions.CONTOUR_MODE_ALL)
          .setClassificationMode(
            if (options.classify) FaceDetectorOptions.CLASSIFICATION_MODE_ALL else FaceDetectorOptions.CLASSIFICATION_MODE_NONE
          )
          .setMinFaceSize(options.minFaceSize)
          .build()
      )
    }
  }

  private val LANDMARKS = mapOf(
    "leftEye" to FaceLandmark.LEFT_EYE,
    "rightEye" to FaceLandmark.RIGHT_EYE,
    "noseBase" to FaceLandmark.NOSE_BASE,
    "mouthLeft" to FaceLandmark.MOUTH_LEFT,
    "mouthRight" to FaceLandmark.MOUTH_RIGHT,
    "mouthBottom" to FaceLandmark.MOUTH_BOTTOM,
  )

  private val CONTOURS = mapOf(
    "face" to FaceContour.FACE,
    "leftEyebrowTop" to FaceContour.LEFT_EYEBROW_TOP,
    "leftEyebrowBottom" to FaceContour.LEFT_EYEBROW_BOTTOM,
    "rightEyebrowTop" to FaceContour.RIGHT_EYEBROW_TOP,
    "rightEyebrowBottom" to FaceContour.RIGHT_EYEBROW_BOTTOM,
    "noseBridge" to FaceContour.NOSE_BRIDGE,
    "upperLipBottom" to FaceContour.UPPER_LIP_BOTTOM,
    "lowerLipTop" to FaceContour.LOWER_LIP_TOP,
  )

  fun detect(image: InputImage, options: Options = Options()): List<Map<String, Any>> {
    val faces = awaitDetector(detector(options).process(image))
    val boxes = faces.map {
      with(it.boundingBox) { Geometry.Box(left.toDouble(), top.toDouble(), right.toDouble(), bottom.toDouble()) }
    }
    return Geometry.outermost(boxes).map {
      FaceMapping.toObservation(raw(faces[it]), image.width, image.height)
    }
  }

  private fun pt(p: PointF) = FaceMapping.Pt(p.x.toDouble(), p.y.toDouble())

  private fun raw(face: Face): FaceMapping.RawFace {
    val box = face.boundingBox
    return FaceMapping.RawFace(
      left = box.left.toDouble(),
      top = box.top.toDouble(),
      right = box.right.toDouble(),
      bottom = box.bottom.toDouble(),
      eulerX = face.headEulerAngleX.toDouble(),
      eulerY = face.headEulerAngleY.toDouble(),
      eulerZ = face.headEulerAngleZ.toDouble(),
      landmarks = LANDMARKS.mapNotNull { (name, type) ->
        face.getLandmark(type)?.let { name to pt(it.position) }
      }.toMap(),
      contours = CONTOURS.mapNotNull { (name, type) ->
        face.getContour(type)?.points?.takeIf { it.isNotEmpty() }?.let { name to it.map(::pt) }
      }.toMap(),
      smiling = face.smilingProbability?.toDouble(),
      leftEyeOpen = face.leftEyeOpenProbability?.toDouble(),
      rightEyeOpen = face.rightEyeOpenProbability?.toDouble(),
    )
  }
}

object FacesFeature : MlKitFeature {
  override val name = "faces"

  override fun define(module: ModuleDefinitionBuilder) {
    module.AsyncFunction("detectFaces") { image: SharedRef<Bitmap>, options: Map<String, Any?>, promise: Promise ->
      val parsed = FaceAnalyzer.Options.from(options)
      MlKitCalls.withImage(image, promise) { FaceAnalyzer.detect(it, parsed) }
    }
  }
}
