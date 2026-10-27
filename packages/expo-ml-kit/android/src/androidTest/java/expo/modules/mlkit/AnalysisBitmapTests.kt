package expo.modules.mlkit

import android.graphics.Bitmap
import androidx.test.ext.junit.runners.AndroidJUnit4
import insidepics.testsupport.Fixtures
import insidepics.testsupport.meanDifference
import insidepics.testsupport.thumbnail
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertSame
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** `AnalysisBitmap` hands ML Kit the frame a viewer shows, a software
 *  ARGB_8888 bitmap, the longer side capped, whatever bitmap the handle
 *  holds, and never releases the handle's own. `ios/Tests/
 *  AnalysisImageTests.swift`'s Android side. */
@RunWith(AndroidJUnit4::class)
class AnalysisBitmapTests {
  @Test fun everyOrientationIsHandedOverUpright() {
    val reference = Fixtures.handle("face.jpg").thumbnail()
    for (name in Fixtures.orientations) {
      AnalysisBitmap.analyze(Fixtures.handle(name)) { image ->
        assertEquals(name, 400, image.width)
        assertEquals(name, 600, image.height)
        val diff = meanDifference(reference, image.bitmapInternal!!.thumbnail())
        assertTrue("$name is not upright: $diff", diff < 12)
      }
    }
  }

  @Test fun anArgbHandlePassesThroughUntouched() {
    val handle = Fixtures.handle("face.jpg").copy(Bitmap.Config.ARGB_8888, false)
    assertSame(handle, AnalysisBitmap.prepare(handle))
  }

  @Test fun everyOtherConfigIsCopiedAndTheHandleKept() {
    val source = Fixtures.handle("face.jpg").copy(Bitmap.Config.ARGB_8888, false)
    for (config in listOf(Bitmap.Config.RGB_565, Bitmap.Config.RGBA_F16, Bitmap.Config.HARDWARE)) {
      val handle = source.copy(config, false) ?: continue
      var seen: Bitmap? = null
      val size = AnalysisBitmap.analyze(handle) { image ->
        seen = image.bitmapInternal
        image.width to image.height
      }
      assertEquals("$config", 400 to 600, size)
      assertNotSame("$config is copied", handle, seen)
      assertEquals(Bitmap.Config.ARGB_8888, seen!!.config)
      assertTrue("$config: the copy is released after", seen!!.isRecycled)
      assertFalse("$config: the handle's own bitmap is kept", handle.isRecycled)
    }
  }

  @Test fun capsTheLongerSide() {
    val large = Bitmap.createBitmap(4000, 3000, Bitmap.Config.ARGB_8888)
    val size = AnalysisBitmap.analyze(large) { it.width to it.height }
    assertEquals(2048 to 1536, size)
    assertFalse(large.isRecycled)
  }

  @Test fun neverRoundsAThinImageToNothing() {
    assertEquals(2048 to 1, AnalysisBitmap.cappedSize(10000, 1))
    assertEquals(300 to 200, AnalysisBitmap.cappedSize(300, 200))
  }

  @Test fun refusesAReleasedImage() {
    val bitmap = Bitmap.createBitmap(8, 8, Bitmap.Config.ARGB_8888)
    bitmap.recycle()
    assertThrows(IllegalArgumentException::class.java) { AnalysisBitmap.prepare(bitmap) }
  }
}
