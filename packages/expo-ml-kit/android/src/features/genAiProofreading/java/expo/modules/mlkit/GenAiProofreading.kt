package expo.modules.mlkit

import android.content.Context
import com.google.mlkit.genai.proofreading.Proofreader
import com.google.mlkit.genai.proofreading.ProofreaderOptions
import com.google.mlkit.genai.proofreading.Proofreading
import com.google.mlkit.genai.proofreading.ProofreadingRequest
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder
import expo.modules.kotlin.records.Field
import expo.modules.kotlin.records.Record

/** `MlKitProofreaderOptions`. */
class ProofreadOptions : Record {
  @Field val inputType: String = "keyboard"
  @Field val language: String = "en"
}

/** GenAI Proofreading (Android only, Gemini Nano): typed or dictated text,
 *  corrected; one or more suggestions, best first. */
object GenAiProofreader {
  private val INPUTS = mapOf("keyboard" to ProofreaderOptions.InputType.KEYBOARD, "voice" to ProofreaderOptions.InputType.VOICE)
  private data class Key(val input: Int, val language: Int)
  private val clients = GenAi.Clients<Key, Proofreader>()

  fun client(context: Context, options: ProofreadOptions): Proofreader {
    val key = Key(GenAi.pick(INPUTS, options.inputType, "input type"), GenAi.language(options.language))
    return clients.get(key) {
      Proofreading.getClient(ProofreaderOptions.builder(context).setInputType(key.input).setLanguage(key.language).build())
    }
  }

  fun status(context: Context, options: ProofreadOptions, promise: Promise) =
    GenAi.settle(promise, client(context, options).checkFeatureStatus(), GenAi::status)

  fun download(context: Context, options: ProofreadOptions, promise: Promise) {
    val client = client(context, options)
    GenAi.download(promise, "Proofreading", client.checkFeatureStatus(), client::downloadFeature)
  }

  fun proofread(context: Context, text: String, options: ProofreadOptions, promise: Promise) {
    val client = client(context, options)
    GenAi.whenAvailable(promise, "Proofreading", client.checkFeatureStatus(), {
      client.runInference(ProofreadingRequest.builder(text).build())
    }) { result -> result.results.map { it.text } }
  }
}

object GenAiProofreadingFeature : MlKitFeature {
  override val name = "genAiProofreading"

  override fun define(module: ModuleDefinitionBuilder) {
    module.AsyncFunction("getProofreaderStatus") { options: ProofreadOptions, promise: Promise ->
      GenAiProofreader.status(MlKitHost.context, options, promise)
    }
    module.AsyncFunction("downloadProofreader") { options: ProofreadOptions, promise: Promise ->
      GenAiProofreader.download(MlKitHost.context, options, promise)
    }
    module.AsyncFunction("proofread") { text: String, options: ProofreadOptions, promise: Promise ->
      GenAiProofreader.proofread(MlKitHost.context, text, options, promise)
    }
  }
}
