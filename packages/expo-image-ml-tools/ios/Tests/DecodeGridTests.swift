import XCTest
@testable import ExpoImageMlTools

/// `fixtures/expected/decode-grid.json`: each fixture as Apple decodes it,
/// summarized as the mean colour of a 16×16 grid of cells. Android's
/// instrumented `DecodeGapTests` compares its own decode against it, which
/// measures how far the two platforms' decoders (and colour handling) put
/// the same photo apart. Recorded on a Mac:
///
///   RECORD_FIXTURE=1 pnpm --filter @insidepics/expo-image-ml-tools test:swift
final class DecodeGridTests: XCTestCase {
  static let side = 16
  static let names =
    ["face.jpg", "text.jpg", "animal.jpg", "body.jpg", "landscape.jpg", "barcode.jpg"]
    + [1, 3, 6, 8].flatMap { tag in ["jpg", "heic"].map { "face-orientation-\(tag).\($0)" } }

  func testGrid_isTheRecordedOne() throws {
    var grids: [String: [Double]] = [:]
    for name in Self.names {
      let rgba = try XCTUnwrap(uprightCGImage(name).flatMap(Pixels.rgba), name)
      grids[name] = decodeGrid(rgba, side: Self.side)
    }
    let path = FixturePaths.path("expected/decode-grid.json")
    if ProcessInfo.processInfo.environment["RECORD_FIXTURE"] == "1" {
      let json: [String: Any] = ["side": Self.side, "grids": grids]
      let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
      try data.write(to: URL(fileURLWithPath: path))
      return
    }
    let recorded = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path)))
    let stored = try XCTUnwrap((recorded as? [String: Any])?["grids"] as? [String: [Double]])
    for name in Self.names {
      let want = try XCTUnwrap(stored[name], "\(name) not recorded")
      let got = try XCTUnwrap(grids[name])
      let worst = zip(want, got).map { abs($0 - $1) }.max() ?? .infinity
      // Rounded to 2 places when stored.
      XCTAssertLessThanOrEqual(worst, 0.01, "\(name): off the recorded grid by \(worst)")
    }
  }
}

/// The mean R, G, B of each of `side`×`side` cells, row by row, 0–255,
/// rounded to 2 places: a summary blind to a decoder's per-pixel noise but
/// not to a shift in colour, brightness or orientation. Android's
/// `DecodeGapTests` computes the same.
func decodeGrid(_ image: RGBAImage, side: Int) -> [Double] {
  var out: [Double] = []
  for cy in 0..<side {
    for cx in 0..<side {
      let x0 = cx * image.width / side
      let x1 = (cx + 1) * image.width / side
      let y0 = cy * image.height / side
      let y1 = (cy + 1) * image.height / side
      var sum = [0.0, 0.0, 0.0]
      for y in y0..<y1 {
        for x in x0..<x1 {
          let i = (y * image.width + x) * 4
          for c in 0..<3 { sum[c] += Double(image.pixels[i + c]) }
        }
      }
      let n = Double((x1 - x0) * (y1 - y0))
      out += sum.map { ($0 / n * 100).rounded() / 100 }
    }
  }
  return out
}
