package expo.modules.mlkit

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.common.MlKitException
import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.common.model.RemoteModelManager
import com.google.mlkit.nl.translate.TranslateRemoteModel
import insidepics.testsupport.Fixtures
import java.util.concurrent.ExecutionException
import java.util.concurrent.TimeUnit
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Translation and Digital Ink, whose models download: the suite downloads
 * them and FAILS if a download never lands. iOS: `DownloadedModelTests`.
 */
@RunWith(AndroidJUnit4::class)
class DownloadedModelTests {
  private fun <T> await(task: Task<T>, seconds: Long = 300): T = Tasks.await(task, seconds, TimeUnit.SECONDS)

  @Test fun translatesOnceBothModelsAreThere() {
    val translated = await(TranslateFeature.translate("Good morning, my friend", "en", "de", true, false))
    assertTrue(translated, translated.contains("Guten Morgen", ignoreCase = true))
    val downloaded = await(RemoteModelManager.getInstance().getDownloadedModels(TranslateRemoteModel::class.java))
    assertTrue("$downloaded", downloaded.any { it.language == "de" })
  }

  @Test fun refusesAPairWhoseModelIsMissing() {
    val model = TranslateRemoteModel.Builder("is").build()
    await(RemoteModelManager.getInstance().deleteDownloadedModel(model))
    try {
      await(TranslateFeature.translate("Hello", "en", "is", false, true))
      fail("translated without the model")
    } catch (e: ExecutionException) {
      assertEquals(MlKitException.NOT_FOUND, (e.cause as MlKitException).errorCode)
    }
  }

  @Test fun readsTheHandwrittenWord() {
    val fixture = JSONObject(Fixtures.text("ink-cat.json"))
    val strokes = (0 until fixture.getJSONArray("strokes").length()).map { i ->
      val points = fixture.getJSONArray("strokes").getJSONArray(i)
      (0 until points.length()).map { j ->
        val p = points.getJSONObject(j)
        mapOf<String, Any?>("x" to p.getDouble("x"), "y" to p.getDouble("y"), "t" to p.getLong("t"))
      }
    }
    await(RemoteModelManager.getInstance().download(DigitalInkFeature.model("en-US"), DownloadConditions.Builder().build()))
    val area = fixture.getJSONObject("writingArea")
    val options = mapOf("language" to "en-US", "writingArea" to mapOf("width" to area.getDouble("width"), "height" to area.getDouble("height")))
    val candidates = await(DigitalInkFeature.recognize(strokes, options))
    assertTrue("$candidates", candidates.take(3).any { (it["text"] as String).equals("cat", ignoreCase = true) })
  }

  @Test fun refusesAnUnknownInkModel() {
    try {
      DigitalInkFeature.model("not-a-language-xx")
      fail("made a model for no language")
    } catch (_: IllegalArgumentException) {
    }
  }
}
