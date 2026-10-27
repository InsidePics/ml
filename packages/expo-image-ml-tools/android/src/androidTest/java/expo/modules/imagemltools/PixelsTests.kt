package expo.modules.imagemltools

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorSpace
import androidx.test.ext.junit.runners.AndroidJUnit4
import insidepics.testsupport.bytes
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * [Pixels], which every tool reads a handle through: exact for the bitmap
 * Glide usually returns, and the same pixels (to the format's precision)
 * for every other kind a handle can hold.
 */
@RunWith(AndroidJUnit4::class)
class PixelsTests {
  /** The formula pattern of `fixtures/expected/model-inputs.json`, opaque. */
  private fun pattern(): RgbaImage {
    val w = 97
    val h = 61
    val px = ByteArray(w * h * 4) { 255.toByte() }
    for (y in 0 until h) for (x in 0 until w) {
      val i = (y * w + x) * 4
      px[i] = ((x * 7 + y * 3) % 256).toByte()
      px[i + 1] = ((x * x + y) % 256).toByte()
      px[i + 2] = ((x * y) % 256).toByte()
    }
    return RgbaImage(w, h, px)
  }

  /** The largest difference of any channel, 0–255. */
  private fun maxDifference(a: ByteArray, b: ByteArray): Int {
    assertEquals(a.size, b.size)
    return a.indices.maxOf { kotlin.math.abs((a[it].toInt() and 0xFF) - (b[it].toInt() and 0xFF)) }
  }

  @Test fun anSrgbBitmapReadsBackByteForByte() {
    val image = pattern()
    val read = Pixels.rgba(Pixels.bitmap(image))
    assertEquals(97, read.width)
    assertEquals(61, read.height)
    assertArrayEquals(image.pixels, read.pixels)
  }

  @Test fun warpOutputReadsBackAsItsOwnBytes() {
    val crop = ImageMath.warp(pattern(), doubleArrayOf(1.0, 0.0, -3.0, 0.0, 1.0, -2.0), 16, 12)
    val handle = Pixels.bitmap(crop)
    assertEquals(16, handle.width)
    assertEquals(12, handle.height)
    assertArrayEquals(crop.pixels, Pixels.rgba(handle).pixels)
    // Read as any other bitmap is read, the bytes are the same too.
    assertArrayEquals(crop.pixels, handle.bytes())
  }

  @Test fun alphaIsPremultipliedAsOnIOS() {
    val bitmap = Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
    bitmap.setPixel(0, 0, Color.argb(128, 200, 100, 0))
    val px = Pixels.rgba(bitmap).pixels.map { it.toInt() and 0xFF }
    assertEquals(128, px[3])
    assertTrue("red premultiplied: ${px[0]}", px[0] in 99..101)
    assertTrue("green premultiplied: ${px[1]}", px[1] in 49..51)
  }

  @Test fun everyOtherConfigReadsAsTheSamePixels() {
    val source = Pixels.bitmap(pattern())
    // Each format's own precision: 5–6 bits a channel for RGB_565.
    for ((config, slack) in listOf(Bitmap.Config.RGBA_F16 to 1, Bitmap.Config.RGB_565 to 8)) {
      val other = source.copy(config, false)
      assertNotNull("$config copy", other)
      val read = Pixels.rgba(other)
      assertEquals("$config", 97, read.width)
      val diff = maxDifference(pattern().pixels, read.pixels)
      assertTrue("$config: off by up to $diff", diff <= slack)
      assertTrue("$config: the handle's own bitmap is kept", !other.isRecycled)
    }
  }

  @Test fun aHardwareBitmapReadsAsTheSamePixels() {
    val hardware = Pixels.bitmap(pattern()).copy(Bitmap.Config.HARDWARE, false)
    // No GPU, no hardware bitmap: the one thing this platform cannot run.
    org.junit.Assume.assumeNotNull(hardware)
    assertEquals(Bitmap.Config.HARDWARE, hardware.config)
    assertTrue(maxDifference(pattern().pixels, Pixels.rgba(hardware).pixels) <= 1)
  }

  @Test fun aDisplayP3BitmapReadsAsSrgb() {
    val p3 = Bitmap.createBitmap(97, 61, Bitmap.Config.ARGB_8888, true, ColorSpace.get(ColorSpace.Named.DISPLAY_P3))
    Canvas(p3).drawBitmap(Pixels.bitmap(pattern()), 0f, 0f, null)
    val stored = p3.bytes()
    assertTrue("stored as P3, not sRGB", maxDifference(pattern().pixels, stored) > 10)
    // Read as Android's own conversion of the stored P3 values to sRGB.
    val toSrgb = ColorSpace.connect(ColorSpace.get(ColorSpace.Named.DISPLAY_P3), ColorSpace.get(ColorSpace.Named.SRGB))
    val expected = stored.copyOf()
    for (i in 0 until stored.size / 4) {
      val rgb = toSrgb.transform(
        (stored[i * 4].toInt() and 0xFF) / 255f,
        (stored[i * 4 + 1].toInt() and 0xFF) / 255f,
        (stored[i * 4 + 2].toInt() and 0xFF) / 255f,
      )
      for (c in 0 until 3) expected[i * 4 + c] = Math.round(rgb[c].coerceIn(0f, 1f) * 255).toByte()
    }
    val read = Pixels.rgba(p3).pixels
    val diff = maxDifference(expected, read)
    assertTrue("off Android's conversion by up to $diff", diff <= 1)
    // Against the sRGB pattern drawn in, P3's 8 bits lose a few levels.
    val drift = maxDifference(pattern().pixels, read)
    android.util.Log.i("PixelsTests", "P3 round trip: up to $drift of 255")
    assertTrue("P3 round trip off by up to $drift", drift <= 10)
  }

  @Test fun aReleasedBitmapIsRefused() {
    val bitmap = Pixels.bitmap(pattern())
    bitmap.recycle()
    assertThrows(IllegalArgumentException::class.java) { Pixels.rgba(bitmap) }
  }
}
