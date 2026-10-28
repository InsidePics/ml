package expo.modules.mlkit

import android.app.Activity
import android.content.Intent
import android.content.IntentSender
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import expo.modules.kotlin.Promise
import expo.modules.kotlin.records.Field
import expo.modules.kotlin.records.Record

/** `scanDocument`'s options: `MlKitDocumentScannerOptions`. */
class DocumentScannerOptions : Record {
  /** 0: no limit. */
  @Field val pageLimit: Int = 0
  /** `jpeg` and/or `pdf`. */
  @Field val formats: List<String> = listOf("jpeg")
  /** `base`, `baseWithFilter` or `full`. */
  @Field val mode: String = "full"
  @Field val galleryImport: Boolean = false
}

/**
 * Google's document scanner (Android only): a Play services screen that
 * finds, crops and cleans up pages with the camera, without the app holding
 * the camera permission. The screen is an activity result; how it is
 * launched is the caller's ([DocumentScannerFeature]: Expo's registry).
 */
object DocumentScanner {
  private val MODES = mapOf(
    "base" to GmsDocumentScannerOptions.SCANNER_MODE_BASE,
    "baseWithFilter" to GmsDocumentScannerOptions.SCANNER_MODE_BASE_WITH_FILTER,
    "full" to GmsDocumentScannerOptions.SCANNER_MODE_FULL,
  )
  private val FORMATS = mapOf(
    "jpeg" to GmsDocumentScannerOptions.RESULT_FORMAT_JPEG,
    "pdf" to GmsDocumentScannerOptions.RESULT_FORMAT_PDF,
  )

  fun options(options: DocumentScannerOptions): GmsDocumentScannerOptions {
    val mode = MODES[options.mode] ?: throw IllegalArgumentException("Unknown document scanner mode ${options.mode}")
    val formats = options.formats.ifEmpty { listOf("jpeg") }.map {
      FORMATS[it] ?: throw IllegalArgumentException("Unknown document format $it")
    }
    val builder = GmsDocumentScannerOptions.Builder()
      .setScannerMode(mode)
      .setGalleryImportAllowed(options.galleryImport)
      .setResultFormats(formats.first(), *formats.drop(1).toIntArray())
    if (options.pageLimit > 0) builder.setPageLimit(options.pageLimit)
    return builder.build()
  }

  /**
   * Opens the scanner over `activity` through `launch`, which starts the
   * sender for a result and calls back with its code and data; resolves
   * with the scan, or null when the user leaves without one.
   */
  fun scan(
    activity: Activity,
    options: DocumentScannerOptions,
    promise: Promise,
    launch: (IntentSender, (Int, Intent?) -> Unit) -> Unit,
  ) {
    val scanner = try {
      GmsDocumentScanning.getClient(options(options))
    } catch (e: IllegalArgumentException) {
      return promise.reject("ERR_ML_KIT", e.message, e)
    }
    scanner.getStartScanIntent(activity)
      .addOnSuccessListener { sender ->
        launch(sender) { code, data ->
          try {
            promise.resolve(result(code, data))
          } catch (e: Throwable) {
            promise.reject("ERR_ML_KIT", e.message ?: "The document scanner failed", e)
          }
        }
      }
      .addOnCanceledListener { promise.resolve(null) }
      .addOnFailureListener { promise.reject("ERR_ML_KIT", it.message ?: "The document scanner could not open", it) }
  }

  /** The screen's result as `MlKitDocumentScan`, or null when cancelled. */
  fun result(code: Int, data: Intent?): Map<String, Any?>? {
    if (code != Activity.RESULT_OK) return null
    val scan = GmsDocumentScanningResult.fromActivityResultIntent(data)
      ?: throw IllegalStateException("The document scanner returned no result")
    return mapOf(
      "pages" to (scan.pages ?: emptyList()).map { mapOf("uri" to it.imageUri.toString()) },
      "pdf" to scan.pdf?.let { mapOf("uri" to it.uri.toString(), "pageCount" to it.pageCount) },
    )
  }
}
