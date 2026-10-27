import XCTest
@testable import ExpoImageMlTools

/// `fixtures/expected/decode-grid.json`: each fixture as Apple decodes it,
/// summarized as the mean colour of a 16×16 grid of cells. Android's
/// instrumented `DecodeGapTests` compares its own decode against it, which
/// measures how far the two platforms' decoders (and colour handling) put
/// the same photo apart; on any Apple device this suite does the same
/// against the Mac's decode it was recorded from. Recorded on a Mac:
///
///   RECORD_FIXTURE=1 pnpm --filter expo-image-ml-tools test:swift
final class DecodeGridTests: XCTestCase {
  static let side = 16
  // The decoders differ by a little even between a Mac and an iPhone (an
  // iPhone 16 Pro: up to 4.9 in a cell of barcode.jpg; an Android 17
  // emulator: 2.2). A colour-space, gamma or orientation slip is off by tens.
  static let meanLimit = 1.0
  static let maxLimit = 8.0
  static let names =
    ["face.jpg", "text.jpg", "animal.jpg", "body.jpg", "landscape.jpg", "barcode.jpg"]
    + [1, 3, 6, 8].flatMap { tag in ["jpg", "heic"].map { "face-orientation-\(tag).\($0)" } }

  func testDecode_staysNearTheRecordedGrid() throws {
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
      let gaps = zip(want, try XCTUnwrap(grids[name])).map { abs($0 - $1) }
      let mean = gaps.reduce(0, +) / Double(gaps.count)
      let max = gaps.max() ?? .infinity
      print("DecodeGridTests: \(name): mean \(mean), max \(max) of 255")
      // Android's DecodeGapTests uses the same limits.
      XCTAssertLessThan(mean, Self.meanLimit, "\(name): mean gap \(mean) of 255")
      XCTAssertLessThan(max, Self.maxLimit, "\(name): max gap \(max) of 255")
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
