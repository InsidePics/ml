package expo.modules.mlkit

import android.graphics.Bitmap
import android.graphics.Point
import android.graphics.Rect
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
import com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder
import expo.modules.kotlin.sharedobjects.SharedRef

/**
 * Text Recognition v2, one bundled recognizer per script. Which run, and
 * which read is kept, is decided in TS (`src/textQuality.ts`) the same on
 * every platform from the text alone: Android's confidences and angles are
 * returned, but iOS reports none.
 */
object TextAnalyzer {
  /** `MlKitTextScript` names, the same iOS uses. */
  private val SCRIPTS: Map<String, Lazy<TextRecognizer>> = mapOf(
    "latin" to lazy { TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS) },
    "chinese" to lazy { TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build()) },
    "devanagari" to lazy { TextRecognition.getClient(DevanagariTextRecognizerOptions.Builder().build()) },
    "japanese" to lazy { TextRecognition.getClient(JapaneseTextRecognizerOptions.Builder().build()) },
    "korean" to lazy { TextRecognition.getClient(KoreanTextRecognizerOptions.Builder().build()) },
  )

  /** The `script` recognizer's read: the full text and its blocks, lines,
   *  elements and symbols (`MlKitTextBlock`). */
  fun recognize(image: InputImage, script: String): Map<String, Any> {
    val recognizer = SCRIPTS[script]?.value ?: throw IllegalArgumentException("Unknown script $script")
    val text = awaitDetector(recognizer.process(image))
    return mapOf("text" to text.text, "blocks" to text.textBlocks.mapNotNull { block ->
      part(image, block.text, block.boundingBox, block.cornerPoints, listOf(block.recognizedLanguage))
        ?.plus("lines" to block.lines.mapNotNull { line ->
          part(image, line.text, line.boundingBox, line.cornerPoints, listOf(line.recognizedLanguage))
            ?.plus(mapOf(
              "confidence" to line.confidence.toDouble(),
              "angle" to line.angle.toDouble(),
              "elements" to line.elements.mapNotNull { element(image, it) },
            ))
        })
    })
  }

  private fun element(image: InputImage, element: Text.Element): Map<String, Any>? =
    part(image, element.text, element.boundingBox, element.cornerPoints, listOf(element.recognizedLanguage))
      ?.plus(mapOf(
        "confidence" to element.confidence.toDouble(),
        "angle" to element.angle.toDouble(),
        "symbols" to element.symbols.mapNotNull { symbol ->
          part(image, symbol.text, symbol.boundingBox, symbol.cornerPoints, listOf(symbol.recognizedLanguage))
            ?.plus(mapOf("confidence" to symbol.confidence.toDouble(), "angle" to symbol.angle.toDouble()))
        },
      ))

  /** What every level shares; none for a part ML Kit gave no box. "und"
   *  (undetermined) languages are dropped. */
  private fun part(
    image: InputImage, text: String, box: Rect?, corners: Array<Point>?, languages: List<String>,
  ): Map<String, Any>? {
    box ?: return null
    return mapOf(
      "text" to text,
      "boundingBox" to box.normalizedIn(image),
      "cornerPoints" to (corners ?: emptyArray()).map { it.normalizedIn(image) },
      "recognizedLanguages" to languages.filter { it.isNotEmpty() && it != "und" },
    )
  }
}

/** Text recognition: `analyzeImage`'s Latin read, and `recognizeText`. */
object TextFeature : MlKitFeature {
  override val name = "text"
  override val imageModels = listOf(ImageModel("mlKitText", "text") { TextAnalyzer.recognize(it, "latin") })

  override fun define(module: ModuleDefinitionBuilder) {
    module.AsyncFunction("recognizeText") { image: SharedRef<Bitmap>, scripts: List<String>, promise: Promise ->
      MlKitCalls.withImage(image, promise) { input -> scripts.map { TextAnalyzer.recognize(input, it) } }
    }
  }
}
