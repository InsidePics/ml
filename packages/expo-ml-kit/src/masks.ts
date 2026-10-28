/**
 * A segmentation mask: one byte per pixel, row-major from the top-left, the
 * model's confidence 0-1 scaled to 0-255 (`>= 128` is "in"). Its size is the
 * mask's own, which may differ from the image's: scale it to draw over it.
 */
export type MlKitMask = {
  width: number;
  height: number;
  data: Uint8Array;
};

/** The confidence (0-1) at mask pixel `x`, `y`. */
export function maskConfidence(mask: MlKitMask, x: number, y: number): number {
  return (mask.data[y * mask.width + x] ?? 0) / 255;
}

/** The share (0-1) of the mask's pixels at or above `threshold` (0-1). */
export function maskCoverage(mask: MlKitMask, threshold = 0.5): number {
  const cut = Math.round(threshold * 255);
  let inside = 0;
  for (const value of mask.data) if (value >= cut) inside++;
  return mask.data.length ? inside / mask.data.length : 0;
}
