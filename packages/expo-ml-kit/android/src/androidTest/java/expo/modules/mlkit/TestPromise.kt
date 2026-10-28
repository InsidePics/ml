package expo.modules.mlkit

import expo.modules.kotlin.Promise
import expo.modules.kotlin.exception.CodedException
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/**
 * A module call's promise, as Expo hands one to a function: the suites
 * call the features' promise-settling code directly and wait here, with a
 * bound, so a call that never settles fails instead of stalling the run.
 * Settling twice fails too.
 */
class TestPromise : Promise {
  private val settled = CountDownLatch(1)
  private val settles = AtomicInteger()
  @Volatile private var value: Any? = null
  @Volatile private var code: String? = null
  @Volatile private var message: String? = null

  override fun resolve(value: Any?) {
    this.value = value
    settles.incrementAndGet()
    settled.countDown()
  }

  override fun reject(code: String?, message: String?, cause: Throwable?) {
    this.code = code ?: "(no code)"
    this.message = message
    settles.incrementAndGet()
    settled.countDown()
  }

  private fun await(seconds: Long) {
    assertTrue("The call did not settle within $seconds s", settled.await(seconds, TimeUnit.SECONDS))
    // Long enough for a second settle racing the first to land.
    Thread.sleep(50)
    assertEquals("The call settled more than once", 1, settles.get())
  }

  /** The value it resolved with; fails on a rejection. */
  fun resolved(seconds: Long = 60): Any? {
    await(seconds)
    code?.let { fail("Rejected with $it: $message") }
    return value
  }

  /** The code it rejected with; fails on a resolution. */
  fun rejected(seconds: Long = 60): String {
    await(seconds)
    return code ?: fail("Resolved with $value instead of rejecting") as Nothing
  }

  val rejectionMessage get() = message

  /** How it settled, or null while it has not. */
  fun outcome(): String? =
    if (settled.count > 0) null else code?.let { "rejected with $it: $message" } ?: "resolved with $value"
}

/** A promise `call` settles, settled. */
fun settle(call: (Promise) -> Unit): TestPromise = TestPromise().also(call)

/** A coroutine API's result, with a bound. */
fun <T> awaitSuspend(seconds: Long = 60, run: suspend () -> T): T =
  runBlocking { withTimeout(seconds * 1000) { run() } }

/** The code a coroutine API's call rejected with; fails on a result. */
fun rejectedCode(seconds: Long = 60, run: suspend () -> Any?): String =
  try {
    val value = awaitSuspend(seconds, run)
    fail("Resolved with $value instead of rejecting") as Nothing
  } catch (e: CodedException) {
    e.code
  }
