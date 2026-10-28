package expo.modules.mlkit

import android.graphics.Bitmap
import com.google.mlkit.genai.common.DownloadStatus
import com.google.mlkit.genai.prompt.Candidate
import com.google.mlkit.genai.prompt.GenerateContentRequest
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.ImagePart
import com.google.mlkit.genai.prompt.TextPart
import expo.modules.kotlin.exception.CodedException
import expo.modules.kotlin.functions.Coroutine
import expo.modules.kotlin.modules.ModuleDefinitionBuilder
import expo.modules.kotlin.records.Field
import expo.modules.kotlin.records.Record
import expo.modules.kotlin.sharedobjects.SharedRef
import kotlinx.coroutines.flow.first

/** `MlKitGenerateOptions`: each left to the model when unset. */
class GenerateOptions : Record {
  @Field val temperature: Float? = null
  @Field val topK: Int? = null
  @Field val maxOutputTokens: Int? = null
  @Field val candidateCount: Int? = null
  @Field val seed: Int? = null
}

/**
 * GenAI Prompt (Android only, Gemini Nano): free text, optionally about an
 * image. `genai-prompt` 1.0.0-beta2: later releases are built with Kotlin
 * 2.3 and 2.4, whose metadata React Native's Kotlin (2.1) cannot read.
 */
object GenAiPrompter {
  private const val WHAT = "The prompt API"
  private val model by lazy { Generation.getClient() }

  private val FINISHES = mapOf(Candidate.FinishReason.STOP to "stop", Candidate.FinishReason.MAX_TOKENS to "maxTokens")

  suspend fun status(): String = GenAi.status(checked { model.checkStatus() })

  /** Downloads the model, returning once it is on the device (at once when
   *  it already is). */
  suspend fun download() {
    when (val code = checked { model.checkStatus() }) {
      3 -> return
      0 -> throw GenAi.unavailable(WHAT, code)
    }
    val end = checked {
      model.download().first { it is DownloadStatus.DownloadCompleted || it is DownloadStatus.DownloadFailed }
    }
    if (end is DownloadStatus.DownloadFailed) throw GenAi.failure(end.e)
  }

  /** The model's candidates for `prompt` (about `image`, when given). */
  suspend fun generate(prompt: String, image: Bitmap?, options: GenerateOptions): List<Map<String, Any?>> {
    val code = checked { model.checkStatus() }
    if (code != 3) throw GenAi.unavailable(WHAT, code)
    val builder = if (image == null) GenerateContentRequest.Builder(TextPart(prompt))
    else GenerateContentRequest.Builder(ImagePart(image), TextPart(prompt))
    builder.temperature = options.temperature
    builder.topK = options.topK
    builder.maxOutputTokens = options.maxOutputTokens
    builder.candidateCount = options.candidateCount
    builder.seed = options.seed
    val response = checked { model.generateContent(builder.build()) }
    return response.candidates.map {
      mapOf("text" to it.text, "finishReason" to (FINISHES[it.finishReason] ?: "other"))
    }
  }

  /** `run`, its failure as a coded rejection. */
  private suspend fun <T> checked(run: suspend () -> T): T =
    try {
      run()
    } catch (e: CodedException) {
      throw e
    } catch (e: Exception) {
      throw GenAi.failure(e)
    }
}

object GenAiPromptFeature : MlKitFeature {
  override val name = "genAiPrompt"

  override fun define(module: ModuleDefinitionBuilder) {
    module.AsyncFunction("getGenerativeModelStatus") Coroutine { -> GenAiPrompter.status() }
    module.AsyncFunction("downloadGenerativeModel") Coroutine { -> GenAiPrompter.download() }
    module.AsyncFunction("generateContent") Coroutine { prompt: String, image: SharedRef<Bitmap>?, options: GenerateOptions ->
      GenAiPrompter.generate(prompt, image?.ref, options)
    }
  }
}
