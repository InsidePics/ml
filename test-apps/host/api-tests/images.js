import { Asset } from 'expo-asset';
import { ImageManipulator } from 'expo-image-manipulator';

/** The repository's fixtures, bundled into the app by Metro. */
const FIXTURES = {
  'face.jpg': require('../../../fixtures/face.jpg'),
  'face-orientation-6.heic': require('../../../fixtures/face-orientation-6.heic'),
  'face-orientation-3.jpg': require('../../../fixtures/face-orientation-3.jpg'),
  'text.jpg': require('../../../fixtures/text.jpg'),
  'barcode.jpg': require('../../../fixtures/barcode.jpg'),
  'qrcode.jpg': require('../../../fixtures/qrcode.jpg'),
  'animal.jpg': require('../../../fixtures/animal.jpg'),
  'body.jpg': require('../../../fixtures/body.jpg'),
  'landscape.jpg': require('../../../fixtures/landscape.jpg'),
};

/** The fixture's file on the device. */
export async function fixtureUri(name) {
  const asset = Asset.fromModule(FIXTURES[name]);
  await asset.downloadAsync();
  return asset.localUri;
}

/** The fixture decoded once into an image handle, as an app would. */
export async function load(name) {
  return ImageManipulator.manipulate(await fixtureUri(name)).renderAsync();
}
