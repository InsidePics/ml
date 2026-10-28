package expo.modules.mlkit

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Language Identification and Smart Reply, the bundled text models, through
 *  the features' own calls. iOS: `LanguageTests`. */
@RunWith(AndroidJUnit4::class)
class LanguageTests {
  @Test fun identifiesTheLanguageOfASentence() {
    assertEquals("de", LanguageIdFeature.identify("Wo ist der Bahnhof, bitte?", null))
    assertEquals("ja", LanguageIdFeature.identify("駅はどこですか", null))
    assertEquals("und", LanguageIdFeature.identify("", null))
  }

  @Test fun ranksThePossibleLanguages() {
    val possible = LanguageIdFeature.possible("Ceci est une phrase en français.", 0.01f)
    assertEquals("fr", possible.first()["language"])
    val confidences = possible.map { it["confidence"] as Double }
    assertEquals(confidences.sortedDescending(), confidences)
  }

  @Test fun suggestsRepliesToTheLastRemoteMessage() {
    val now = System.currentTimeMillis()
    val result = SmartReplyFeature.suggest(listOf(
      mapOf("text" to "Hey, are you coming to dinner tonight?", "timestamp" to now - 60_000, "userId" to "friend"),
    ))
    assertEquals("success", result["status"])
    assertTrue("$result", (result["suggestions"] as List<*>).isNotEmpty())
  }

  @Test fun repliesToNothingInAnUnsupportedLanguage() {
    val result = SmartReplyFeature.suggest(listOf(
      mapOf("text" to "Kommst du heute Abend zum Essen?", "timestamp" to System.currentTimeMillis(), "userId" to "friend"),
    ))
    assertEquals("notSupportedLanguage", result["status"])
    assertEquals(emptyList<String>(), result["suggestions"])
  }
}
