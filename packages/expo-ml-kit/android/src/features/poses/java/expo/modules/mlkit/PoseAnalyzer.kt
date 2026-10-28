package expo.modules.mlkit

import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.pose.PoseDetection
import com.google.mlkit.vision.pose.PoseLandmark
import com.google.mlkit.vision.pose.defaults.PoseDetectorOptions

/** Pose Detection (base, bundled), single-image mode: one person, 33 points. */
object PoseAnalyzer {
  private val detector by lazy {
    PoseDetection.getClient(
      PoseDetectorOptions.Builder().setDetectorMode(PoseDetectorOptions.SINGLE_IMAGE_MODE).build()
    )
  }

  /** The wire names (`MlKitPoseLandmark.type`), the same iOS writes. */
  private val NAMES = mapOf(
    PoseLandmark.NOSE to "nose",
    PoseLandmark.LEFT_EYE_INNER to "leftEyeInner",
    PoseLandmark.LEFT_EYE to "leftEye",
    PoseLandmark.LEFT_EYE_OUTER to "leftEyeOuter",
    PoseLandmark.RIGHT_EYE_INNER to "rightEyeInner",
    PoseLandmark.RIGHT_EYE to "rightEye",
    PoseLandmark.RIGHT_EYE_OUTER to "rightEyeOuter",
    PoseLandmark.LEFT_EAR to "leftEar",
    PoseLandmark.RIGHT_EAR to "rightEar",
    PoseLandmark.LEFT_MOUTH to "leftMouth",
    PoseLandmark.RIGHT_MOUTH to "rightMouth",
    PoseLandmark.LEFT_SHOULDER to "leftShoulder",
    PoseLandmark.RIGHT_SHOULDER to "rightShoulder",
    PoseLandmark.LEFT_ELBOW to "leftElbow",
    PoseLandmark.RIGHT_ELBOW to "rightElbow",
    PoseLandmark.LEFT_WRIST to "leftWrist",
    PoseLandmark.RIGHT_WRIST to "rightWrist",
    PoseLandmark.LEFT_PINKY to "leftPinky",
    PoseLandmark.RIGHT_PINKY to "rightPinky",
    PoseLandmark.LEFT_INDEX to "leftIndex",
    PoseLandmark.RIGHT_INDEX to "rightIndex",
    PoseLandmark.LEFT_THUMB to "leftThumb",
    PoseLandmark.RIGHT_THUMB to "rightThumb",
    PoseLandmark.LEFT_HIP to "leftHip",
    PoseLandmark.RIGHT_HIP to "rightHip",
    PoseLandmark.LEFT_KNEE to "leftKnee",
    PoseLandmark.RIGHT_KNEE to "rightKnee",
    PoseLandmark.LEFT_ANKLE to "leftAnkle",
    PoseLandmark.RIGHT_ANKLE to "rightAnkle",
    PoseLandmark.LEFT_HEEL to "leftHeel",
    PoseLandmark.RIGHT_HEEL to "rightHeel",
    PoseLandmark.LEFT_FOOT_INDEX to "leftFootIndex",
    PoseLandmark.RIGHT_FOOT_INDEX to "rightFootIndex",
  )

  /** Zero poses or one; `x`/`z` over the width, `y` over the height. */
  fun detect(image: InputImage): List<Map<String, Any>> {
    val landmarks = awaitDetector(detector.process(image)).allPoseLandmarks
    if (landmarks.isEmpty()) return emptyList()
    val w = image.width.toDouble()
    val h = image.height.toDouble()
    return listOf(mapOf("landmarks" to landmarks.map {
      val p = it.position3D
      mapOf(
        "type" to (NAMES[it.landmarkType] ?: "unknown"),
        "x" to p.x / w,
        "y" to p.y / h,
        "z" to p.z / w,
        "inFrameLikelihood" to it.inFrameLikelihood.toDouble(),
      )
    }))
  }
}

object PosesFeature : MlKitFeature {
  override val name = "poses"
  override val imageModels = listOf(ImageModel("mlKitPoses", "poses", PoseAnalyzer::detect))
}
