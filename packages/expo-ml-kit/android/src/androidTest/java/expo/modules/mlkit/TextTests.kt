package expo.modules.mlkit

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import androidx.test.ext.junit.runners.AndroidJUnit4
import insidepics.testsupport.Fixtures
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import kotlin.math.ceil

/**
 * Text Recognition v2: the Latin read through `analyzeImage`, every bundled
 * script through `recognize`. The non-Latin samples are rendered here with
 * the system's fonts, so no photo of anyone's writing needs a licence.
 * `ios/Tests/TextTests.swift`, test for test.
 */
@RunWith(AndroidJUnit4::class)
class TextTests {
  @Test fun latinReadsTheSign() {
    val text = analyze("text.jpg", setOf("mlKitText"))["text"].json()
    val read = (text["text"] as String).uppercase()
    for (word in listOf("WARNING", "AMMUNITION", "TESTING", "HARLEY", "NOTICE")) {
      assertTrue("missing $word in: $read", read.contains(word))
    }
    val blocks = text["blocks"].list()
    assertTrue(blocks.size >= 2)
    for (block in blocks) assertUnitRect(block["boundingBox"], "text block")
  }

  @Test fun latinReadsNothingInALandscape() {
    assertEquals("", (analyze("landscape.jpg", setOf("mlKitText"))["text"].json()["text"] as String).trim())
  }

  @Test fun textIsSkippedWhenNeitherTextNorEntitiesAreAsked() {
    val text = analyze("text.jpg", setOf("mlKitLabels"))["text"].json()
    assertEquals("", text["text"])
    assertEquals(0, (text["blocks"] as List<*>).size)
  }

  @Test fun everyScriptReadsItsOwnWriting() {
    val samples = listOf(
      "chinese" to "你好世界",
      "japanese" to "こんにちは",
      "korean" to "안녕하세요",
      "devanagari" to "नमस्ते दुनिया",
      "latin" to "Hello World",
    )
    for ((script, sample) in samples) {
      val read = (recognize(render(sample), listOf(script))[0]["text"] as String).filterNot { it.isWhitespace() }
      val want = sample.filterNot { it.isWhitespace() }
      // One character of slack, as on iOS, where the Devanagari model drops
      // a vowel sign. A recognizer that cannot read the script misses more.
      assertTrue("$script read \"$read\" for \"$sample\"", editDistance(read, want) <= 1)
    }
  }

  @Test fun recognizeReturnsOneReadPerScriptInOrder() {
    val reads = recognize(Fixtures.handle("text.jpg"), listOf("latin", "korean"))
    assertEquals(2, reads.size)
    // The CJK and Devanagari models read Latin text too.
    for (read in reads) assertTrue((read["text"] as String).uppercase().contains("WARNING"))
  }

  @Test fun recognizeRejectsAnUnknownScript() {
    assertThrows(IllegalArgumentException::class.java) {
      recognize(Fixtures.handle("text.jpg"), listOf("klingon"))
    }
  }

  /** Levenshtein distance, by code point (a vowel sign counts as one). */
  private fun editDistance(a: String, b: String): Int {
    val x = a.codePoints().toArray()
    val y = b.codePoints().toArray()
    var row = IntArray(y.size + 1) { it }
    for (i in 1..x.size) {
      val next = IntArray(y.size + 1)
      next[0] = i
      for (j in 1..y.size) next[j] = minOf(row[j] + 1, next[j - 1] + 1, row[j - 1] + if (x[i - 1] == y[j - 1]) 0 else 1)
      row = next
    }
    return row[y.size]
  }

  /** Black text on white, 96 px in the default font (which falls back to
   *  the script's own font), padded. */
  private fun render(text: String): Bitmap {
    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.BLACK
      textSize = 96f
      typeface = Typeface.DEFAULT
    }
    val metrics = paint.fontMetrics
    val width = ceil(paint.measureText(text)).toInt() + 160
    val height = ceil(metrics.descent - metrics.ascent).toInt() + 160
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    canvas.drawColor(Color.WHITE)
    canvas.drawText(text, 80f, 80f - metrics.ascent, paint)
    return bitmap
  }
}
