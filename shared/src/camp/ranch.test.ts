import { describe, expect, it } from "vitest";
import { MATERIALS } from "../world/drops.ts";
import { RANCH_CAP, RANCH_KINDS, ranchProblem, ranchYield, type RanchAnimal } from "./ranch.ts";

const now = new Date("2026-10-03T12:00:00Z");
const old = "2026-10-03T08:00:00Z";
const herd = (kinds: string[], bornAt = old): RanchAnimal[] => kinds.map((kind, i) => ({ id: i + 1, kind, bornAt }));

describe("the ranch's rules", () => {
  it("gives only materials that exist", () => {
    for (const k of Object.values(RANCH_KINDS)) for (const id of [...Object.keys(k.perHour), ...Object.keys(k.butcher ?? {})]) expect(MATERIALS[id], id).toBeDefined();
  });

  it("yields by the minute from the full-grown ones, carrying fractions on", () => {
    const five = herd(["sheep", "sheep", "sheep", "sheep", "sheep"]); // 2 rags an hour
    const a = ranchYield(five, 30, now);
    expect(a.gain).toEqual({ scrap_rag: 1 });
    const b = ranchYield(five, 15, now, a.carry);
    expect(b.gain).toEqual({});
    expect(ranchYield(five, 15, now, b.carry).gain).toEqual({ scrap_rag: 1 });
    expect(ranchYield(herd(["pig", "pig"]), 600, now).gain).toEqual({}); // (pigs are for meat)
  });

  it("gives nothing for the young, unless they were caught grown", () => {
    const young = herd(["sheep", "sheep", "sheep"], "2026-10-03T11:30:00Z");
    expect(ranchYield(young, 60, now).gain).toEqual({});
    expect(ranchYield(young.map((a) => ({ ...a, caught: true })), 60, now).gain).toEqual({ scrap_rag: 1 });
  });

  it("keeps the herd within the camp's cap and its kinds", () => {
    expect(ranchProblem(herd(Array(RANCH_CAP[1]).fill("chicken")), 1)).toBeNull();
    expect(ranchProblem(herd(Array(RANCH_CAP[1] + 1).fill("chicken")), 1)).toContain("最多養");
    expect(ranchProblem(herd(["dragon"]), 3)).toBe("牧場不養這種動物。");
    expect(ranchProblem([{ id: 1, kind: "pig", bornAt: old }, { id: 1, kind: "pig", bornAt: old }], 3)).toContain("重複");
  });
});
