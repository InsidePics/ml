#if canImport(MLKitEntityExtraction) && !targetEnvironment(simulator)
import Foundation
import MLKitCommon
import MLKitEntityExtraction

/// Entity Extraction, one extractor per language, as Android's
/// `EntityAnalyzer.kt` runs it. The base detector is bundled; a language's
/// model downloads at first use, on Wi-Fi only. Until it is on the device the
/// result is nil — "unknown", for the caller to retry — never an empty list,
/// which would read as "no entities".
enum EntityAnalyzer {
  /// The entity types kept. Payment cards and IBANs are left out, as on
  /// Android: the numbers are in the OCR text already, and a labelled,
  /// searchable copy would only make them easier to harvest.
  static let entityTypes: [EntityType: String] = [
    .address: "address",
    .dateTime: "dateTime",
    .email: "email",
    .flightNumber: "flightNumber",
    .ISBN: "isbn",
    .money: "money",
    .phone: "phone",
    .trackingNumber: "trackingNumber",
    .URL: "url",
  ]

  /// `DateTimeGranularity` by raw value: unknown (0), then year to second.
  private static let granularities = [
    "unknown", "year", "month", "week", "day", "hour", "minute", "second",
  ]

  /// `ParcelTrackingCarrier` by raw value, the same list Android indexes.
  private static let carriers = [
    "unknown", "fedex", "ups", "dhl", "usps", "ontrac", "lasership", "israelPost", "swissPost",
    "msc", "amazon", "iParcel",
  ]

  private static let lock = NSLock()
  private static var extractors: [String: EntityExtractor] = [:]
  /// Per language: nil, no download yet or the last one failed; false, one
  /// in flight; true, on the device.
  private static var ready: [String: Bool] = [:]

  static func model(_ language: String) throws -> EntityExtractionModelIdentifier {
    guard let model = EntityExtractionModelIdentifier.fromLanguageTag(language) else {
      throw NSError(domain: "ExpoMlKit", code: 3, userInfo: [
        NSLocalizedDescriptionKey: "No entity model for \(language)",
      ])
    }
    return model
  }

  static func extractor(_ language: String) throws -> EntityExtractor {
    let identifier = try model(language)
    lock.lock()
    defer { lock.unlock() }
    if let found = extractors[language] { return found }
    let made = EntityExtractor.entityExtractor(options: EntityExtractorOptions(modelIdentifier: identifier))
    extractors[language] = made
    return made
  }

  /// `language`'s model download, `done` called with its error, if any.
  static func download(
    _ language: String, wifiOnly: Bool = true, _ done: @escaping (Error?) -> Void
  ) throws {
    let extractor = try extractor(language)
    lock.lock()
    ready[language] = ready[language] ?? false
    lock.unlock()
    let conditions = ModelDownloadConditions(
      allowsCellularAccess: !wifiOnly, allowsBackgroundDownloading: true)
    extractor.downloadModelIfNeeded(with: conditions) { error in
      lock.lock()
      ready[language] = error == nil ? true : nil
      lock.unlock()
      done(error)
    }
  }

  /// Whether `language`'s model is on the device. A download just started
  /// is waited for briefly — an already-present model settles at once, so the
  /// first call of a session is not left unknown — and otherwise only
  /// checked: off Wi-Fi it never settles, and this module's queue is shared.
  private static func modelReady(_ language: String) throws -> Bool {
    lock.lock()
    let state = ready[language]
    lock.unlock()
    if let state { return state }
    let done = DispatchSemaphore(value: 0)
    try download(language) { _ in done.signal() }
    _ = done.wait(timeout: .now() + 2)
    lock.lock()
    defer { lock.unlock() }
    return ready[language] == true
  }

  /// The entities in `text`; nil while the language model is not on the
  /// device yet. Text with nothing in it has no entities either way.
  static func extract(_ text: String, options: [String: Any] = [:]) throws -> [[String: Any]]? {
    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }
    let language = options["language"] as? String ?? "en"
    if try !modelReady(language) { return nil }
    let params = EntityExtractionParams()
    if let names = options["types"] as? [String] {
      params.typesFilter = Set(entityTypes.filter { names.contains($0.value) }.keys)
    }
    if let time = options["referenceTime"] as? NSNumber {
      params.referenceTime = Date(timeIntervalSince1970: time.doubleValue / 1000)
    }
    if let zone = options["timeZone"] as? String { params.referenceTimeZone = TimeZone(identifier: zone) }
    if let locale = options["locale"] as? String { params.preferredLocale = Locale(identifier: locale) }
    // A box per call: a callback that lands after the wait gave up writes
    // into this call's box, never a later call's.
    final class Box { var value: [[String: Any]]? }
    let box = Box()
    let done = DispatchSemaphore(value: 0)
    let source = text as NSString
    try extractor(language).annotateText(text, params: params) { annotations, error in
      if error == nil {
        let found = (annotations ?? []).flatMap { annotation in
          annotation.entities.compactMap { json(source, annotation.range, $0) }
        }
        lock.lock()
        box.value = found
        lock.unlock()
      }
      done.signal()
    }
    guard done.wait(timeout: .now() + 30) == .success else { return nil }
    lock.lock()
    defer { lock.unlock() }
    return box.value
  }

  private static func json(_ source: NSString, _ range: NSRange, _ entity: Entity) -> [String: Any]? {
    guard let type = entityTypes[entity.entityType] else { return nil }
    var out: [String: Any] = [
      "type": type, "value": source.substring(with: range),
      "start": range.location, "end": range.location + range.length,
    ]
    if let date = entity.dateTimeEntity {
      out["dateTime"] = [
        "timestamp": date.dateTime.timeIntervalSince1970 * 1000,
        "granularity": granularities[safe: date.dateTimeGranularity.rawValue] ?? "unknown",
      ]
    }
    if let money = entity.moneyEntity {
      out["money"] = [
        "integerPart": money.integerPart, "fractionalPart": money.fractionalPart,
        "currency": money.unnormalizedCurrency,
      ]
    }
    if let flight = entity.flightNumberEntity {
      out["flightNumber"] = ["airlineCode": flight.airlineCode, "flightNumber": flight.flightNumber]
    }
    if let isbn = entity.isbnEntity { out["isbn"] = isbn.isbn }
    if let parcel = entity.trackingNumberEntity {
      out["trackingNumber"] = [
        "carrier": carriers[safe: parcel.parcelCarrier.rawValue] ?? "unknown",
        "number": parcel.parcelTrackingNumber,
      ]
    }
    return out
  }
}

extension Array {
  subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
#endif
