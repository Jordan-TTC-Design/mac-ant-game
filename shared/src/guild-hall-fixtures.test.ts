import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { buildGuildHallFixtures } from "./guild-hall-fixtures.ts";

describe("guild-hall-fixtures.json (what the Mac's Swift copy must match)", () => {
  it("matches the rules as they are now", () => {
    const saved = JSON.parse(readFileSync(new URL("./guild-hall-fixtures.json", import.meta.url), "utf8"));
    expect(saved).toEqual(JSON.parse(JSON.stringify(buildGuildHallFixtures())));
  });
});
