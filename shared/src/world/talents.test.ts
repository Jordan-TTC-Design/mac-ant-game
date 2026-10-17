import { describe, expect, it } from "vitest";
import { cannotLearn, pointsSpent, TALENT_TREES, TALENTS, talentBonus, talentPoints, talentProblem, talentResetCost, talentRule, treesFor } from "./talents.ts";

describe("種族天賦", () => {
  it("gives each race four trees of its own (the camp's one of them), each laid out in rows with a top talent", () => {
    for (const race of ["goblin", "elf", "undead"]) {
      const trees = treesFor(race);
      expect(trees).toHaveLength(4);
      for (const tree of trees) {
        const talents = TALENTS.filter((x) => x.tree === tree.id);
        expect(new Set(talents.map((x) => x.row))).toEqual(new Set([0, 1, 2, 3, 4]));
        expect(talents.filter((x) => x.row === 4)).toHaveLength(1);
        for (const x of talents) if (x.requires) expect(talentRule(x.requires)!.row).toBeLessThan(x.row);
      }
    }
    expect(new Set(TALENT_TREES.map((x) => x.id)).size).toBe(12);
    expect(new Set(TALENTS.map((x) => x.id)).size).toBe(TALENTS.length);
  });

  it("opens rows with points spent above and the race level, and needs the talent above first", () => {
    expect(talentPoints(1)).toBe(0);
    expect(talentPoints(20)).toBe(19);
    expect(cannotLearn("goblin", 1, {}, "g_raid.sharp")).toContain("沒有天賦點");
    expect(cannotLearn("goblin", 3, {}, "g_raid.sharp")).toBeNull();
    expect(cannotLearn("goblin", 3, {}, "e_ranger.swift")).toBe("沒有這個天賦。"); // (another race's)
    // row 1 needs level 5 and 4 points above it in that tree
    expect(cannotLearn("goblin", 4, { "g_raid.sharp": 2 }, "g_raid.warband")).toContain("等級 5");
    expect(cannotLearn("goblin", 8, { "g_raid.sharp": 3 }, "g_raid.warband")).toContain("先點 4 點");
    expect(cannotLearn("goblin", 8, { "g_raid.sharp": 3, "g_raid.greed": 1 }, "g_raid.warband")).toBeNull();
    // row 2's 洗劫 needs 大隊人馬 at full rank
    const eight = { "g_raid.sharp": 3, "g_raid.greed": 3, "g_raid.ambush": 2 };
    expect(cannotLearn("goblin", 12, eight, "g_raid.pillage")).toContain("大隊人馬");
    expect(cannotLearn("goblin", 12, { ...eight, "g_raid.ambush": 0, "g_raid.warband": 3 }, "g_raid.pillage")).toBeNull();
  });

  it("takes nothing back without a reset, and keeps within the points", () => {
    expect(talentProblem("goblin", 5, { "g_raid.sharp": 2 }, { "g_raid.sharp": 1 })).toContain("重置");
    expect(talentProblem("goblin", 5, {}, { "g_raid.sharp": 3, "g_raid.greed": 1 })).toBeNull();
    expect(talentProblem("goblin", 5, {}, { "g_raid.sharp": 3, "g_raid.greed": 2 })).toContain("沒有天賦點");
    expect(pointsSpent({ a: 2, b: 3 })).toBe(5);
    expect(talentResetCost(0)).toEqual({ crystal_shard: 15, amber: 4 });
    expect(talentResetCost(2)).toEqual({ crystal_shard: 45, amber: 12 });
  });

  it("adds the talents up by what they do", () => {
    expect(talentBonus({ "g_raid.sharp": 2, "g_raid.plunder": 1, "g_raid.warband": 3 })).toEqual({ attack: 0.06, party: 3, plunder: 1 });
    // every big-world tree's top talent opens something new
    for (const tree of TALENT_TREES.filter((x) => !x.id.endsWith("_camp"))) {
      const top = TALENTS.find((x) => x.tree === tree.id && x.row === 4)!;
      expect(top.ranks).toBe(1);
      expect(["plunder", "tunnels", "refine", "ambush", "sacredTree", "moonGate", "raiseDead", "nightRaid", "blight"]).toContain(top.effect);
    }
    expect(talentBonus(null)).toEqual({});
  });
});
