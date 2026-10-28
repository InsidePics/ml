package expo.modules.mlkit

import android.graphics.Bitmap
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder
import expo.modules.kotlin.sharedobjects.SharedRef

/** Barcode Scanning, bundled model, every format. */
object BarcodeAnalyzer {
  private val everyFormat by lazy { BarcodeScanning.getClient() }

  /** `Barcode.FORMAT_*` without the prefix: `ML_KIT_BARCODE_FORMATS`. QR's
   *  name contains "QR", which the QR reader matches on. A code in any other
   *  format is dropped. */
  private val FORMATS = mapOf(
    Barcode.FORMAT_AZTEC to "AZTEC",
    Barcode.FORMAT_CODABAR to "CODABAR",
    Barcode.FORMAT_CODE_39 to "CODE_39",
    Barcode.FORMAT_CODE_93 to "CODE_93",
    Barcode.FORMAT_CODE_128 to "CODE_128",
    Barcode.FORMAT_DATA_MATRIX to "DATA_MATRIX",
    Barcode.FORMAT_EAN_8 to "EAN_8",
    Barcode.FORMAT_EAN_13 to "EAN_13",
    Barcode.FORMAT_ITF to "ITF",
    Barcode.FORMAT_PDF417 to "PDF417",
    Barcode.FORMAT_QR_CODE to "QR_CODE",
    Barcode.FORMAT_UPC_A to "UPC_A",
    Barcode.FORMAT_UPC_E to "UPC_E",
  )

  /** The codes in `image`, every format or only `formats` (names from
   *  `ML_KIT_BARCODE_FORMATS`; fewer formats scan faster). */
  fun scan(image: InputImage, formats: List<String>? = null): List<Map<String, Any?>> =
    awaitDetector(scanner(formats).process(image)).mapNotNull { code ->
      val format = FORMATS[code.format] ?: return@mapNotNull null
      BarcodeValues.fields(code, format) + mapOf(
        "boundingBox" to (code.boundingBox?.normalizedIn(image) ?: Geometry.rect(0.0, 0.0, 0.0, 0.0, 1, 1)),
        "cornerPoints" to (code.cornerPoints ?: emptyArray()).map { it.normalizedIn(image) },
      )
    }

  /** `Barcode.FORMAT_*` for a `ML_KIT_BARCODE_FORMATS` name. */
  fun format(name: String): Int =
    FORMATS.entries.firstOrNull { it.value == name }?.key ?: throw IllegalArgumentException("Unknown barcode format $name")

  private val scanners = mutableMapOf<List<String>, BarcodeScanner>()

  private fun scanner(formats: List<String>?): BarcodeScanner {
    if (formats.isNullOrEmpty()) return everyFormat
    val key = formats.sorted()
    return synchronized(scanners) {
      scanners.getOrPut(key) {
        val codes = key.map(::format)
        BarcodeScanning.getClient(
          BarcodeScannerOptions.Builder().setBarcodeFormats(codes.first(), *codes.drop(1).toIntArray()).build()
        )
      }
    }
  }
}

object BarcodesFeature : MlKitFeature {
  override val name = "barcodes"
  override val imageModels = listOf(ImageModel("mlKitBarcodes", "barcodes") { BarcodeAnalyzer.scan(it) })

  override fun define(module: ModuleDefinitionBuilder) {
    module.AsyncFunction("detectBarcodes") { image: SharedRef<Bitmap>, formats: List<String>?, promise: Promise ->
      MlKitCalls.withImage(image, promise) { BarcodeAnalyzer.scan(it, formats) }
    }
  }
}
