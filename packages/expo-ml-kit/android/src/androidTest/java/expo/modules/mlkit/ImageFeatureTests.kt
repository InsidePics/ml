package expo.modules.mlkit

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.google.mlkit.vision.common.InputImage
import insidepics.testsupport.Fixtures
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** The image features beyond `analyzeImage`'s defaults: the full text
 *  structure, face classification, label and object options, the accurate
 *  pose model, custom models and selfie segmentation. iOS: `ImageFeatureTests`. */
@RunWith(AndroidJUnit4::class)
class ImageFeatureTests {
  private fun <T> on(name: String, run: (InputImage) -> T): T = AnalysisBitmap.analyze(Fixtures.handle(name), run)

  /** The model fixture as a file, as a caller passes its own model's path. */
  private val model: Map<String, Any?> by lazy {
    val file = File(InstrumentationRegistry.getInstrumentation().targetContext.cacheDir, "mobilenet.tflite")
    file.writeBytes(Fixtures.bytes("mobilenet-v1-metadata.tflite"))
    mapOf("path" to "file://${file.absolutePath}")
  }

  @Test fun textReadsLinesElementsAndSymbols() {
    val text = on("text.jpg") { TextAnalyzer.recognize(it, "latin") }
    val lines = text["blocks"].list().flatMap { it["lines"].list() }
    assertTrue(lines.isNotEmpty())
    val word = lines.flatMap { it["elements"].list() }.first { it["text"] == "WARNING" }
    assertUnitRect(word["boundingBox"], "word box")
    assertEquals(4, word["cornerPoints"].list().size)
    assertTrue((word["confidence"] as Double) in 0.0..1.0)
    assertEquals("WARNING", word["symbols"].list().joinToString("") { it["text"] as String })
    assertTrue("${word["recognizedLanguages"]}", "en" in (word["recognizedLanguages"] as List<*>))
  }

  @Test fun facesScoreTheSmileAndOpenEyesWhenAsked() {
    val plain = on("face.jpg") { FaceAnalyzer.detect(it) }.single()
    assertTrue("smilingProbability" !in plain)
    val face = on("face.jpg") { FaceAnalyzer.detect(it, FaceAnalyzer.Options(classify = true)) }.single()
    assertTrue("$face", (face["smilingProbability"] as Double) > 0.5)
    assertTrue("$face", (face["leftEyeOpenProbability"] as Double) > 0.5)
    assertTrue("$face", (face["rightEyeOpenProbability"] as Double) > 0.5)
  }

  @Test fun labelsHonourTheThreshold() {
    val all = on("animal.jpg") { LabelAnalyzer.label(it, 0.1f) }
    val sure = on("animal.jpg") { LabelAnalyzer.label(it, 0.8f) }
    assertTrue(all.size > sure.size)
    assertTrue(all.all { (it["confidence"] as Double) >= 0.1 })
  }

  @Test fun objectsFindOneOrSeveralUnlabelledWhenAsked() {
    val one = on("body.jpg") { ObjectAnalyzer.detect(it, multiple = false, classify = false) }
    assertEquals(1, one.size)
    assertEquals(0, one.single()["labels"].list().size)
  }

  @Test fun theAccuratePoseModelFindsTheSamePerson() {
    val accurate = on("body.jpg") { PoseAnalyzer.detect(it, PosesAccurateFeature.detector) }
    val landmarks = accurate.single()["landmarks"].list()
    assertEquals(33, landmarks.size)
    val base = on("body.jpg") { PoseAnalyzer.detect(it) }.single()["landmarks"].list()
    val nose = { list: List<Json> -> list.first { it["type"] == "nose" } }
    assertEquals(nose(base)["x"] as Double, nose(landmarks)["x"] as Double, 0.05)
  }

  @Test fun aCustomClassifierLabelsTheDog() {
    val labels = on("animal.jpg") { CustomLabelsFeature.label(it, mapOf("model" to model, "confidenceThreshold" to 0.1)) }
    assertTrue("$labels", labels.any { (it["text"] as String).contains("shepherd", ignoreCase = true) })
  }

  @Test fun aCustomClassifierLabelsTheDetectedObjects() {
    val objects = on("body.jpg") { CustomObjectsFeature.detect(it, mapOf("model" to model, "confidenceThreshold" to 0.1)) }
    assertTrue(objects.isNotEmpty())
    assertTrue("$objects", objects.any { it["labels"].list().isNotEmpty() })
  }

  @Test fun aMissingModelFileIsRefused() {
    val missing = mapOf("model" to mapOf("path" to "/nowhere/model.tflite"))
    val error = runCatching { CustomModels.path(missing) }.exceptionOrNull()
    assertTrue("$error", error is IllegalArgumentException)
  }

  @Test fun selfieSegmentationMasksThePerson() {
    val mask = on("body.jpg") { SelfieSegmentationFeature.segment(it, rawSize = false) }
    val bytes = mask["data"] as ByteArray
    assertEquals((mask["width"] as Int) * (mask["height"] as Int), bytes.size)
    val inside = bytes.count { (it.toInt() and 0xFF) >= 128 }.toDouble() / bytes.size
    assertTrue("person share $inside", inside in 0.05..0.9)
    val empty = on("landscape.jpg") { SelfieSegmentationFeature.segment(it, rawSize = false) }
    val emptyShare = (empty["data"] as ByteArray).count { (it.toInt() and 0xFF) >= 128 }.toDouble() / bytes.size
    assertTrue("landscape share $emptyShare", emptyShare < inside)
  }
}
