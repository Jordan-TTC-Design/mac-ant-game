import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { worldNames } from "../../scripts/world-names.ts";

// The Mac's 大世界 page reads mac/Resources/World/names.json: it must say what the rules say.
describe("the Mac's world names", () => {
  it("are up to date (run: node --experimental-strip-types scripts/write-world-names.ts)", () => {
    const file = JSON.parse(readFileSync(new URL("../../../mac/Resources/World/names.json", import.meta.url), "utf8"));
    expect(file).toEqual(JSON.parse(JSON.stringify(worldNames())));
  });
});
