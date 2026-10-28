package expo.modules.mlkit

import android.graphics.Bitmap
import com.google.mlkit.vision.common.InputImage
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
 * every platform. ML Kit's per-line confidence is not used: iOS has none.
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

  /** The `script` recognizer's read: the full text and its blocks. */
  fun recognize(image: InputImage, script: String): Map<String, Any> {
    val recognizer = SCRIPTS[script]?.value ?: throw IllegalArgumentException("Unknown script $script")
    val text = awaitDetector(recognizer.process(image))
    val blocks = text.textBlocks.mapNotNull { block ->
      val box = block.boundingBox ?: return@mapNotNull null
      mapOf("text" to block.text, "boundingBox" to box.normalizedIn(image))
    }
    return mapOf("text" to text.text, "blocks" to blocks)
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
