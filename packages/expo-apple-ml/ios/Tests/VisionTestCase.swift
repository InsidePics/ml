import XCTest
import Vision
@testable import ExpoAppleIntelligence

/// Shared by the integration suites that run the full pipeline on the
/// repository's fixtures. Tests needing CoreML (faces, classification,
/// saliency, aesthetics, feature prints) run only on a device: the simulator
/// has no Neural Engine context.
class VisionTestCase: XCTestCase {

  var isSimulator: Bool {
    #if targetEnvironment(simulator)
    return true
    #else
    return false
    #endif
  }

  /// Generation (text, images) is checked on an iPhone only: on a Mac it
  /// depends on Apple Intelligence being enabled for the signed-in user, so a
  /// Mac result proves nothing about the device. `pnpm test:device:ios` runs it.
  var isIPhone: Bool {
    #if os(iOS) && !targetEnvironment(simulator)
    return true
    #else
    return false
    #endif
  }

  func fixturePath(_ name: String) -> String {
    FixturePaths.path(name)
  }

  func loadFixture(_ name: String) -> (CGImage, CGFloat, CGFloat)? {
    fixtureImage(name)
  }

  func generateFeaturePrint(fixture: String) -> VNFeaturePrintObservation? {
    guard let (cgImage, _, _) = loadFixture(fixture) else { return nil }
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let req = VNGenerateImageFeaturePrintRequest()
    try? handler.perform([req])
    return req.results?.first as? VNFeaturePrintObservation
  }

  @available(iOS 18.0, macOS 15.0, *)
  func computeAestheticScore(fixture: String) -> Double? {
    guard let (cgImage, _, _) = loadFixture(fixture) else { return nil }
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let req = VNCalculateImageAestheticsScoresRequest()
    try? handler.perform([req])
    let result = VisionModern.processAesthetics(req.results)
    return result?["overallScore"] as? Double
  }
}
