import { beforeEach, describe, expect, it, vi } from 'vitest';

import { detectFaceMesh, type ImageRef } from '../index';
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
    faceMesh: () => detectFaceMesh(photo),
  },
  () => mod
);

describe('face mesh', () => {
  it('passes its flag, defaulting off', async () => {
    await detectFaceMesh(photo);
    await detectFaceMesh(photo, { boundingBoxOnly: true });
    expect(mod.detectFaceMesh?.mock.calls).toEqual([
      [photo, false],
      [photo, true],
    ]);
  });
});
