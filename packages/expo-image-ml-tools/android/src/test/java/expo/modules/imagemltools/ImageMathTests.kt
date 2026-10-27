package expo.modules.imagemltools

import java.io.File
import java.security.MessageDigest
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * The maths against the recorded reference (`fixtures/expected/
 * model-inputs.json`, the same values iOS's `ImageMathTests` checks): the
 * pattern rebuilt from its formula, through every operation, bit for bit.
 */
class ImageMathTests {
  private val json = File(System.getProperty("expected")).readText()
  private val pattern = json.substringAfter("\"pattern\" : {").substringBefore("}")

  private fun field(name: String): String =
    Regex("\"$name\" : \"?([^\",\\n]+)\"?").find(pattern)!!.groupValues[1]

  private fun matrix(): DoubleArray =
    Regex("\"matrix\" : \\[([^\\]]+)]").find(pattern)!!.groupValues[1]
      .split(",").map { it.trim().toDouble() }.toDoubleArray()

  private val clipMean = doubleArrayOf(0.485, 0.456, 0.406)
  private val clipStd = doubleArrayOf(0.229, 0.224, 0.225)
  private val half = doubleArrayOf(0.5, 0.5, 0.5)

  private fun patternImage(): RgbaImage {
    val w = 97
    val h = 61
    val px = ByteArray(w * h * 4) { 255.toByte() }
    for (y in 0 until h) {
      for (x in 0 until w) {
        val i = (y * w + x) * 4
        px[i] = ((x * 7 + y * 3) % 256).toByte()
        px[i + 1] = ((x * x + y) % 256).toByte()
        px[i + 2] = ((x * y) % 256).toByte()
      }
    }
    return RgbaImage(w, h, px)
  }

  private fun sha256(bytes: ByteArray): String =
    MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }

  private fun bits(value: Double): String = java.lang.Long.toUnsignedString(value.toRawBits())

  @Test fun rebuildsTheRecordedPattern() {
    assertEquals(field("rgba"), sha256(patternImage().pixels))
  }

  @Test fun coverNearestIsTheRecordedCrop() {
    val tensor = ImageMath.tensor(patternImage(), 32, 32, Fit.COVER, Filter.NEAREST, clipMean, clipStd, Layout.NCHW)
    assertEquals(field("clip32"), sha256(ImageMath.bytes(tensor)))
  }

  @Test fun theMatrixIsReadWhole() {
    assertEquals(6, matrix().size)
  }

  @Test fun warpThenTensorIsTheRecordedFace() {
    val crop = ImageMath.warp(patternImage(), matrix(), 24, 24)
    assertEquals(field("warp24"), sha256(crop.pixels))
    val tensor = ImageMath.tensor(crop, 24, 24, Fit.STRETCH, Filter.NEAREST, half, half, Layout.NCHW)
    assertEquals(field("face24"), sha256(ImageMath.bytes(tensor)))
    assertEquals(field("face24Blur"), bits(ImageMath.sharpness(crop)))
  }

  @Test fun statistics() {
    assertEquals(field("sharpness"), bits(ImageMath.sharpness(patternImage())))
    assertEquals(field("histogram16"), sha256(ImageMath.bytes(ImageMath.histogram(patternImage(), 16))))
  }

  @Test fun nhwcInterleavesTheSameValues() {
    val image = patternImage()
    val mean = doubleArrayOf(0.1, 0.2, 0.3)
    val std = doubleArrayOf(0.5, 0.6, 0.7)
    val planar = ImageMath.tensor(image, 8, 6, Fit.STRETCH, Filter.BILINEAR, mean, std, Layout.NCHW)
    val packed = ImageMath.tensor(image, 8, 6, Fit.STRETCH, Filter.BILINEAR, mean, std, Layout.NHWC)
    val plane = 48
    for (p in 0 until plane) for (ch in 0 until 3) assertEquals(planar[ch * plane + p], packed[p * 3 + ch])
  }

  @Test fun warpSurvivesNaNAndHugeMatrices() {
    // NaN, or a shift far off the image: nothing to sample, transparent black.
    for (m in listOf(doubleArrayOf(Double.NaN, 0.0, 0.0, 0.0, 1.0, 0.0), doubleArrayOf(1.0, 0.0, 1e20, 0.0, 1.0, 0.0))) {
      assertArrayEquals(ByteArray(36), ImageMath.warp(patternImage(), m, 3, 3).pixels)
    }
    // A 1e300 zoom maps every output onto the top-left pixel: opaque black.
    val zoomed = ImageMath.warp(patternImage(), doubleArrayOf(1e300, 0.0, 0.0, 0.0, 1e300, 0.0), 3, 3)
    assertArrayEquals(ByteArray(36) { if (it % 4 == 3) -1 else 0 }, zoomed.pixels)
  }

  @Test fun sharpnessIsZeroBelowThreeByThree() {
    assertEquals(0.0, ImageMath.sharpness(RgbaImage(2, 9, ByteArray(72) { 200.toByte() })), 0.0)
  }

  @Test fun oneHistogramBinHoldsEverything() {
    assertArrayEquals(floatArrayOf(1f), ImageMath.histogram(patternImage(), 1), 0f)
  }

  @Test fun upscalingASmallImageStaysInRange() {
    val tiny = RgbaImage(2, 1, byteArrayOf(0, 0, 0, -1, -1, -1, -1, -1))
    for (filter in Filter.values()) {
      val t = ImageMath.tensor(tiny, 7, 5, Fit.COVER, filter, DoubleArray(3), doubleArrayOf(1.0, 1.0, 1.0), Layout.NCHW)
      assertEquals(105, t.size)
      assert(t.all { it in 0f..1f })
      assertEquals(0f, t[0])
      assertEquals(1f, t[6])
    }
  }

  @Test fun aDegenerateMatrixLeavesTheCropBlack() {
    val crop = ImageMath.warp(patternImage(), DoubleArray(6), 4, 4)
    assertArrayEquals(ByteArray(64), crop.pixels)
  }
}
