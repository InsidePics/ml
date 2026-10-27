package expo.modules.mlkit

import org.junit.Assert.assertEquals
import org.junit.Test

class GeometryTests {
  @Test fun rectIsNormalizedWithATopLeftOrigin() {
    assertEquals(
      mapOf("x" to 0.1, "y" to 0.25, "width" to 0.4, "height" to 0.5),
      Geometry.rect(100.0, 200.0, 500.0, 600.0, 1000, 800),
    )
  }

  private fun box(l: Int, t: Int, r: Int, b: Int) =
    Geometry.Box(l.toDouble(), t.toDouble(), r.toDouble(), b.toDouble())

  @Test fun aFaceFoundAgainInsideItselfIsDropped() {
    // The bespectacled fixture at 1536×2048: the face, and its lower half.
    val face = box(380, 357, 1079, 1264)
    val lowerHalf = box(346, 529, 801, 999)
    assertEquals(listOf(0), Geometry.outermost(listOf(face, lowerHalf)))
    assertEquals(listOf(1), Geometry.outermost(listOf(lowerHalf, face)))
  }

  @Test fun neighbouringFacesAreAllKept() {
    val adult = box(0, 0, 100, 100)
    val childInFront = box(70, 60, 130, 120) // a third of it over the adult
    val apart = box(300, 0, 400, 100)
    val same = box(300, 0, 400, 100) // equal boxes: neither is larger
    assertEquals(listOf(0, 1, 2, 3), Geometry.outermost(listOf(adult, childInFront, apart, same)))
  }

  @Test fun anEmptyBoxInsideAFaceIsDropped() {
    assertEquals(listOf(0), Geometry.outermost(listOf(box(0, 0, 10, 10), box(5, 5, 5, 5))))
  }
}
