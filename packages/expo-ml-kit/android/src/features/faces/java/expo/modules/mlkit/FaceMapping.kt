package expo.modules.mlkit

/**
 * ML Kit faces onto Apple Vision's `FaceObservation` contract, so a caller's
 * one face pipeline (alignment, embedding, clustering) takes Android and iOS
 * faces alike. Pure Kotlin (no Android
 * imports) so the JVM tests run it as shipped (`run-jvm.sh`).
 *
 * Vision's frame, which every number here is converted to:
 * - the box normalized 0-1 with a BOTTOM-left origin: `y = 1 - bottom / H`;
 * - landmark points normalized to the box, also bottom-left;
 * - `leftEye` is the IMAGE-left eye (81 of 81 committed Vision fixtures), and
 *   `outerLips[0]` / `[6]` are the image-left / -right mouth corners;
 * - angles in radians, roll counter-clockwise positive. ML Kit's Euler Z is
 *   counter-clockwise positive too (same sign; degrees → radians). Its Y and X
 *   are converted the same way; Vision's yaw/pitch sign is not documented, and
 *   nothing reads them, so those two are best effort.
 *
 * Which side a pair (eyes, mouth corners, eyebrows) is on is decided from the
 * points themselves — across the face's own up axis, so a rolled face is
 * sided correctly — not from ML Kit's names, which are the SUBJECT's left.
 */
object FaceMapping {
  data class Pt(val x: Double, val y: Double)

  /** One ML Kit face in upright-image pixels (top-left origin). */
  data class RawFace(
    val left: Double,
    val top: Double,
    val right: Double,
    val bottom: Double,
    val eulerX: Double?,
    val eulerY: Double?,
    val eulerZ: Double?,
    /** `leftEye`, `rightEye`, `noseBase`, `mouthLeft`, `mouthRight`,
     *  `mouthBottom` — ML Kit's subject-side names. */
    val landmarks: Map<String, Pt>,
    /** ML Kit `FaceContour` names camel-cased (`face`, `leftEyebrowTop`,
     *  `noseBridge`, `upperLipBottom`, ...); present for prominent faces. */
    val contours: Map<String, List<Pt>>,
    /** Classification, when asked for: 0-1, the eyes the SUBJECT's. */
    val smiling: Double? = null,
    val leftEyeOpen: Double? = null,
    val rightEyeOpen: Double? = null,
  )

  /** Points between the two mouth corners `outerLips` carries, so the
   *  right corner lands at index 6 as in Vision's region. */
  private const val LIP_STEPS = 6

  fun toObservation(face: RawFace, width: Int, height: Int): Map<String, Any> {
    val w = width.toDouble()
    val h = height.toDouble()
    val bx = face.left / w
    val by = 1.0 - face.bottom / h
    val bw = (face.right - face.left) / w
    val bh = (face.bottom - face.top) / h
    fun inBox(p: Pt): Map<String, Double> =
      mapOf("x" to (p.x / w - bx) / bw, "y" to ((1.0 - p.y / h) - by) / bh)

    val out = mutableMapOf<String, Any>(
      "boundingBox" to mapOf("x" to bx, "y" to by, "width" to bw, "height" to bh),
      // ML Kit gives no detection score.
      "confidence" to 1.0,
    )
    face.eulerZ?.let { out["roll"] = Math.toRadians(it) }
    face.eulerY?.let { out["yaw"] = Math.toRadians(it) }
    face.eulerX?.let { out["pitch"] = Math.toRadians(it) }
    face.smiling?.let { out["smilingProbability"] = it }
    val (imageLeft, imageRight) = eyesOpenImageLeftFirst(face)
    imageLeft?.let { out["leftEyeOpenProbability"] = it }
    imageRight?.let { out["rightEyeOpenProbability"] = it }
    if (bw > 0 && bh > 0) {
      val regions = regions(face)
      if (regions.isNotEmpty()) {
        out["landmarks"] = regions.mapValues { (_, pts) -> pts.map(::inBox) }
      }
    }
    return out
  }

