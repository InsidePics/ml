import CoreGraphics
import CryptoKit
import Foundation
@testable import ExpoImageMlTools

/// `fixtures/expected/model-inputs.json`: what the InsidePics app's
/// model-input code built from each fixture (decoded with macOS ImageIO and
/// CoreGraphics) and from a formula-made pattern. The tools must reproduce
/// it bit for bit, so inputs, and the embeddings made from them, carry over.
struct Expected {
  let json: [String: Any]

  static func load() throws -> Expected {
    let data = try Data(contentsOf: URL(fileURLWithPath: FixturePaths.path("expected/model-inputs.json")))
    return Expected(json: try JSONSerialization.jsonObject(with: data) as! [String: Any])
  }

  var fixtures: [String: [String: Any]] { json["fixtures"] as! [String: [String: Any]] }
  var pattern: [String: Any] { json["pattern"] as! [String: Any] }
  var clipMean: [Double] { (json["clip"] as! [String: Any])["mean"] as! [Double] }
  var clipStd: [Double] { (json["clip"] as! [String: Any])["std"] as! [Double] }
}

/// The pattern any platform rebuilds from its formula (Android's tests do).
func patternImage() -> RGBAImage {
  let w = 97
  let h = 61
  var px = [UInt8](repeating: 255, count: w * h * 4)
  for y in 0..<h {
    for x in 0..<w {
      let i = (y * w + x) * 4
      px[i] = UInt8((x * 7 + y * 3) % 256)
      px[i + 1] = UInt8((x * x + y) % 256)
      px[i + 2] = UInt8((x * y) % 256)
    }
  }
  return RGBAImage(width: w, height: h, pixels: px)
}

func sha256(_ data: Data) -> String {
  SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func sha256(_ floats: [Float]) -> String { sha256(ImageMath.bytes(floats)) }

/// A Double's bit pattern as the JSON stores it, so equality is exact.
func bits(_ value: Double) -> String { value.bitPattern.description }

/// The fixture decoded upright the way the InsidePics app's old decoder did
/// (`fixtureImage`: ImageIO applying the orientation while decoding).
func uprightCGImage(_ name: String) -> CGImage? { fixtureImage(name)?.0 }
