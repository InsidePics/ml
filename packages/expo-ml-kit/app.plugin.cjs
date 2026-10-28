// Expo config plugin: `plugins: ['expo-ml-kit']` in app.json, or
// `['expo-ml-kit', { features: ['text', 'translate'] }]` (or 'all').
// Both: only the features named are linked (the defaults when none are).
// iOS: ML Kit unlinked from Apple Silicon simulator builds (none exists).
// Android: the minimum SDK raised to what ML Kit's models declare.
const withMlKitFeatures = require('./plugin/withMlKitFeatures.cjs');
const withMlKitMinSdk = require('./plugin/withMlKitMinSdk.cjs');
const withMlKitSimulator = require('./plugin/withMlKitSimulator.cjs');

module.exports = (config, props = {}) =>
  withMlKitFeatures(
    withMlKitMinSdk(withMlKitSimulator(config)),
    props.features
  );
