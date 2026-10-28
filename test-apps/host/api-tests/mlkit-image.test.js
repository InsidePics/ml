// expo-ml-kit's image calls beyond analyzeImage, through the bridge: each
// option reaches the native side and each result comes back in its TS shape.
import * as MlKit from 'expo-ml-kit';
import { Platform } from 'react-native';

import { fixtureUri, load } from './images';
import { assert, assertEqual, assertRejects, test } from './runner';

const inUnit = (v) => typeof v === 'number' && v >= 0 && v <= 1;

/** The model fixture's path, as a caller passes its own model's. */
const model = async () => ({
  path: await fixtureUri('mobilenet-v1-metadata.tflite'),
});

test('ml kit: every feature is linked (the host enables all)', async () => {
  const expected = MlKit.ML_KIT_FEATURES.filter(
    (f) => Platform.OS === 'android' || MlKit.ML_KIT_ARTIFACTS[f].ios.length
  );
  for (const feature of expected) {
    assert(MlKit.isMlKitAvailable(feature), `${feature} linked`);
  }
});

test('ml kit: detectBarcodes parses each value type', async () => {
  const codes = await MlKit.detectBarcodes(await load('barcode-values.png'));
  const byType = Object.fromEntries(codes.map((c) => [c.valueType, c]));
  assertEqual(
    Object.keys(byType).sort(),
    ['calendarEvent', 'contactInfo', 'email', 'geo', 'phone', 'sms']
      .concat(['text', 'url', 'wifi'])
      .sort(),
    'value types'
  );
  assertEqual(byType.wifi.wifi.ssid, 'InsidePics', 'wifi ssid');
  assertEqual(byType.wifi.wifi.encryptionType, 'wpa', 'wifi encryption');
  assertEqual(byType.url.url.url, 'https://example.com/ml-kit', 'url');
  assertEqual(byType.email.email.address, 'ml@example.com', 'email');
  assertEqual(byType.phone.phone.number, '+15550101', 'phone');
  assertEqual(byType.sms.sms.message, 'Hello there', 'sms');
  assert(Math.abs(byType.geo.geo.latitude - 40.7128) < 1e-6, 'latitude');
  assertEqual(
    byType.contactInfo.contactInfo.name.formattedName,
    'Jane Doe',
    'contact'
  );
  assertEqual(
    byType.calendarEvent.calendarEvent.start,
    '2026-10-28T09:00:00Z',
    'event start'
  );
  assertEqual(byType.text.rawValue, 'Hello, ML Kit', 'text');
});

test('ml kit: detectBarcodes reads a licence and honours formats', async () => {
  const [license] = await MlKit.detectBarcodes(
    await load('barcode-license.png')
  );
  assertEqual(license.format, 'PDF417', 'format');
  assertEqual(license.driverLicense.lastName, 'DOE', 'last name');
  const image = await load('barcode.jpg');
  const [ean] = await MlKit.detectBarcodes(image, { formats: ['EAN_13'] });
  assertEqual(ean.displayValue, '2404105001722', 'EAN-13');
  assertEqual(ean.cornerPoints.length, 4, 'corners');
  assert(
    ean.cornerPoints.every((p) => inUnit(p.x) && inUnit(p.y)),
    'corners normalized'
  );
  const none = await MlKit.detectBarcodes(image, { formats: ['QR_CODE'] });
  assertEqual(none.length, 0, 'QR only finds no EAN');
  await assertRejects(
    () => MlKit.detectBarcodes(image, { formats: ['NOT_A_FORMAT'] }),
    /NOT_A_FORMAT/,
    'unknown format'
  );
});

test('ml kit: recognizeText returns lines, words and languages', async () => {
  const text = await MlKit.recognizeText(await load('text.jpg'));
  const words = text.blocks.flatMap((b) => b.lines.flatMap((l) => l.elements));
  const word = words.find((w) => w.text === 'WARNING');
  assert(word, 'finds WARNING');
  assertEqual(word.cornerPoints.length, 4, 'word corners');
  assert(inUnit(word.boundingBox.x), 'word box normalized');
  if (Platform.OS === 'android') {
    assertEqual(word.symbols.map((s) => s.text).join(''), 'WARNING', 'symbols');
    assert(inUnit(word.confidence), 'confidence');
  }
  const other = await MlKit.recognizeText(await load('text.jpg'), 'japanese');
  assert(typeof other.text === 'string', 'another script runs');
});

