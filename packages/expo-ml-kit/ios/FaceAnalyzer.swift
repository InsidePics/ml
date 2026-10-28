#if canImport(MLKitFaceDetection) && !targetEnvironment(simulator)
import CoreGraphics
import Foundation
import MLKitFaceDetection
import MLKitVision
import UIKit

/// ML Kit Face Detection onto Apple Vision's `FaceObservation` contract — a
/// line-for-line port of Android's `FaceAnalyzer.kt` + `FaceMapping.kt`, so
/// both platforms write one `mlKitFaces` shape (the `mlKitArtifacts` test pins
/// the region names together). Landmarks are returned for every face, so the
/// alignment points come from them; contours, which ML Kit only returns for
/// the most prominent faces, fill the other regions best effort.
///
/// Vision's frame, which every number here is converted to:
/// - the box normalized 0-1 with a BOTTOM-left origin: `y = 1 - bottom / H`;
/// - landmark points normalized to the box, also bottom-left;
/// - `leftEye` is the IMAGE-left eye, and `outerLips[0]` / `[6]` are the
///   image-left / -right mouth corners;
/// - angles in radians: Euler Z / Y / X → roll / yaw / pitch, as on Android.
///
/// Which side a pair (eyes, mouth corners, eyebrows) is on is decided from the
/// points themselves — across the face's own up axis — not from ML Kit's
/// names, which are the SUBJECT's left.
enum FaceAnalyzer {
  private static let detector: FaceDetector = {
    let options = FaceDetectorOptions()
    options.performanceMode = .accurate
    options.landmarkMode = .all
    options.contourMode = .all
    // Down from 0.1: group photos' small faces, as Vision finds them.
    options.minFaceSize = 0.05
    return FaceDetector.faceDetector(options: options)
  }()

  private static let landmarkTypes: [(String, FaceLandmarkType)] = [
    ("leftEye", .leftEye),
    ("rightEye", .rightEye),
    ("noseBase", .noseBase),
    ("mouthLeft", .mouthLeft),
    ("mouthRight", .mouthRight),
    ("mouthBottom", .mouthBottom),
  ]

  private static let contourTypes: [(String, FaceContourType)] = [
    ("face", .face),
    ("leftEyebrowTop", .leftEyebrowTop),
    ("leftEyebrowBottom", .leftEyebrowBottom),
    ("rightEyebrowTop", .rightEyebrowTop),
    ("rightEyebrowBottom", .rightEyebrowBottom),
    ("noseBridge", .noseBridge),
    ("upperLipBottom", .upperLipBottom),
    ("lowerLipTop", .lowerLipTop),
  ]

  /// Points between the two mouth corners `outerLips` carries, so the right
  /// corner lands at index 6 as in Vision's region.
  private static let lipSteps = 6

  static func detect(_ image: UIImage) throws -> [[String: Any]] {
    let w = Double(image.size.width)
    let h = Double(image.size.height)
    let faces = try detector.results(in: MlKitAnalyzer.visionImage(image))
    return FaceBoxes.outermost(faces.map(\.frame)).map { observation(faces[$0], w, h) }
  }

  private static func pt(_ p: VisionPoint) -> CGPoint { CGPoint(x: p.x, y: p.y) }

  private static func observation(_ face: Face, _ w: Double, _ h: Double) -> [String: Any] {
    let box = face.frame
    let bx = Double(box.minX) / w
    let by = 1.0 - Double(box.maxY) / h
    let bw = Double(box.width) / w
    let bh = Double(box.height) / h
    func inBox(_ p: CGPoint) -> [String: Double] {
      ["x": (Double(p.x) / w - bx) / bw, "y": ((1.0 - Double(p.y) / h) - by) / bh]
    }

    var out: [String: Any] = [
      "boundingBox": ["x": bx, "y": by, "width": bw, "height": bh],
      // ML Kit gives no detection score.
      "confidence": 1.0,
    ]
    if face.hasHeadEulerAngleZ { out["roll"] = radians(face.headEulerAngleZ) }
    if face.hasHeadEulerAngleY { out["yaw"] = radians(face.headEulerAngleY) }
    if face.hasHeadEulerAngleX { out["pitch"] = radians(face.headEulerAngleX) }
    if bw > 0 && bh > 0 {
      let found = regions(face)
      if !found.isEmpty { out["landmarks"] = found.mapValues { $0.map(inBox) } }
    }
    return out
  }

  private static func radians(_ degrees: CGFloat) -> Double { Double(degrees) * .pi / 180 }

