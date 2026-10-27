package expo.modules.mlkit

import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage

/** Barcode Scanning, bundled model, every format. */
object BarcodeAnalyzer {
  private val scanner by lazy { BarcodeScanning.getClient() }

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

  fun scan(image: InputImage): List<Map<String, Any?>> =
    awaitDetector(scanner.process(image)).mapNotNull { code ->
      val format = FORMATS[code.format] ?: return@mapNotNull null
      val box = code.boundingBox
      mapOf(
        "rawValue" to code.rawValue,
        "format" to format,
        "boundingBox" to (box?.normalizedIn(image) ?: Geometry.rect(0.0, 0.0, 0.0, 0.0, 1, 1)),
      )
    }
}
