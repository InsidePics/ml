package expo.modules.mlkit

import androidx.test.ext.junit.runners.AndroidJUnit4
import insidepics.testsupport.Fixtures
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import kotlin.math.abs

/**
 * ML Kit's faces in Apple Vision's `FaceObservation` frame: box normalized
 * with a bottom-left origin, landmarks normalized to the box, `leftEye` the
 * image-left eye, `outerLips[0]`/`[6]` the image-left/-right mouth corners.
 * `ios/Tests/FaceTests.swift`, test for test.
 */
@RunWith(AndroidJUnit4::class)
class FaceTests {
  @Test fun findsTheFaceWithItsLandmarks() {
    val faces = detectFaces("face.jpg")
    assertEquals("face.jpg holds one face", 1, faces.size)
    val face = faces[0]
    assertUnitRect(face["boundingBox"], "face box")
    val landmarks = face["landmarks"].json()
    for (region in listOf("leftEye", "rightEye", "nose", "outerLips")) {
      val points = landmarks[region].list()
      assertTrue(region, points.isNotEmpty())
      for (p in points) {
        assertTrue("$region x in the box", (p["x"] as Double) in -0.1..1.1)
        assertTrue("$region y in the box", (p["y"] as Double) in -0.1..1.1)
      }
    }
    assertTrue("corners at 0 and 6", landmarks["outerLips"].list().size >= 7)
  }

  @Test fun putsTheImageLeftEyeLeftAndTheEyesAboveTheMouth() {
    val landmarks = detectFaces("face.jpg")[0]["landmarks"].json()
    val left = landmarks["leftEye"].list()[0]
    val right = landmarks["rightEye"].list()[0]
    val lips = landmarks["outerLips"].list()
    assertTrue("leftEye is the image-left eye", (left["x"] as Double) < (right["x"] as Double))
    assertTrue("outerLips[0] is the image-left corner", (lips[0]["x"] as Double) < (lips[6]["x"] as Double))
    // Bottom-left origin: up is a larger y.
    assertTrue("eyes above the mouth", (left["y"] as Double) > (lips[0]["y"] as Double))
  }

  @Test fun placesTheEyesWhereTheyAreInThePhoto() {
    // face.jpg (400×600): the eyes sit near (162, 240) and (263, 238) px,
    // top-left origin.
    val face = detectFaces("face.jpg")[0]
    val left = landmarkInImage(face, "leftEye")
    val right = landmarkInImage(face, "rightEye")
    assertEquals(162.0 / 400, left.first, 0.03)
    assertEquals(240.0 / 600, left.second, 0.03)
    assertEquals(263.0 / 400, right.first, 0.03)
    assertEquals(238.0 / 600, right.second, 0.03)
  }

  @Test fun findsTheSameFaceUnderEveryOrientation() {
    val reference = box(detectFaces("face.jpg")[0])
    for (name in Fixtures.orientations) {
      val faces = detectFaces(name)
      assertEquals(name, 1, faces.size)
      val found = box(faces[0])
      for (i in 0 until 4) assertEquals("$name box[$i]", reference[i], found[i], 0.02)
    }
  }

  @Test fun findsNoFaceInALandscape() {
    assertEquals(0, detectFaces("landscape.jpg").size)
  }

  @Test fun reportsHeadAnglesInRadians() {
    val face = detectFaces("face.jpg")[0]
    for (angle in listOf("roll", "yaw", "pitch")) {
      val value = face[angle] as? Double ?: error("missing $angle")
      assertTrue("$angle in radians, near upright", abs(value) < Math.PI / 2)
    }
  }
}
