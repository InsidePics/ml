package expo.modules.imagemltools

import android.graphics.Bitmap
import androidx.test.ext.junit.runners.AndroidJUnit4
import insidepics.testsupport.Fixtures
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** A phone camera's 12 MP photo (3024×4032), through every tool again and
 *  again, in each bitmap kind a handle holds: the copies made to read it
 *  are released, so the heap ends where it began. */
@RunWith(AndroidJUnit4::class)
class LargeImageTests {
  private val clipMean = doubleArrayOf(0.485, 0.456, 0.406)
  private val clipStd = doubleArrayOf(0.229, 0.224, 0.225)

  private fun usedHeap(): Long {
    repeat(3) { System.gc(); System.runFinalization() }
    val runtime = Runtime.getRuntime()
    return runtime.totalMemory() - runtime.freeMemory()
  }

  /** Each tool once, as the module runs it: the pixels read anew per call.
   *  A function of its own, so nothing it read outlives it in the test's
   *  frame. */
  private fun everyTool(handle: Bitmap) {
    val tensor = ImageMath.tensor(
      Pixels.rgba(handle), 256, 256, Fit.COVER, Filter.NEAREST, clipMean, clipStd, Layout.NCHW,
    )
    assertEquals(3 * 256 * 256, tensor.size)
    val crop = ImageMath.warp(Pixels.rgba(handle), doubleArrayOf(0.1, 0.0, -100.0, 0.0, 0.1, -100.0), 112, 112)
    assertTrue(ImageMath.sharpness(crop) > 0)
    assertEquals(64, ImageMath.histogram(Pixels.rgba(handle), 64).size)
  }

  @Test fun everyToolOnATwelveMegapixelPhotoKeepsTheHeapFlat() {
    val photo = Bitmap.createScaledBitmap(Fixtures.handle("face.jpg"), 3024, 4032, true)
    for (config in listOf(Bitmap.Config.ARGB_8888, Bitmap.Config.RGBA_F16, Bitmap.Config.HARDWARE)) {
      val handle = (if (config == photo.config) photo else photo.copy(config, false)) ?: error("no $config bitmap")
      val before = usedHeap()
      repeat(5) { everyTool(handle) }
      val grown = usedHeap() - before
      assertTrue("$config: the heap grew by ${grown / 1_000_000} MB", grown < 20_000_000)
      assertFalse("$config: the handle is kept", handle.isRecycled)
    }
  }
}
