package expo.modules.mlkit

import androidx.test.ext.junit.runners.AndroidJUnit4
import insidepics.testsupport.Fixtures
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Barcode Scanning's parsed values (`detectBarcodes`), on generated codes
 *  whose payloads `scripts/make-barcode-fixtures.swift` names. */
@RunWith(AndroidJUnit4::class)
class BarcodeTests {
  private fun scan(name: String, formats: List<String>? = null): List<Json> =
    AnalysisBitmap.analyze(Fixtures.handle(name)) { BarcodeAnalyzer.scan(it, formats) }

  @Test fun valuesParseEveryType() {
    val codes = scan("barcode-values.png").associateBy { it["valueType"] as String }
    assertEquals(
      setOf("wifi", "url", "email", "phone", "sms", "geo", "contactInfo", "calendarEvent", "text"),
      codes.keys,
    )
    val wifi = codes["wifi"]!!["wifi"].json()
    assertEquals("InsidePics", wifi["ssid"])
    assertEquals("correct horse", wifi["password"])
    assertEquals("wpa", wifi["encryptionType"])
    assertEquals("https://example.com/ml-kit", codes["url"]!!["url"].json()["url"])
    val email = codes["email"]!!["email"].json()
    assertEquals("ml@example.com", email["address"])
    assertEquals("Hello", email["subject"])
    assertEquals("+15550101", codes["phone"]!!["phone"].json()["number"])
    assertEquals("Hello there", codes["sms"]!!["sms"].json()["message"])
    val geo = codes["geo"]!!["geo"].json()
    assertEquals(40.7128, geo["latitude"] as Double, 1e-6)
    assertEquals(-74.006, geo["longitude"] as Double, 1e-6)
    val contact = codes["contactInfo"]!!["contactInfo"].json()
    assertEquals("Jane Doe", contact["name"].json()["formattedName"])
    assertEquals("Example", contact["organization"])
    assertEquals("jane@example.com", contact["emails"].list().first()["address"])
    val event = codes["calendarEvent"]!!["calendarEvent"].json()
    assertEquals("Launch", event["summary"])
    assertEquals("2026-10-28T09:00:00Z", event["start"])
    assertEquals("Hello, ML Kit", codes["text"]!!["rawValue"])
  }

  @Test fun licenseReadsTheAamvaFields() {
    val code = scan("barcode-license.png").first()
    assertEquals("PDF417", code["format"])
    assertEquals("driverLicense", code["valueType"])
    val license = code["driverLicense"].json()
    assertEquals("JANE", license["firstName"])
    assertEquals("DOE", license["lastName"])
    assertEquals("T64235789", license["licenseNumber"])
  }

  @Test fun ean13IsAProductWithFourCorners() {
    val code = scan("barcode.jpg").first { it["format"] == "EAN_13" }
    assertEquals("product", code["valueType"])
    assertEquals("2404105001722", code["displayValue"])
    val corners = code["cornerPoints"].list()
    assertEquals(4, corners.size)
    for (corner in corners) assertTrue("$corner", (corner["x"] as Double) in 0.0..1.0 && (corner["y"] as Double) in 0.0..1.0)
  }

  @Test fun formatsLimitTheScan() {
    assertEquals(1, scan("barcode.jpg", listOf("EAN_13")).size)
    assertEquals(0, scan("barcode.jpg", listOf("QR_CODE")).size)
    assertThrows(IllegalArgumentException::class.java) { scan("barcode.jpg", listOf("NOT_A_FORMAT")) }
  }
}