  /** Vision's regions, in pixels. The four alignment reads (eyes, nose,
   *  mouth corners) come from landmarks, which every face has; contours add
   *  the rest where ML Kit returned them. */
  fun regions(face: RawFace): Map<String, List<Pt>> {
    val lm = face.landmarks
    val eyeA = lm["leftEye"]
    val eyeB = lm["rightEye"]
    val mouthA = lm["mouthLeft"]
    val mouthB = lm["mouthRight"]
    val nose = lm["noseBase"]
    val out = linkedMapOf<String, List<Pt>>()
    val up = upAxis(eyeA, eyeB, mouthA, mouthB, nose) ?: return out
    val (leftEye, rightEye) = imageLeftFirst(up, eyeA!!, eyeB!!)
    out["leftEye"] = listOf(leftEye)
    out["rightEye"] = listOf(rightEye)
    if (nose != null) out["nose"] = listOf(nose)
    if (mouthA != null && mouthB != null) {
      val (l, r) = imageLeftFirst(up, mouthA, mouthB)
      val lips = (0..LIP_STEPS).map { lerp(l, r, it.toDouble() / LIP_STEPS) }
      out["outerLips"] = lips + listOfNotNull(lm["mouthBottom"])
    }
    contourRegions(face.contours, up, out)
    return out
  }

  /** The eye-open scores, image-left eye first, as the landmarks are named:
   *  ML Kit scores the subject's eyes, sided here like the eye landmarks
   *  (across the face's up axis); without them, as an unmirrored photo shows
   *  a subject, their left eye on the image's right. */
  fun eyesOpenImageLeftFirst(face: RawFace): Pair<Double?, Double?> {
    val lm = face.landmarks
    val up = upAxis(lm["leftEye"], lm["rightEye"], lm["mouthLeft"], lm["mouthRight"], lm["noseBase"])
    val subjectLeftIsImageLeft = up != null && side(up, lm["leftEye"]!!, lm["rightEye"]!!) <= 0
    return if (subjectLeftIsImageLeft) face.leftEyeOpen to face.rightEyeOpen else face.rightEyeOpen to face.leftEyeOpen
  }

  private fun contourRegions(
    c: Map<String, List<Pt>>,
    up: Pt,
    out: MutableMap<String, List<Pt>>,
  ) {
    c["face"]?.takeIf { it.isNotEmpty() }?.let { out["faceContour"] = it }
    c["noseBridge"]?.takeIf { it.isNotEmpty() }?.let { out["noseCrest"] = it }
    val inner = (c["upperLipBottom"] ?: emptyList()) +
      (c["lowerLipTop"] ?: emptyList()).asReversed()
    if (inner.isNotEmpty()) out["innerLips"] = inner
    val browA = (c["leftEyebrowTop"] ?: emptyList()) + (c["leftEyebrowBottom"] ?: emptyList())
    val browB = (c["rightEyebrowTop"] ?: emptyList()) + (c["rightEyebrowBottom"] ?: emptyList())
    if (browA.isNotEmpty() && browB.isNotEmpty()) {
      val leftFirst = side(up, centroid(browA), centroid(browB)) < 0
      out["leftEyebrow"] = if (leftFirst) browA else browB
      out["rightEyebrow"] = if (leftFirst) browB else browA
    }
  }

  /** The face's "up" in image pixels (y down): mouth (or nose) to eyes. */
  private fun upAxis(eyeA: Pt?, eyeB: Pt?, mouthA: Pt?, mouthB: Pt?, nose: Pt?): Pt? {
    if (eyeA == null || eyeB == null) return null
    val eyes = lerp(eyeA, eyeB, 0.5)
    val below = if (mouthA != null && mouthB != null) lerp(mouthA, mouthB, 0.5) else nose
    if (below != null) {
      val up = Pt(eyes.x - below.x, eyes.y - below.y)
      if (up.x != 0.0 || up.y != 0.0) return up
    }
    // No point below the eyes: the eye line's normal, assuming an upright head.
    val ex = eyeB.x - eyeA.x
    val ey = eyeB.y - eyeA.y
    val n = Pt(ey, -ex)
    return if (n.y <= 0) n else Pt(-n.x, -n.y)
  }

  /** Negative when `a` is on the image-left of `b` across `up`. */
  private fun side(up: Pt, a: Pt, b: Pt): Double {
    val vx = a.x - b.x
    val vy = a.y - b.y
    return up.x * vy - up.y * vx
  }

  private fun imageLeftFirst(up: Pt, a: Pt, b: Pt): Pair<Pt, Pt> =
    if (side(up, a, b) <= 0) a to b else b to a

  private fun lerp(a: Pt, b: Pt, t: Double) = Pt(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)

  private fun centroid(points: List<Pt>): Pt =
    Pt(points.sumOf { it.x } / points.size, points.sumOf { it.y } / points.size)
}
