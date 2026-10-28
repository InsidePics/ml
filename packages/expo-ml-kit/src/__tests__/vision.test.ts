import { beforeEach, describe, expect, it, vi } from 'vitest';

import {
  detectFaceMesh,
  downloadSubjectSegmentationModule,
  isSubjectSegmentationModuleReady,
  scanCode,
  scanDocument,
  segmentSubjects,
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
    faceMesh: () => detectFaceMesh(photo),
    subjectSegmentation: () => segmentSubjects(photo),
    codeScanner: () => scanCode(),
    documentScanner: () => scanDocument(),
  },
  () => mod
);

describe('face mesh and subject segmentation', () => {
  it('pass their flags, defaulting off', async () => {
    await detectFaceMesh(photo);
    await detectFaceMesh(photo, { boundingBoxOnly: true });
    expect(mod.detectFaceMesh?.mock.calls).toEqual([
      [photo, false],
      [photo, true],
    ]);
    await segmentSubjects(photo, { subjects: true });
    expect(mod.segmentSubjects).toHaveBeenCalledWith(photo, true);
  });

  it('reach the Play services module calls', async () => {
    mod.isSubjectSegmentationModuleReady = vi.fn().mockResolvedValue(false);
    await expect(isSubjectSegmentationModuleReady()).resolves.toBe(false);
    await downloadSubjectSegmentationModule();
    expect(mod.downloadSubjectSegmentationModule).toHaveBeenCalledOnce();
  });
});

describe('scanners', () => {
  it('fill in their defaults', async () => {
    await scanCode({ formats: ['QR_CODE'] });
    expect(mod.scanCode).toHaveBeenCalledWith({
      formats: ['QR_CODE'],
      allowManualInput: false,
      autoZoom: false,
    });
    await scanDocument({ formats: ['pdf'], pageLimit: 2 });
    expect(mod.scanDocument).toHaveBeenCalledWith({
      pageLimit: 2,
      formats: ['pdf'],
      mode: 'full',
      galleryImport: false,
    });
  });

  it('pass a cancelled scan through as null', async () => {
    mod.scanCode = vi.fn().mockResolvedValue(null);
    mod.scanDocument = vi.fn().mockResolvedValue(null);
    await expect(scanCode()).resolves.toBeNull();
    await expect(scanDocument()).resolves.toBeNull();
  });

  it('pass a scan through as native returns it', async () => {
    const scan = { pages: [{ uri: 'file:///p1.jpg' }], pdf: null };
    mod.scanDocument = vi.fn().mockResolvedValue(scan);
    await expect(scanDocument()).resolves.toBe(scan);
  });
});
