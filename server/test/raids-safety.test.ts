import { describe, expect, it } from "vitest";
import { planRaid, raidRaceLevel, RAID_MAX_FALLEN } from "@goblincamp/shared/camp";
import { resolveRaid } from "../src/camp/raids.ts";

// (mac-ant-game-f5's preview, 2026-10-17: a bare camp at race level 50 lost ~15 residents a raid and its home emptied)
describe("raids never wipe out a camp", () => {
  const alive = Array.from({ length: 200 }, (_, i) => ({ id: i + 1, breed: "common", gear: null }));
  it("a bare camp of a high race level meets first-tier monsters, and loses at most 5% a raid", () => {
    const level = raidRaceLevel(50, 0);
    let worst = 0;
    for (let i = 0; i < 30; i++) {
      const plan = planRaid("goblin", 11, Date.parse("2026-10-17T00:00:00Z"), i, alive.length, level, [])!;
      expect(plan.boss).toBeUndefined();
      const out = resolveRaid("goblin", 11, plan, alive, {}, level);
      worst = Math.max(worst, out.fallen.length);
    }
    expect(worst).toBeLessThanOrEqual(Math.max(1, Math.floor(200 * RAID_MAX_FALLEN)));
  });
  it("even an overwhelming raid takes no more than 5%", () => {
    const plan = planRaid("goblin", 11, Date.parse("2026-10-17T00:00:00Z"), 0, alive.length, 50, [])!;
    const out = resolveRaid("goblin", 11, plan, alive, {}, 50);
    expect(out.fallen.length).toBeLessThanOrEqual(10);
  });
});
