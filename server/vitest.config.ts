import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    // every file uses the one test database and empties it between tests, so they take turns
    fileParallelism: false,
    testTimeout: 20_000,
    // the big world's terrain from the seed, not the internet (test/osm.test.ts reads a saved tile instead)
    env: { WORLD_TERRAIN: "seed" },
  },
});
