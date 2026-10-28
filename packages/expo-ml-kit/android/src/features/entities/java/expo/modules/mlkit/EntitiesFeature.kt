package expo.modules.mlkit

import com.google.mlkit.common.model.RemoteModelManager
import com.google.mlkit.nl.entityextraction.EntityExtractionRemoteModel
import com.google.mlkit.nl.entityextraction.EntityExtractorOptions
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder

/** Entity Extraction's functions: extraction on the analysis thread, and
 *  the language models' downloads, settled from their tasks. */
object EntitiesFeature : MlKitFeature {
  override val name = "entities"

  private val models get() = RemoteModelManager.getInstance()

  private fun remote(language: String) = EntityExtractionRemoteModel.Builder(EntityAnalyzer.model(language)).build()

  override fun define(module: ModuleDefinitionBuilder) {
    // Text alone: analyzeImage's (the confident lines TS chose) or a caller's.
    module.AsyncFunction("extractEntities") { text: String, options: Map<String, Any?>?, promise: Promise ->
      MlKitCalls.onQueue(promise) { EntityAnalyzer.extract(text, options ?: emptyMap()) }
    }

    module.AsyncFunction("downloadEntityModel") { language: String, wifiOnly: Boolean, promise: Promise ->
      MlKitCalls.settle(promise, EntityAnalyzer.download(language, wifiOnly)) { null }
    }

    module.AsyncFunction("deleteEntityModel") { language: String, promise: Promise ->
      MlKitCalls.settle(promise, models.deleteDownloadedModel(remote(language))) { null }
    }

    module.AsyncFunction("downloadedEntityModels") { promise: Promise ->
      MlKitCalls.settle(promise, models.getDownloadedModels(EntityExtractionRemoteModel::class.java)) { found ->
        found.mapNotNull { EntityExtractorOptions.toLanguageTag(it.modelIdentifier) }
      }
    }
  }
}
