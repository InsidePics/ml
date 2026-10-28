import XCTest
@testable import ExpoImageMlTools

/// The pixel maths against the recorded reference: the pattern everywhere
/// (Android's suite checks the same values), the photo fixtures on a Mac,
/// where the reference was decoded.
final class ImageMathTests: XCTestCase {

  private var expected: Expected!

  override func setUpWithError() throws {
    expected = try Expected.load()
  }

  // MARK: - Pattern (every platform)

  func testPattern_rebuildsTheRecordedPixels() {
    XCTAssertEqual(sha256(Data(patternImage().pixels)), expected.pattern["rgba"] as? String)
  }

  func testPattern_coverNearestIsTheRecordedCrop() {
    let tensor = ImageMath.tensor(
      patternImage(), width: 32, height: 32, fit: .cover, filter: .nearest,
      mean: expected.clipMean, std: expected.clipStd, layout: .nchw)
    XCTAssertEqual(tensor.count, 3 * 32 * 32)
    XCTAssertEqual(sha256(tensor), expected.pattern["clip32"] as? String)
  }

  func testPattern_warpThenTensorIsTheRecordedFace() throws {
    let matrix = try XCTUnwrap(expected.pattern["matrix"] as? [Double])
    let crop = ImageMath.warp(patternImage(), matrix, width: 24, height: 24)
    XCTAssertEqual(sha256(Data(crop.pixels)), expected.pattern["warp24"] as? String)
    let tensor = ImageMath.tensor(
      crop, width: 24, height: 24, fit: .stretch, filter: .nearest,
      mean: [0.5, 0.5, 0.5], std: [0.5, 0.5, 0.5], layout: .nchw)
    XCTAssertEqual(sha256(tensor), expected.pattern["face24"] as? String)
    XCTAssertEqual(bits(ImageMath.sharpness(crop)), expected.pattern["face24Blur"] as? String)
  }

  func testPattern_statistics() {
    let image = patternImage()
    XCTAssertEqual(bits(ImageMath.sharpness(image)), expected.pattern["sharpness"] as? String)
    XCTAssertEqual(
      sha256(ImageMath.histogram(image, bins: 16)), expected.pattern["histogram16"] as? String)
  }

  // MARK: - Fixtures (macOS, where the reference was decoded)

  func testFixtures_reproduceTheAppsInputs() throws {
    #if !os(macOS)
    throw XCTSkip("The fixture reference was decoded on macOS; HandleTests covers iOS")
    #else
    // The JPEGs: ImageIO decodes them identically on every Mac. A HEIC's
    // decode depends on the machine (Apple's hardware HEVC decoder, or the
    // software one on a virtual Mac such as CI's, 0.23 of 255 apart), so its
    // pixels are checked within limits by DecodeGridTests instead.
    for (name, want) in expected.fixtures where !name.hasSuffix(".heic") {
      let cg = try XCTUnwrap(uprightCGImage(name), name)
      let rgba = try XCTUnwrap(Pixels.rgba(cg), name)
      XCTAssertEqual(sha256(Data(rgba.pixels)), want["rgba"] as? String, "\(name) pixels")
      try assertInputs(rgba, want, name)
    }
    #endif
  }

  func testWarp_leavesADegenerateMatrixBlack() {
    let crop = ImageMath.warp(patternImage(), [0, 0, 0, 0, 0, 0], width: 4, height: 4)
    XCTAssertEqual(crop.pixels, [UInt8](repeating: 0, count: 64))
  }

  func testWarp_survivesNaNAndHugeMatrices() {
    // NaN, or a shift far off the image: nothing to sample, transparent black.
    for matrix in [[Double.nan, 0, 0, 0, 1, 0], [1, 0, 1e20, 0, 1, 0]] {
      let crop = ImageMath.warp(patternImage(), matrix, width: 3, height: 3)
      XCTAssertEqual(crop.pixels, [UInt8](repeating: 0, count: 36), "\(matrix)")
    }
    // A 1e300 zoom maps every output onto the top-left pixel: opaque black.
    let zoomed = ImageMath.warp(patternImage(), [1e300, 0, 0, 0, 1e300, 0], width: 3, height: 3)
    XCTAssertEqual(zoomed.pixels, Array([[UInt8]](repeating: [0, 0, 0, 255], count: 9).joined()))
  }

