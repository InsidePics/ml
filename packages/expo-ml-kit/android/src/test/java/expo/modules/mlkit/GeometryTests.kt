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

}
