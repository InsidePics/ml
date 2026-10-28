package expo.modules.mlkit

import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.common.MlKitException
import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.common.model.RemoteModelManager
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.TranslateRemoteModel
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.Translator
import com.google.mlkit.nl.translate.TranslatorOptions
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder

/**
 * On-device Translation. Every language's model downloads (~30 MB) when the
 * caller asks; a translation whose models are missing rejects with
 * `ERR_ML_KIT_MODEL` rather than starting a download nobody chose. Nothing
 * here waits on the analysis thread: each call settles from its task.
 */
object TranslateFeature : MlKitFeature {
  override val name = "translate"

  private val models get() = RemoteModelManager.getInstance()

  /** ML Kit's code for a BCP-47 tag, or a refusal naming the tag. */
  fun language(tag: String): String =
    TranslateLanguage.fromLanguageTag(tag) ?: throw IllegalArgumentException("ML Kit does not translate $tag")

  private fun remote(tag: String) = TranslateRemoteModel.Builder(language(tag)).build()

  private fun conditions(wifiOnly: Boolean) = DownloadConditions.Builder().apply { if (wifiOnly) requireWifi() }.build()

  private val translators = mutableMapOf<Pair<String, String>, Translator>()

  fun translator(from: String, to: String): Translator = synchronized(translators) {
    translators.getOrPut(from to to) {
      Translation.getClient(TranslatorOptions.Builder().setSourceLanguage(language(from)).setTargetLanguage(language(to)).build())
    }
  }

  /** Both ends' models on the device (English's always is). */
  fun modelsReady(from: String, to: String): Task<Boolean> {
    val wanted = listOf(from, to).map(::language).filter { it != TranslateLanguage.ENGLISH }
    return models.getDownloadedModels(TranslateRemoteModel::class.java).continueWith { task ->
      val downloaded = task.result.map { it.language }.toSet()
      wanted.all { it in downloaded }
    }
  }

  /** `text` translated, fetching the models first when `download`. */
  fun translate(text: String, from: String, to: String, download: Boolean, wifiOnly: Boolean): Task<String> {
    val translator = translator(from, to)
    if (download) return translator.downloadModelIfNeeded(conditions(wifiOnly)).onSuccessTask { translator.translate(text) }
    return modelsReady(from, to).onSuccessTask { ready ->
      if (ready) translator.translate(text)
      else Tasks.forException(MlKitException("Translation model for $from or $to is not downloaded", MlKitException.NOT_FOUND))
    }
  }

  override fun define(module: ModuleDefinitionBuilder) {
    module.AsyncFunction("translate") { text: String, options: Map<String, Any?>, promise: Promise ->
      val from = options["from"] as? String ?: throw IllegalArgumentException("No source language")
      val to = options["to"] as? String ?: throw IllegalArgumentException("No target language")
      val download = options["downloadIfNeeded"] as? Boolean ?: false
      val wifiOnly = options["wifiOnly"] as? Boolean ?: true
      translate(text, from, to, download, wifiOnly)
        .addOnSuccessListener { promise.resolve(it) }
        .addOnFailureListener { e ->
          val missing = e is MlKitException && e.errorCode == MlKitException.NOT_FOUND
          promise.reject(if (missing) "ERR_ML_KIT_MODEL" else "ERR_ML_KIT", e.message ?: "Translation failed", e)
        }
    }

    module.AsyncFunction("downloadTranslationModel") { tag: String, wifiOnly: Boolean, promise: Promise ->
      MlKitCalls.settle(promise, models.download(remote(tag), conditions(wifiOnly))) { null }
    }

    module.AsyncFunction("deleteTranslationModel") { tag: String, promise: Promise ->
      MlKitCalls.settle(promise, models.deleteDownloadedModel(remote(tag))) { null }
    }

    module.AsyncFunction("downloadedTranslationModels") { promise: Promise ->
      MlKitCalls.settle(promise, models.getDownloadedModels(TranslateRemoteModel::class.java)) { found ->
        // ML Kit's translate codes are BCP-47 tags already.
        found.map { it.language }
      }
    }
  }
}
