package expo.modules.mlkit

import android.graphics.Bitmap
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import expo.modules.kotlin.sharedobjects.SharedRef

/**
 * Google ML Kit on an Expo image handle (`SharedRef<Bitmap>`, from
 * expo-image-manipulator or any module that makes one), the Android
 * counterpart of `ios/ExpoMlKitModule.swift`. Every image call runs its
 * detectors on the caller's one decode ([AnalysisBitmap]). Results follow
 * `src/ExpoMlKit.types.ts`; the functions are the enabled features'
 * ([MlKitFeature]).
 */
class ExpoMlKitModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("ExpoMlKit")

    // Every Android device runs ML Kit.
    Constant("isAvailable") { true }
    Constant("features") { ENABLED_FEATURES.map { it.name } }

    AsyncFunction("analyzeImage") { image: SharedRef<Bitmap>, models: List<String>, promise: Promise ->
      MlKitCalls.withImage(image, promise) { MlKitAnalyzer.analyze(it, models.toSet()) }
    }

    ENABLED_FEATURES.forEach { it.define(this) }
  }
}
