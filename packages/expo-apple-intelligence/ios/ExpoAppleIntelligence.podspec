require 'json'

package = JSON.parse(File.read(File.join(__dir__, '..', 'package.json')))

Pod::Spec.new do |s|
  s.name           = 'ExpoAppleIntelligence'
  s.version        = package['version']
  s.summary        = package['description']
  s.description    = package['description']
  s.license        = package['license']
  s.author         = package['author']
  s.homepage       = package['homepage']
  s.platforms      = {
    :ios => '16.4',
    :osx => '13.0'
  }
  s.swift_version  = '5.9'
  s.source         = { :git => 'https://github.com/InsidePics/ml.git', :tag => "expo-apple-intelligence@#{s.version}" }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'

  s.frameworks = 'Vision'
  s.weak_frameworks = 'FoundationModels', 'Speech', 'AVFAudio', 'ImagePlayground'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }

  s.source_files = "**/*.{h,m,mm,swift,hpp,cpp}"
  s.exclude_files = "Tests/**"

  s.test_spec 'ExpoAppleIntelligenceTests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.swift'
    # The repository's fixtures/, copied here by scripts/test-device-ios.sh:
    # CocoaPods takes no resource from outside the pod or through a link.
    test_spec.resources = 'Tests/Fixtures/**/*'
    test_spec.frameworks = 'XCTest'
    # ExpoModulesCore pulls in React Native's C++ codegen.
    test_spec.libraries = 'c++'
    # Unhosted test bundles run only on simulators and Macs; a host app lets
    # them run on an iPhone, where Vision uses the Neural Engine.
    test_spec.requires_app_host = true
  end
end
