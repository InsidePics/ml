package expo.modules.mlkit

import expo.modules.mlkit.FaceMapping.Pt
import expo.modules.mlkit.FaceMapping.RawFace
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * ML Kit faces onto Vision's frame, checked the way `face/align.ts` reads it:
 * every landmark lifted back to image pixels with align.ts's own formula,
 * `[bx + x * bw, 1 - (by + y * bh)]`, must land on the pixel it came from,
 * with the IMAGE-left eye and mouth corner first.
 */
class FaceMappingTests {
  private val w = 1000
  private val h = 800

  /** A frontal face; ML Kit names the SUBJECT's sides, so its "left" eye
   *  and mouth corner are on the image right. */
  private val frontal = RawFace(
    left = 300.0, top = 200.0, right = 500.0, bottom = 450.0,
    eulerX = -10.0, eulerY = 20.0, eulerZ = 30.0,
    landmarks = mapOf(
      "leftEye" to Pt(450.0, 280.0),
      "rightEye" to Pt(350.0, 280.0),
      "noseBase" to Pt(400.0, 340.0),
      "mouthLeft" to Pt(440.0, 390.0),
      "mouthRight" to Pt(360.0, 390.0),
      "mouthBottom" to Pt(400.0, 410.0),
    ),
    contours = mapOf(
      "leftEyebrowTop" to listOf(Pt(430.0, 250.0), Pt(470.0, 250.0)),
      "rightEyebrowTop" to listOf(Pt(330.0, 250.0), Pt(370.0, 250.0)),
      "noseBridge" to listOf(Pt(400.0, 280.0), Pt(400.0, 320.0)),
    ),
  )

  /** align.ts's lift, back to pixels (top-left origin). */
  @Suppress("UNCHECKED_CAST")
  private fun lifted(obs: Map<String, Any>, region: String): List<Pt> {
    val box = obs["boundingBox"] as Map<String, Double>
    val lm = obs["landmarks"] as Map<String, List<Map<String, Double>>>
    return lm.getValue(region).map {
      Pt(
        (box.getValue("x") + it.getValue("x") * box.getValue("width")) * w,
        (1.0 - (box.getValue("y") + it.getValue("y") * box.getValue("height"))) * h,
      )
    }
  }

  private fun assertPt(expected: Pt, actual: Pt) {
    assertEquals(expected.x, actual.x, 1e-9)
    assertEquals(expected.y, actual.y, 1e-9)
  }

  @Test fun boxIsNormalizedWithABottomLeftOrigin() {
    @Suppress("UNCHECKED_CAST")
    val box = FaceMapping.toObservation(frontal, w, h)["boundingBox"] as Map<String, Double>
    assertEquals(0.3, box.getValue("x"), 1e-12)
    assertEquals(1 - 450.0 / 800, box.getValue("y"), 1e-12)
    assertEquals(0.2, box.getValue("width"), 1e-12)
    assertEquals(250.0 / 800, box.getValue("height"), 1e-12)
  }

  @Test fun alignmentPointsLiftBackToTheirPixelsImageLeftFirst() {
    val obs = FaceMapping.toObservation(frontal, w, h)
    assertPt(Pt(350.0, 280.0), lifted(obs, "leftEye").single())
    assertPt(Pt(450.0, 280.0), lifted(obs, "rightEye").single())
    assertPt(Pt(400.0, 340.0), lifted(obs, "nose").single())
    val lips = lifted(obs, "outerLips")
    assertPt(Pt(360.0, 390.0), lips[0])
    assertPt(Pt(440.0, 390.0), lips[6])
    assertPt(Pt(400.0, 410.0), lips[7])
    assertPt(Pt(330.0, 250.0), lifted(obs, "leftEyebrow")[0])
    assertPt(Pt(400.0, 280.0), lifted(obs, "noseCrest")[0])
  }

  @Test fun sidesComeFromThePointsNotTheNames() {
    val swapped = frontal.copy(
      landmarks = frontal.landmarks + mapOf(
        "leftEye" to frontal.landmarks.getValue("rightEye"),
        "rightEye" to frontal.landmarks.getValue("leftEye"),
        "mouthLeft" to frontal.landmarks.getValue("mouthRight"),
        "mouthRight" to frontal.landmarks.getValue("mouthLeft"),
      )
    )
    assertEquals(FaceMapping.regions(frontal), FaceMapping.regions(swapped))
  }

  @Test fun aFaceRolledAQuarterTurnIsSidedAlongItsOwnAxis() {
    // Head rolled 90° counter-clockwise: eyes stacked, the face looks left.
    // Its image-left eye (in the face's frame) is the LOWER one.
    val rolled = frontal.copy(
      landmarks = mapOf(
        "leftEye" to Pt(350.0, 250.0),
        "rightEye" to Pt(350.0, 350.0),
        "mouthLeft" to Pt(450.0, 260.0),
        "mouthRight" to Pt(450.0, 340.0),
      ),
      contours = emptyMap(),
    )
    val regions = FaceMapping.regions(rolled)
    assertPt(Pt(350.0, 350.0), regions.getValue("leftEye").single())
    assertPt(Pt(450.0, 340.0), regions.getValue("outerLips")[0])
  }

