import { Asset } from 'expo-asset';
import { ImageManipulator } from 'expo-image-manipulator';

import app from '../app.json';

/** The repository's fixtures, bundled into the app by Metro. */
const FIXTURES = {
  'face.jpg': require('../../../fixtures/face.jpg'),
  'face-orientation-6.heic': require('../../../fixtures/face-orientation-6.heic'),
  'face-orientation-3.jpg': require('../../../fixtures/face-orientation-3.jpg'),
  'text.jpg': require('../../../fixtures/text.jpg'),
  'barcode.jpg': require('../../../fixtures/barcode.jpg'),
  'barcode-values.png': require('../../../fixtures/barcode-values.png'),
  'barcode-license.png': require('../../../fixtures/barcode-license.png'),
  'qrcode.jpg': require('../../../fixtures/qrcode.jpg'),
  'animal.jpg': require('../../../fixtures/animal.jpg'),
  'body.jpg': require('../../../fixtures/body.jpg'),
  'landscape.jpg': require('../../../fixtures/landscape.jpg'),
  'mobilenet-v1-metadata.tflite': require('../../../fixtures/mobilenet-v1-metadata.tflite'),
};

/** The fixture on the device. An Android release build ships images as
 *  drawable resources, which expo-asset names without a scheme; any other
 *  file it copies out to a `file://` path. */
export async function fixtureUri(name) {
  const asset = Asset.fromModule(FIXTURES[name]);
  await asset.downloadAsync();
  const uri = asset.localUri;
  return uri.includes(':')
    ? uri
    : `android.resource://${app.expo.android.package}/drawable/${uri}`;
}

/** The fixture decoded once into an image handle, as an app would. */
export async function load(name) {
  return ImageManipulator.manipulate(await fixtureUri(name)).renderAsync();
}
