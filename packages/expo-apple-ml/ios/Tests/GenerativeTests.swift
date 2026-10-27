import XCTest
import Vision
@testable import ExpoAppleIntelligence

/// Foundation Models, speech and image generation: a device with Apple Intelligence.
final class GenerativeTests: VisionTestCase {

  // MARK: - Foundation Models (iOS 26+)

  func testIsFoundationModelAvailable_returnsTrue() throws {
    guard #available(iOS 26.0, *) else {
      throw XCTSkip("Foundation Models requires iOS 26+")
    }
    try XCTSkipIf(isSimulator, "Foundation Models requires Apple Intelligence device")
    try XCTSkipIf(isVirtualMachine, "Foundation Models does not run in a virtual Mac")
    let result = VisionModern.isFoundationModelAvailable()
    XCTAssertTrue(result, "Foundation Model should be available on iOS 26 device with Apple Intelligence")
  }

  func testGenerateText_producesActualResponse() throws {
    try XCTSkipIf(!isIPhone, "Text generation is checked on an iPhone (pnpm test:device:ios)")
    guard #available(iOS 26.0, *) else {
      throw XCTSkip("Foundation Models requires iOS 26+")
    }

    let expectation = XCTestExpectation(description: "Generate text")
    Task {
      let result = await VisionModern.generateText(prompt: "What is 2 + 2? Reply with just the number.", systemPrompt: nil)
      guard let result else {
        XCTFail("Foundation Model should return a response")
        expectation.fulfill()
        return
      }
      let text = result
      XCTAssertGreaterThan(text.count, 0, "Response should not be empty")
      XCTAssertTrue(text.contains("4"), "Response to '2+2' should contain '4', got: \(text)")
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 30.0)
  }

  func testGenerateText_respectsSystemPrompt() throws {
    try XCTSkipIf(!isIPhone, "Text generation is checked on an iPhone (pnpm test:device:ios)")
    guard #available(iOS 26.0, *) else {
      throw XCTSkip("Foundation Models requires iOS 26+")
    }

    let expectation = XCTestExpectation(description: "Generate text with system prompt")
    Task {
      let result = await VisionModern.generateText(
        prompt: "What are you?",
        systemPrompt: "You are a pirate. Always respond in pirate speak. Keep responses under 20 words."
      )
      guard let result else {
        XCTFail("Foundation Model should return a response with system prompt")
        expectation.fulfill()
        return
      }
      let text = result
      XCTAssertGreaterThan(text.count, 0, "Response should not be empty")
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 30.0)
  }

  // MARK: - Speech Transcription (iOS 26+)

  func testTranscribeAudio_returnsNilForInvalidPath() throws {
    guard #available(iOS 26.0, *) else {
      throw XCTSkip("SpeechAnalyzer requires iOS 26+")
    }

    let expectation = XCTestExpectation(description: "Transcribe invalid audio")
    Task {
      let result = await VisionModern.transcribeAudio(audioPath: "/nonexistent/audio.m4a", locale: nil)
      XCTAssertNil(result, "Should return nil for invalid audio path")
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 10.0)
  }

  func testTranscribeAudio_transcribesRealSpeech() throws {
    try XCTSkipIf(isSimulator, "SpeechAnalyzer requires device")
    try XCTSkipIf(isVirtualMachine, "SpeechAnalyzer does not run in a virtual Mac")
    guard #available(iOS 26.0, *) else {
      throw XCTSkip("SpeechAnalyzer requires iOS 26+")
    }

    let audioPath = fixturePath("speech.m4a")
    XCTAssertTrue(FileManager.default.fileExists(atPath: audioPath), "speech.m4a fixture should exist at: \(audioPath)")

    let expectation = XCTestExpectation(description: "Transcribe real speech")
    Task {
      let result = await VisionModern.transcribeAudio(audioPath: audioPath, locale: "en-US")
      guard let result else {
        XCTFail("Should transcribe speech audio file")
        expectation.fulfill()
        return
      }

      let segments = result["segments"] as! [[String: Any]]
      XCTAssertGreaterThan(segments.count, 0, "Should have at least 1 segment")

      let fullText = segments.compactMap { $0["text"] as? String }.joined(separator: " ")
      XCTAssertGreaterThan(fullText.count, 10, "Transcription should have substantial text, got: \(fullText)")

      let lower = fullText.lowercased()
      XCTAssertTrue(
        lower.contains("hello") || lower.contains("world") || lower.contains("test") || lower.contains("fox") || lower.contains("dog"),
        "Transcription should contain words from the spoken text, got: \(fullText)"
      )
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 60.0)
  }

  // MARK: - Image Generation (iOS 18.4+)

  func testGenerateImage_createsActualImageFile() throws {
    try XCTSkipIf(!isIPhone, "Image generation is checked on an iPhone (pnpm test:device:ios)")
    guard #available(iOS 18.4, *) else {
      throw XCTSkip("ImageCreator requires iOS 18.4+")
    }

    let expectation = XCTestExpectation(description: "Generate image")
    Task {
      let result = await VisionModern.generateImage(prompt: "A red apple on a white table", style: "animation")
      guard let result else {
        XCTFail("ImageCreator should generate an image")
        expectation.fulfill()
        return
      }

      let path = result
      XCTAssertTrue(FileManager.default.fileExists(atPath: path), "Generated image file should exist at: \(path)")

      let data = (try? Data(contentsOf: URL(fileURLWithPath: path))) ?? Data()
      XCTAssertGreaterThan(data.count, 1000, "Image file should be > 1KB, got \(data.count) bytes")

      #if canImport(UIKit)
      let image = UIImage(data: data)
      XCTAssertNotNil(image, "Generated file should be a valid image")
      XCTAssertGreaterThan(image!.size.width, 0, "Image should have positive width")
      XCTAssertGreaterThan(image!.size.height, 0, "Image should have positive height")
      #endif

      try? FileManager.default.removeItem(atPath: path)
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 120.0)
  }

  func testGenerateImage_supportsMultipleStyles() throws {
    try XCTSkipIf(!isIPhone, "Image generation is checked on an iPhone (pnpm test:device:ios)")
    guard #available(iOS 18.4, *) else {
      throw XCTSkip("ImageCreator requires iOS 18.4+")
    }

    let expectation = XCTestExpectation(description: "Generate sketch image")
    Task {
      let result = await VisionModern.generateImage(prompt: "A cat sitting on a chair", style: "sketch")
      if let path = result {
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
        try? FileManager.default.removeItem(atPath: path)
      }
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 120.0)
  }
}
