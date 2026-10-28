package expo.modules.mlkit

import androidx.test.ext.junit.runners.AndroidJUnit4
import insidepics.testsupport.Fixtures
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Face Mesh Detection (`detectFaceMesh`) on `face.jpg`, one face. */
@RunWith(AndroidJUnit4::class)
class FaceMeshTests {
  private fun detect(boundingBoxOnly: Boolean = false): List<Json> =
    AnalysisBitmap.analyze(Fixtures.handle("face.jpg")) { FaceMeshAnalyzer.detect(it, boundingBoxOnly) }

  @Test fun meshesTheFaceIn468PointsInsideItsBox() {
    val face = detect().single()
    assertUnitRect(face["boundingBox"], "box")
    val box = face["boundingBox"].json()
    val points = face["points"].list()
    assertEquals(468, points.size)
    val slack = 0.05
    for (point in points) {
      val x = point["x"] as Double
      val y = point["y"] as Double
      assertTrue("$point", x >= (box["x"] as Double) - slack && x <= (box["x"] as Double) + (box["width"] as Double) + slack)
      assertTrue("$point", y >= (box["y"] as Double) - slack && y <= (box["y"] as Double) + (box["height"] as Double) + slack)
      assertTrue("z is scaled like x: $point", kotlin.math.abs(point["z"] as Double) < 1)
    }
  }

  @Test fun trianglesAndContoursIndexThePoints() {
    val face = detect().single()
    @Suppress("UNCHECKED_CAST")
    val triangles = face["triangles"] as List<List<Int>>
    assertTrue("${triangles.size} triangles", triangles.size > 800)
    for (triangle in triangles) {
      assertEquals(3, triangle.size)
      assertTrue("$triangle", triangle.all { it in 0 until 468 })
    }
    @Suppress("UNCHECKED_CAST")
    val contours = face["contours"] as Map<String, List<Int>>
    assertEquals(12, contours.size)
    for ((name, indexes) in contours) assertTrue("$name is empty", indexes.isNotEmpty() && indexes.all { it in 0 until 468 })
  }

  @Test fun theEyesSitAboveTheLips() {
    val face = detect().single()
    val points = face["points"].list()
    @Suppress("UNCHECKED_CAST")
    val contours = face["contours"] as Map<String, List<Int>>
    fun meanY(name: String) = contours.getValue(name).map { points[it]["y"] as Double }.average()
    fun meanX(name: String) = contours.getValue(name).map { points[it]["x"] as Double }.average()
    assertTrue("eyes above the mouth (top-left origin)", meanY("leftEye") < meanY("upperLipTop"))
    // Face Mesh's left is the image's (the subject's right), unlike Face
    // Detection's.
    assertTrue("left eye on the image's left", meanX("leftEye") < meanX("rightEye"))
  }

  @Test fun boundingBoxOnlyFindsTheFaceWithoutAMesh() {
    val face = detect(boundingBoxOnly = true).single()
    assertUnitRect(face["boundingBox"], "box")
    assertEquals(emptyList<Any>(), face["points"])
    assertEquals(emptyList<Any>(), face["triangles"])
  }
}
