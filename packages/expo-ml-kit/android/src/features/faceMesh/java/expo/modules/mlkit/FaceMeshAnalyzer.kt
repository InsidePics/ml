package expo.modules.mlkit

import android.graphics.Bitmap
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.facemesh.FaceMesh
import com.google.mlkit.vision.facemesh.FaceMeshDetection
import com.google.mlkit.vision.facemesh.FaceMeshDetectorOptions
import com.google.mlkit.vision.facemesh.FaceMeshPoint
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.ModuleDefinitionBuilder
import expo.modules.kotlin.sharedobjects.SharedRef

/** Face Mesh Detection (Android only): 468 points per face, the triangles
 *  between them, and the named contours, or only the faces' boxes. */
object FaceMeshAnalyzer {
  private val meshes by lazy { FaceMeshDetection.getClient() }
  private val boxesOnly by lazy {
    FaceMeshDetection.getClient(
      FaceMeshDetectorOptions.Builder().setUseCase(FaceMeshDetectorOptions.BOUNDING_BOX_ONLY).build()
    )
  }

  /** `FaceMesh.*` contours, camel-cased: `MlKitFaceMeshContour`. Left and
   *  right are the image's (`LEFT_EYE` is the subject's right eye). */
  private val CONTOURS = mapOf(
    FaceMesh.FACE_OVAL to "faceOval",
    FaceMesh.LEFT_EYEBROW_TOP to "leftEyebrowTop",
    FaceMesh.LEFT_EYEBROW_BOTTOM to "leftEyebrowBottom",
    FaceMesh.RIGHT_EYEBROW_TOP to "rightEyebrowTop",
    FaceMesh.RIGHT_EYEBROW_BOTTOM to "rightEyebrowBottom",
    FaceMesh.LEFT_EYE to "leftEye",
    FaceMesh.RIGHT_EYE to "rightEye",
    FaceMesh.UPPER_LIP_TOP to "upperLipTop",
    FaceMesh.UPPER_LIP_BOTTOM to "upperLipBottom",
    FaceMesh.LOWER_LIP_TOP to "lowerLipTop",
    FaceMesh.LOWER_LIP_BOTTOM to "lowerLipBottom",
    FaceMesh.NOSE_BRIDGE to "noseBridge",
  )

  /**
   * The faces in `image`. Points are normalized to the upright image,
   * top-left origin, in `FaceMeshPoint` index order; `z` (depth, smaller is
   * nearer) is scaled like `x`. Triangles and contours are indexes into the
   * points. With `boundingBoxOnly`, each face is its box alone.
   */
  fun detect(image: InputImage, boundingBoxOnly: Boolean = false): List<Map<String, Any>> {
    val detector = if (boundingBoxOnly) boxesOnly else meshes
    return awaitDetector(detector.process(image)).map { mesh ->
      val points = mesh.allPoints.sortedBy { it.index }
      mapOf(
        "boundingBox" to mesh.boundingBox.normalizedIn(image),
        "points" to points.map { point(it, image) },
        "triangles" to mesh.allTriangles.map { triangle -> triangle.allPoints.map { it.index } },
        "contours" to if (points.isEmpty()) emptyMap() else CONTOURS.entries.associate { (type, name) ->
          name to mesh.getPoints(type).map { it.index }
        },
      )
    }
  }

  private fun point(point: FaceMeshPoint, image: InputImage): Map<String, Double> {
    val position = point.position
    return mapOf(
      "x" to position.x.toDouble() / image.width,
      "y" to position.y.toDouble() / image.height,
      "z" to position.z.toDouble() / image.width,
    )
  }
}

object FaceMeshFeature : MlKitFeature {
  override val name = "faceMesh"

  override fun define(module: ModuleDefinitionBuilder) {
    module.AsyncFunction("detectFaceMesh") { image: SharedRef<Bitmap>, boundingBoxOnly: Boolean, promise: Promise ->
      MlKitCalls.withImage(image, promise) { FaceMeshAnalyzer.detect(it, boundingBoxOnly) }
    }
  }
}
