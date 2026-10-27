import Foundation

/// Locates a file of the repository's shared `fixtures/` (this file is linked
/// into each package's tests) under both ways the tests run: a CocoaPods test
/// bundle on a device, where the script copied them in as resources, and a
/// checkout (`swift test` on a Mac), read in place.
enum FixturePaths {
  private final class Anchor {}

  static func path(_ name: String) -> String {
    let base = (name as NSString).deletingPathExtension
    let ext = (name as NSString).pathExtension
    // A CocoaPods resource lands at the bundle's top level, folders dropped.
    let file = ((name as NSString).lastPathComponent as NSString).deletingPathExtension
    let bundles = [Bundle(for: Anchor.self)]
    let bundled = bundles.flatMap {
      [$0.path(forResource: base, ofType: ext, inDirectory: "Fixtures"),
       $0.path(forResource: base, ofType: ext),
       $0.path(forResource: file, ofType: ext)]
    }
    // test-support/ios/FixturePaths.swift → the repository root.
    let root = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath()
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let checkout = root.appendingPathComponent("fixtures/\(name)").path
    return (bundled.compactMap { $0 } + [checkout]).first {
      FileManager.default.isReadableFile(atPath: $0)
    } ?? checkout
  }
}
