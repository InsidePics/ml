const fs = require('fs');
const path = require('path');
const { withDangerousMod } = require('expo/config-plugins');

const MARKER = '# [expo-ml-kit] ML Kit: no Apple Silicon simulator build';

/**
 * Google's ML Kit iOS frameworks ship an arm64 slice built for DEVICES and
 * an x86_64 slice for Intel simulators — none for an arm64 (Apple Silicon)
 * simulator, so linking them into a simulator build fails. Excluding arm64
 * from simulator builds is not an option either — Xcode 26 runs no x86_64
 * simulator — though ML Kit's own pods ask the app to do exactly that
 * (`EXCLUDED_ARCHS[sdk=iphonesimulator*] = arm64`); the hook removes it.
 *
 * So simulator builds do not link ML Kit at all: this moves the ML Kit
 * frameworks of every aggregate target's `OTHER_LDFLAGS` under
 * `sdk=iphoneos*`, and `expo-ml-kit`'s Swift compiles its ML Kit code
 * out there and reports `isAvailable: false`, so the app plans no `mlKit*`
 * cell on a simulator. Device builds are untouched.
 */
const HELPER = `${MARKER}
def expo_ml_kit_unlink_on_simulator(installer)
  installer.aggregate_targets.each do |target|
    target.xcconfigs.each do |config, xcconfig|
      frameworks = xcconfig.other_linker_flags[:frameworks]
      ml_kit = frameworks.select { |name| name.start_with?('MLKit') || name == 'MLImage' }
      next if ml_kit.empty?
      # Out of the flags every SDK links, back in for devices only. (A
      # simulator-only override would not do: its $(inherited) is the very
      # setting it overrides.)
      ml_kit.each { |name| frameworks.delete(name) }
      xcconfig.attributes['OTHER_LDFLAGS[sdk=iphoneos*]'] =
        (['$(inherited)'] + ml_kit.map { |name| %(-framework "#{name}") }).join(' ')
      # ML Kit's pods ask the app to exclude arm64 from simulator builds,
      # which leaves an Apple Silicon simulator (Xcode 26: no Rosetta) with
      # nothing to build. ML Kit is unlinked there instead (above).
      xcconfig.attributes.delete('EXCLUDED_ARCHS[sdk=iphonesimulator*]')
      xcconfig.save_as(Pathname.new(target.xcconfig_path(config)))
    end
  end
end
`;

const CALL = '    expo_ml_kit_unlink_on_simulator(installer)';

/**
 * Add the helper and call it first thing in `post_install`, once. Exported
 * so the behaviour is testable without Expo's plugin machinery.
 */
function applyMlKitSimulatorHook(contents) {
  if (contents.includes(MARKER)) return contents;
  const hook = 'post_install do |installer|\n';
  if (!contents.includes(hook)) {
    throw new Error('withMlKitSimulator: the Podfile has no post_install');
  }
  return `${HELPER}\n${contents.replace(hook, `${hook}${CALL}\n`)}`;
}

/** The dangerous mod itself. Exported so it can be run without Expo. */
function patchPodfile(cfg) {
  const podfile = path.join(cfg.modRequest.platformProjectRoot, 'Podfile');
  fs.writeFileSync(
    podfile,
    applyMlKitSimulatorHook(fs.readFileSync(podfile, 'utf8'))
  );
  return cfg;
}

module.exports = function withMlKitSimulator(config) {
  return withDangerousMod(config, ['ios', patchPodfile]);
};

module.exports.applyMlKitSimulatorHook = applyMlKitSimulatorHook;
module.exports.patchPodfile = patchPodfile;
