// expo-ml-kit's GenAI calls (Gemini Nano through AICore, Android only)
// through the bridge. Each checks what this device can reach: with the model
// available it runs it and checks the answer; without, the call is refused
// at once with ERR_ML_KIT_GENAI_UNAVAILABLE. On iOS every one is refused as
// not linked. None is skipped.
import * as MlKit from 'expo-ml-kit';
import { Platform } from 'react-native';

import { load } from './images';
import { assert, assertRejects, test } from './runner';

const STATUSES = ['available', 'downloadable', 'downloading', 'unavailable'];
const TEXT =
  'The team met on Monday to plan the launch. They agreed to ship the app ' +
  'in March, after a beta in February, and to hire two more engineers.';

const nonEmpty = (value) =>
  assert(typeof value === 'string' && value.trim(), `empty: ${value}`);
const suggestions = (value) =>
  assert(value.length && value.every((s) => s.trim()), `none: ${value}`);

const FEATURES = [
  {
    name: 'summarization',
    status: MlKit.getSummarizerStatus,
    download: MlKit.downloadSummarizer,
    infer: () => MlKit.summarize(TEXT),
    check: nonEmpty,
  },
  {
    name: 'proofreading',
    status: MlKit.getProofreaderStatus,
    download: MlKit.downloadProofreader,
    infer: () => MlKit.proofread('Their going too the store tomorow.'),
    check: suggestions,
  },
  {
    name: 'rewriting',
    status: MlKit.getRewriterStatus,
    download: MlKit.downloadRewriter,
    infer: () => MlKit.rewrite(TEXT, { style: 'shorten' }),
    check: suggestions,
  },
  {
    name: 'image description',
    status: MlKit.getImageDescriberStatus,
    download: MlKit.downloadImageDescriber,
    infer: async () => MlKit.describeImage(await load('animal.jpg')),
    check: (text) => assert(/dog/i.test(text), text),
  },
  {
    name: 'prompt',
    status: MlKit.getGenerativeModelStatus,
    download: MlKit.downloadGenerativeModel,
    infer: () => MlKit.generateContent('Name one primary colour.'),
    check: (candidates) => nonEmpty(candidates[0]?.text),
  },
];

for (const feature of FEATURES) {
  test(`ml kit: genai ${feature.name} runs or is refused`, async () => {
    if (Platform.OS === 'ios') {
      await assertRejects(feature.status, /ERR_ML_KIT_FEATURE/, 'status');
      await assertRejects(feature.infer, /ERR_ML_KIT_FEATURE/, 'call');
      return;
    }
    const status = await feature.status();
    assert(STATUSES.includes(status), `status ${status}`);
    if (status === 'available') return feature.check(await feature.infer());
    await assertRejects(
      feature.infer,
      new RegExp(`ERR_ML_KIT_GENAI_UNAVAILABLE[\\s\\S]*${status}`),
      'refused while not available'
    );
    if (status === 'unavailable') {
      await assertRejects(
        feature.download,
        /ERR_ML_KIT_GENAI_UNAVAILABLE/,
        'nothing to download'
      );
    }
  });
}
