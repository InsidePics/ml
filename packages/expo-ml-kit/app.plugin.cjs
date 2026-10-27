// Expo config plugin: `plugins: ['expo-ml-kit']` in app.json.
// iOS: ML Kit unlinked from Apple Silicon simulator builds (none exists).
// Android: the minimum SDK raised to what ML Kit's models declare.
const withMlKitMinSdk = require('./plugin/withMlKitMinSdk.cjs');
const withMlKitSimulator = require('./plugin/withMlKitSimulator.cjs');

module.exports = (config) => withMlKitMinSdk(withMlKitSimulator(config));
