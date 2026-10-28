#if canImport(MLKitPoseDetection) && !targetEnvironment(simulator)
import CoreGraphics
import MLKitPoseDetection
import MLKitPoseDetectionCommon
import MLKitVision

/// Pose Detection (base, bundled), single-image mode: one person, 33 points.
enum PoseAnalyzer {
  private static let detector: PoseDetector = {
    let options = PoseDetectorOptions()
    options.detectorMode = .singleImage
    return PoseDetector.poseDetector(options: options)
  }()

  /// Android's `PoseLandmark` names, camel-cased (iOS calls some differently:
  /// `mouthLeft`, `leftPinkyFinger`, `leftToe`).
  static let poseLandmarks: [PoseLandmarkType: String] = [
    .nose: "nose",
    .leftEyeInner: "leftEyeInner",
    .leftEye: "leftEye",
    .leftEyeOuter: "leftEyeOuter",
    .rightEyeInner: "rightEyeInner",
    .rightEye: "rightEye",
    .rightEyeOuter: "rightEyeOuter",
    .leftEar: "leftEar",
    .rightEar: "rightEar",
    .mouthLeft: "leftMouth",
    .mouthRight: "rightMouth",
    .leftShoulder: "leftShoulder",
    .rightShoulder: "rightShoulder",
    .leftElbow: "leftElbow",
    .rightElbow: "rightElbow",
    .leftWrist: "leftWrist",
    .rightWrist: "rightWrist",
    .leftPinkyFinger: "leftPinky",
    .rightPinkyFinger: "rightPinky",
    .leftIndexFinger: "leftIndex",
    .rightIndexFinger: "rightIndex",
    .leftThumb: "leftThumb",
    .rightThumb: "rightThumb",
    .leftHip: "leftHip",
    .rightHip: "rightHip",
    .leftKnee: "leftKnee",
    .rightKnee: "rightKnee",
    .leftAnkle: "leftAnkle",
    .rightAnkle: "rightAnkle",
    .leftHeel: "leftHeel",
    .rightHeel: "rightHeel",
    .leftToe: "leftFootIndex",
    .rightToe: "rightFootIndex",
  ]

  /// Zero poses or one; `x`/`z` over the width, `y` over the height. The
  /// accurate model (`posesAccurate`) passes its own detector.
  static func detect(_ image: VisionImage, _ size: CGSize, with: PoseDetector? = nil) throws
    -> [[String: Any]]
  {
    try (with ?? detector).results(in: image).prefix(1).compactMap { pose -> [String: Any]? in
      if pose.landmarks.isEmpty { return nil }
      return [
        "landmarks": pose.landmarks.map { landmark in
          [
            "type": poseLandmarks[landmark.type] ?? "unknown",
            "x": Double(landmark.position.x / size.width),
            "y": Double(landmark.position.y / size.height),
            "z": Double(landmark.position.z / size.width),
            "inFrameLikelihood": Double(landmark.inFrameLikelihood),
          ] as [String: Any]
        }
      ]
    }
  }
}
#endif
