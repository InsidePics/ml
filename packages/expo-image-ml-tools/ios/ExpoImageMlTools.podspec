require 'json'

package = JSON.parse(File.read(File.join(__dir__, '..', 'package.json')))

Pod::Spec.new do |s|
  s.name           = 'ExpoImageMlTools'
  s.version        = package['version']
  s.summary        = package['description']
  s.description    = package['description']
  s.license        = 'MIT'
  s.author         = package['author']
  s.homepage       = 'https://github.com/InsidePics/ml'
  s.platforms      = { :ios => '16.4' }
  s.swift_version  = '5.9'
  s.source         = { git: 'https://github.com/InsidePics/ml.git' }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'
  s.frameworks = 'CoreGraphics', 'UIKit'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }

  s.source_files = "**/*.{h,m,mm,swift,hpp,cpp}"
  s.exclude_files = "Tests/**"

  s.test_spec 'ExpoImageMlToolsTests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.swift'
    # The repository's fixtures/, copied here by scripts/test-device-ios.sh:
    # CocoaPods takes no resource from outside the pod or through a link.
    test_spec.resources = 'Tests/Fixtures/**/*'
    test_spec.frameworks = 'XCTest'
    # ExpoModulesCore pulls in React Native's C++ codegen.
    test_spec.libraries = 'c++'
    test_spec.requires_app_host = true
  end
end
