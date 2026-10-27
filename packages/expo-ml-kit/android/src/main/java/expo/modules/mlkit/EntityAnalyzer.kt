package expo.modules.mlkit

import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.nl.entityextraction.Entity
import com.google.mlkit.nl.entityextraction.EntityExtraction
import com.google.mlkit.nl.entityextraction.EntityExtractorOptions
import java.util.concurrent.TimeUnit

/**
 * Entity Extraction over the recognized text (English model). The base
 * detector is bundled; the language model is downloaded by ML Kit at first
 * use, on Wi-Fi only. Until it is on the device the result is null —
 * "unknown", which the app leaves unrecorded and retries — never an empty
 * list, which would read as "no entities".
 */
object EntityAnalyzer {
  private const val FIRST_WAIT_SECONDS = 2L

  private val extractor by lazy {
    EntityExtraction.getClient(EntityExtractorOptions.Builder(EntityExtractorOptions.ENGLISH).build())
  }

  /** The entity types kept, by their wire names. Payment cards and IBANs
   *  are left out: the numbers are in the OCR text already, and a labelled,
   *  searchable copy of them would only make them easier to harvest. */
  private val TYPES = mapOf(
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

  /** The language model's download, started once and again only after one
   *  fails. */
  @Volatile private var download: Task<Void>? = null

  /**
   * Whether the language model is on the device. A download just started is
   * waited for briefly — when the model is already there it settles at once,
   * so the first photo of a session is not left "unknown" — and otherwise
   * only checked: off Wi-Fi it never settles, and this module's one thread
   * is shared with every other call.
   */
  private fun modelReady(): Boolean {
    var task = download
    val started = task == null || (task.isComplete && !task.isSuccessful)
    if (started) {
      task = extractor.downloadModelIfNeeded(DownloadConditions.Builder().requireWifi().build())
      download = task
    }
    if (started && !task!!.isComplete) {
      try {
        Tasks.await(task, FIRST_WAIT_SECONDS, TimeUnit.SECONDS)
      } catch (_: Exception) {
        return false
      }
    }
    return task!!.isComplete && task.isSuccessful
  }

  /** The entities in `text`; null while the language model is not on the
   *  device yet. Text with nothing in it has no entities either way. */
  fun extract(text: String): List<Map<String, String>>? {
    if (text.isBlank()) return emptyList()
    if (!modelReady()) return null
    return awaitDetector(extractor.annotate(text)).flatMap { annotation ->
      annotation.entities.mapNotNull { entity ->
        val type = TYPES[entity.type] ?: return@mapNotNull null
        mapOf("type" to type, "value" to annotation.annotatedText)
      }
    }
  }
}
