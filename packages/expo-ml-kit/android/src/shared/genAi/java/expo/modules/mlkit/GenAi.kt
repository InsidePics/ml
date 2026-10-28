package expo.modules.mlkit

import com.google.common.util.concurrent.ListenableFuture
import com.google.mlkit.genai.common.DownloadCallback
import com.google.mlkit.genai.common.GenAiException
import expo.modules.kotlin.Promise
import expo.modules.kotlin.exception.CodedException
import java.util.concurrent.CancellationException
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executor

/**
 * What the GenAI features (Gemini Nano through Android's AICore) share:
 * the status every API reports, settling from their futures, and the one
 * rejection for a call the device cannot serve. Nothing here waits on a
 * thread: the futures' listeners settle the call.
 */
object GenAi {
  /** `FeatureStatus` by value: `MlKitGenAiStatus`. */
  private val STATUSES = listOf("unavailable", "downloadable", "downloading", "available")

  fun status(code: Int): String = STATUSES.getOrElse(code) { "unavailable" }

  /** The `Language` values the text APIs share (BCP 47 → `*Options.Language`):
   *  summarization takes the first three. `MlKitGenAiLanguage`. */
  private val LANGUAGES = listOf("en", "ja", "ko", "de", "fr", "it", "es")

  fun language(tag: String, supported: Int = LANGUAGES.size): Int =
    LANGUAGES.indexOf(tag).takeIf { it in 0 until supported }
      ?: throw IllegalArgumentException("Unsupported language $tag (${LANGUAGES.take(supported).joinToString()})")

  /** `name`'s value in `values`, or a clear refusal of an unknown one. */
  fun <T> pick(values: Map<String, T>, name: String, what: String): T =
    values[name] ?: throw IllegalArgumentException("Unknown $what $name (${values.keys.joinToString()})")

  /** A call refused because the feature is not `available` here. */
  fun unavailable(what: String, code: Int) = CodedException(
    "ERR_ML_KIT_GENAI_UNAVAILABLE",
    "$what is ${status(code)} on this device" +
      if (code == 1 || code == 2) ": download it first" else " (it needs Gemini Nano through AICore)",
    null,
  )

  /** A GenAI failure as a rejection, its `GenAiException` code in the message. */
  fun failure(e: Throwable): CodedException {
    val cause = if (e is ExecutionException) e.cause ?: e else e
    return if (cause is GenAiException) CodedException("ERR_ML_KIT_GENAI", "${cause.message} (GenAI error ${cause.errorCode})", cause)
    else CodedException("ERR_ML_KIT_GENAI", cause.message ?: "ML Kit GenAI failed", cause)
  }

  private val direct = Executor { it.run() }

  /** Settle `promise` from `future`'s listener. */
  fun <T> settle(promise: Promise, future: ListenableFuture<T>, map: (T) -> Any?) {
    future.addListener({
      try {
        promise.resolve(map(future.get()))
      } catch (e: CancellationException) {
        promise.reject("ERR_ML_KIT_GENAI", "The GenAI call was cancelled", e)
      } catch (e: CodedException) {
        promise.reject(e)
      } catch (e: Throwable) {
        promise.reject(failure(e))
      }
    }, direct)
  }

  /** `run`'s future, once `status` says the feature is available; else the
   *  call rejects at once with [unavailable]. */
  fun <T> whenAvailable(
    promise: Promise,
    what: String,
    status: ListenableFuture<Int>,
    run: () -> ListenableFuture<T>,
    map: (T) -> Any?,
  ) {
    status.addListener({
      try {
        val code = status.get()
        if (code == 3) settle(promise, run(), map) else promise.reject(unavailable(what, code))
      } catch (e: Throwable) {
        promise.reject(failure(e))
      }
    }, direct)
  }

  /** Download the feature's model, resolving once it is on the device (at
   *  once when it already is). Settled from the download's own future. */
  fun download(promise: Promise, what: String, status: ListenableFuture<Int>, start: (DownloadCallback) -> ListenableFuture<Void>) {
    status.addListener({
      try {
        when (val code = status.get()) {
          3 -> promise.resolve(null)
          0 -> promise.reject(unavailable(what, code))
          else -> settle(promise, start(quiet)) { null }
        }
      } catch (e: Throwable) {
        promise.reject(failure(e))
      }
    }, direct)
  }

  /** Progress is not reported: the download's future settles the call. */
  private val quiet = object : DownloadCallback {
    override fun onDownloadStarted(bytesToDownload: Long) {}
    override fun onDownloadProgress(totalBytesDownloaded: Long) {}
    override fun onDownloadCompleted() {}
    override fun onDownloadFailed(e: GenAiException) {}
  }

  /** Clients by their options, one per distinct set: each holds AICore's
   *  connection. */
  class Clients<K, C> {
    private val clients = mutableMapOf<K, C>()

    fun get(key: K, make: () -> C): C = synchronized(clients) { clients.getOrPut(key, make) }
  }
}
