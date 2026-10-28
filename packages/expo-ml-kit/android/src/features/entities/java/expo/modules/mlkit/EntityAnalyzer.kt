package expo.modules.mlkit

import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.nl.entityextraction.Entity
import com.google.mlkit.nl.entityextraction.EntityAnnotation
import com.google.mlkit.nl.entityextraction.EntityExtraction
import com.google.mlkit.nl.entityextraction.EntityExtractionParams
import com.google.mlkit.nl.entityextraction.EntityExtractor
import com.google.mlkit.nl.entityextraction.EntityExtractorOptions
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.TimeUnit

/**
 * Entity Extraction, one extractor per language. The base detector is
 * bundled; a language's model is downloaded by ML Kit at first use, on Wi-Fi
 * only. Until it is on the device the result is null — "unknown", for the
 * caller to retry — never an empty list, which would read as "no entities".
 */
object EntityAnalyzer {
  private const val FIRST_WAIT_SECONDS = 2L

  /** The entity types kept, by their wire names (`MlKitEntityType`).
   *  Payment cards and IBANs are left out: the numbers are in the OCR text
   *  already, and a labelled, searchable copy of them would only make them
   *  easier to harvest. */
  val TYPES = mapOf(
    Entity.TYPE_ADDRESS to "address",
    Entity.TYPE_DATE_TIME to "dateTime",
    Entity.TYPE_EMAIL to "email",
    Entity.TYPE_FLIGHT_NUMBER to "flightNumber",
    Entity.TYPE_ISBN to "isbn",
    Entity.TYPE_MONEY to "money",
    Entity.TYPE_PHONE to "phone",
    Entity.TYPE_TRACKING_NUMBER to "trackingNumber",
    Entity.TYPE_URL to "url",
  )

  /** `DateTimeEntity.GRANULARITY_*`, year (0) to second (6). */
  private val GRANULARITIES = listOf("year", "month", "week", "day", "hour", "minute", "second")

  /** `TrackingNumberEntity.CARRIER_*` by value, the same list iOS indexes. */
  private val CARRIERS = listOf(
    "unknown", "fedex", "ups", "dhl", "usps", "ontrac", "lasership", "israelPost", "swissPost", "msc", "amazon",
    "iParcel",
  )

  /** ML Kit's model identifier for a BCP-47 tag (`en` → "english"). */
  fun model(language: String): String =
    EntityExtractorOptions.fromLanguageTag(language) ?: throw IllegalArgumentException("No entity model for $language")

  private val extractors = mutableMapOf<String, EntityExtractor>()

  fun extractor(language: String): EntityExtractor = synchronized(extractors) {
    extractors.getOrPut(language) { EntityExtraction.getClient(EntityExtractorOptions.Builder(model(language)).build()) }
  }

  /** Each language's download, started once and again only after one fails. */
  private val downloads = mutableMapOf<String, Task<Void>>()

  /** `language`'s model download (Wi-Fi only unless `wifiOnly` is false),
   *  the one in flight if there is one. */
  fun download(language: String, wifiOnly: Boolean = true): Task<Void> = synchronized(downloads) {
    val running = downloads[language]
    if (running != null && !(running.isComplete && !running.isSuccessful)) return running
    val conditions = DownloadConditions.Builder().apply { if (wifiOnly) requireWifi() }.build()
    extractor(language).downloadModelIfNeeded(conditions).also { downloads[language] = it }
  }

  /**
   * Whether `language`'s model is on the device. A download just started is
   * waited for briefly — when the model is already there it settles at once,
   * so the first call of a session is not left "unknown" — and otherwise
   * only checked: off Wi-Fi it never settles, and this module's analysis
   * thread is shared with every other call.
   */
  private fun modelReady(language: String): Boolean {
    val task = download(language)
    if (!task.isComplete) {
      try {
        Tasks.await(task, FIRST_WAIT_SECONDS, TimeUnit.SECONDS)
      } catch (_: Exception) {
        return false
      }
    }
    return task.isSuccessful
  }

  /** The entities in `text`; null while the language model is not on the
   *  device yet. Text with nothing in it has no entities either way. */
  fun extract(text: String, options: Map<String, Any?> = emptyMap()): List<Map<String, Any>>? {
    if (text.isBlank()) return emptyList()
    val language = options["language"] as? String ?: "en"
    if (!modelReady(language)) return null
    val params = EntityExtractionParams.Builder(text).apply {
      (options["types"] as? List<*>)?.let { names ->
        setEntityTypesFilter(TYPES.filterValues { it in names }.keys)
      }
      (options["referenceTime"] as? Number)?.let { setReferenceTime(it.toLong()) }
      (options["timeZone"] as? String)?.let { setReferenceTimeZone(TimeZone.getTimeZone(it)) }
      (options["locale"] as? String)?.let { setPreferredLocale(Locale.forLanguageTag(it)) }
    }.build()
    return awaitDetector(extractor(language).annotate(params)).flatMap { annotation ->
      annotation.entities.mapNotNull { json(annotation, it) }
    }
  }

  private fun json(annotation: EntityAnnotation, entity: Entity): Map<String, Any>? {
    val type = TYPES[entity.type] ?: return null
    val out = mutableMapOf<String, Any>(
      "type" to type, "value" to annotation.annotatedText, "start" to annotation.start, "end" to annotation.end,
    )
    when (entity.type) {
      Entity.TYPE_DATE_TIME -> entity.asDateTimeEntity()?.let {
        out["dateTime"] = mapOf(
          "timestamp" to it.timestampMillis.toDouble(),
          "granularity" to (GRANULARITIES.getOrNull(it.dateTimeGranularity) ?: "unknown"),
        )
      }
      Entity.TYPE_MONEY -> entity.asMoneyEntity()?.let {
        out["money"] = mapOf(
          "integerPart" to it.integerPart, "fractionalPart" to it.fractionalPart, "currency" to it.unnormalizedCurrency,
        )
      }
      Entity.TYPE_FLIGHT_NUMBER -> entity.asFlightNumberEntity()?.let {
        out["flightNumber"] = mapOf("airlineCode" to it.airlineCode, "flightNumber" to it.flightNumber)
      }
      Entity.TYPE_ISBN -> entity.asIsbnEntity()?.let { out["isbn"] = it.isbn }
      Entity.TYPE_TRACKING_NUMBER -> entity.asTrackingNumberEntity()?.let {
        out["trackingNumber"] = mapOf(
          "carrier" to (CARRIERS.getOrNull(it.parcelCarrier) ?: "unknown"), "number" to it.parcelTrackingNumber,
        )
      }
    }
    return out
  }
}
