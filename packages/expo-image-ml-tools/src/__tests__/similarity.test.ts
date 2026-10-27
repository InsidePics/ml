import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

import { similarityTransform, type Point } from '../similarity';

/** The recorded reference: each face's matrix, from the app's own code. */
const expected = JSON.parse(
  readFileSync(
    new URL('../../../../fixtures/expected/model-inputs.json', import.meta.url),
    'utf8'
  )
) as {
  faces: Record<string, Point[]>;
  faceTargets112: Point[];
  fixtures: Record<
    string,
    {
      width: number;
      height: number;
      faces: Record<string, { matrix: number[] } | null>;
    }
  >;
  pattern: { width: number; height: number; matrix: number[] };
};

describe('similarityTransform', () => {
  it('is the recorded matrix, bit for bit, for every fixture face', () => {
    let checked = 0;
    for (const [name, fixture] of Object.entries(expected.fixtures)) {
      for (const [key, face] of Object.entries(fixture.faces)) {
        if (!face) continue;
        const lifted = expected.faces[key]!.map(
          ([x, y]) => [x * fixture.width, y * fixture.height] as const
        );
        expect(
          similarityTransform(lifted, expected.faceTargets112),
          `${name} ${key}`
        ).toEqual(face.matrix);
        checked++;
      }
    }
    expect(checked).toBeGreaterThan(40);
  });

  it('is the recorded matrix for the pattern', () => {
    const landmarks: Point[] = [
      [0.3, 0.35],
      [0.62, 0.33],
      [0.47, 0.5],
      [0.35, 0.68],
      [0.6, 0.66],
    ];
    const small: Point[] = [
      [7, 9],
      [17, 9],
      [12, 14],
      [8, 19],
      [16, 19],
    ];
    const { width, height, matrix } = expected.pattern;
    const lifted = landmarks.map(([x, y]) => [x * width, y * height] as const);
    expect(similarityTransform(lifted, small)).toEqual(matrix);
  });

  it('maps the source points onto the targets when they are similar', () => {
    const src: Point[] = [
      [10, 10],
      [30, 10],
      [20, 30],
    ];
    // Scaled by 2, rotated 90°, moved by (5, 7).
    const dst = src.map(([x, y]) => [-2 * y + 5, 2 * x + 7] as const);
    const m = similarityTransform(src, dst)!;
    for (let i = 0; i < src.length; i++) {
      const [x, y] = src[i]!;
      expect(m[0] * x + m[1] * y + m[2]).toBeCloseTo(dst[i]![0], 9);
      expect(m[3] * x + m[4] * y + m[5]).toBeCloseTo(dst[i]![1], 9);
    }
  });

  it('declines fewer than two points, or points that coincide', () => {
    expect(similarityTransform([[1, 1]], [[2, 2]])).toBeNull();
    expect(
      similarityTransform(
        [
          [3, 3],
          [3, 3],
        ],
        [
          [0, 0],
          [1, 1],
        ]
      )
    ).toBeNull();
  });
});
