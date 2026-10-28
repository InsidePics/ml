import { readdirSync, readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

import {
  DEFAULT_ML_KIT_FEATURES,
  ML_KIT_ARTIFACTS,
  ML_KIT_BARCODE_FORMATS,
} from '../artifacts';
import { OTHER_TEXT_SCRIPTS } from '../textQuality';

/**
 * `features.json` is the one table of what each feature links; these pin the
 * code to it: both builds read it rather than list artifacts of their own,
 * and every feature's code is wired on each platform it names artifacts for.
 */
const read = (path: string) =>
  readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');
const gradle = read('android/build.gradle');
const podspec = read('ios/ExpoMlKit.podspec');
const swiftFeatures = read('ios/MlKitFeatures.swift');
const pinned = Object.entries(ML_KIT_ARTIFACTS);

describe('ML Kit artifacts', () => {
  it('are linked from features.json alone, never listed by a build', () => {
    expect(gradle).toContain('src/features.json');
    expect(gradle).not.toMatch(
      /implementation 'com\.google\.(mlkit|android\.gms)/
    );
    expect(podspec).toContain("'src', 'features.json'");
    expect(podspec).not.toMatch(/s\.dependency 'MLKit/);
  });

  it('are pinned releases of Google ML Kit, never an umbrella that floats', () => {
    for (const [, { android, ios }] of pinned) {
      for (const artifact of android) {
        expect(artifact).toMatch(
          /^com\.google\.(mlkit|android\.gms):[\w-]+:\d[\w.-]*$/
        );
      }
      for (const pod of ios) expect(pod).toMatch(/^MLKit\w+ \d[\w.-]*$/);
    }
    expect(JSON.stringify(ML_KIT_ARTIFACTS)).not.toMatch(/GoogleMLKit/);
  });

  it('defaults to the features the module has always linked', () => {
    expect(DEFAULT_ML_KIT_FEATURES).toEqual([
      'text',
      'labels',
      'barcodes',
      'poses',
      'objects',
      'entities',
      'faces',
    ]);
  });

  it.each(pinned)('wires %s on each platform it links', (feature, pair) => {
    const kotlinName = `${feature[0]?.toUpperCase()}${feature.slice(1)}Feature`;
    const dir = `android/src/features/${feature}/java/expo/modules/mlkit`;
    const kotlin = readdirSync(new URL(`../../${dir}`, import.meta.url))
      .map((file) => read(`${dir}/${file}`))
      .join('\n');
    expect(kotlin).toContain(`object ${kotlinName} : MlKitFeature`);
    expect(kotlin).toContain(`override val name = "${feature}"`);
    const firstPod = pair.ios[0]?.split(' ')[0];
    if (firstPod) {
      expect(swiftFeatures).toContain(
        `#if canImport(${firstPod})\n    names.append("${feature}")`
      );
    } else {
      expect(swiftFeatures).not.toContain(`names.append("${feature}")`);
    }
  });
});

/** Both platforms write one vocabulary, so one result shape covers both. */
describe('ML Kit wire names', () => {
  const kotlin = (feature: string, file: string) =>
    read(`android/src/features/${feature}/java/expo/modules/mlkit/${file}`);
  const swiftTable = (file: string, name: string) => {
    const swift = read(`ios/${file}`);
    const start = swift.indexOf(`static let ${name}`);
    const body = swift.slice(start, swift.indexOf(']\n', start));
    return [...body.matchAll(/"(\w+)"\)?,/g)].map((m) => m[1] ?? '');
  };
  const kotlinTable = (source: string, prefix: string) =>
    [...source.matchAll(new RegExp(`${prefix}\\w+ to "(\\w+)"`, 'g'))].map(
      (m) => m[1] ?? ''
    );

  it('names barcode formats alike, QR among them', () => {
    const android = kotlinTable(
      kotlin('barcodes', 'BarcodeAnalyzer.kt'),
      'FORMAT_'
    );
    expect(new Set(android)).toEqual(ML_KIT_BARCODE_FORMATS);
    expect(
      new Set(swiftTable('BarcodeAnalyzer.swift', 'barcodeFormats'))
    ).toEqual(ML_KIT_BARCODE_FORMATS);
    expect(android.filter((name) => /qr/i.test(name))).toEqual(['QR_CODE']);
  });

  it('names the 33 pose landmarks alike', () => {
    const android = kotlinTable(
      kotlin('poses', 'PoseAnalyzer.kt'),
      'PoseLandmark\\.'
    );
    expect(android).toHaveLength(33);
    expect(new Set(swiftTable('PoseAnalyzer.swift', 'poseLandmarks'))).toEqual(
      new Set(android)
    );
  });

  it('runs the same text recognizers, the scripts TS asks for', () => {
    const android = [
      ...kotlin('text', 'TextAnalyzer.kt').matchAll(/"(\w+)" to lazy/g),
    ].map((m) => m[1] ?? '');
    const ios = [
      ...read('ios/TextAnalyzer.swift').matchAll(/case "(\w+)": return/g),
    ].map((m) => m[1] ?? '');
    expect(android).toEqual(['latin', ...OTHER_TEXT_SCRIPTS]);
    expect(ios).toEqual(android);
  });

  it('maps faces onto the same Vision regions', () => {
    const outKeys = (source: string) =>
      new Set([...source.matchAll(/out\["(\w+)"\] =/g)].map((m) => m[1] ?? ''));
    const android = outKeys(kotlin('faces', 'FaceMapping.kt'));
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
    const android = kotlinTable(
      kotlin('entities', 'EntityAnalyzer.kt'),
      'Entity\\.TYPE_'
    );
    expect(new Set(swiftTable('EntityAnalyzer.swift', 'entityTypes'))).toEqual(
      new Set(android)
    );
    expect(android).not.toContain('paymentCard');
    expect(android).not.toContain('iban');
  });
});
