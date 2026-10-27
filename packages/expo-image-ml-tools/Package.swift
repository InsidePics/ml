// swift-tools-version:5.9
// The pixel maths on a Mac, without the Expo host: `swift test`. The module
// glue (ExpoModulesCore) is left out; everything it calls is built here.
import PackageDescription

let package = Package(
  name: "ExpoImageMlTools",
  platforms: [.iOS("16.4"), .macOS("13.0")],
  targets: [
    .target(
      name: "ExpoImageMlTools", path: "ios",
      exclude: ["ExpoImageMlToolsModule.swift", "ExpoImageMlTools.podspec", "Tests"]),
    .testTarget(
      name: "ExpoImageMlToolsTests", dependencies: ["ExpoImageMlTools"], path: "ios/Tests"),
  ]
)
