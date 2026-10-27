package expo.modules.mlkit

import android.graphics.Bitmap
import insidepics.testsupport.Fixtures
import org.junit.Assert.assertTrue
import org.junit.Assert.fail

// Shared by the ML Kit suites: each call takes the module's path, the
// fixture decoded as a caller's handle is (Glide, as expo-image-manipulator)
// and handed to ML Kit by `AnalysisBitmap.analyze`. Instrumented tests run
// off the main thread, where ML Kit's `Tasks.await` must be.

typealias Json = Map<String, Any?>

/** The fixture as the module's `analyzeImage` returns it, for `models`. */
fun analyze(name: String, models: Set<String>): Json =
  AnalysisBitmap.analyze(Fixtures.handle(name)) { MlKitAnalyzer.analyze(it, models) }

/** ML Kit's faces in the fixture, as the module's `detectFaces` returns them. */
fun detectFaces(name: String): List<Json> =
  AnalysisBitmap.analyze(Fixtures.handle(name)) { FaceAnalyzer.detect(it) }

/** `scripts`' reads of `bitmap`, as the module's `recognizeText` returns them. */
fun recognize(bitmap: Bitmap, scripts: List<String>): List<Json> =
  AnalysisBitmap.analyze(bitmap) { MlKitAnalyzer.recognize(it, scripts) }

@Suppress("UNCHECKED_CAST")
fun Any?.json(): Json = this as? Json ?: fail("not an object: $this") as Nothing

@Suppress("UNCHECKED_CAST")
fun Any?.list(): List<Json> = this as? List<Json> ?: fail("not a list: $this") as Nothing

/** A normalized rect (`x`, `y`, `width`, `height`) inside the unit square. */
fun assertUnitRect(value: Any?, message: String) {
  val rect = value.json()
  val x = rect["x"] as Double
  val y = rect["y"] as Double
  val w = rect["width"] as Double
  val h = rect["height"] as Double
  val slack = 0.01
  assertTrue("$message: $rect", w > 0 && h > 0)
  assertTrue("$message: $rect", x >= -slack && y >= -slack)
  assertTrue("$message: $rect", x + w <= 1 + slack && y + h <= 1 + slack)
}

/** A face's box: x, y, width, height (Vision's frame, bottom-left origin). */
fun box(face: Json?): DoubleArray {
  val rect = face?.get("boundingBox").json()
  return doubleArrayOf(rect["x"] as Double, rect["y"] as Double, rect["width"] as Double, rect["height"] as Double)
}

/** A landmark region's centre in image coordinates, normalized, TOP-left
 *  origin (regions are box-relative with a bottom-left origin). */
fun landmarkInImage(face: Json, region: String): Pair<Double, Double> {
  val (bx, by, bw, bh) = box(face).toList()
  val points = face["landmarks"].json()[region].list()
  assertTrue("no $region", points.isNotEmpty())
  val x = points.sumOf { it["x"] as Double } / points.size
  val y = points.sumOf { it["y"] as Double } / points.size
  return (bx + x * bw) to (1 - (by + y * bh))
}
