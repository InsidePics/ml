package expo.modules.mlkit

import android.content.Context
import android.graphics.Bitmap
import com.google.mlkit.genai.imagedescription.ImageDescriber
import com.google.mlkit.genai.imagedescription.ImageDescriberOptions
import com.google.mlkit.genai.imagedescription.ImageDescription
import com.google.mlkit.genai.imagedescription.ImageDescriptionRequest
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder
import expo.modules.kotlin.sharedobjects.SharedRef

/** GenAI Image Description (Android only, Gemini Nano): a short English
 *  description of an image handle. */
object GenAiImageDescriber {
  @Volatile private var describer: ImageDescriber? = null

  fun client(context: Context): ImageDescriber =
    describer ?: synchronized(this) {
      describer ?: ImageDescription.getClient(ImageDescriberOptions.builder(context).build()).also { describer = it }
    }

  fun status(context: Context, promise: Promise) = GenAi.settle(promise, client(context).checkFeatureStatus(), GenAi::status)

  fun download(context: Context, promise: Promise) {
    val client = client(context)
    GenAi.download(promise, "Image description", client.checkFeatureStatus(), client::downloadFeature)
  }

  /** The bitmap as the handle holds it: the model takes any size, and the
   *  upright decode is the caller's (expo-image-manipulator's). */
  fun describe(context: Context, bitmap: Bitmap, promise: Promise) {
    val client = client(context)
    GenAi.whenAvailable(promise, "Image description", client.checkFeatureStatus(), {
      client.runInference(ImageDescriptionRequest.builder(bitmap).build())
    }) { it.description }
  }
}

object GenAiImageDescriptionFeature : MlKitFeature {
  override val name = "genAiImageDescription"

  override fun define(module: ModuleDefinitionBuilder) {
    module.AsyncFunction("getImageDescriberStatus") { promise: Promise ->
      GenAiImageDescriber.status(MlKitHost.context, promise)
    }
    module.AsyncFunction("downloadImageDescriber") { promise: Promise ->
      GenAiImageDescriber.download(MlKitHost.context, promise)
    }
    module.AsyncFunction("describeImage") { image: SharedRef<Bitmap>, promise: Promise ->
      GenAiImageDescriber.describe(MlKitHost.context, image.ref, promise)
    }
  }
}
