package expo.modules.mlkit

import com.google.mlkit.nl.languageid.LanguageIdentification
import com.google.mlkit.nl.languageid.LanguageIdentificationOptions
import com.google.mlkit.nl.languageid.LanguageIdentifier
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder

/** Language Identification (bundled): a text's BCP-47 language, or every
 *  likely one with its confidence. `und` is "could not tell". */
object LanguageIdFeature : MlKitFeature {
  override val name = "languageId"

  private val identifiers = mutableMapOf<Float?, LanguageIdentifier>()

  private fun identifier(threshold: Float?): LanguageIdentifier = synchronized(identifiers) {
    identifiers.getOrPut(threshold) {
      val options = LanguageIdentificationOptions.Builder()
      if (threshold != null) options.setConfidenceThreshold(threshold)
      LanguageIdentification.getClient(options.build())
    }
  }

  private fun threshold(options: Map<String, Any?>?) = (options?.get("confidenceThreshold") as? Number)?.toFloat()

  fun identify(text: String, threshold: Float?): String = awaitDetector(identifier(threshold).identifyLanguage(text))

  fun possible(text: String, threshold: Float?): List<Map<String, Any>> =
    awaitDetector(identifier(threshold).identifyPossibleLanguages(text)).map {
      mapOf("language" to it.languageTag, "confidence" to it.confidence.toDouble())
    }

  override fun define(module: ModuleDefinitionBuilder) {
    module.AsyncFunction("identifyLanguage") { text: String, options: Map<String, Any?>?, promise: Promise ->
      MlKitCalls.onQueue(promise) { identify(text, threshold(options)) }
    }

    module.AsyncFunction("identifyPossibleLanguages") { text: String, options: Map<String, Any?>?, promise: Promise ->
      MlKitCalls.onQueue(promise) { possible(text, threshold(options)) }
    }
  }
}
