package expo.modules.mlkit

import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import expo.modules.kotlin.Promise
import insidepics.testsupport.Fixtures
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * The GenAI features (Gemini Nano through AICore) report the device's real
 * status, and a call the device cannot serve rejects with
 * `ERR_ML_KIT_GENAI_UNAVAILABLE` at once instead of waiting. On a device
 * with Gemini Nano the same tests run the model and check its answer: each
 * test checks what this device can reach, and none is skipped.
 */
@RunWith(AndroidJUnit4::class)
class GenAiTests {
  private val context get() = InstrumentationRegistry.getInstrumentation().targetContext
  private val statuses = setOf("available", "downloadable", "downloading", "unavailable")
  private val text = "The team met on Monday to plan the launch. They agreed to ship the app in March, " +
    "after a beta in February, and to hire two more engineers before then."

  /** The status `status` reports; when not available, `infer` (and, when
   *  unavailable, `download`) reject with the GenAI code. Else `infer`'s
   *  result passes `check`. */
  private fun reportsAndRefuses(
    what: String,
    status: (Promise) -> Unit,
    download: (Promise) -> Unit,
    infer: (Promise) -> Unit,
    check: (Any?) -> Unit,
  ) {
    val reported = settle(status).resolved() as String
    Log.i("GenAiTests", "$what: $reported")
    assertTrue("$what reported $reported", reported in statuses)
    if (reported == "available") return check(settle(infer).resolved(seconds = 120))
    val refused = settle(infer)
    assertEquals("$what: ${refused.rejectionMessage}", "ERR_ML_KIT_GENAI_UNAVAILABLE", refused.rejected())
    assertTrue("${refused.rejectionMessage}", refused.rejectionMessage!!.contains(reported))
    if (reported == "unavailable") assertEquals("ERR_ML_KIT_GENAI_UNAVAILABLE", settle(download).rejected())
  }

  private fun nonEmptyText(value: Any?) = assertTrue("empty: $value", (value as String).isNotBlank())

  private fun nonEmptySuggestions(value: Any?) {
    @Suppress("UNCHECKED_CAST")
    val suggestions = value as List<String>
    assertTrue("no suggestions", suggestions.isNotEmpty() && suggestions.all { it.isNotBlank() })
  }

  @Test fun summarization() = SummarizeOptions().let { options ->
    reportsAndRefuses(
      "Summarization",
      { GenAiSummarizer.status(context, options, it) },
      { GenAiSummarizer.download(context, options, it) },
      { GenAiSummarizer.summarize(context, text, options, it) },
      ::nonEmptyText,
    )
  }

  @Test fun proofreading() = ProofreadOptions().let { options ->
    reportsAndRefuses(
      "Proofreading",
      { GenAiProofreader.status(context, options, it) },
      { GenAiProofreader.download(context, options, it) },
      { GenAiProofreader.proofread(context, "Their going too the store tomorow.", options, it) },
      ::nonEmptySuggestions,
    )
  }

  @Test fun rewriting() = RewriteOptions().let { options ->
    reportsAndRefuses(
      "Rewriting",
      { GenAiRewriter.status(context, options, it) },
      { GenAiRewriter.download(context, options, it) },
      { GenAiRewriter.rewrite(context, text, options, it) },
      ::nonEmptySuggestions,
    )
  }

  @Test fun imageDescription() {
    val dog = Fixtures.handle("animal.jpg")
    reportsAndRefuses(
      "Image description",
      { GenAiImageDescriber.status(context, it) },
      { GenAiImageDescriber.download(context, it) },
      { GenAiImageDescriber.describe(context, dog, it) },
    ) { assertTrue("$it", (it as String).contains("dog", ignoreCase = true)) }
  }

  @Test fun prompt() {
    val reported = awaitSuspend { GenAiPrompter.status() }
    Log.i("GenAiTests", "Prompt: $reported")
    assertTrue("Prompt reported $reported", reported in statuses)
    if (reported == "available") {
      val answer = awaitSuspend(120) { GenAiPrompter.generate("Name one primary colour.", null, GenerateOptions()) }
      assertTrue("$answer", answer.isNotEmpty() && (answer.first()["text"] as String).isNotBlank())
      return
    }
    assertEquals("ERR_ML_KIT_GENAI_UNAVAILABLE", rejectedCode { GenAiPrompter.generate("Hi", null, GenerateOptions()) })
    if (reported == "unavailable") assertEquals("ERR_ML_KIT_GENAI_UNAVAILABLE", rejectedCode { GenAiPrompter.download() })
  }
}
