/** jest config for the Firebase rules test suite (runs under the emulator). */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/test'],
  testMatch: ['**/*.test.ts'],
  testTimeout: 30000,
  // Transpile-only: the edge-function port (supabase/functions) uses Deno's
  // required `.ts` import extensions, which full type-checking rejects.
  transform: {
    '^.+\\.ts$': ['ts-jest', { isolatedModules: true }],
  },
};