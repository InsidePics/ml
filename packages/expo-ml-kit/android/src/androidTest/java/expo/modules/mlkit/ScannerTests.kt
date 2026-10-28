package expo.modules.mlkit

import android.app.Activity
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts.StartIntentSenderForResult
import androidx.lifecycle.Lifecycle
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Google's code and document scanners: each screen really opens (Play
 * services installs its module on first use, which the wait allows for),
 * and a back press, the user leaving, resolves the call with null. A screen
 * that never shows FAILS the test.
 */
@RunWith(AndroidJUnit4::class)
class ScannerTests {
  private val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())

  @Before fun wake() {
    device.wakeUp()
    device.executeShellCommand("wm dismiss-keyguard")
  }

  @Test fun codeScannerResolvesNullWhenTheUserLeaves() {
    ActivityScenario.launch(ComponentActivity::class.java).use { scenario ->
      val promise = TestPromise()
      scenario.onActivity { CodeScanner.scan(it, CodeScannerOptions(), promise) }
      leaveGooglesScreen(scenario, promise)
      assertNull(settledAfterLeaving(promise))
    }
  }

  @Test fun documentScannerResolvesNullWhenTheUserLeaves() {
    ActivityScenario.launch(ComponentActivity::class.java).use { scenario ->
      val promise = TestPromise()
      scenario.onActivity { activity ->
        DocumentScanner.scan(activity, DocumentScannerOptions(), promise) { sender, done ->
          activity.activityResultRegistry
            .register("scan", StartIntentSenderForResult()) { done(it.resultCode, it.data) }
            .launch(IntentSenderRequest.Builder(sender).build())
        }
      }
      leaveGooglesScreen(scenario, promise)
      assertNull(settledAfterLeaving(promise))
    }
  }

  @Test fun aCancelledScreenIsNoScan() {
    assertNull(DocumentScanner.result(Activity.RESULT_CANCELED, null))
  }

  /**
   * Waits for Google's screen to cover the test's activity (the code
   * scanner's runs in this app's process, so the package is no sign), then
   * presses back on it. Fails if the call settles first, or the screen never
   * shows: Play services could not fetch the scanner's module, say.
   */
  private fun leaveGooglesScreen(scenario: ActivityScenario<ComponentActivity>, promise: TestPromise, timeoutMs: Long = 180_000) {
    val deadline = System.currentTimeMillis() + timeoutMs
    while (scenario.state == Lifecycle.State.RESUMED) {
      promise.outcome()?.let { fail("The scanner $it before its screen opened") }
      assertTrue("Google's screen never opened (${front()})", System.currentTimeMillis() < deadline)
      Thread.sleep(500)
    }
    // Let it settle in before leaving it, and say what was left: on a
    // device that cannot fetch the module, a "downloading" screen.
    Thread.sleep(3000)
    Log.i("ScannerTests", "Leaving ${front()}")
    device.pressBack()
  }

  /** What the call settled with once the screen was left, or a failure
   *  naming what is in front instead. */
  private fun settledAfterLeaving(promise: TestPromise): Any? {
    val deadline = System.currentTimeMillis() + 30_000
    while (promise.outcome() == null) {
      assertTrue("The call did not settle after the back press (${front()})", System.currentTimeMillis() < deadline)
      Thread.sleep(500)
    }
    return promise.resolved(seconds = 1)
  }

  private fun front(): String =
    device.executeShellCommand("dumpsys activity activities").lines()
      .firstOrNull { "topResumedActivity" in it }?.trim() ?: "no resumed activity"
}