  func testSharpness_isZeroBelowThreeByThree() {
    let tiny = RGBAImage(width: 2, height: 9, pixels: [UInt8](repeating: 200, count: 72))
    XCTAssertEqual(ImageMath.sharpness(tiny), 0)
  }

  func testHistogram_oneBinHoldsEverything() {
    XCTAssertEqual(ImageMath.histogram(patternImage(), bins: 1), [1])
  }

  func testTensor_upscalesASmallImageWithinItsRange() {
    let tiny = RGBAImage(width: 2, height: 1, pixels: [0, 0, 0, 255, 255, 255, 255, 255])
    for filter in [Filter.nearest, .bilinear] {
      let tensor = ImageMath.tensor(
        tiny, width: 7, height: 5, fit: .cover, filter: filter,
        mean: [0, 0, 0], std: [1, 1, 1], layout: .nchw)
      XCTAssertEqual(tensor.count, 3 * 7 * 5)
      XCTAssertTrue(tensor.allSatisfy { (0...1).contains($0) }, "\(filter)")
      XCTAssertEqual(tensor.first, 0, "left edge is the black pixel")
      XCTAssertEqual(tensor[6], 1, "right edge is the white pixel")
    }
  }

  func testTensor_nhwcInterleavesTheSameValues() {
    let image = patternImage()
    let args = (w: 8, h: 6, mean: [0.1, 0.2, 0.3], std: [0.5, 0.6, 0.7])
    let planar = ImageMath.tensor(
      image, width: args.w, height: args.h, fit: .stretch, filter: .bilinear,
      mean: args.mean, std: args.std, layout: .nchw)
    let packed = ImageMath.tensor(
      image, width: args.w, height: args.h, fit: .stretch, filter: .bilinear,
      mean: args.mean, std: args.std, layout: .nhwc)
    let plane = args.w * args.h
    for p in 0..<plane {
      for ch in 0..<3 { XCTAssertEqual(packed[p * 3 + ch], planar[ch * plane + p]) }
    }
  }

  func testTensor_bilinearOfAFlatImageIsFlat() {
    let flat = RGBAImage(
      width: 10, height: 7, pixels: (0..<70).flatMap { _ in [UInt8(51), 102, 153, 255] })
    let tensor = ImageMath.tensor(
      flat, width: 23, height: 5, fit: .cover, filter: .bilinear,
      mean: [0, 0, 0], std: [1, 1, 1], layout: .nchw)
    let plane = 23 * 5
    for p in 0..<plane {
      XCTAssertEqual(tensor[p], 0.2, accuracy: 1e-6)
      XCTAssertEqual(tensor[plane + p], 0.4, accuracy: 1e-6)
      XCTAssertEqual(tensor[2 * plane + p], 0.6, accuracy: 1e-6)
    }
  }
}

/// The CLIP crop, each recorded face and the statistics of `rgba` equal the
/// reference `want` (one fixture's entry).
func assertInputs(
  _ rgba: RGBAImage, _ want: [String: Any], _ name: String,
  file: StaticString = #filePath, line: UInt = #line
) throws {
  let expected = try Expected.load()
  let clip = ImageMath.tensor(
    rgba, width: 256, height: 256, fit: .cover, filter: .nearest,
    mean: expected.clipMean, std: expected.clipStd, layout: .nchw)
  XCTAssertEqual(sha256(clip), want["clip"] as? String, "\(name) clip", file: file, line: line)
  let faces = try XCTUnwrap(want["faces"] as? [String: Any])
  for (key, value) in faces {
    guard let face = value as? [String: Any], let matrix = face["matrix"] as? [Double] else {
      continue
    }
    let crop = ImageMath.warp(rgba, matrix, width: 112, height: 112)
    let tensor = ImageMath.tensor(
      crop, width: 112, height: 112, fit: .stretch, filter: .nearest,
      mean: [0.5, 0.5, 0.5], std: [0.5, 0.5, 0.5], layout: .nchw)
    XCTAssertEqual(sha256(tensor), face["tensor"] as? String, "\(name) \(key)", file: file, line: line)
    XCTAssertEqual(bits(ImageMath.sharpness(crop)), face["blur"] as? String, "\(name) \(key) blur", file: file, line: line)
  }
  XCTAssertEqual(bits(ImageMath.sharpness(rgba)), want["sharpness"] as? String, "\(name) sharpness", file: file, line: line)
  XCTAssertEqual(
    sha256(ImageMath.histogram(rgba, bins: 64)), want["histogram64"] as? String,
    "\(name) histogram", file: file, line: line)
}
