package expo.modules.mlkit

import android.content.Context
import com.google.android.gms.common.api.OptionalModuleApi
import com.google.android.gms.common.moduleinstall.InstallStatusListener
import com.google.android.gms.common.moduleinstall.ModuleInstall
import com.google.android.gms.common.moduleinstall.ModuleInstallRequest
import com.google.android.gms.common.moduleinstall.ModuleInstallStatusUpdate.InstallState
import expo.modules.kotlin.Promise
import java.util.concurrent.atomic.AtomicBoolean

/**
 * A Google Play services model module (`play-services-mlkit-*`): whether the
 * device has it, and its install. Both are settled from Play services'
 * listeners, never waited for on the analysis thread.
 */
object PlayModules {
  /** Resolves whether `api`'s module is on the device. */
  fun isReady(context: Context, api: OptionalModuleApi, promise: Promise) {
    MlKitCalls.settle(promise, ModuleInstall.getClient(context).areModulesAvailable(api)) { it.areModulesAvailable() }
  }

  /** `run` once `api`'s module is on the device; else rejects with
   *  `ERR_ML_KIT_MODULE_MISSING` straight away. */
  fun whenReady(context: Context, api: OptionalModuleApi, what: String, promise: Promise, run: () -> Unit) {
    ModuleInstall.getClient(context).areModulesAvailable(api)
      .addOnSuccessListener {
        if (it.areModulesAvailable()) run()
        else promise.reject("ERR_ML_KIT_MODULE_MISSING", "$what's Google Play services module is not on this device yet: download it first", null)
      }
      .addOnFailureListener { promise.reject("ERR_ML_KIT_MODULE_MISSING", it.message ?: "Google Play services is unavailable", it) }
  }

  /**
   * Installs `api`'s module, resolving once it is on the device (at once
   * when it already is) and rejecting when the install fails or is
   * cancelled. The request's own task completes on acceptance, before the
   * download: the install's end comes through its status listener.
   */
  fun install(context: Context, api: OptionalModuleApi, promise: Promise) {
    val client = ModuleInstall.getClient(context)
    val settled = AtomicBoolean(false)
    lateinit var listener: InstallStatusListener
    fun finish(error: String?) {
      if (!settled.compareAndSet(false, true)) return
      client.unregisterListener(listener)
      if (error == null) promise.resolve(null) else promise.reject("ERR_ML_KIT_MODULE_INSTALL", error, null)
    }
    listener = InstallStatusListener { update ->
      when (update.installState) {
        InstallState.STATE_COMPLETED -> finish(null)
        InstallState.STATE_FAILED -> finish("The module's install failed (error ${update.errorCode})")
        InstallState.STATE_CANCELED -> finish("The module's install was cancelled")
      }
    }
    val request = ModuleInstallRequest.newBuilder().addApi(api).setListener(listener).build()
    client.installModules(request)
      .addOnSuccessListener { if (it.areModulesAlreadyInstalled()) finish(null) }
      .addOnFailureListener { finish(it.message ?: "The module's install could not start") }
  }
}
