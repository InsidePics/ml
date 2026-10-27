package expo.modules.imagemltools

import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import insidepics.testsupport.Fixtures
import org.json.JSONObject
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import kotlin.math.abs

/**
 * How far Android's decode of each fixture (Glide, as an app's handle holds
 * it, read by [Pixels]) is from Apple's, recorded in `fixtures/expected/
 * decode-grid.json` by `ios/Tests/DecodeGridTests.swift`: the mean colour
 * of a 16×16 grid of cells, 0–255. The decoders differ pixel by pixel, so
 * model inputs are not bit-identical across platforms; averaged over a
 * cell that noise is gone, and what is left is a shift in colour,
 * brightness or orientation, which must not be there.
 */
@RunWith(AndroidJUnit4::class)
class DecodeGapTests {
  @Test fun everyFixtureDecodesAsOnApple() {
    val recorded = JSONObject(Fixtures.text("expected/decode-grid.json"))
    val side = recorded.getInt("side")
    val grids = recorded.getJSONObject("grids")
    val names = grids.keys().asSequence().toList()
    assertTrue("a recorded grid per fixture", names.size >= 14)
    for (name in names) {
      val want = grids.getJSONArray(name).let { a -> DoubleArray(a.length()) { a.getDouble(it) } }
      val got = decodeGrid(Pixels.rgba(Fixtures.handle(name)), side)
      val gaps = want.indices.map { abs(want[it] - got[it]) }
      val mean = gaps.average()
      val max = gaps.max()
      Log.i("DecodeGapTests", "$name: mean %.3f, max %.2f of 255".format(mean, max))
      assertTrue("$name: mean gap $mean of 255", mean < MEAN_LIMIT)
      assertTrue("$name: max gap $max of 255", max < MAX_LIMIT)
    }
  }

  /** `ios/Tests/DecodeGridTests.swift`'s `decodeGrid`, line for line. */
  private fun decodeGrid(image: RgbaImage, side: Int): DoubleArray {
    val out = DoubleArray(side * side * 3)
    for (cy in 0 until side) for (cx in 0 until side) {
      val x0 = cx * image.width / side
      val x1 = (cx + 1) * image.width / side
      val y0 = cy * image.height / side
      val y1 = (cy + 1) * image.height / side
      val sum = DoubleArray(3)
      for (y in y0 until y1) for (x in x0 until x1) {
        val i = (y * image.width + x) * 4
        for (c in 0 until 3) sum[c] += (image.pixels[i + c].toInt() and 0xFF).toDouble()
      }
      val n = ((x1 - x0) * (y1 - y0)).toDouble()
      for (c in 0 until 3) out[(cy * side + cx) * 3 + c] = Math.round(sum[c] / n * 100) / 100.0
    }
    return out
  }

  private companion object {
    // Measured on an Android 17 emulator: JPEG means 0.03–0.21, HEIC 0.33,
    // no cell past 2.22. A colour-space or gamma slip moves cells by tens.
    const val MEAN_LIMIT = 1.0
    const val MAX_LIMIT = 5.0
  }
}
