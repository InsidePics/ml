package expo.modules.mlkit

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.common.model.RemoteModelManager
import com.google.mlkit.nl.entityextraction.EntityExtractionRemoteModel
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Entity Extraction downloads each language's model at first use. The suite
 * waits for those downloads, and FAILS if one never lands: an extractor that
 * silently stays "unknown" is the failure this checks for.
 * `ios/Tests/EntityTests.swift`, test for test.
 */
@RunWith(AndroidJUnit4::class)
class EntityTests {
  private val downloadTimeoutMs = 180_000L

  private val text = """
    Call +1 650-253-0000 or write to info@example.com.
    Visit https://example.com before March 3, 2027 at 10am.
    1600 Amphitheatre Parkway, Mountain View, CA 94043
    It costs $12.50 on flight LX 38, tracked as 1Z204E380338943508.
  """.trimIndent()

  @Test fun findsEachKindKeptWithItsSpan() {
    val entities = extractOnceReady(text)
    val types = entities.map { it["type"] }.toSet()
    for (kind in listOf("phone", "email", "url", "dateTime", "address", "money", "flightNumber", "trackingNumber")) {
      assertTrue("missing $kind in $entities", kind in types)
    }
    for (entity in entities) {
      assertEquals(entity["value"], text.substring(entity["start"] as Int, entity["end"] as Int))
    }
  }

  @Test fun parsesTheValuesItKnows() {
    val byType = extractOnceReady(text).associateBy { it["type"] }
    val money = byType["money"]!!["money"].json()
    assertEquals(12, money["integerPart"])
    assertEquals(50, money["fractionalPart"])
    val flight = byType["flightNumber"]!!["flightNumber"].json()
    assertEquals("LX", flight["airlineCode"])
    assertEquals("38", flight["flightNumber"])
    assertEquals("ups", byType["trackingNumber"]!!["trackingNumber"].json()["carrier"])
    val date = byType["dateTime"]!!["dateTime"].json()
    assertTrue("$date", (date["timestamp"] as Double) > 1.7e12)
    assertTrue("$date", date["granularity"] in listOf("hour", "minute"))
  }

  @Test fun keepsOnlyTheTypesAsked() {
    val entities = extractOnceReady(text, mapOf("types" to listOf("email", "url")))
    assertEquals(setOf("email", "url"), entities.map { it["type"] }.toSet())
  }

  @Test fun readsAnotherLanguageWithItsOwnModel() {
    val entities = extractOnceReady("Rufen Sie mich morgen um 15 Uhr an: +49 30 1234567", mapOf("language" to "de"))
    assertTrue("$entities", entities.any { it["type"] == "phone" })
    val downloaded = Tasks.await(
      RemoteModelManager.getInstance().getDownloadedModels(EntityExtractionRemoteModel::class.java), 30, TimeUnit.SECONDS,
    ).map { it.modelIdentifier }
    assertTrue("$downloaded", "german" in downloaded)
  }

  @Test fun findsNothingInPlainWords() {
    assertEquals(0, extractOnceReady("A quiet afternoon by the lake").size)
  }

  @Test fun answersEmptyForBlankTextWithoutTheModel() {
    assertEquals(emptyList<Any>(), EntityAnalyzer.extract("  \n "))
  }

  /** `extract` answers null while the model is downloading; poll until it
   *  answers, or fail. */
  private fun extractOnceReady(text: String, options: Map<String, Any?> = emptyMap()): List<Json> {
    val deadline = System.currentTimeMillis() + downloadTimeoutMs
    while (System.currentTimeMillis() < deadline) {
      EntityAnalyzer.extract(text, options)?.let { return it }
      Thread.sleep(2000)
    }
    fail("The entity model did not download within ${downloadTimeoutMs / 1000} s")
    error("unreachable")
  }
}