test('ml kit: detectFaces classifies, fast mode and minFaceSize', async () => {
  const image = await load('face.jpg');
  const [plain] = await MlKit.detectFaces(image);
  assert(!('smilingProbability' in plain), 'no scores unasked');
  const [face] = await MlKit.detectFaces(image, { classify: true });
  assert(face.smilingProbability > 0.5, 'smiling');
  assert(face.leftEyeOpenProbability > 0.5, 'left eye open');
  assert(face.rightEyeOpenProbability > 0.5, 'right eye open');
  const fast = await MlKit.detectFaces(image, { performance: 'fast' });
  assertEqual(fast.length, 1, 'fast mode finds the face');
  // A search hint, not a filter (ML Kit scans no smaller scales): a face
  // wider than the minimum is still found.
  const width = plain.boundingBox.width;
  const big = await MlKit.detectFaces(image, { minFaceSize: width / 2 });
  assertEqual(big.length, 1, `found with minFaceSize ${width / 2}`);
});

test('ml kit: labelImage threshold and detectObjects options', async () => {
  const dog = await load('animal.jpg');
  const all = await MlKit.labelImage(dog, { confidenceThreshold: 0.1 });
  const sure = await MlKit.labelImage(dog, { confidenceThreshold: 0.8 });
  assert(all.length > sure.length, 'a higher threshold keeps fewer');
  assert(
    all.every((l) => l.confidence >= 0.1),
    'all above the threshold'
  );
  const body = await load('body.jpg');
  const one = await MlKit.detectObjects(body, {
    multipleObjects: false,
    classify: false,
  });
  assertEqual(one.length, 1, 'only the most prominent');
  assertEqual(one[0].labels.length, 0, 'unlabelled');
});

test('ml kit: detectPose with the accurate model', async () => {
  const body = await load('body.jpg');
  const [accurate] = await MlKit.detectPose(body, { model: 'accurate' });
  assertEqual(accurate.landmarks.length, 33, '33 landmarks');
  const [base] = await MlKit.detectPose(body);
  const nose = (pose) => pose.landmarks.find((l) => l.type === 'nose');
  assert(Math.abs(nose(base).x - nose(accurate).x) < 0.05, 'same nose');
});

test('ml kit: a custom classifier labels images and objects', async () => {
  const custom = await model();
  const labels = await MlKit.labelImage(await load('animal.jpg'), {
    model: custom,
    confidenceThreshold: 0.1,
  });
  assert(
    labels.some((l) => /shepherd/i.test(l.text)),
    `shepherd in ${labels.map((l) => l.text)}`
  );
  const objects = await MlKit.detectObjects(await load('body.jpg'), {
    model: custom,
    confidenceThreshold: 0.01,
    maxLabelsPerObject: 1,
  });
  assert(objects.length >= 1, 'boxes something');
  assert(
    objects.every((o) => o.labels.length <= 1),
    'at most one label each'
  );
});

test('ml kit: a missing custom model file is refused', async () => {
  const dog = await load('animal.jpg');
  await assertRejects(
    () =>
      MlKit.labelImage(dog, {
        model: { path: '/nowhere/model.tflite' },
      }),
    /No model file/,
    'missing model file'
  );
});

test('ml kit: segmentSelfie masks the person as bytes', async () => {
  const mask = await MlKit.segmentSelfie(await load('body.jpg'));
  assert(mask.data instanceof Uint8Array, 'data is a Uint8Array');
  assertEqual(mask.data.length, mask.width * mask.height, 'one byte a pixel');
  const person = MlKit.maskCoverage(mask);
  assert(person > 0.05 && person < 0.9, `person share ${person}`);
  const empty = MlKit.maskCoverage(
    await MlKit.segmentSelfie(await load('landscape.jpg'))
  );
  assert(empty < person, `landscape share ${empty}`);
  const raw = await MlKit.segmentSelfie(await load('body.jpg'), {
    rawSizeMask: true,
  });
  assertEqual([raw.width, raw.height], [256, 256], 'raw mask size');
});

test('ml kit: detectFaceMesh on Android, refused on iOS', async () => {
  const image = await load('face.jpg');
  if (Platform.OS === 'ios') {
    await assertRejects(
      () => MlKit.detectFaceMesh(image),
      /ERR_ML_KIT_FEATURE/,
      'Android only'
    );
    return;
  }
  const [mesh] = await MlKit.detectFaceMesh(image);
  assertEqual(mesh.points.length, 468, '468 points');
  assert(mesh.triangles.length > 800, 'triangles');
  assertEqual(Object.keys(mesh.contours).length, 12, 'contours');
  const [box] = await MlKit.detectFaceMesh(image, { boundingBoxOnly: true });
  assertEqual(box.points.length, 0, 'no mesh, box only');
});
