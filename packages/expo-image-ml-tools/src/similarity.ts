/** A point in pixels, `[x, y]`. */
export type Point = readonly [number, number];

/** An affine transform `[a, b, tx, c, d, ty]`: `x' = a x + b y + tx`,
 *  `y' = c x + d y + ty`. */
export type AffineMatrix = readonly [
  number,
  number,
  number,
  number,
  number,
  number,
];

/**
 * The least-squares similarity transform (rotation, uniform scale,
 * translation) taking `src` onto `dst`, as `warp` takes it: e.g. a face's
 * landmarks in the image onto a model's template. Null with fewer than two
 * points or when every `src` point coincides.
 */
export function similarityTransform(
  src: readonly Point[],
  dst: readonly Point[]
): AffineMatrix | null {
  const n = Math.min(src.length, dst.length);
  if (n < 2) return null;
  let srcCx = 0;
  let srcCy = 0;
  let dstCx = 0;
  let dstCy = 0;
  for (let i = 0; i < n; i++) {
    srcCx += src[i]![0];
    srcCy += src[i]![1];
    dstCx += dst[i]![0];
    dstCy += dst[i]![1];
  }
  srcCx /= n;
  srcCy /= n;
  dstCx /= n;
  dstCy /= n;
  let num1 = 0;
  let num2 = 0;
  let denom = 0;
  for (let i = 0; i < n; i++) {
    const sx = src[i]![0] - srcCx;
    const sy = src[i]![1] - srcCy;
    const dx = dst[i]![0] - dstCx;
    const dy = dst[i]![1] - dstCy;
    num1 += dx * sx + dy * sy;
    num2 += dy * sx - dx * sy;
    denom += sx * sx + sy * sy;
  }
  if (denom === 0) return null;
  const a = num1 / denom;
  const b = num2 / denom;
  const tx = dstCx - a * srcCx + b * srcCy;
  const ty = dstCy - a * srcCy - b * srcCx;
  return [a, -b, tx, b, a, ty];
}
