import { describe, expect, it } from "vitest";
import { MATERIALS } from "./drops.ts";
import { LAIRS } from "./contents.ts";
import { cellsLost, levelAfterSwitch, pickSome, raceSwitchCost, raceSwitchPrice, raceSwitchProblem, raceTokenDrop, RACE_TOKENS, residentsKept } from "./race-switch.ts";
import { randomFrom } from "./random.ts";

describe("換族", () => {
  it("takes 2/5 of the level, 1/5 the first time", () => {
    expect(levelAfterSwitch(20, false)).toBe(12);
    expect(levelAfterSwitch(10, false)).toBe(6);
    expect(levelAfterSwitch(20, true)).toBe(16);
    expect(levelAfterSwitch(10, true)).toBe(8);
    expect(levelAfterSwitch(1, false)).toBe(1);
  });

  it("halves the residents (a quarter the first time), a lone one stays", () => {
    expect(residentsKept(10, false)).toBe(5);
    expect(residentsKept(9, false)).toBe(5);
    expect(residentsKept(1, false)).toBe(1);
    expect(residentsKept(8, true)).toBe(6);
  });

  it("gives up a third of the far land (a sixth the first time), rounded down", () => {
    expect(cellsLost(9, false)).toBe(3);
    expect(cellsLost(2, false)).toBe(0);
    expect(cellsLost(12, true)).toBe(2);
  });

  it("costs by the level, half the first time, and five of the new race's 信物", () => {
    expect(raceSwitchCost(12, false)).toEqual({ log: 3000, stone: 3000, crystal_shard: 15, amber: 3 });
    expect(raceSwitchCost(22, true)).toEqual({ log: 5000, stone: 5000, crystal_shard: 25, amber: 8 });
    expect(raceSwitchPrice(15, false, "elf").token_elf).toBe(5);
  });

  it("says why it cannot", () => {
    const base = { race: "goblin", to: "elf", level: 12, switchedAt: null, now: new Date("2026-10-18T00:00:00Z"), materials: raceSwitchPrice(12, true, "elf"), switches: 0, travelling: 0 };
    expect(raceSwitchProblem(base)).toBeNull();
    expect(raceSwitchProblem({ ...base, level: 9 })).toMatch(/10 級/);
    expect(raceSwitchProblem({ ...base, to: "goblin" })).toMatch(/已經/);
    expect(raceSwitchProblem({ ...base, travelling: 1 })).toMatch(/路上/);
    expect(raceSwitchProblem({ ...base, switches: 1 })).toMatch(/不夠/);
    expect(raceSwitchProblem({ ...base, switchedAt: new Date("2026-10-10T00:00:00Z") })).toMatch(/14 天/);
    expect(raceSwitchProblem({ ...base, switchedAt: new Date("2026-10-01T00:00:00Z") })).toBeNull();
  });

  it("drops 信物 only from the right lairs, for camps of level 10, never their own race's", () => {
    const always = () => 0;
    expect(raceTokenDrop("crypt", "goblin", 10, always)).toBe("token_undead");
    expect(raceTokenDrop("crypt", "undead", 10, always)).toBeNull();
    expect(raceTokenDrop("crypt", "goblin", 9, always)).toBeNull();
    expect(raceTokenDrop("wolf_den", "goblin", 20, always)).toBeNull();
    expect(raceTokenDrop("bear_cave", "elf", 12, () => 0.3)).toBeNull();
  });

  it("names real materials and lairs", () => {
    const kinds = new Set(LAIRS.map((k) => k.id));
    for (const t of Object.values(RACE_TOKENS)) {
      expect(MATERIALS[t.id]).toBeDefined();
      for (const l of t.lairs) expect(kinds.has(l), l).toBe(true);
    }
  });

  it("picks the same at random from the same seed", () => {
    const a = pickSome([1, 2, 3, 4, 5, 6], 3, randomFrom(7));
    expect(pickSome([1, 2, 3, 4, 5, 6], 3, randomFrom(7))).toEqual(a);
    expect(new Set(a).size).toBe(3);
  });
});
