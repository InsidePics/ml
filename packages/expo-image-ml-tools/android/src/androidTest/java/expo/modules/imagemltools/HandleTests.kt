package expo.modules.imagemltools

import androidx.test.ext.junit.runners.AndroidJUnit4
import insidepics.testsupport.Fixtures
import insidepics.testsupport.bytes
import insidepics.testsupport.meanDifference
import insidepics.testsupport.thumbnail
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * A handle's pixels on Android: however the photo was stored (turned, with
 * an EXIF orientation to show it upright; JPEG or HEIC), the tools read it
 * upright, pixel for pixel. `ios/Tests/HandleTests.swift`'s Android side.
 */
@RunWith(AndroidJUnit4::class)
class HandleTests {
  @Test fun everyOrientationReadsUprightPixelForPixel() {
    for (name in Fixtures.orientations + listOf("face.jpg", "text.jpg")) {
      val read = Pixels.rgba(Fixtures.handle(name))
      val rotated = Fixtures.rotatedDecode(name)
      assertEquals("$name width", rotated.width, read.width)
      assertEquals("$name height", rotated.height, read.height)
      val diff = meanDifference(rotated.bytes(), read.pixels)
      assertEquals("$name: mean difference $diff of 255", 0.0, diff, 0.0)
    }
  }

  @Test fun everyOrientationIsTheUprightPhoto() {
    // Against the photo itself, not a turn made here: recompressed, so close
    // rather than equal; a wrong turn is far off.
    val reference = Fixtures.handle("face.jpg").thumbnail()
    for (name in Fixtures.orientations) {
      val handle = Fixtures.handle(name)
      assertEquals("$name width", 400, handle.width)
      assertEquals("$name height", 600, handle.height)
      val diff = meanDifference(reference, handle.thumbnail())
      assertTrue("$name is not upright: $diff", diff < 12)
    }
  }

  @Test fun aHandleIsReadWithoutChangingIt() {
    val handle = Fixtures.handle("face.jpg")
    val before = handle.bytes()
    Pixels.rgba(handle)
    assertTrue(!handle.isRecycled)
    assertEquals(0.0, meanDifference(before, handle.bytes()), 0.0)
  }
}
