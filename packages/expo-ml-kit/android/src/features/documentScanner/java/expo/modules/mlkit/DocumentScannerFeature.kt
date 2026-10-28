package expo.modules.mlkit

import android.content.Context
import android.content.Intent
import android.content.IntentSender
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts.StartIntentSenderForResult
import expo.modules.kotlin.Promise
import expo.modules.kotlin.activityresult.AppContextActivityResultContract
import expo.modules.kotlin.activityresult.AppContextActivityResultLauncher
import expo.modules.kotlin.functions.Queues
import expo.modules.kotlin.modules.ModuleDefinitionBuilder

/**
 * The scanner's screen through Expo's activity result registry, which
 * starts an `IntentSender` the way `StartIntentSenderForResult` asks. The
 * registry persists a launch's input, and a sender cannot be: the input is
 * a tag, and the sender the one scan in flight.
 */
private object ScannerScreen : AppContextActivityResultContract<String, Pair<Int, Intent?>> {
  @Volatile var sender: IntentSender? = null

  override fun createIntent(context: Context, input: String): Intent {
    val request = IntentSenderRequest.Builder(sender ?: throw IllegalStateException("No document scan to start")).build()
    return Intent(StartIntentSenderForResult.ACTION_INTENT_SENDER_REQUEST)
      .putExtra(StartIntentSenderForResult.EXTRA_INTENT_SENDER_REQUEST, request)
  }

  override fun parseResult(input: String, resultCode: Int, intent: Intent?) = resultCode to intent
}

/** Owns the module's one `RegisterActivityContracts` slot: no other feature
 *  may set it, or the scanner's launcher is lost. */
object DocumentScannerFeature : MlKitFeature {
  override val name = "documentScanner"

  @Volatile private var launcher: AppContextActivityResultLauncher<String, Pair<Int, Intent?>>? = null

  override fun define(module: ModuleDefinitionBuilder) {
    module.RegisterActivityContracts { launcher = registerForActivityResult(ScannerScreen) }
    module.AsyncFunction("scanDocument") { options: DocumentScannerOptions, promise: Promise ->
      val screen = launcher
        ?: return@AsyncFunction promise.reject("ERR_ML_KIT_NO_ACTIVITY", "The document scanner is not registered with an activity yet", null)
      DocumentScanner.scan(MlKitHost.activity, options, promise) { sender, done ->
        ScannerScreen.sender = sender
        screen.launch("scan") { (code, data) ->
          ScannerScreen.sender = null
          done(code, data)
        }
      }
    }.runOnQueue(Queues.MAIN)
  }
}
