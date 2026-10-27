package expo.modules.mlkit

import android.graphics.PointF
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.Face
import com.google.mlkit.vision.face.FaceContour
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import com.google.mlkit.vision.face.FaceLandmark

/**
 * ML Kit Face Detection, mapped onto Vision's `FaceObservation` by
 * [FaceMapping]. Landmarks (`LANDMARK_MODE_ALL`) are returned for every face,
 * so the five alignment points come from them; contours, which ML Kit only
 * returns for the most prominent faces, fill the other regions best effort.
 */
object FaceAnalyzer {
  private val detector by lazy {
    FaceDetection.getClient(
      FaceDetectorOptions.Builder()
        .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE)
        .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL)
        .setContourMode(FaceDetectorOptions.CONTOUR_MODE_ALL)
        // Down from 0.1: group photos' small faces, as Vision finds them.
        .setMinFaceSize(0.05f)
        .build()
    )
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

  fun detect(image: InputImage): List<Map<String, Any>> =
    awaitDetector(detector.process(image)).map {
      FaceMapping.toObservation(raw(it), image.width, image.height)
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
    )
  }
}
