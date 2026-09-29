import { describe, expect, it } from "vitest";
import { buildingsFor, buildingYield, CELL_BUILDINGS, cellBonus, cellBuildingName, workingLevel } from "./holdings.ts";
import { materialName } from "./drops.ts";
import type { Terrain } from "./contents.ts";

describe("buildings on held cells", () => {
  it("gives every ground two to choose from, all with materials that have names", () => {
    for (const t of ["forest", "park", "water", "urban", "open", "road"] as Terrain[]) expect(buildingsFor(t)).toHaveLength(2);
    for (const r of CELL_BUILDINGS) {
      for (const m of [r.makes, r.finds, ...Object.values(r.races ?? {}).map((v) => v.makes)]) {
        for (const id of Object.keys(m ?? {})) expect(materialName(id)).not.toBe(id);
      }
    }
  });

  it("works at the level before while it is being raised, and at none while first built", () => {
    const at = Date.parse("2026-10-01T09:00:00Z");
    const later = new Date(at + 3_600_000).toISOString();
    expect(workingLevel({ kind: "watchtower", level: 1, busyUntil: later }, at)).toBe(0);
    expect(workingLevel({ kind: "watchtower", level: 2, busyUntil: later }, at)).toBe(1);
    expect(workingLevel({ kind: "watchtower", level: 2, busyUntil: later }, at + 3_600_000)).toBe(2);
    expect(cellBonus("goblin", { kind: "watchtower", level: 1, busyUntil: later }, at).fort).toBe(0);
    expect(cellBonus("goblin", { kind: "watchtower", level: 3 }, at).fort).toBe(0.35);
    expect(cellBonus("goblin", { kind: "dock", level: 2 }, at).travel).toBe(0.75);
    expect(cellBonus("goblin", null, at)).toEqual({ makes: {}, finds: {}, fort: 0, travel: 1, room: 0, party: 0 });
  });

  it("has each race's own version where it differs", () => {
    expect(cellBuildingName("lodge", "elf")).toBe("射手小屋");
    expect(cellBonus("elf", { kind: "lodge", level: 1 }, 0).makes).toEqual({ feather: 1, rabbit_fur: 1 });
    expect(cellBonus("undead", { kind: "fishery", level: 3 }, 0).makes).toEqual({ ration_jerky: 3, frog_skin: 2 });
  });

  it("adds its makes to every yield and rolls its finds", () => {
    const bonus = cellBonus("goblin", { kind: "workshop", level: 3 }, 0);
    let k = 0;
    const got = buildingYield(bonus, 4, () => (k++ % 2 === 0 ? 0 : 0.99));
    expect(got.scrap_iron).toBe(20);
    expect(got.crystal_shard).toBe(2);
  });
});
