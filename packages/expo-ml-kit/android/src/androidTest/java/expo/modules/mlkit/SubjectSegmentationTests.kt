package expo.modules.mlkit

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import insidepics.testsupport.Fixtures
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Subject Segmentation on `body.jpg` and `animal.jpg`. Its model is a Play
 * services module: the tests that segment install it first through the
 * module's own download call, and FAIL if the install does not finish in
 * time. Until it is installed, a segment call is refused at once.
 */
@RunWith(AndroidJUnit4::class)
class SubjectSegmentationTests {
  private val context get() = InstrumentationRegistry.getInstrumentation().targetContext

  private fun ready() = settle { PlayModules.isReady(context, SubjectSegmenter.module, it) }.resolved() as Boolean

  /** Installs the module (at once when it is there), or fails. */
  private fun install() {
    settle { PlayModules.install(context, SubjectSegmenter.module, it) }.resolved(seconds = 600)
    assertTrue("installed, yet not ready", ready())
  }

  private fun segment(name: String, subjects: Boolean): Json {
    install()
    return settle { SubjectSegmenter.segment(context, Fixtures.handle(name), subjects, it) }.resolved().json()
  }

  private fun coverage(mask: Json): Double {
    val data = mask["data"] as ByteArray
    assertEquals((mask["width"] as Int) * (mask["height"] as Int), data.size)
    return data.count { (it.toInt() and 0xFF) >= 128 }.toDouble() / data.size
  }

  @Test fun refusesWithoutTheModuleRatherThanWaiting() {
    val image = Fixtures.handle("body.jpg")
    val call = settle { SubjectSegmenter.segment(context, image, false, it) }
    if (ready()) call.resolved() else assertEquals("ERR_ML_KIT_MODULE_MISSING", call.rejected(seconds = 30))
  }

  @Test fun installsTheModule() {
    install()
    // Installing again resolves at once.
    settle { PlayModules.install(context, SubjectSegmenter.module, it) }.resolved(seconds = 60)
  }

  @Test fun separatesThePersonFromTheRoom() {
    val result = segment("body.jpg", subjects = false)
    val foreground = result["foreground"].json()
    assertEquals(640, foreground["width"])
    assertEquals(427, foreground["height"])
    val share = coverage(foreground)
    assertTrue("foreground share $share", share in 0.05..0.8)
    assertEquals(emptyList<Any>(), result["subjects"])
  }

  @Test fun givesEachSubjectItsBoxAndMask() {
    for (name in listOf("body.jpg", "animal.jpg")) {
      val subjects = segment(name, subjects = true)["subjects"].list()
      assertTrue("no subject in $name", subjects.isNotEmpty())
      for (subject in subjects) {
        assertUnitRect(subject["boundingBox"], name)
        val box = subject["boundingBox"].json()
        val mask = subject["mask"].json()
        assertEquals(Math.round((box["width"] as Double) * 640).toInt(), mask["width"])
        assertTrue("an empty subject in $name", coverage(mask) > 0.1)
      }
    }
  }

  @Test fun theDogFillsMuchOfItsPhoto() {
    val share = coverage(segment("animal.jpg", subjects = false)["foreground"].json())
    assertTrue("foreground share $share", share in 0.1..0.9)
  }
}
