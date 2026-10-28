import UIKit
import XCTest
@testable import ExpoMlKit

#if !targetEnvironment(simulator)

/// Barcode Scanning's parsed values (`detectBarcodes`), on generated codes
/// whose payloads `scripts/make-barcode-fixtures.swift` names.
final class BarcodeTests: MlKitTestCase {

  private func scan(_ name: String, formats: [String]? = nil) throws -> [[String: Any]] {
    let picture = try image(name)
    return try background {
      try BarcodeAnalyzer.scan(
        MlKitAnalyzer.visionImage(picture), picture.size, formats: formats)
    }
  }

  private func byType(_ codes: [[String: Any]]) -> [String: [String: Any]] {
    Dictionary(codes.map { ($0["valueType"] as? String ?? "", $0) }) { first, _ in first }
  }

  func testValues_parseEveryType() throws {
    let codes = byType(try scan("barcode-values.png"))
    XCTAssertEqual(
      Set(codes.keys),
      ["wifi", "url", "email", "phone", "sms", "geo", "contactInfo", "calendarEvent", "text"])
    let wifi = try XCTUnwrap(codes["wifi"]?["wifi"] as? [String: Any])
    XCTAssertEqual(wifi["ssid"] as? String, "InsidePics")
    XCTAssertEqual(wifi["password"] as? String, "correct horse")
    XCTAssertEqual(wifi["encryptionType"] as? String, "wpa")
    let url = try XCTUnwrap(codes["url"]?["url"] as? [String: Any])
    XCTAssertEqual(url["url"] as? String, "https://example.com/ml-kit")
    let email = try XCTUnwrap(codes["email"]?["email"] as? [String: Any])
    XCTAssertEqual(email["address"] as? String, "ml@example.com")
    XCTAssertEqual(email["subject"] as? String, "Hello")
    let phone = try XCTUnwrap(codes["phone"]?["phone"] as? [String: Any])
    XCTAssertEqual(phone["number"] as? String, "+15550101")
    let sms = try XCTUnwrap(codes["sms"]?["sms"] as? [String: Any])
    XCTAssertEqual(sms["message"] as? String, "Hello there")
    let geo = try XCTUnwrap(codes["geo"]?["geo"] as? [String: Double])
    XCTAssertEqual(try XCTUnwrap(geo["latitude"]), 40.7128, accuracy: 1e-6)
    XCTAssertEqual(try XCTUnwrap(geo["longitude"]), -74.006, accuracy: 1e-6)
    let contact = try XCTUnwrap(codes["contactInfo"]?["contactInfo"] as? [String: Any])
    XCTAssertEqual((contact["name"] as? [String: Any])?["formattedName"] as? String, "Jane Doe")
    XCTAssertEqual(contact["organization"] as? String, "Example")
    XCTAssertEqual((contact["emails"] as? [[String: Any]])?.first?["address"] as? String, "jane@example.com")
    let event = try XCTUnwrap(codes["calendarEvent"]?["calendarEvent"] as? [String: Any])
    XCTAssertEqual(event["summary"] as? String, "Launch")
    XCTAssertEqual(event["start"] as? String, "2026-10-28T09:00:00Z")
    XCTAssertEqual(codes["text"]?["rawValue"] as? String, "Hello, ML Kit")
  }

  func testLicense_readsTheAAMVAFields() throws {
    let code = try XCTUnwrap(try scan("barcode-license.png").first)
    XCTAssertEqual(code["format"] as? String, "PDF417")
    XCTAssertEqual(code["valueType"] as? String, "driverLicense")
    let license = try XCTUnwrap(code["driverLicense"] as? [String: Any])
    XCTAssertEqual(license["firstName"] as? String, "JANE")
    XCTAssertEqual(license["lastName"] as? String, "DOE")
    XCTAssertEqual(license["licenseNumber"] as? String, "T64235789")
  }

  func testEAN13_isAProductWithFourCorners() throws {
    let code = try XCTUnwrap(try scan("barcode.jpg").first { $0["format"] as? String == "EAN_13" })
    XCTAssertEqual(code["valueType"] as? String, "product")
    XCTAssertEqual(code["displayValue"] as? String, "2404105001722")
    let corners = try XCTUnwrap(code["cornerPoints"] as? [[String: Double]])
    XCTAssertEqual(corners.count, 4)
    for corner in corners {
      XCTAssertTrue((0...1).contains(corner["x"] ?? -1) && (0...1).contains(corner["y"] ?? -1))
    }
  }

  func testFormats_limitTheScan() throws {
    XCTAssertEqual(try scan("barcode.jpg", formats: ["EAN_13"]).count, 1)
    XCTAssertEqual(try scan("barcode.jpg", formats: ["QR_CODE"]).count, 0)
    XCTAssertThrowsError(try scan("barcode.jpg", formats: ["NOT_A_FORMAT"]))
  }
}
#endif
