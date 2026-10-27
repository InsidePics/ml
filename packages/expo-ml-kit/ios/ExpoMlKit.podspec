require 'json'

package = JSON.parse(File.read(File.join(__dir__, '..', 'package.json')))

Pod::Spec.new do |s|
  s.name           = 'ExpoMlKit'
  s.version        = package['version']
  s.summary        = package['description']
  s.description    = package['description']
  s.license        = 'MIT'
  s.author         = package['author']
  s.homepage       = 'https://github.com/InsidePics/ml'
  s.platforms      = {
    :ios => '16.4'
  }
  s.swift_version  = '5.9'
  s.source         = { git: 'https://github.com/InsidePics/ml.git' }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'

  # BUNDLED ML Kit models only (the model ships in the app), so a result
  # names the model that produced it. Each pod is pinned to `ML_KIT_ARTIFACTS`
  # in src/artifacts.ts (the `mlKitArtifacts` test).
  # Google ships no Apple Silicon simulator build of these: the module
  # compiles them out there and reports itself unavailable, and the config
  # plugin (app.plugin.js) unlinks them from simulator builds.
  s.dependency 'MLKitTextRecognition', '7.0.0'
  s.dependency 'MLKitTextRecognitionChinese', '6.0.0'
  s.dependency 'MLKitTextRecognitionDevanagari', '6.0.0'
  s.dependency 'MLKitTextRecognitionJapanese', '6.0.0'
  s.dependency 'MLKitTextRecognitionKorean', '6.0.0'
  s.dependency 'MLKitImageLabeling', '8.0.0'
  s.dependency 'MLKitBarcodeScanning', '8.0.0'
  s.dependency 'MLKitPoseDetection', '1.0.0-beta16'
  s.dependency 'MLKitObjectDetection', '8.0.0'
  s.dependency 'MLKitEntityExtraction', '1.0.0-beta15'
  s.dependency 'MLKitFaceDetection', '8.0.0'

  s.frameworks = 'ImageIO', 'CoreGraphics', 'UIKit'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }

  s.source_files = "**/*.{h,m,mm,swift,hpp,cpp}"
  s.exclude_files = "Tests/**"

  s.test_spec 'ExpoMlKitTests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.swift'
    # The repository's shared fixtures (Tests/Fixtures links to them).
    test_spec.resources = 'Tests/Fixtures/*'
    test_spec.frameworks = 'XCTest'
    # ExpoModulesCore pulls in React Native's C++ codegen.
    test_spec.libraries = 'c++'
    # Apple Vision's faces, for the check that both detectors put one face in
    # one place (the merge a caller makes depends on it).
    test_spec.dependency 'ExpoAppleIntelligence'
    # ML Kit has no simulator build: the suites run on an iPhone, hosted.
    test_spec.requires_app_host = true
  end
end
