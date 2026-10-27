const { withGradleProperties } = require('expo/config-plugins');

/**
 * ML Kit's entity extraction declares Android 8.0 (API 26) as its minimum, so
 * an app at Expo's default of 24 fails its manifest merge. This raises the
 * app's `android.minSdkVersion` (the property expo-build-properties also
 * writes) to 26, and never lowers a higher one.
 */
const MIN_SDK = 26;
const KEY = 'android.minSdkVersion';

/** The gradle properties with the minimum raised. Exported for tests. */
function raiseMinSdk(properties) {
  const entry = properties.find((p) => p.type === 'property' && p.key === KEY);
  if (entry) {
    if (Number(entry.value) < MIN_SDK) entry.value = String(MIN_SDK);
    return properties;
  }
  return [
    ...properties,
    { type: 'property', key: KEY, value: String(MIN_SDK) },
  ];
}

module.exports = function withMlKitMinSdk(config) {
  return withGradleProperties(config, (cfg) => {
    cfg.modResults = raiseMinSdk(cfg.modResults);
    return cfg;
  });
};

module.exports.raiseMinSdk = raiseMinSdk;
module.exports.MIN_SDK = MIN_SDK;
