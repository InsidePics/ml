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
  s.source         = { git: 'https://github.com/InsidePics/ml.git', tag: "expo-ml-kit@#{s.version}" }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'

  # The ML Kit features the app enables: `expoMlKit.features` in its
  # Podfile.properties.json (the config plugin's `features`), else the
  # defaults. `src/features.json` names each feature's pods; a feature with
  # none is Android-only. Each feature's Swift compiles only where its pod can
  # be imported (`#if canImport(...)`), so leaving one out leaves out its code.
  # Google ships no Apple Silicon simulator build of these: the module
  # compiles them out there and reports itself unavailable, and the config
  # plugin (app.plugin.cjs) unlinks them from simulator builds.
  catalog = JSON.parse(File.read(File.join(__dir__, '..', 'src', 'features.json')))
  properties_file = File.join(Pod::Config.instance.installation_root.to_s, 'Podfile.properties.json')
  chosen = File.exist?(properties_file) ? JSON.parse(File.read(properties_file))['expoMlKit.features'] : nil
  features = chosen ? chosen.split(',').map(&:strip).reject(&:empty?) : catalog.select { |_, f| f['default'] }.keys
  features.each do |feature|
    raise "expo-ml-kit: no feature '#{feature}'" unless catalog.key?(feature)
    catalog[feature]['ios'].each do |pod|
      name, version = pod.split(' ', 2)
      s.dependency name, version
    end
  end

  s.frameworks = 'ImageIO', 'CoreGraphics', 'UIKit'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }

  s.source_files = "**/*.{h,m,mm,swift,hpp,cpp}"
  s.exclude_files = "Tests/**"

  s.test_spec 'ExpoMlKitTests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.swift'
    # The repository's fixtures/, copied here by scripts/test-device-ios.sh:
    # CocoaPods takes no resource from outside the pod or through a link.
    test_spec.resources = 'Tests/Fixtures/**/*'
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