  /// Vision's regions, in pixels. The four alignment reads (eyes, nose, mouth
  /// corners) come from landmarks, which every face has; contours add the
  /// rest where ML Kit returned them.
  private static func regions(_ face: Face) -> [String: [CGPoint]] {
    var lm: [String: CGPoint] = [:]
    for (name, type) in landmarkTypes {
      if let landmark = face.landmark(ofType: type) { lm[name] = pt(landmark.position) }
    }
    var out: [String: [CGPoint]] = [:]
    guard let eyeA = lm["leftEye"], let eyeB = lm["rightEye"],
      let up = upAxis(eyeA, eyeB, lm["mouthLeft"], lm["mouthRight"], lm["noseBase"])
    else { return out }
    let (leftEye, rightEye) = imageLeftFirst(up, eyeA, eyeB)
    out["leftEye"] = [leftEye]
    out["rightEye"] = [rightEye]
    if let nose = lm["noseBase"] { out["nose"] = [nose] }
    if let mouthA = lm["mouthLeft"], let mouthB = lm["mouthRight"] {
      let (l, r) = imageLeftFirst(up, mouthA, mouthB)
      let lips = (0...lipSteps).map { lerp(l, r, Double($0) / Double(lipSteps)) }
      out["outerLips"] = lips + [lm["mouthBottom"]].compactMap { $0 }
    }
    var c: [String: [CGPoint]] = [:]
    for (name, type) in contourTypes {
      if let points = face.contour(ofType: type)?.points, !points.isEmpty {
        c[name] = points.map(pt)
      }
    }
    contourRegions(c, up, &out)
    return out
  }

  private static func contourRegions(
    _ c: [String: [CGPoint]], _ up: CGPoint, _ out: inout [String: [CGPoint]]
  ) {
    if let face = c["face"], !face.isEmpty { out["faceContour"] = face }
    if let bridge = c["noseBridge"], !bridge.isEmpty { out["noseCrest"] = bridge }
    let inner = (c["upperLipBottom"] ?? []) + (c["lowerLipTop"] ?? []).reversed()
    if !inner.isEmpty { out["innerLips"] = inner }
    let browA = (c["leftEyebrowTop"] ?? []) + (c["leftEyebrowBottom"] ?? [])
    let browB = (c["rightEyebrowTop"] ?? []) + (c["rightEyebrowBottom"] ?? [])
    if !browA.isEmpty && !browB.isEmpty {
      let leftFirst = side(up, centroid(browA), centroid(browB)) < 0
      out["leftEyebrow"] = leftFirst ? browA : browB
      out["rightEyebrow"] = leftFirst ? browB : browA
    }
  }

  /// The face's "up" in image pixels (y down): mouth (or nose) to eyes.
  private static func upAxis(
    _ eyeA: CGPoint, _ eyeB: CGPoint, _ mouthA: CGPoint?, _ mouthB: CGPoint?, _ nose: CGPoint?
  ) -> CGPoint? {
    let eyes = lerp(eyeA, eyeB, 0.5)
    let below: CGPoint?
    if let mouthA, let mouthB { below = lerp(mouthA, mouthB, 0.5) } else { below = nose }
    if let below {
      let up = CGPoint(x: eyes.x - below.x, y: eyes.y - below.y)
      if up.x != 0 || up.y != 0 { return up }
    }
    // No point below the eyes: the eye line's normal, assuming an upright head.
    let ex = eyeB.x - eyeA.x
    let ey = eyeB.y - eyeA.y
    let n = CGPoint(x: ey, y: -ex)
    return n.y <= 0 ? n : CGPoint(x: -n.x, y: -n.y)
  }

  /// Negative when `a` is on the image-left of `b` across `up`.
  private static func side(_ up: CGPoint, _ a: CGPoint, _ b: CGPoint) -> Double {
    let vx = Double(a.x - b.x)
    let vy = Double(a.y - b.y)
    return Double(up.x) * vy - Double(up.y) * vx
  }

  private static func imageLeftFirst(_ up: CGPoint, _ a: CGPoint, _ b: CGPoint)
    -> (CGPoint, CGPoint)
  {
    side(up, a, b) <= 0 ? (a, b) : (b, a)
  }

  private static func lerp(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
    CGPoint(x: Double(a.x) + Double(b.x - a.x) * t, y: Double(a.y) + Double(b.y - a.y) * t)
  }

  private static func centroid(_ points: [CGPoint]) -> CGPoint {
    let n = Double(points.count)
    return CGPoint(
      x: points.reduce(0) { $0 + Double($1.x) } / n,
      y: points.reduce(0) { $0 + Double($1.y) } / n)
  }
}
#endif
