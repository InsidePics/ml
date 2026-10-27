package expo.modules.mlkit

import android.graphics.Rect
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.TimeUnit

/**
 * A detector's result, waited for with a bound: every call shares this
 * module's one thread, so a task that never settles would otherwise hold up
 * every later one, the QR reader's included.
 */
fun <T> awaitDetector(task: Task<T>): T = Tasks.await(task, 30, TimeUnit.SECONDS)

/** This rectangle normalized to `image`, top-left origin. */
fun Rect.normalizedIn(image: InputImage) =
  Geometry.rect(
    left.toDouble(), top.toDouble(), right.toDouble(), bottom.toDouble(),
    image.width, image.height,
  )
