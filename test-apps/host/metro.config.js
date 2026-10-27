// Expo's monorepo defaults (the workspace root is watched, so the shared
// fixtures/ are bundled as assets), plus HEIC as an asset type.
const { getDefaultConfig } = require('expo/metro-config');

const config = getDefaultConfig(__dirname);
config.resolver.assetExts.push('heic');

module.exports = config;
