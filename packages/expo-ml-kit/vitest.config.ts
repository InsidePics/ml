import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: ['src/**/__tests__/**/*.test.ts'],
    coverage: {
      provider: 'v8',
      // The typed wrapper is exercisable off-device. The native binding
      // (requireOptionalNativeModule) and the Kotlin are verified by
      // `pnpm test:kotlin` (JVM) and on device, not here.
      include: ['src/index.ts', 'src/textQuality.ts'],
    },
  },
});
