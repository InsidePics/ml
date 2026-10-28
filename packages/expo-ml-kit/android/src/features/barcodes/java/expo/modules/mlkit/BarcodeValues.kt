package expo.modules.mlkit

import com.google.mlkit.vision.barcode.common.Barcode

/**
 * A barcode's decoded content, the `MlKitBarcode` fields beside its box: the
 * raw and display values, the value type ML Kit parsed, and that type's
 * fields — `ios/BarcodeValues.swift` writes the same. Shared by
 * [BarcodeAnalyzer] and the code scanner, which has no image to box in.
 */
object BarcodeValues {
  /** `Barcode.TYPE_*`, camel-cased: `MlKitBarcodeValueType`. */
  private val VALUE_TYPES = mapOf(
    Barcode.TYPE_CONTACT_INFO to "contactInfo",
    Barcode.TYPE_EMAIL to "email",
    Barcode.TYPE_ISBN to "isbn",
    Barcode.TYPE_PHONE to "phone",
    Barcode.TYPE_PRODUCT to "product",
    Barcode.TYPE_SMS to "sms",
    Barcode.TYPE_TEXT to "text",
    Barcode.TYPE_URL to "url",
    Barcode.TYPE_WIFI to "wifi",
    Barcode.TYPE_GEO to "geo",
    Barcode.TYPE_CALENDAR_EVENT to "calendarEvent",
    Barcode.TYPE_DRIVER_LICENSE to "driverLicense",
  )

  private val PHONE_TYPES = mapOf(
    Barcode.Phone.TYPE_WORK to "work",
    Barcode.Phone.TYPE_HOME to "home",
    Barcode.Phone.TYPE_FAX to "fax",
    Barcode.Phone.TYPE_MOBILE to "mobile",
  )
  private val EMAIL_TYPES = mapOf(Barcode.Email.TYPE_WORK to "work", Barcode.Email.TYPE_HOME to "home")
  private val ADDRESS_TYPES = mapOf(Barcode.Address.TYPE_WORK to "work", Barcode.Address.TYPE_HOME to "home")
  private val WIFI_TYPES = mapOf(
    Barcode.WiFi.TYPE_OPEN to "open",
    Barcode.WiFi.TYPE_WPA to "wpa",
    Barcode.WiFi.TYPE_WEP to "wep",
  )

  /** Everything but the box and corners, which need the image. */
  fun fields(code: Barcode, format: String): Map<String, Any?> {
    val type = VALUE_TYPES[code.valueType] ?: "unknown"
    val out = mutableMapOf<String, Any?>(
      "rawValue" to code.rawValue,
      "displayValue" to code.displayValue,
      "format" to format,
      "valueType" to type,
    )
    when (type) {
      "email" -> out["email"] = code.email?.let(::email)
      "phone" -> out["phone"] = code.phone?.let(::phone)
      "sms" -> out["sms"] = code.sms?.let { mapOf("phoneNumber" to it.phoneNumber, "message" to it.message) }
      "url" -> out["url"] = code.url?.let { mapOf("title" to it.title, "url" to it.url) }
      "wifi" -> out["wifi"] = code.wifi?.let {
        mapOf("ssid" to it.ssid, "password" to it.password, "encryptionType" to (WIFI_TYPES[it.encryptionType] ?: "unknown"))
      }
      "geo" -> out["geo"] = code.geoPoint?.let { mapOf("latitude" to it.lat, "longitude" to it.lng) }
      "contactInfo" -> out["contactInfo"] = code.contactInfo?.let(::contact)
      "calendarEvent" -> out["calendarEvent"] = code.calendarEvent?.let(::event)
      "driverLicense" -> out["driverLicense"] = code.driverLicense?.let(::license)
    }
    return out
  }

  private fun email(e: Barcode.Email) = mapOf(
    "address" to e.address, "subject" to e.subject, "body" to e.body, "type" to (EMAIL_TYPES[e.type] ?: "unknown"),
  )

  private fun phone(p: Barcode.Phone) = mapOf("number" to p.number, "type" to (PHONE_TYPES[p.type] ?: "unknown"))

  private fun contact(c: Barcode.ContactInfo) = mapOf(
    "name" to c.name?.let {
      mapOf(
        "formattedName" to it.formattedName, "pronunciation" to it.pronunciation, "prefix" to it.prefix,
        "first" to it.first, "middle" to it.middle, "last" to it.last, "suffix" to it.suffix,
      )
    },
    "organization" to c.organization,
    "title" to c.title,
    "phones" to c.phones.map(::phone),
    "emails" to c.emails.map(::email),
    "urls" to c.urls,
    "addresses" to c.addresses.map {
      mapOf("lines" to it.addressLines.toList(), "type" to (ADDRESS_TYPES[it.type] ?: "unknown"))
    },
  )

  private fun event(e: Barcode.CalendarEvent) = mapOf(
    "summary" to e.summary, "description" to e.description, "location" to e.location,
    "organizer" to e.organizer, "status" to e.status,
    "start" to e.start?.let(::dateTime), "end" to e.end?.let(::dateTime),
  )

  /** ISO 8601, `Z` when the code says UTC, else the code's own local time. */
  private fun dateTime(d: Barcode.CalendarDateTime): String =
    "%04d-%02d-%02dT%02d:%02d:%02d%s".format(
      d.year, d.month, d.day, d.hours.coerceAtLeast(0), d.minutes.coerceAtLeast(0),
      d.seconds.coerceAtLeast(0), if (d.isUtc) "Z" else "",
    )

  private fun license(l: Barcode.DriverLicense) = mapOf(
    "documentType" to l.documentType, "firstName" to l.firstName, "middleName" to l.middleName,
    "lastName" to l.lastName, "gender" to l.gender, "addressStreet" to l.addressStreet,
    "addressCity" to l.addressCity, "addressState" to l.addressState, "addressZip" to l.addressZip,
    "licenseNumber" to l.licenseNumber, "issueDate" to l.issueDate, "expiryDate" to l.expiryDate,
    "birthDate" to l.birthDate, "issuingCountry" to l.issuingCountry,
  )
}
