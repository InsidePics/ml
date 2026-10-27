import {
  histogram,
  imageSize,
  sharpness,
  similarityTransform,
  toTensor,
  warp,
} from 'expo-image-ml-tools';
import * as MlKit from 'expo-ml-kit';
import { Platform } from 'react-native';

import { load } from './images';
import { assert, assertEqual, assertRejects, test } from './runner';

const IOS = Platform.OS === 'ios';
// expo-apple-ml's import throws where its module is not linked.
const Apple = IOS ? require('expo-apple-ml').default : null;
/** Faces from the platform's detector; both return Vision's face shape. */
const detectFaces = (image) =>
  IOS ? Apple.detectFaces(image) : MlKit.detectFaces(image);

const CLIP = { mean: [0.485, 0.456, 0.406], std: [0.229, 0.224, 0.225] };
const FACE_TARGETS = [
  [38.2946, 51.6963],
  [73.5318, 51.5014],
  [56.0252, 71.7366],
  [41.5493, 92.3655],
  [70.7299, 92.2041],
];

test('tools: imageSize is the upright size', async () => {
  assertEqual(
    imageSize(await load('face.jpg')),
    { width: 400, height: 600 },
    'jpg'
  );
  assertEqual(
    imageSize(await load('face-orientation-6.heic')),
    { width: 400, height: 600 },
    'heic 6'
  );
});

test('tools: toTensor gives a CLIP input of the right size and range', async () => {
  const t = await toTensor(await load('face.jpg'), {
    width: 256,
    height: 256,
    fit: 'cover',
    filter: 'nearest',
    ...CLIP,
  });
  assertEqual(t.length, 3 * 256 * 256, 'length');
  const min = Math.min(...t.subarray(0, 4096));
  const max = Math.max(...t.subarray(0, 4096));
  assert(min >= -2.2 && max <= 2.7 && max > min, `range ${min}..${max}`);
});

test('tools: every layout and filter through the bridge', async () => {
  const image = await load('animal.jpg');
  const nchw = await toTensor(image, { width: 8, height: 6, fit: 'stretch' });
  const nhwc = await toTensor(image, {
    width: 8,
    height: 6,
    fit: 'stretch',
    layout: 'nhwc',
  });
  assertEqual(nhwc[0 * 3 + 1], nchw[48 + 0], 'same values, other layout');
  const nearest = await toTensor(image, {
    width: 8,
    height: 6,
    filter: 'nearest',
  });
  assertEqual(nearest.length, 144, 'nearest');
});

test('tools: a face aligned by warp feeds a tensor, sharpness, and both detectors', async () => {
  const image = await load('face.jpg');
  const face = (await detectFaces(image))[0];
  const box = face.boundingBox;
  // Vision landmark regions are box-relative with a bottom-left origin.
  const point = (region) => {
    const pts = face.landmarks[region];
    const x = pts.reduce((s, p) => s + p.x, 0) / pts.length;
    const y = pts.reduce((s, p) => s + p.y, 0) / pts.length;
    return [
      (box.x + x * box.width) * 400,
      (1 - (box.y + y * box.height)) * 600,
    ];
  };
  const lips = face.landmarks.outerLips;
  const corner = (p) => [
    (box.x + p.x * box.width) * 400,
    (1 - (box.y + p.y * box.height)) * 600,
  ];
  const src = [
    point('leftEye'),
    point('rightEye'),
    point('nose'),
    corner(lips[0]),
    corner(lips[Math.floor(lips.length / 2)]),
  ];
  const matrix = similarityTransform(src, FACE_TARGETS);
  assert(matrix, 'a transform');
  const crop = await warp(image, matrix, 112, 112);
  assertEqual(imageSize(crop), { width: 112, height: 112 }, 'crop size');
  const tensor = await toTensor(crop, {
    width: 112,
    height: 112,
    fit: 'stretch',
    filter: 'nearest',
    mean: [0.5, 0.5, 0.5],
    std: [0.5, 0.5, 0.5],
  });
  assertEqual(tensor.length, 3 * 112 * 112, 'face tensor');
  assert(
    tensor.every((v) => v >= -1 && v <= 1),
    'in [-1, 1]'
  );
  assert((await sharpness(crop)) > 0, 'sharpness');
  // The same alignment with a margin is a face to both detectors (Android's
  // ML Kit finds none in a crop as tight as the 112 one; iOS's does).
  const margin = 28;
  const wide = await warp(
    image,
    similarityTransform(
      src,
      FACE_TARGETS.map(([x, y]) => [x + margin, y + margin])
    ),
    112 + 2 * margin,
    112 + 2 * margin
  );
  assertEqual(
    (await MlKit.detectFaces(wide)).length,
    1,
    'ML Kit finds the aligned face'
  );
  if (IOS)
    assertEqual(
      (await Apple.detectFaces(wide)).length,
      1,
      'Apple finds the aligned face'
    );
});

test('tools: histogram sums to one; sharpness is a number', async () => {
  const image = await load('landscape.jpg');
  const h = await histogram(image, 64);
  assertEqual(h.length, 64, 'bins');
  assert(Math.abs(h.reduce((a, b) => a + b, 0) - 1) < 1e-4, 'sums to 1');
  assert(Number.isFinite(await sharpness(image)), 'sharpness');
});

test('tools: bad options are refused by the native side, not crashed on', async () => {
  const image = await load('face.jpg');
  await assertRejects(
    () => toTensor(image, { width: 4, height: 4, std: [1, 0, 1] }),
    /ERR_ARGUMENT/,
    'std 0'
  );
  await assertRejects(
    () => toTensor(image, { width: 4, height: 4, mean: [0, 0] }),
    /ERR_ARGUMENT/,
    'two means'
  );
  await assertRejects(
    () => toTensor(image, { width: 4, height: 4, fit: 'fill' }),
    /ERR_ARGUMENT/,
    'unknown fit'
  );
  await assertRejects(
    () => warp(image, [1, 0, 0], 4, 4),
    /ERR_ARGUMENT/,
    'short matrix'
  );
  await assertRejects(
    () => warp(image, [1, 0, 0, 0, 1, 0], 0, 4),
    /ERR_ARGUMENT/,
    'zero width'
  );
  await assertRejects(
    () => toTensor(image, { width: 0, height: 4 }),
    /positive/,
    'checked in JS'
  );
  await assertRejects(() => histogram(image, 0), /bins/, 'checked in JS');
});

test('tools: a path or a released handle is refused, not crashed on', async () => {
  await assertRejects(() => sharpness('/tmp/face.jpg'), /./, 'string');
  const image = await load('face.jpg');
  image.release();
  await assertRejects(() => sharpness(image), /./, 'released handle');
});

test('one handle, every module at once', async () => {
  const image = await load('face.jpg');
  const [faces, mlKit, tensor] = await Promise.all([
    detectFaces(image),
    MlKit.detectFaces(image),
    toTensor(image, { width: 32, height: 32 }),
  ]);
  assertEqual(
    [faces.length, mlKit.length, tensor.length],
    [1, 1, 3072],
    'each module read it'
  );
});
