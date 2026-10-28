package expo.modules.mlkit

import android.content.Context
import com.google.mlkit.genai.rewriting.Rewriter
import com.google.mlkit.genai.rewriting.RewriterOptions
import com.google.mlkit.genai.rewriting.Rewriting
import com.google.mlkit.genai.rewriting.RewritingRequest
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder
import expo.modules.kotlin.records.Field
import expo.modules.kotlin.records.Record

/** `MlKitRewriterOptions`. */
class RewriteOptions : Record {
  @Field val style: String = "rephrase"
  @Field val language: String = "en"
}

/** GenAI Rewriting (Android only, Gemini Nano): text in another style; one
 *  or more suggestions, best first. */
object GenAiRewriter {
  private val STYLES = mapOf(
    "elaborate" to RewriterOptions.OutputType.ELABORATE,
    "emojify" to RewriterOptions.OutputType.EMOJIFY,
    "shorten" to RewriterOptions.OutputType.SHORTEN,
    "friendly" to RewriterOptions.OutputType.FRIENDLY,
    "professional" to RewriterOptions.OutputType.PROFESSIONAL,
    "rephrase" to RewriterOptions.OutputType.REPHRASE,
  )
  private data class Key(val style: Int, val language: Int)
  private val clients = GenAi.Clients<Key, Rewriter>()

  fun client(context: Context, options: RewriteOptions): Rewriter {
    val key = Key(GenAi.pick(STYLES, options.style, "rewriting style"), GenAi.language(options.language))
    return clients.get(key) {
      Rewriting.getClient(RewriterOptions.builder(context).setOutputType(key.style).setLanguage(key.language).build())
    }
  }

  fun status(context: Context, options: RewriteOptions, promise: Promise) =
    GenAi.settle(promise, client(context, options).checkFeatureStatus(), GenAi::status)

  fun download(context: Context, options: RewriteOptions, promise: Promise) {
    val client = client(context, options)
    GenAi.download(promise, "Rewriting", client.checkFeatureStatus(), client::downloadFeature)
  }

  fun rewrite(context: Context, text: String, options: RewriteOptions, promise: Promise) {
    val client = client(context, options)
    GenAi.whenAvailable(promise, "Rewriting", client.checkFeatureStatus(), {
      client.runInference(RewritingRequest.builder(text).build())
    }) { result -> result.results.map { it.text } }
  }
}

object GenAiRewritingFeature : MlKitFeature {
  override val name = "genAiRewriting"

  override fun define(module: ModuleDefinitionBuilder) {
    module.AsyncFunction("getRewriterStatus") { options: RewriteOptions, promise: Promise ->
      GenAiRewriter.status(MlKitHost.context, options, promise)
    }
    module.AsyncFunction("downloadRewriter") { options: RewriteOptions, promise: Promise ->
      GenAiRewriter.download(MlKitHost.context, options, promise)
    }
    module.AsyncFunction("rewrite") { text: String, options: RewriteOptions, promise: Promise ->
      GenAiRewriter.rewrite(MlKitHost.context, text, options, promise)
    }
  }
}
