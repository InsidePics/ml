package expo.modules.mlkit

import android.app.Activity
import com.google.mlkit.common.MlKitException
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import expo.modules.kotlin.Promise
import expo.modules.kotlin.functions.Queues
import expo.modules.kotlin.modules.ModuleDefinitionBuilder
import expo.modules.kotlin.records.Field
import expo.modules.kotlin.records.Record

/** `scanCode`'s options: `MlKitCodeScannerOptions`. */
class CodeScannerOptions : Record {
  /** `ML_KIT_BARCODE_FORMATS` names; every format when empty. */
  @Field val formats: List<String> = emptyList()
  @Field val allowManualInput: Boolean = false
  @Field val autoZoom: Boolean = false
}

/**
 * Google's code scanner (Android only): a Play services screen that finds
 * one code with the camera, without the app holding the camera permission.
 * Its value has [BarcodeValues]' fields; there is no image to box it in.
 */
object CodeScanner {
  /**
   * Opens the scanner over `activity` and resolves with the code's value, or
   * null when the user leaves without one. Settled from the scan's listeners.
   */
  fun scan(activity: Activity, options: CodeScannerOptions, promise: Promise) {
    val builder = GmsBarcodeScannerOptions.Builder()
    if (options.formats.isNotEmpty()) {
      val codes = options.formats.map(BarcodeAnalyzer::format)
      builder.setBarcodeFormats(codes.first(), *codes.drop(1).toIntArray())
    }
    if (options.allowManualInput) builder.allowManualInput()
    if (options.autoZoom) builder.enableAutoZoom()
    GmsBarcodeScanning.getClient(activity, builder.build()).startScan()
      .addOnSuccessListener { code ->
        val format = BarcodeAnalyzer.FORMATS[code.format]
        if (format == null) promise.reject("ERR_ML_KIT", "The scanner read a code of an unknown format (${code.format})", null)
        else promise.resolve(BarcodeValues.fields(code, format))
      }
      .addOnCanceledListener { promise.resolve(null) }
      .addOnFailureListener { e ->
        if ((e as? MlKitException)?.errorCode == MlKitException.CODE_SCANNER_CANCELLED) promise.resolve(null)
        else promise.reject("ERR_ML_KIT", e.message ?: "The code scanner failed", e)
      }
  }
}

object CodeScannerFeature : MlKitFeature {
  override val name = "codeScanner"

  override fun define(module: ModuleDefinitionBuilder) {
    module.AsyncFunction("scanCode") { options: CodeScannerOptions, promise: Promise ->
      CodeScanner.scan(MlKitHost.activity, options, promise)
    }.runOnQueue(Queues.MAIN)
  }
}
