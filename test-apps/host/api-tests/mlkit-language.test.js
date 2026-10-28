// expo-ml-kit's text calls through the bridge: entities, language ID, Smart
// Reply, Translation and Digital Ink, with their models' download, list and
// delete calls. Downloads must land: a test that cannot fetch its model
// fails (the runner's timeout), it never skips.
import * as MlKit from 'expo-ml-kit';

import ink from '../../../fixtures/ink-cat.json';
import { assert, assertEqual, assertRejects, test } from './runner';

const TEXT = [
  'Call +1 650-253-0000 or write to info@example.com.',
  'It costs $12.75 on flight LX 38.',
].join('\n');

/** `extractEntities` answers null while the model downloads; ask again. */
async function entitiesOnceReady(text, options) {
  for (let i = 0; i < 50; i++) {
    const found = await MlKit.extractEntities(text, options);
    if (found) return found;
    await new Promise((resolve) => setTimeout(resolve, 2000));
  }
  throw new Error('the entity model never downloaded');
}

test('ml kit: extractEntities finds, parses and filters', async () => {
  await MlKit.downloadEntityModel('en', { wifiOnly: false });
  const entities = await MlKit.extractEntities(TEXT);
  const byType = Object.fromEntries(entities.map((e) => [e.type, e]));
  for (const type of ['phone', 'email', 'money', 'flightNumber']) {
    assert(byType[type], `finds ${type}`);
  }
  for (const e of entities) {
    assertEqual(TEXT.slice(e.start, e.end), e.value, `${e.type} span`);
  }
  assertEqual(byType.money.money.integerPart, 12, 'money');
  assertEqual(byType.flightNumber.flightNumber.airlineCode, 'LX', 'airline');
  const only = await MlKit.extractEntities(TEXT, { types: ['email'] });
  assertEqual(
    only.map((e) => e.type),
    ['email'],
    'types filter'
  );
  assertEqual(await MlKit.extractEntities('  '), [], 'blank text');
});

test('ml kit: extractEntities resolves dates in the time zone and locale', async () => {
  const at = (text, locale) =>
    MlKit.extractEntities(text, {
      types: ['dateTime'],
      referenceTime: Date.UTC(2026, 9, 28, 12),
      timeZone: 'UTC',
      locale,
    });
  const [tomorrow] = await at('Meet me tomorrow at 5pm');
  assertEqual(
    tomorrow.dateTime.timestamp,
    Date.UTC(2026, 9, 29, 17),
    'tomorrow at 5pm UTC'
  );
  const [uk] = await at('Due on 1/2/2027', 'en-GB');
  const [us] = await at('Due on 1/2/2027', 'en-US');
  assertEqual(uk.dateTime.timestamp, Date.UTC(2027, 1, 1), 'en-GB: 1 Feb');
  assertEqual(us.dateTime.timestamp, Date.UTC(2027, 0, 2), 'en-US: 2 Jan');
});

test('ml kit: entity models download, list and delete', async () => {
  await MlKit.downloadEntityModel('de', { wifiOnly: false });
  assert(
    (await MlKit.downloadedEntityModels()).includes('de'),
    'German listed'
  );
  const found = await entitiesOnceReady('Rufen Sie +49 30 1234567 an', {
    language: 'de',
  });
  assert(
    found.some((e) => e.type === 'phone'),
    'German phone'
  );
  await MlKit.deleteEntityModel('de');
  assert(!(await MlKit.downloadedEntityModels()).includes('de'), 'German gone');
});

test('ml kit: identifyLanguage and the possible languages', async () => {
  assertEqual(
    await MlKit.identifyLanguage('Wo ist der Bahnhof, bitte?'),
    'de',
    'German'
  );
  assertEqual(await MlKit.identifyLanguage(''), 'und', 'nothing to tell');
  const possible = await MlKit.identifyPossibleLanguages(
    'Ceci est une phrase en français.'
  );
  assertEqual(possible[0].language, 'fr', 'French first');
  const sure = await MlKit.identifyPossibleLanguages('Hola', {
    confidenceThreshold: 0.99,
  });
  assert(
    sure.every((l) => l.confidence >= 0.99 || l.language === 'und'),
    'threshold'
  );
});

test('ml kit: suggestReplies answers English, not German', async () => {
  const now = Date.now();
  const english = await MlKit.suggestReplies([
    { text: 'Are you coming to dinner tonight?', timestamp: now, userId: 'a' },
  ]);
  assertEqual(english.status, 'success', 'English');
  assert(english.suggestions.length > 0, 'suggestions');
  const german = await MlKit.suggestReplies([
    { text: 'Kommst du heute Abend zum Essen?', timestamp: now, userId: 'a' },
  ]);
  assertEqual(
    german,
    { status: 'notSupportedLanguage', suggestions: [] },
    'de'
  );
});

test('ml kit: translate, its models listed, deleted and missing', async () => {
  await MlKit.downloadTranslationModel('de', { wifiOnly: false });
  assert(
    (await MlKit.downloadedTranslationModels()).includes('de'),
    'German listed'
  );
  const german = await MlKit.translate('Good morning, my friend', {
    from: 'en',
    to: 'de',
  });
  assert(/guten morgen/i.test(german), german);
  await MlKit.deleteTranslationModel('is');
  assert(
    !(await MlKit.downloadedTranslationModels()).includes('is'),
    'Icelandic gone'
  );
  await assertRejects(
    () => MlKit.translate('Hello', { from: 'en', to: 'is' }),
    /ERR_ML_KIT_MODEL/,
    'missing model'
  );
});

test('ml kit: recognizeInk reads the word, then its model is gone', async () => {
  await MlKit.downloadInkModel('en-US', { wifiOnly: false });
  assertEqual(await MlKit.isInkModelDownloaded('en-US'), true, 'downloaded');
  const read = await MlKit.recognizeInk(ink.strokes, {
    language: 'en-US',
    writingArea: ink.writingArea,
    preContext: 'the ',
  });
  assert(
    read.slice(0, 3).some((c) => c.text.toLowerCase() === 'cat'),
    `cat in ${read.map((c) => c.text)}`
  );
  await MlKit.deleteInkModel('en-US');
  assertEqual(await MlKit.isInkModelDownloaded('en-US'), false, 'deleted');
  await assertRejects(
    () => MlKit.recognizeInk(ink.strokes, { language: 'en-US' }),
    /ERR_ML_KIT_MODEL/,
    'missing model'
  );
  await assertRejects(
    () => MlKit.isInkModelDownloaded('not-a-language-xx'),
    /./,
    'unknown model'
  );
});

test('ml kit: recognizeInk runs the shapes and emoji models', async () => {
  for (const language of ['zxx-Zsym-x-shapes', 'zxx-Zsye-x-emoji']) {
    await MlKit.downloadInkModel(language, { wifiOnly: false });
    const read = await MlKit.recognizeInk(ink.strokes, { language });
    assert(Array.isArray(read), `${language} answers`);
    assert(
      read.every((c) => typeof c.text === 'string'),
      `${language} candidates`
    );
  }
});
