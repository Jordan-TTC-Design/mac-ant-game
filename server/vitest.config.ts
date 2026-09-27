import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    // every file uses the one test database and empties it between tests, so they take turns
    fileParallelism: false,
    testTimeout: 20_000,
  },
});
