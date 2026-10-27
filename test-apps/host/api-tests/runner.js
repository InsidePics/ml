// A minimal test runner for the packages' JS API on a device: the calls go
// through Expo's real JS-to-native bridge, which XCTest never touches.

const tests = [];

/** Register a test; `run` may be async and throws to fail. */
export function test(name, run) {
  tests.push({ name, run });
}

export class AssertionError extends Error {}

export function assert(condition, message) {
  if (!condition) throw new AssertionError(message);
}

/** JSON with object keys sorted: native dictionaries have no key order. */
function canonical(value) {
  return JSON.stringify(value, (_, v) =>
    v && typeof v === 'object' && !Array.isArray(v)
      ? Object.fromEntries(
          Object.keys(v)
            .sort()
            .map((k) => [k, v[k]])
        )
      : v
  );
}

export function assertEqual(actual, expected, message) {
  const a = canonical(actual);
  const e = canonical(expected);
  if (a !== e) throw new AssertionError(`${message}: got ${a}, expected ${e}`);
}

/** `run` must reject (or throw); returns the error. `pattern` matches its
 *  code or message. */
export async function assertRejects(run, pattern, message) {
  try {
    await run();
  } catch (error) {
    const text = `${error?.code ?? ''} ${error?.message ?? error}`;
    if (pattern && !pattern.test(text)) {
      throw new AssertionError(
        `${message}: rejected with "${text}", not ${pattern}`
      );
    }
    return error;
  }
  throw new AssertionError(`${message}: did not reject`);
}

/** A test that has not settled by then fails: a call that never answers
 *  (a promise the native side drops) is a failure, not a stuck run. */
const TIMEOUT_MS = 120_000;

function withTimeout(run) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(
      () =>
        reject(new AssertionError(`no answer within ${TIMEOUT_MS / 1000} s`)),
      TIMEOUT_MS
    );
  });
  return Promise.race([Promise.resolve().then(run), timeout]).finally(() =>
    clearTimeout(timer)
  );
}

/** Every registered test, one at a time; a failure never stops the rest.
 *  `onProgress` gets the results so far after each test. */
export async function runAll(onProgress = () => {}) {
  const results = [];
  for (const { name, run } of tests) {
    const started = Date.now();
    onProgress(results, name);
    try {
      await withTimeout(run);
      results.push({ name, passed: true, ms: Date.now() - started });
    } catch (error) {
      results.push({
        name,
        passed: false,
        ms: Date.now() - started,
        error: `${error?.code ? `${error.code}: ` : ''}${error?.message ?? error}`,
      });
    }
  }
  return results;
}
