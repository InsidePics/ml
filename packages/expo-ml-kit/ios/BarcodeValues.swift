#if canImport(MLKitBarcodeScanning) && !targetEnvironment(simulator)
import Foundation
import MLKitBarcodeScanning

/// A barcode's decoded content, the `MlKitBarcode` fields beside its box, as
/// Android's `BarcodeValues.kt` writes them: the raw and display values, the
/// value type ML Kit parsed, and that type's fields.
enum BarcodeValues {
  /// `MlKitBarcodeValueType`, as Android names `Barcode.TYPE_*`.
  static let valueTypes: [(BarcodeValueType, String)] = [
    (.contactInfo, "contactInfo"),
    (.email, "email"),
    (.ISBN, "isbn"),
    (.phone, "phone"),
    (.product, "product"),
    (.SMS, "sms"),
    (.text, "text"),
    (.URL, "url"),
    (.wiFi, "wifi"),
    (.geographicCoordinates, "geo"),
    (.calendarEvent, "calendarEvent"),
    (.driversLicense, "driverLicense"),
  ]

  /// Everything but the box and corners, which need the image.
  static func fields(_ code: Barcode, format: String) -> [String: Any] {
    let type = valueTypes.first { $0.0 == code.valueType }?.1 ?? "unknown"
    var out: [String: Any] = [
      "rawValue": code.rawValue ?? NSNull(),
      "displayValue": code.displayValue ?? NSNull(),
      "format": format,
      "valueType": type,
    ]
    switch type {
    case "email": out["email"] = code.email.map(email) ?? NSNull()
    case "phone": out["phone"] = code.phone.map(phone) ?? NSNull()
    case "sms":
      out["sms"] = code.sms.map { sms -> [String: Any] in
        ["phoneNumber": sms.phoneNumber ?? NSNull(), "message": sms.message ?? NSNull()]
      } ?? NSNull()
    case "url":
      out["url"] = code.url.map { url -> [String: Any] in
        ["title": url.title ?? NSNull(), "url": url.url ?? NSNull()]
      } ?? NSNull()
    case "wifi": out["wifi"] = code.wifi.map(wifi) ?? NSNull()
    case "geo":
      out["geo"] = code.geoPoint.map { geo -> [String: Any] in
        ["latitude": geo.latitude, "longitude": geo.longitude]
      } ?? NSNull()
    case "contactInfo": out["contactInfo"] = code.contactInfo.map(contact) ?? NSNull()
    case "calendarEvent": out["calendarEvent"] = code.calendarEvent.map(event) ?? NSNull()
    case "driverLicense": out["driverLicense"] = code.driverLicense.map(license) ?? NSNull()
    default: break
    }
    return out
  }

  private static func kind(_ work: Bool, _ home: Bool) -> String {
    work ? "work" : home ? "home" : "unknown"
  }

  private static func email(_ e: BarcodeEmail) -> [String: Any] {
    [
      "address": e.address ?? NSNull(), "subject": e.subject ?? NSNull(), "body": e.body ?? NSNull(),
      "type": kind(e.type == .work, e.type == .home),
    ]
  }

  private static func phone(_ p: BarcodePhone) -> [String: Any] {
    let type: String
    switch p.type {
    case .fax: type = "fax"
    case .mobile: type = "mobile"
    default: type = kind(p.type == .work, p.type == .home)
    }
    return ["number": p.number ?? NSNull(), "type": type]
  }

  private static func wifi(_ w: BarcodeWifi) -> [String: Any] {
    let type: String
    switch w.type {
    case .open: type = "open"
    case .WPA: type = "wpa"
    case .WEP: type = "wep"
    default: type = "unknown"
    }
    return ["ssid": w.ssid ?? NSNull(), "password": w.password ?? NSNull(), "encryptionType": type]
  }

  private static func contact(_ c: BarcodeContactInfo) -> [String: Any] {
    let name: Any = c.name.map { n -> [String: Any] in
      [
        "formattedName": n.formattedName ?? NSNull(), "pronunciation": n.pronunciation ?? NSNull(),
        "prefix": n.prefix ?? NSNull(), "first": n.first ?? NSNull(), "middle": n.middle ?? NSNull(),
        "last": n.last ?? NSNull(), "suffix": n.suffix ?? NSNull(),
      ]
    } ?? NSNull()
    return [
      "name": name,
      "organization": c.organization ?? NSNull(),
      "title": c.jobTitle ?? NSNull(),
      "phones": (c.phones ?? []).map(phone),
      "emails": (c.emails ?? []).map(email),
      "urls": c.urls ?? [],
      "addresses": (c.addresses ?? []).map {
        ["lines": $0.addressLines ?? [], "type": kind($0.type == .work, $0.type == .home)] as [String: Any]
      },
    ]
  }

  private static let iso: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  private static func event(_ e: BarcodeCalendarEvent) -> [String: Any] {
    [
      "summary": e.summary ?? NSNull(), "description": e.eventDescription ?? NSNull(),
      "location": e.location ?? NSNull(), "organizer": e.organizer ?? NSNull(),
      "status": e.status ?? NSNull(),
      "start": e.start.map(iso.string) ?? NSNull(), "end": e.end.map(iso.string) ?? NSNull(),
    ]
  }

  private static func license(_ l: BarcodeDriverLicense) -> [String: Any] {
    [
      "documentType": l.documentType, "firstName": l.firstName, "middleName": l.middleName,
      "lastName": l.lastName, "gender": l.gender, "addressStreet": l.addressStreet,
      "addressCity": l.addressCity, "addressState": l.addressState, "addressZip": l.addressZip,
      "licenseNumber": l.licenseNumber, "issueDate": l.issuingDate, "expiryDate": l.expiryDate,
      "birthDate": l.birthDate, "issuingCountry": l.issuingCountry,
    ].mapValues { $0 ?? NSNull() as Any }
  }
}
#endif
