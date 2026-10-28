#if canImport(MLKitPoseDetectionAccurate) && !targetEnvironment(simulator)
import MLKitPoseDetectionAccurate
import MLKitPoseDetectionCommon

/// Pose Detection's accurate model (bundled), single-image mode: the same
/// 33 landmarks as `poses`, steadier and slower.
enum AccuratePoseAnalyzer {
  static let detector: PoseDetector = {
    let options = AccuratePoseDetectorOptions()
    options.detectorMode = .singleImage
    return PoseDetector.poseDetector(options: options)
  }()
}
#endif
