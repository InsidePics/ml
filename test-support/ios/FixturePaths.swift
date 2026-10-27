import Foundation

/// Locates a file of the repository's shared `fixtures/` (each package's
/// `ios/Tests/Fixtures` links to it, and this file is linked into each
/// package's tests) under every way the tests run: the SwiftPM package
/// (`swift test`, where the fixtures are a resource bundle), a CocoaPods test
/// spec, and a plain checkout as a last resort.
enum FixturePaths {
  private final class Anchor {}

  static func path(_ name: String) -> String {
    let base = (name as NSString).deletingPathExtension
    let ext = (name as NSString).pathExtension
    var bundles = [Bundle(for: Anchor.self)]
    #if SWIFT_PACKAGE
    bundles.insert(Bundle.module, at: 0)
    #endif
    // A bundled copy may be the link itself, dangling once copied: only a
    // readable file counts.
    let bundled = bundles.flatMap {
      [$0.path(forResource: base, ofType: ext, inDirectory: "Fixtures"),
       $0.path(forResource: base, ofType: ext)]
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
