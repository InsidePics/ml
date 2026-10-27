package expo.modules.mlkit

import android.graphics.Bitmap
import androidx.test.ext.junit.runners.AndroidJUnit4
import insidepics.testsupport.Fixtures
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** A phone camera's 12 MP photo (4032×3024), through every model again and
 *  again: each call's copy is released, so the heap ends where it began,
 *  and the handle is never touched. */
@RunWith(AndroidJUnit4::class)
class LargeImageTests {
  private val everyModel = setOf("mlKitText", "mlKitLabels", "mlKitBarcodes", "mlKitPoses", "mlKitObjects")

  private fun usedHeap(): Long {
    repeat(3) { System.gc(); System.runFinalization() }
    val runtime = Runtime.getRuntime()
    return runtime.totalMemory() - runtime.freeMemory()
  }

  @Test fun everyModelOnATwelveMegapixelPhotoKeepsTheHeapFlat() {
    val face = Fixtures.handle("face.jpg")
    // Portrait, as the face was shot: 3024×4032.
    val photo = Bitmap.createScaledBitmap(face, 3024, 4032, true)
    for (config in listOf(Bitmap.Config.ARGB_8888, Bitmap.Config.RGBA_F16)) {
      val handle = if (config == photo.config) photo else photo.copy(config, false)
      val before = usedHeap()
      repeat(5) {
        val result = AnalysisBitmap.analyze(handle) { MlKitAnalyzer.analyze(it, everyModel) }
        // Capped to 2048 on the longer side, the shape kept.
        assertEquals("$config", 1536, result["imageWidth"])
        assertEquals("$config", 2048, result["imageHeight"])
        val faces = AnalysisBitmap.analyze(handle) { FaceAnalyzer.detect(it) }
        assertEquals("$config: the face", 1, faces.size)
      }
      val grown = usedHeap() - before
      assertTrue("$config: the heap grew by ${grown / 1_000_000} MB", grown < 20_000_000)
      assertFalse("$config: the handle is kept", handle.isRecycled)
    }
  }
}
