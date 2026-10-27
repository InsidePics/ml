import * as MlKit from '@insidepics/expo-ml-kit';

import { load } from './images';
import { assert, assertEqual, assertRejects, test } from './runner';

const EVERY = [
  'mlKitText',
  'mlKitLabels',
  'mlKitBarcodes',
  'mlKitPoses',
  'mlKitObjects',
];

test('ml kit: available on a device', async () => {
  assertEqual(MlKit.isMlKitAvailable(), true, 'isMlKitAvailable');
});

test('ml kit: analyzeImage runs every model on one handle', async () => {
  const result = await MlKit.analyzeImage(await load('animal.jpg'), EVERY);
  assertEqual([result.imageWidth, result.imageHeight], [640, 427], 'size');
  assert(
    result.labels.some((l) => l.text === 'Dog'),
    'labels the dog'
  );
  assert(result.objects.length >= 1, 'boxes the dog');
  assertEqual(result.barcodes.length, 0, 'no barcode');
  assert(Array.isArray(result.entities), 'entities present');
});

test('ml kit: text, barcodes and pose through the bridge', async () => {
  const text = await MlKit.analyzeImage(await load('text.jpg'), ['mlKitText']);
  assert(/WARNING/.test(text.text.text), 'reads WARNING');
  const codes = await MlKit.analyzeImage(await load('barcode.jpg'), [
    'mlKitBarcodes',
  ]);
  assert(
    codes.barcodes.some((c) => c.rawValue === '2404105001722'),
    'EAN-13'
  );
  const pose = await MlKit.analyzeImage(await load('body.jpg'), ['mlKitPoses']);
  assertEqual(pose.poses[0]?.landmarks.length, 33, '33 landmarks');
});

test('ml kit: detectFaces on a rotated HEIC handle', async () => {
  const faces = await MlKit.detectFaces(await load('face-orientation-6.heic'));
  assertEqual(faces.length, 1, 'one face');
  assert(faces[0].landmarks?.leftEye?.length >= 1, 'landmarks');
});

test('ml kit: entities from text', async () => {
  const result = await MlKit.analyzeImage(await load('text.jpg'), [
    'mlKitEntities',
  ]);
  assert(
    Array.isArray(result.entities) || result.entities === null,
    'entities or unknown'
  );
});

test('ml kit: a path instead of a handle is refused, not crashed on', async () => {
  await assertRejects(() => MlKit.detectFaces('/tmp/face.jpg'), /./, 'string');
  await assertRejects(() => MlKit.analyzeImage({}, EVERY), /./, 'plain object');
});

test('ml kit: a released handle is refused, not crashed on', async () => {
  const image = await load('face.jpg');
  image.release();
  await assertRejects(() => MlKit.detectFaces(image), /./, 'released handle');
});
