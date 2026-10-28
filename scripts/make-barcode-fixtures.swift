// Writes the barcode value-type fixtures, generated here (no licence beyond
// the repository's):
//
//   swift scripts/make-barcode-fixtures.swift   (from the repository root)
//
// - `barcode-values.png`: a 3×3 grid of QR codes, one per value type ML Kit
//   parses (Wi-Fi, URL, email, phone, SMS, geo, contact, calendar event,
//   plain text), so one scan checks every parser.
// - `barcode-license.png`: a PDF417 AAMVA driver licence (a made-up person).
//
// The payloads are the tests' expected values (`SceneTests`, `BarcodeTests`).
import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

let fixtures = URL(fileURLWithPath: "fixtures")

let payloads = [
  "WIFI:T:WPA;S:InsidePics;P:correct horse;;",
  "https://example.com/ml-kit",
  "MATMSG:TO:ml@example.com;SUB:Hello;BODY:Hi there;;",
  "tel:+15550101",
  "SMSTO:+15550101:Hello there",
  "geo:40.7128,-74.006",
  "BEGIN:VCARD\nVERSION:3.0\nN:Doe;Jane;;;\nFN:Jane Doe\nORG:Example\nTITLE:Engineer\n"
    + "TEL;TYPE=WORK:+15550102\nEMAIL;TYPE=HOME:jane@example.com\nURL:https://example.com\nEND:VCARD",
  "BEGIN:VEVENT\nSUMMARY:Launch\nLOCATION:Room 1\nDTSTART:20261028T090000Z\n"
    + "DTEND:20261028T100000Z\nEND:VEVENT",
  "Hello, ML Kit",
]

// AAMVA 2016 (version 08): the header, a one-entry subfile directory, and
// the DL subfile (its elements separated by LF, ended by CR), whose offset
// and length the directory states.
let licenseFields = [
  "DCAC", "DCBNONE", "DCDNONE", "DBA10282030", "DCSDOE", "DACJANE", "DADQ",
  "DBD10282022", "DBB01151990", "DBC2", "DAYBLU", "DAU065 IN", "DAG1 MAIN ST",
  "DAIANYTOWN", "DAJVA", "DAK123450000  ", "DAQT64235789", "DCFDD1234",
  "DCGUSA", "DDEN", "DDFN", "DDGN",
]
let licenseSubfile = "DL" + licenseFields.joined(separator: "\n") + "\r"
let licenseHeader = "@\n\u{1e}\rANSI 636000080001"
let license =
  licenseHeader + "DL" + String(format: "%04d%04d", licenseHeader.utf8.count + 10, licenseSubfile.utf8.count)
  + licenseSubfile

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data((message + "\n").utf8))
  exit(1)
}

let context = CIContext()

/// `text` as a barcode `filter` draws it, scaled to whole pixels about `side`.
func code(_ filter: String, _ text: String, side: CGFloat) -> CGImage {
  guard let generator = CIFilter(name: filter) else { fail("no \(filter)") }
  generator.setValue(Data(text.utf8), forKey: "inputMessage")
  if filter == "CIQRCodeGenerator" { generator.setValue("M", forKey: "inputCorrectionLevel") }
  guard let output = generator.outputImage else { fail("could not draw \(text)") }
  let scale = (side / output.extent.width).rounded(.down)
  let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
  guard let image = context.createCGImage(scaled, from: scaled.extent) else { fail("render") }
  return image
}

/// The codes on white, `columns` wide, each cell `cell` px with a quiet zone.
func sheet(_ codes: [CGImage], columns: Int, cell: CGSize) -> CGImage {
  let rows = (codes.count + columns - 1) / columns
  let size = CGSize(width: cell.width * CGFloat(columns), height: cell.height * CGFloat(rows))
  guard let space = CGColorSpace(name: CGColorSpace.sRGB),
    let ctx = CGContext(
      data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
      bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
  else { fail("no context") }
  ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
  ctx.fill(CGRect(origin: .zero, size: size))
  ctx.interpolationQuality = .none
  for (i, image) in codes.enumerated() {
    let col = CGFloat(i % columns)
    let row = CGFloat(rows - 1 - i / columns)  // Core Graphics: bottom-left origin.
    let w = CGFloat(image.width)
    let h = CGFloat(image.height)
    let x = col * cell.width + (cell.width - w) / 2
    let y = row * cell.height + (cell.height - h) / 2
    ctx.draw(image, in: CGRect(x: x, y: y, width: w, height: h))
  }
  guard let out = ctx.makeImage() else { fail("no image") }
  return out
}

func write(_ image: CGImage, _ name: String) {
  let url = fixtures.appendingPathComponent(name)
  guard
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
  else { fail("cannot write \(name)") }
  CGImageDestinationAddImage(dest, image, nil)
  guard CGImageDestinationFinalize(dest) else { fail("cannot finalize \(name)") }
  print("wrote fixtures/\(name)")
}

let qr = payloads.map { code("CIQRCodeGenerator", $0, side: 300) }
write(sheet(qr, columns: 3, cell: CGSize(width: 400, height: 400)), "barcode-values.png")
let pdf417 = code("CIPDF417BarcodeGenerator", license, side: 900)
write(
  sheet([pdf417], columns: 1, cell: CGSize(width: pdf417.width + 120, height: pdf417.height + 120)),
  "barcode-license.png")
