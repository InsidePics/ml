package expo.modules.mlkit

import android.content.Context
import com.google.mlkit.genai.summarization.Summarization
import com.google.mlkit.genai.summarization.SummarizationRequest
import com.google.mlkit.genai.summarization.Summarizer
import com.google.mlkit.genai.summarization.SummarizerOptions
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder
import expo.modules.kotlin.records.Field
import expo.modules.kotlin.records.Record

/** `MlKitSummarizerOptions`. */
class SummarizeOptions : Record {
  @Field val inputType: String = "article"
  @Field val outputType: String = "oneBullet"
  @Field val language: String = "en"
  @Field val autoTruncate: Boolean = false
}

/** GenAI Summarization (Android only, Gemini Nano): an article or a
 *  conversation as one to three bullets. */
object GenAiSummarizer {
  private val INPUTS = mapOf("article" to SummarizerOptions.InputType.ARTICLE, "conversation" to SummarizerOptions.InputType.CONVERSATION)
  private val OUTPUTS = mapOf(
    "oneBullet" to SummarizerOptions.OutputType.ONE_BULLET,
    "twoBullets" to SummarizerOptions.OutputType.TWO_BULLETS,
    "threeBullets" to SummarizerOptions.OutputType.THREE_BULLETS,
  )
  private data class Key(val input: Int, val output: Int, val language: Int, val truncate: Boolean)
  private val clients = GenAi.Clients<Key, Summarizer>()

  fun client(context: Context, options: SummarizeOptions): Summarizer {
    val key = Key(
      GenAi.pick(INPUTS, options.inputType, "input type"),
      GenAi.pick(OUTPUTS, options.outputType, "output type"),
      GenAi.language(options.language, supported = 3),
      options.autoTruncate,
    )
    return clients.get(key) {
      Summarization.getClient(
        SummarizerOptions.builder(context)
          .setInputType(key.input)
          .setOutputType(key.output)
          .setLanguage(key.language)
          .setLongInputAutoTruncationEnabled(key.truncate)
          .build()
      )
    }
  }

  fun status(context: Context, options: SummarizeOptions, promise: Promise) =
    GenAi.settle(promise, client(context, options).checkFeatureStatus(), GenAi::status)

  fun download(context: Context, options: SummarizeOptions, promise: Promise) {
    val client = client(context, options)
    GenAi.download(promise, "Summarization", client.checkFeatureStatus(), client::downloadFeature)
  }

  fun summarize(context: Context, text: String, options: SummarizeOptions, promise: Promise) {
    val client = client(context, options)
    GenAi.whenAvailable(promise, "Summarization", client.checkFeatureStatus(), {
      client.runInference(SummarizationRequest.builder(text).build())
    }) { it.summary }
  }
}

object GenAiSummarizationFeature : MlKitFeature {
  override val name = "genAiSummarization"

  override fun define(module: ModuleDefinitionBuilder) {
    module.AsyncFunction("getSummarizerStatus") { options: SummarizeOptions, promise: Promise ->
      GenAiSummarizer.status(MlKitHost.context, options, promise)
    }
    module.AsyncFunction("downloadSummarizer") { options: SummarizeOptions, promise: Promise ->
      GenAiSummarizer.download(MlKitHost.context, options, promise)
    }
    module.AsyncFunction("summarize") { text: String, options: SummarizeOptions, promise: Promise ->
      GenAiSummarizer.summarize(MlKitHost.context, text, options, promise)
    }
  }
}
