package expo.modules.mlkit

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Barcodes, labels, objects and pose through `analyzeImage`, and the one
 *  decode it shares between them. `ios/Tests/SceneTests.swift`, test for
 *  test. */
@RunWith(AndroidJUnit4::class)
class SceneTests {
  private val everyModel = setOf("mlKitText", "mlKitLabels", "mlKitBarcodes", "mlKitPoses", "mlKitObjects")

  private fun barcodes(name: String) = analyze(name, setOf("mlKitBarcodes"))["barcodes"].list()

  @Test fun barcodesReadTheQRCode() {
    val codes = barcodes("qrcode.jpg")
    val qr = codes.firstOrNull { it["format"] == "QR_CODE" } ?: error("no QR in $codes")
    assertFalse("QR payload", (qr["rawValue"] as? String).isNullOrEmpty())
    assertUnitRect(qr["boundingBox"], "QR box")
  }

  @Test fun barcodesReadTheEAN13Label() {
    val codes = barcodes("barcode.jpg")
    val ean = codes.firstOrNull { it["format"] == "EAN_13" } ?: error("no EAN-13 in $codes")
    assertEquals("2404105001722", ean["rawValue"])
    assertUnitRect(ean["boundingBox"], "EAN-13 box")
  }

  @Test fun barcodesFindNoneInALandscape() {
    assertEquals(0, barcodes("landscape.jpg").size)
  }

  @Test fun labelsNameTheDog() {
    val labels = analyze("animal.jpg", setOf("mlKitLabels"))["labels"].list()
    val names = labels.map { it["text"] as String }
    assertTrue("labels: $names", "Dog" in names)
    for (label in labels) {
      assertTrue((label["confidence"] as Double) in 0.0..1.0)
      assertNotNull(label["index"] as? Int)
    }
  }

  @Test fun objectsBoxThePeople() {
    val objects = analyze("body.jpg", setOf("mlKitObjects"))["objects"].list()
    assertTrue(objects.isNotEmpty())
    for (obj in objects) {
      assertUnitRect(obj["boundingBox"], "object box")
      assertNotNull(obj["labels"] as? List<*>)
    }
  }

  /** Known limitation, pinned: ML Kit's object detector boxes nothing in the
   *  lying dog, in any of its modes, though its labels name the dog. If this
   *  fails, Google's model has changed: look, then move the dog to the test
   *  above. */
  @Test fun objectsBoxNoDogLyingInGrass() {
    val result = analyze("animal.jpg", setOf("mlKitObjects", "mlKitLabels"))
    assertEquals(0, result["objects"].list().size)
    assertTrue(result["labels"].list().any { it["text"] == "Dog" })
  }

  @Test fun poseFindsAllThirtyThreeLandmarks() {
    val poses = analyze("body.jpg", setOf("mlKitPoses"))["poses"].list()
    assertEquals("single-person pose", 1, poses.size)
    val landmarks = poses[0]["landmarks"].list()
    assertEquals(33, landmarks.size)
    val types = landmarks.map { it["type"] as String }.toSet()
    assertEquals("each landmark named once", 33, types.size)
    assertFalse("unknown" in types)
    assertTrue(types.containsAll(listOf("nose", "leftShoulder", "rightAnkle", "leftFootIndex")))
    for (landmark in landmarks) assertTrue((landmark["inFrameLikelihood"] as Double) in 0.0..1.0)
  }

  @Test fun poseFindsNobodyInALandscape() {
    assertEquals(0, analyze("landscape.jpg", setOf("mlKitPoses"))["poses"].list().size)
  }

  @Test fun analyzeRunsOnlyTheModelsAsked() {
    val result = analyze("animal.jpg", setOf("mlKitLabels"))
    assertTrue(result["labels"].list().isNotEmpty())
    // Left out, not empty: TS fills in the parts not asked for.
    for (key in listOf("text", "barcodes", "poses", "objects")) assertNull("$key not run", result[key])
  }

  @Test fun analyzeReportsTheUprightSizeWithEveryModel() {
    val result = analyze("face-orientation-6.jpg", everyModel)
    assertEquals(400, result["imageWidth"])
    assertEquals(600, result["imageHeight"])
    for (key in listOf("text", "labels", "barcodes", "poses", "objects")) assertNotNull("missing $key", result[key])
  }
}
