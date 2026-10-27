import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

import { ML_KIT_ARTIFACTS, ML_KIT_BARCODE_FORMATS } from '../artifacts';
import { OTHER_TEXT_SCRIPTS } from '../textQuality';

/**
 * A result's version stamp must name the model that produced it, on both
 * platforms: every ML Kit release the module links is the one
 * `ML_KIT_ARTIFACTS` pins, and each is BUNDLED — never a Play services
 * (`play-services-mlkit-*`) model, which updates under the app.
 */
const read = (path: string) =>
  readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');
const gradle = read('android/build.gradle');
const podspec = read('ios/ExpoMlKit.podspec');

const gradleArtifacts = [...gradle.matchAll(/implementation '([^']+)'/g)].map(
  (m) => m[1] ?? ''
);
const pods = [
  ...podspec.matchAll(/s\.dependency '(MLKit\w+)', '([^']+)'/g),
].map((m) => `${m[1] ?? ''} ${m[2] ?? ''}`);
const pinned: readonly {
  android: readonly string[];
  ios: readonly string[];
}[] = Object.values(ML_KIT_ARTIFACTS);

describe('ML Kit artifacts', () => {
  it('links exactly the pinned Android artifacts, bundled ones only', () => {
    expect(gradleArtifacts.sort()).toEqual(
      pinned.flatMap((pair) => pair.android).sort()
    );
    for (const artifact of gradleArtifacts) {
      expect(artifact).toMatch(/^com\.google\.mlkit:/);
    }
    expect(gradle).not.toMatch(/play-services-mlkit/);
  });

  it('links exactly the pinned iOS pods, bundled models only', () => {
    expect(pods.sort()).toEqual(pinned.flatMap((pair) => pair.ios).sort());
    // The bundled pods; Google's `GoogleMLKit` umbrella would float them.
    expect(podspec).not.toMatch(/GoogleMLKit/);
  });
});

/** Both platforms write one vocabulary, so one result shape covers both. */
describe('ML Kit wire names', () => {
  const kotlin = (file: string) =>
    read(`android/src/main/java/expo/modules/mlkit/${file}`);
  const swift = read('ios/MlKitNames.swift');
  const swiftTable = (name: string) => {
    const start = swift.indexOf(`static let ${name}`);
    const body = swift.slice(start, swift.indexOf(']\n', start));
    return [...body.matchAll(/"(\w+)"\)?,/g)].map((m) => m[1] ?? '');
  };
  const kotlinTable = (source: string, prefix: string) =>
    [...source.matchAll(new RegExp(`${prefix}\\w+ to "(\\w+)"`, 'g'))].map(
      (m) => m[1] ?? ''
    );

  it('names barcode formats alike, QR among them', () => {
    const android = kotlinTable(kotlin('BarcodeAnalyzer.kt'), 'FORMAT_');
    expect(new Set(android)).toEqual(ML_KIT_BARCODE_FORMATS);
    expect(new Set(swiftTable('barcodeFormats'))).toEqual(
      ML_KIT_BARCODE_FORMATS
    );
    expect(android.filter((name) => /qr/i.test(name))).toEqual(['QR_CODE']);
  });

  it('names the 33 pose landmarks alike', () => {
    const android = kotlinTable(kotlin('PoseAnalyzer.kt'), 'PoseLandmark\\.');
    expect(android).toHaveLength(33);
    expect(new Set(swiftTable('poseLandmarks'))).toEqual(new Set(android));
  });

  it('runs the same text recognizers, the scripts TS asks for', () => {
    const android = [
      ...kotlin('TextAnalyzer.kt').matchAll(/"(\w+)" to lazy/g),
    ].map((m) => m[1] ?? '');
    const ios = [
      ...read('ios/MlKitAnalyzer.swift').matchAll(/case "(\w+)": return/g),
    ].map((m) => m[1] ?? '');
    expect(android).toEqual(['latin', ...OTHER_TEXT_SCRIPTS]);
    expect(ios).toEqual(android);
  });

  it('maps faces onto the same Vision regions', () => {
    const outKeys = (source: string) =>
      new Set([...source.matchAll(/out\["(\w+)"\] =/g)].map((m) => m[1] ?? ''));
    const android = outKeys(kotlin('FaceMapping.kt'));
    const regions = [
      'leftEye',
      'rightEye',
      'nose',
      'outerLips',
      'faceContour',
      'noseCrest',
      'innerLips',
      'leftEyebrow',
      'rightEyebrow',
    ];
    expect(android).toEqual(
      new Set(['roll', 'yaw', 'pitch', 'landmarks', ...regions])
    );
    expect(outKeys(read('ios/FaceAnalyzer.swift'))).toEqual(android);
  });

  it('keeps the same entity types, without cards or IBANs', () => {
    const android = kotlinTable(kotlin('EntityAnalyzer.kt'), 'Entity\\.TYPE_');
    expect(new Set(swiftTable('entityTypes'))).toEqual(new Set(android));
    expect(android).not.toContain('paymentCard');
    expect(android).not.toContain('iban');
  });
});
