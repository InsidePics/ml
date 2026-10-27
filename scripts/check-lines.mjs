#!/usr/bin/env node
// 300-line hard limit (250 soft) for every tracked source file, tests
// included, in every language the repo holds. Exits non-zero over 300.
import { execSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const SOFT = 250;
const HARD = 300;
const EXTS = /\.(ts|tsx|mts|js|mjs|cjs|swift|kt|kts|sh|rb|gradle)$/;

const files = execSync('git ls-files', { encoding: 'utf8' })
  .split('\n')
  .filter((f) => EXTS.test(f));

let failed = false;
for (const file of files) {
  const lines = readFileSync(file, 'utf8').split('\n').length;
  if (lines > HARD) {
    console.error(`${file}: ${lines} lines (hard limit ${HARD})`);
    failed = true;
  } else if (lines > SOFT) {
    console.warn(`${file}: ${lines} lines (soft limit ${SOFT})`);
  }
}
process.exit(failed ? 1 : 0);
