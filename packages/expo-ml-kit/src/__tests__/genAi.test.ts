import { beforeEach, describe, expect, it, vi } from 'vitest';

import {
  describeImage,
  downloadSummarizer,
  generateContent,
  getGenerativeModelStatus,
  getProofreaderStatus,
  getRewriterStatus,
  proofread,
  rewrite,
  summarize,
  type ImageRef,
} from '../index';
import {
  describeAndroidOnly,
  linkEveryFeature,
  type NativeMock,
} from './androidOnly';

const native = vi.hoisted(() => ({ module: null as unknown }));
vi.mock('expo', () => ({
  requireOptionalNativeModule: () =>
    new Proxy(
      {},
      {
        get: (_, key: string) =>
          (native.module as Record<string, unknown> | null)?.[key],
      }
    ),
}));

const photo = { width: 4, height: 3 } as unknown as ImageRef;
let mod: NativeMock;
beforeEach(() => {
  mod = linkEveryFeature(native);
});

describeAndroidOnly(
  {
    genAiSummarization: () => summarize('text'),
    genAiProofreading: () => proofread('text'),
    genAiRewriting: () => rewrite('text'),
    genAiImageDescription: () => describeImage(photo),
    genAiPrompt: () => generateContent('hi'),
  },
  () => mod
);

describe('GenAI options', () => {
  it('fill in each text feature’s defaults', async () => {
    await summarize('long text', { outputType: 'threeBullets' });
    expect(mod.summarize).toHaveBeenCalledWith('long text', {
      inputType: 'article',
      outputType: 'threeBullets',
      language: 'en',
      autoTruncate: false,
    });
    await downloadSummarizer({ language: 'ko' });
    expect(mod.downloadSummarizer).toHaveBeenCalledWith(
      expect.objectContaining({ language: 'ko' })
    );
    await getProofreaderStatus({ inputType: 'voice' });
    expect(mod.getProofreaderStatus).toHaveBeenCalledWith({
      inputType: 'voice',
      language: 'en',
    });
    await rewrite('hey', { style: 'professional', language: 'de' });
    expect(mod.rewrite).toHaveBeenCalledWith('hey', {
      style: 'professional',
      language: 'de',
    });
    await getRewriterStatus();
    expect(mod.getRewriterStatus).toHaveBeenCalledWith({
      style: 'rephrase',
      language: 'en',
    });
  });

  it('hand the prompt’s image apart from its generation options', async () => {
    await generateContent('what is this?', { image: photo, topK: 3 });
    expect(mod.generateContent).toHaveBeenCalledWith('what is this?', photo, {
      topK: 3,
    });
    await generateContent('hi');
    expect(mod.generateContent).toHaveBeenLastCalledWith('hi', null, {});
  });
});

describe('GenAI results', () => {
  it('pass the device’s status through', async () => {
    mod.getGenerativeModelStatus = vi.fn().mockResolvedValue('unavailable');
    await expect(getGenerativeModelStatus()).resolves.toBe('unavailable');
  });

  it('pass a refusal through with its code', async () => {
    const refusal = Object.assign(new Error('no AICore'), {
      code: 'ERR_ML_KIT_GENAI_UNAVAILABLE',
    });
    mod.summarize = vi.fn().mockRejectedValue(refusal);
    await expect(summarize('text')).rejects.toBe(refusal);
  });
});
