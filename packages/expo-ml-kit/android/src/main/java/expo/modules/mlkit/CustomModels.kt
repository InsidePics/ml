package expo.modules.mlkit

import com.google.mlkit.common.model.LocalModel
import java.io.File

/** A caller's TensorFlow Lite model (`MlKitCustomModel`), as the custom
 *  labeler and object detector load it. */
object CustomModels {
  /** The model file `options.model.path` names: absolute or `file://`. */
  fun path(options: Map<String, Any?>): String {
    val model = options["model"] as? Map<*, *> ?: throw IllegalArgumentException("No custom model given")
    val path = (model["path"] as? String)?.removePrefix("file://")
      ?: throw IllegalArgumentException("The custom model has no path")
    require(File(path).isFile) { "No model file at $path" }
    return path
  }

  fun local(path: String): LocalModel = LocalModel.Builder().setAbsoluteFilePath(path).build()
}
