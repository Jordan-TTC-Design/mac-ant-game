import { describe, expect, it } from "vitest";
import { buildingsFor, buildingYield, CELL_BUILDINGS, cellBonus, cellBuildingName, connectedCells, eatRations, fedYield, upkeepDue, heldNeighbours, LANDMARKS, regionHasRoomForTown, regionTowns, standInLandmark, townRoom, townsJoined, workingLevel } from "./holdings.ts";
import { cellAt, cellId, neighbors } from "./grid.ts";
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
    expect(cellBonus("goblin", null, at)).toEqual({ makes: {}, finds: {}, fort: 0, travel: 1, room: 0, party: 0, xp: 0, yieldBoost: 0 });
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

describe("landmarks", () => {
  it("add to what the building gives, and a temple helps the held cells next to it", () => {
    const station = { kind: "station" as const, name: "大安站" };
    expect(cellBonus("goblin", { kind: "inn", level: 3 }, 0, { landmark: station }).travel).toBeCloseTo(0.7 * 0.65);
    expect(cellBonus("goblin", { kind: "watchtower", level: 1 }, 0, { landmark: { kind: "temple", name: "福德宮" } }).fort).toBeCloseTo(0.35);
    expect(cellBonus("goblin", null, 0, { templeNear: true }).fort).toBe(0.1);
    expect(cellBonus("goblin", null, 0, { landmark: { kind: "temple", name: "福德宮" }, templeNear: true }).fort).toBe(0.2);
    expect(cellBonus("goblin", { kind: "field", level: 2 }, 0, { landmark: { kind: "market", name: "東門市場" } }).makes).toEqual({ ration_bread: 2, food_cheese: 1, food_carrot: 2 });
    expect(cellBonus("goblin", null, 0, { landmark: { kind: "university", name: "臺大" } }).xp).toBe(20);
  });

  it("has a stand-in without the real map: a few cells, every kind, the same every time", () => {
    const cells = Array.from({ length: 4000 }, (_, i) => `${i % 80}:${Math.floor(i / 80)}`);
    const found = cells.map(standInLandmark).filter((l) => l);
    expect(found.length / cells.length).toBeGreaterThan(0.03);
    expect(found.length / cells.length).toBeLessThan(0.07);
    expect(new Set(found.map((l) => l!.kind)).size).toBe(LANDMARKS.length);
    expect(standInLandmark(cells[7]!)).toEqual(standInLandmark(cells[7]!));
  });
});

describe("cells held side by side", () => {
  it("are one region when joined through neighbours, and each neighbour adds to the yield (up to three)", () => {
    const a = cellId(100, 100);
    const [b, c] = neighbors(a) as [string, string];
    const far = cellId(120, 120);
    const held = new Set([a, b, c, far]);
    expect(new Set(connectedCells(a, held))).toEqual(new Set([a, b, c]));
    expect(connectedCells(far, held)).toEqual([far]);
    expect(connectedCells(cellId(1, 1), held)).toEqual([]);
    expect(heldNeighbours(a, held)).toBe(2);
    expect(cellBonus("goblin", null, 0, { neighbours: 2 }).yieldBoost).toBeCloseTo(0.2);
    expect(cellBonus("goblin", null, 0, { neighbours: 6 }).yieldBoost).toBeCloseTo(0.3);
  });
});

describe("keeping many cells", () => {
  it("eats rations, the kind there is most of first, as many as there are", () => {
    expect(eatRations({ ration_bread: 1, ration_fish: 3, scrap_wood: 9 }, 3)).toEqual({ eaten: { ration_fish: 2, ration_bread: 1 }, paid: 3 });
    expect(eatRations({ ration_berry: 1 }, 3)).toEqual({ eaten: { ration_berry: 1 }, paid: 1 });
    expect(eatRations({}, 2)).toEqual({ eaten: {}, paid: 0 });
  });
  it("owes a ration every other yield, counted from when the cell was taken", () => {
    expect([upkeepDue(0, 1), upkeepDue(1, 1), upkeepDue(0, 2), upkeepDue(3, 5)]).toEqual([0, 1, 1, 3]);
  });
  it("halves a hungry cell's yield, in proportion to how hungry", () => {
    expect(fedYield({ scrap_wood: 8, amber: 1 }, 1)).toEqual({ scrap_wood: 8, amber: 1 });
    expect(fedYield({ scrap_wood: 8, amber: 1 }, 0)).toEqual({ scrap_wood: 4 });
    expect(fedYield({ scrap_wood: 8 }, 0.5)).toEqual({ scrap_wood: 6 });
  });
});

describe("towns and their region", () => {
  it("adds half a cell's room per town, stacking up to four", () => {
    expect(townRoom(50, 0)).toBe(0);
    expect(townRoom(50, 1)).toBe(25);
    expect(townRoom(50, 2)).toBe(50);
    expect(townRoom(30, 3)).toBe(45);
    expect(townRoom(50, 9)).toBe(100); // (4 at most)
    // a town counts itself among the four but gets no room from itself
    expect(townsJoined(1, true)).toBe(0);
    expect(townsJoined(3, false)).toBe(3);
    expect(townsJoined(6, false)).toBe(4);
    expect(townsJoined(6, true)).toBe(3);
    const at = Date.parse("2026-10-01T09:00:00Z");
    expect(cellBonus("goblin", null, at, { townsJoined: 2 }).room).toBe(50);
    expect(cellBonus("elf", null, at, { townsJoined: 1 }).room).toBe(15);
  });

  it("allows one town for every four cells of a region, and counts only the towns joined to a cell", () => {
    expect(regionHasRoomForTown(4, 0)).toBe(true);
    expect(regionHasRoomForTown(7, 1)).toBe(false);
    expect(regionHasRoomForTown(8, 1)).toBe(true);
    const home = cellAt({ lat: 25.0302, lng: 121.5357 });
    const [a, b] = neighbors(home) as [string, string];
    const far = cellAt({ lat: 25.1, lng: 121.6 });
    const held = new Set([home, a, b, far]);
    expect(regionTowns(b, held, new Set([a, far]))).toBe(1);
    expect(regionTowns(far, held, new Set([a, far]))).toBe(1);
  });
});
