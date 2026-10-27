package expo.modules.mlkit

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Entity Extraction downloads its English model at first use. The suite
 * waits for that download, and FAILS if it never lands: an extractor that
 * silently stays "unknown" is the failure this checks for.
 * `ios/Tests/EntityTests.swift`, test for test.
 */
@RunWith(AndroidJUnit4::class)
class EntityTests {
  private val downloadTimeoutMs = 180_000L

  @Test fun findsEachKindKept() {
    val text = """
      Call +1 650-253-0000 or write to info@example.com.
      Visit https://example.com before March 3, 2027 at 10am.
      1600 Amphitheatre Parkway, Mountain View, CA 94043
    """.trimIndent()
    val entities = extractOnceReady(text)
    val types = entities.map { it["type"] }.toSet()
    for (kind in listOf("phone", "email", "url", "dateTime", "address")) {
      assertTrue("missing $kind in $entities", kind in types)
    }
    for (entity in entities) assertTrue("${entity["value"]} is a span of the text", text.contains(entity["value"]!!))
  }

  @Test fun findsNothingInPlainWords() {
    assertEquals(0, extractOnceReady("A quiet afternoon by the lake").size)
  }

  @Test fun answersEmptyForBlankTextWithoutTheModel() {
    assertEquals(emptyList<Any>(), EntityAnalyzer.extract("  \n "))
  }

  /** `extract` answers null while the model is downloading; poll until it
   *  answers, or fail. */
  private fun extractOnceReady(text: String): List<Map<String, String>> {
    val deadline = System.currentTimeMillis() + downloadTimeoutMs
    while (System.currentTimeMillis() < deadline) {
      EntityAnalyzer.extract(text)?.let { return it }
      Thread.sleep(2000)
    }
    fail("The entity model did not download within ${downloadTimeoutMs / 1000} s")
    error("unreachable")
  }
}
