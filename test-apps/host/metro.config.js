// Expo's monorepo defaults (the workspace root is watched, so the shared
// fixtures/ are bundled as assets), plus HEIC images and the TensorFlow Lite
// model fixture as asset types.
const { getDefaultConfig } = require('expo/metro-config');

const config = getDefaultConfig(__dirname);
config.resolver.assetExts.push('heic', 'tflite');

module.exports = config;