  @Test fun withoutMouthCornersTheNoseGivesTheFaceItsUp() {
    // Rolled a quarter turn, as above, but only eyes and nose: the nose sits
    // to the image right of the eyes, so "up" points left and the lower eye
    // is the image-left one.
    val noseOnly = frontal.copy(
      landmarks = mapOf(
        "leftEye" to Pt(350.0, 250.0),
        "rightEye" to Pt(350.0, 350.0),
        "noseBase" to Pt(420.0, 300.0),
      ),
      contours = emptyMap(),
    )
    val regions = FaceMapping.regions(noseOnly)
    assertPt(Pt(350.0, 350.0), regions.getValue("leftEye").single())
    assertFalse(regions.containsKey("outerLips"))
  }

  @Test fun withEyesAloneAnUprightHeadIsAssumed() {
    val eyesOnly = frontal.copy(
      landmarks = mapOf("leftEye" to Pt(450.0, 280.0), "rightEye" to Pt(350.0, 280.0)),
      contours = emptyMap(),
    )
    assertPt(Pt(350.0, 280.0), FaceMapping.regions(eyesOnly).getValue("leftEye").single())
  }

  @Test fun eyebrowsAreSidedLikeTheEyesOnARolledFace() {
    val rolled = frontal.copy(
      landmarks = mapOf(
        "leftEye" to Pt(350.0, 250.0),
        "rightEye" to Pt(350.0, 350.0),
        "mouthLeft" to Pt(450.0, 260.0),
        "mouthRight" to Pt(450.0, 340.0),
      ),
      contours = mapOf(
        "leftEyebrowTop" to listOf(Pt(320.0, 240.0)),
        "rightEyebrowTop" to listOf(Pt(320.0, 360.0)),
      ),
    )
    assertPt(Pt(320.0, 360.0), FaceMapping.regions(rolled).getValue("leftEyebrow").single())
  }

  @Test fun aDegenerateBoxCarriesNoLandmarks() {
    val flat = frontal.copy(right = frontal.left)
    assertFalse(FaceMapping.toObservation(flat, w, h).containsKey("landmarks"))
  }

  @Test fun anglesAreRadiansWithTheirSigns() {
    val obs = FaceMapping.toObservation(frontal, w, h)
    assertEquals(Math.PI / 6, obs["roll"] as Double, 1e-12)
    assertEquals(Math.toRadians(20.0), obs["yaw"] as Double, 1e-12)
    assertEquals(Math.toRadians(-10.0), obs["pitch"] as Double, 1e-12)
    assertEquals(1.0, obs["confidence"] as Double, 0.0)
  }

  @Test fun aFaceWithoutEyesHasNoLandmarks() {
    val obs = FaceMapping.toObservation(frontal.copy(landmarks = emptyMap()), w, h)
    assertFalse(obs.containsKey("landmarks"))
    assertTrue(obs.containsKey("boundingBox"))
  }

  /**
   * The recorded fixture (`android/src/test/fixtures/face.json`): this mapping's output for
   * [frontal]. A caller that aligns faces from these landmarks can pin its own
   * tests to it. `RECORD_FIXTURE=1` rewrites it.
   */
  @Test fun theSharedFixtureIsThisMappingsOutput() {
    val file = File(System.getProperty("faceFixture") ?: error("run via run-jvm.sh"))
    val fixture = Json.encode(
      mapOf(
        "imageWidth" to w,
        "imageHeight" to h,
        "observation" to FaceMapping.toObservation(frontal, w, h),
        "expectedPixels" to listOf(
          listOf(350.0, 280.0), listOf(450.0, 280.0), listOf(400.0, 340.0),
          listOf(360.0, 390.0), listOf(440.0, 390.0),
        ),
      )
    ) + "\n"
    if (System.getenv("RECORD_FIXTURE") == "1") file.writeText(fixture)
    assertEquals(file.readText(), fixture)
  }

  /**
   * One object both families saw on a phone (a barcode): Apple Vision's box,
   * bottom-left, and ML Kit's pixels, top-left. Mapped onto Vision's frame
   * they are the same box (a caller pairing the two detectors' faces by overlap, at IoU >= 0.5, pairs them); taken as
   * stored, with no flip, they do not overlap at all.
   */
  @Test
  fun boxLandsInVisionsFrameBesideApplesBox() {
    val apple = listOf(0.339, 0.212, 0.338, 0.149)
    val mlKit = RawFace(
      left = 0.341 * w, top = 0.628 * h, right = 0.683 * w, bottom = 0.808 * h,
      eulerX = 0.0, eulerY = 0.0, eulerZ = 0.0,
      landmarks = emptyMap(), contours = emptyMap(),
    )
    @Suppress("UNCHECKED_CAST")
    val box = FaceMapping.toObservation(mlKit, w, h)["boundingBox"] as Map<String, Double>
    val mapped = listOf(box["x"]!!, box["y"]!!, box["width"]!!, box["height"]!!)
    assertTrue(iou(apple, mapped) >= 0.5)
    assertTrue(iou(apple, listOf(0.341, 0.628, 0.342, 0.18)) == 0.0)
  }

  private fun iou(a: List<Double>, b: List<Double>): Double {
    val ix = maxOf(0.0, minOf(a[0] + a[2], b[0] + b[2]) - maxOf(a[0], b[0]))
    val iy = maxOf(0.0, minOf(a[1] + a[3], b[1] + b[3]) - maxOf(a[1], b[1]))
    val inter = ix * iy
    return inter / (a[2] * a[3] + b[2] * b[3] - inter)
  }
}
