import { beforeEach, describe, expect, it, vi } from 'vitest';

import {
  detectObjects,
  detectPose,
  downloadEntityModel,
  extractEntities,
  identifyLanguage,
  labelImage,
  maskConfidence,
  maskCoverage,
  ML_KIT_FEATURES,
  recognizeText,
  segmentSelfie,
  suggestReplies,
  type ImageRef,
} from '../index';

// The binding `requireOptionalNativeModule` returns, read through on every
// access so each test can swap the module under it.
const native = vi.hoisted(() => ({
  module: null as Record<string, unknown> | null,
}));
vi.mock('expo', () => ({
  requireOptionalNativeModule: () =>
    new Proxy({}, { get: (_, key: string) => native.module?.[key] }),
}));

const photo = {} as ImageRef;
const fn = (value: unknown = []) => vi.fn().mockResolvedValue(value);
let mod: Record<string, ReturnType<typeof vi.fn>>;
let features: string[];

beforeEach(() => {
  mod = {
    labelImage: fn(),
    labelImageCustom: fn(),
    detectObjects: fn(),
    detectObjectsCustom: fn(),
    detectPose: fn(),
    detectPoseAccurate: fn(),
    recognizeText: fn([{ text: 'Hi', blocks: [] }]),
    extractEntities: fn(),
    downloadEntityModel: fn(null),
    identifyLanguage: fn('fr'),
    suggestReplies: fn({ status: 'success', suggestions: ['Yes'] }),
    segmentSelfie: fn({ width: 1, height: 1, data: new Uint8Array([255]) }),
  };
  features = [...ML_KIT_FEATURES];
  native.module = {
    ...mod,
    isAvailable: true,
    get features() {
      return features;
    },
  };
});
const unlink = (feature: string) => {
  features = features.filter((name) => name !== feature);
};

describe('the scene calls', () => {
  it('run the base models, or the custom and accurate ones when asked', async () => {
    await labelImage(photo, { confidenceThreshold: 0.2 });
    expect(mod.labelImage).toHaveBeenCalledWith(photo, {
      confidenceThreshold: 0.2,
    });
    const model = { path: '/m.tflite' };
    await labelImage(photo, { model });
    expect(mod.labelImageCustom).toHaveBeenCalledWith(photo, { model });
    await detectObjects(photo, { model });
    expect(mod.detectObjectsCustom).toHaveBeenCalled();
    await detectPose(photo, { model: 'accurate' });
    expect(mod.detectPoseAccurate).toHaveBeenCalledWith(photo);
    expect(mod.detectPose).not.toHaveBeenCalled();
  });

  it('need the variant feature linked, not only the base one', async () => {
    unlink('customLabels');
    await expect(
      labelImage(photo, { model: { path: '/m.tflite' } })
    ).rejects.toMatchObject({ code: 'ERR_ML_KIT_FEATURE' });
    await expect(labelImage(photo)).resolves.toEqual([]);
  });
});

describe('the text calls', () => {
  it('read with one script, Latin by default', async () => {
    await expect(recognizeText(photo)).resolves.toEqual({
      text: 'Hi',
      blocks: [],
    });
    expect(mod.recognizeText).toHaveBeenCalledWith(photo, ['latin']);
  });

  it('extract entities in English unless told otherwise', async () => {
    await extractEntities('Call me', { types: ['phone'] });
    expect(mod.extractEntities).toHaveBeenCalledWith('Call me', {
      types: ['phone'],
      language: 'en',
    });
    await downloadEntityModel('de');
    expect(mod.downloadEntityModel).toHaveBeenCalledWith('de', true);
  });

  it('pass language and reply calls through', async () => {
    await expect(identifyLanguage('Bonjour')).resolves.toBe('fr');
    const conversation = [{ text: 'Hi', timestamp: 1, userId: 'a' }];
    await expect(suggestReplies(conversation)).resolves.toMatchObject({
      status: 'success',
    });
    expect(mod.suggestReplies).toHaveBeenCalledWith(conversation);
  });
});

describe('masks', () => {
  it('read confidences and coverage from the bytes', async () => {
    const mask = await segmentSelfie(photo);
    expect(maskConfidence(mask, 0, 0)).toBe(1);
    const half = { width: 2, height: 1, data: new Uint8Array([0, 200]) };
    expect(maskCoverage(half)).toBe(0.5);
    expect(maskCoverage(half, 0.9)).toBe(0);
    expect(maskCoverage({ width: 0, height: 0, data: new Uint8Array() })).toBe(
      0
    );
  });
});
