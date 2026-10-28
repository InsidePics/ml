const {
  withGradleProperties,
  withPodfileProperties,
} = require('expo/config-plugins');

const CATALOG = require('../src/features.json');

/** The property both builds read: android/build.gradle from the app's
 *  gradle.properties, ios/ExpoMlKit.podspec from Podfile.properties.json. */
const KEY = 'expoMlKit.features';

/**
 * The features an app links: the plugin's `features` (`'all'`, or a list of
 * `src/features.json` keys), else the defaults, with what each requires
 * (entities read the recognized text). An unknown name fails the prebuild
 * rather than linking less than the app asked for.
 */
function resolveFeatures(features) {
  const all = Object.keys(CATALOG);
  const asked =
    features === undefined
      ? all.filter((name) => CATALOG[name].default)
      : features === 'all'
        ? all
        : features;
  if (!Array.isArray(asked)) {
    throw new Error("expo-ml-kit: `features` is 'all' or a list of features");
  }
  const chosen = new Set();
  const add = (name) => {
    if (!CATALOG[name]) {
      throw new Error(
        `expo-ml-kit: no feature '${name}' (known: ${all.join(', ')})`
      );
    }
    chosen.add(name);
    (CATALOG[name].requires ?? []).forEach(add);
  };
  asked.forEach(add);
  // In the catalogue's order, so the property is stable across prebuilds.
  return all.filter((name) => chosen.has(name));
}

/** `properties` (gradle's entries) with the feature list set. Exported for
 *  tests. */
function setGradleFeatures(properties, features) {
  const value = features.join(',');
  const entry = properties.find((p) => p.type === 'property' && p.key === KEY);
  if (entry) {
    entry.value = value;
    return properties;
  }
  return [...properties, { type: 'property', key: KEY, value }];
}

module.exports = function withMlKitFeatures(config, features) {
  const chosen = resolveFeatures(features);
  config = withGradleProperties(config, (cfg) => {
    cfg.modResults = setGradleFeatures(cfg.modResults, chosen);
    return cfg;
  });
  return withPodfileProperties(config, (cfg) => {
    // iOS links only the features that have pods; the podspec skips the rest.
    cfg.modResults[KEY] = chosen.join(',');
    return cfg;
  });
};

module.exports.resolveFeatures = resolveFeatures;
module.exports.setGradleFeatures = setGradleFeatures;
module.exports.KEY = KEY;
