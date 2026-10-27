import Apple from '@insidepics/expo-apple-intelligence';
import { Platform } from 'react-native';

import { load } from './images';
import { assert, assertEqual, assertRejects, test as anyTest } from './runner';

// Apple Intelligence is iOS only.
const test = Platform.OS === 'ios' ? anyTest : () => {};

test('apple: analyzeImage finds the face, upright size, every part', async () => {
  const image = await load('face.jpg');
  const result = await Apple.analyzeImage(image);
  assertEqual([result.imageWidth, result.imageHeight], [400, 600], 'size');
  assertEqual(result.faces.length, 1, 'faces');
  assert(
    typeof result.faces[0].quality === 'number',
    'the face carries its quality'
  );
  for (const key of [
    'text',
    'labels',
    'barcodes',
    'bodyPoses',
    'featurePrint',
    'saliency',
  ]) {
    assert(key in result, `missing ${key}`);
  }
});

test('apple: a rotated HEIC handle is analysed upright', async () => {
  const result = await Apple.analyzeImage(
    await load('face-orientation-6.heic')
  );
  assertEqual(
    [result.imageWidth, result.imageHeight],
    [400, 600],
    'upright size'
  );
  assertEqual(result.faces.length, 1, 'faces');
});

test('apple: single requests through the bridge', async () => {
  const text = await Apple.recognizeText(await load('text.jpg'));
  assert(
    text.some((t) => /WARNING/i.test(t.candidates[0]?.string ?? '')),
    'reads WARNING'
  );
  const codes = await Apple.detectBarcodes(await load('barcode.jpg'));
  assert(
    codes.some((c) => c.payloadStringValue === '2404105001722'),
    'EAN-13 payload'
  );
  const faces = await Apple.detectFaces(await load('landscape.jpg'));
  assertEqual(faces.length, 0, 'no face in a landscape');
  const animals = await Apple.detectAnimals(await load('animal.jpg'));
  assert(animals.length >= 1, 'the dog');
});

test('apple: a path instead of a handle is refused, not crashed on', async () => {
  await assertRejects(() => Apple.analyzeImage('/tmp/face.jpg'), /./, 'string');
  await assertRejects(() => Apple.detectFaces({}), /./, 'plain object');
  await assertRejects(() => Apple.detectFaces(null), /./, 'null');
});

test('apple: a released handle is refused, not crashed on', async () => {
  const image = await load('face.jpg');
  image.release();
  await assertRejects(() => Apple.detectFaces(image), /./, 'released handle');
});
