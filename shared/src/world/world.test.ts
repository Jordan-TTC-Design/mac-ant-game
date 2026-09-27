import { describe, expect, it } from "vitest";
import { combatPower, lairFighters, residentFighter, simulateBattle, type Fighter, type Resident } from "./battle.ts";
import { LAIRS, lairAt, lootFor, type Lair } from "./contents.ts";
import { expeditionInput, expeditionReportSchema } from "./api.ts";
import { resolveExpedition } from "./expedition.ts";
import { cellAt, cellCenter, cellDistance, cellsWithin, isCellId, metersBetween, neighbors } from "./grid.ts";
import { rank, raceLevel, xpForLevel } from "./leaderboard.ts";
import { seeded } from "./random.ts";
import {
  GARRISON_MIN, afterDefeat, canBuildTown, canOpenWorld, checkAttack, checkOccupy, maxCells, nestBirths, openWorld, travelMinutes,
  type PlayerWorldState,
} from "./territory.ts";

// 大安森林公園: about 900 m east to west
const DAAN = { west: { lat: 25.0301, lng: 121.5318 }, middle: { lat: 25.0301, lng: 121.5355 }, east: { lat: 25.0301, lng: 121.5392 } };

describe("grid", () => {
  it("gives the east, middle and west of 大安森林公園 cells of their own", () => {
    const cells = [cellAt(DAAN.west), cellAt(DAAN.middle), cellAt(DAAN.east)];
    expect(new Set(cells).size).toBe(3);
    for (const c of cells) expect(isCellId(c)).toBe(true);
  });

  it("puts a cell's middle back in the same cell", () => {
    for (const p of [DAAN.middle, { lat: 35.68, lng: 139.76 }, { lat: 51.5, lng: -0.12 }, { lat: -33.86, lng: 151.2 }, { lat: 0.1, lng: 179.99 }]) {
      const c = cellAt(p);
      expect(cellAt(cellCenter(c))).toBe(c);
    }
  });

  it("has six neighbours, each of which counts it as a neighbour, about a cell away", () => {
    const c = cellAt(DAAN.middle);
    const around = neighbors(c);
    expect(around).toHaveLength(6);
    for (const n of around) {
      expect(neighbors(n)).toContain(c);
      const d = cellDistance(c, n);
      expect(d).toBeGreaterThan(250);
      expect(d).toBeLessThan(420);
    }
  });

  it("makes cells about the same size in Taipei and in London", () => {
    const size = (p: { lat: number; lng: number }) => Math.min(...neighbors(cellAt(p)).map((n) => cellDistance(cellAt(p), n)));
    expect(Math.abs(size(DAAN.middle) - size({ lat: 51.5, lng: -0.12 }))).toBeLessThan(40);
  });

  it("lists the cells around a point", () => {
    const cells = cellsWithin(DAAN.middle, 1000);
    expect(cells.length).toBeGreaterThan(25);
    expect(cells.length).toBeLessThan(45);
    for (const c of cells) expect(metersBetween(DAAN.middle, cellCenter(c))).toBeLessThanOrEqual(1000);
    expect(cells).toContain(cellAt(DAAN.middle));
  });
});

describe("what lives in a cell", () => {
  it("is the same every time for the same world and cell", () => {
    const c = cellAt(DAAN.middle);
    expect(lairAt(7, c, "park")).toEqual(lairAt(7, c, "park"));
  });

  it("fills a fair share of cells, with the right kinds for the terrain", () => {
    const cells = cellsWithin(DAAN.middle, 3000);
    const forest = cells.map((c) => lairAt(1, c, "forest")).filter((l): l is Lair => l !== null);
    const share = forest.length / cells.length;
    expect(share).toBeGreaterThan(0.3);
    expect(share).toBeLessThan(0.6);
    const allowed = new Set(LAIRS.filter((l) => (l.terrain.forest ?? 0) > 0).map((l) => l.id));
    for (const l of forest) {
      expect(allowed.has(l.kind)).toBe(true);
      expect(l.foes.length).toBeGreaterThan(0);
    }
    // water only ever has what lives by water
    for (const c of cells.slice(0, 200)) {
      const l = lairAt(1, c, "water");
      if (l) expect(["slime_pit", "troll_bridge"]).toContain(l.kind);
    }
  });

  it("has some that live alone and some in groups, and mostly low levels", () => {
    const lairs = cellsWithin(DAAN.middle, 4000).map((c) => lairAt(3, c, "forest")).filter((l): l is Lair => l !== null);
    expect(lairs.some((l) => l.foes.length === 1)).toBe(true);
    expect(lairs.some((l) => l.foes.length >= 3)).toBe(true);
    const low = lairs.filter((l) => l.level <= 2).length;
    expect(low / lairs.length).toBeGreaterThan(0.4);
  });

  it("drops loot, more at higher levels", () => {
    const lair: Lair = { cell: "1:1", kind: "barbarian_camp", name: "", faction: "barbarian", level: 1, foes: ["barbarian"] };
    const total = (level: number) => {
      let sum = 0;
      for (let i = 0; i < 200; i++) sum += Object.values(lootFor({ ...lair, level }, seeded("loot", level, i))).reduce((a, b) => a + b, 0);
      return sum;
    };
    expect(total(6)).toBeGreaterThan(total(1));
  });
});

const goblin = (id: string, breed = "common", over: Partial<Resident> = {}): Resident => ({ id, name: id, breed, might: 1, health: 3, speed: 1, ...over });
const party = (n: number, breed = "common", over: Partial<Resident> = {}) => Array.from({ length: n }, (_, i) => goblin(`${breed}${i}`, breed, over));
const fighters = (rs: Resident[], side: "attack" | "defend", ranged = 0) => rs.map((r) => residentFighter(r, side, { ranged }));

describe("battle", () => {
  it("is the same battle for the same seed", () => {
    const a = fighters(party(6), "attack"), d = fighters(party(5), "defend");
    expect(simulateBattle(a, d, { seed: 42 })).toEqual(simulateBattle(a, d, { seed: 42 }));
  });

  it("is usually won by the bigger side", () => {
    let wins = 0;
    for (let seed = 0; seed < 50; seed++) if (simulateBattle(fighters(party(12), "attack"), fighters(party(5), "defend"), { seed }).winner === "attack") wins++;
    expect(wins).toBeGreaterThan(45);
  });

  it("keeps shooters in the back row safe from blades while the front row stands", () => {
    const front = fighters(party(4, "brute", { health: 30 }), "defend");
    const archers = fighters([0, 1, 2].map((i) => goblin(`archer${i}`)), "defend", 34);
    const attackers = fighters(party(3, "common", { might: 0.5 }), "attack");
    const result = simulateBattle(attackers, [...front, ...archers], { seed: 1, maxRounds: 5 });
    const archerIds = new Set(archers.map((f) => f.id));
    expect(result.events.filter((e) => e.kind === "hit" && archerIds.has(e.target))).toHaveLength(0);
  });

  it("lets a healer heal", () => {
    const d = [...fighters(party(3, "brute"), "defend"), ...fighters([goblin("sage", "sage", { might: 1.5 })], "defend")];
    const result = simulateBattle(fighters(party(6), "attack"), d, { seed: 3 });
    expect(result.events.some((e) => e.kind === "heal")).toBe(true);
  });

  it("makes a leader's side hit harder", () => {
    const withLeader = [...fighters(party(4), "attack"), ...fighters([goblin("gold", "golden", { might: 0.01, health: 100 })], "attack")];
    const without = [...fighters(party(4), "attack"), ...fighters([goblin("gold", "common", { might: 0.01, health: 100 })], "attack")];
    const dmg = (a: Fighter[]) => simulateBattle(a, fighters(party(1, "brute", { health: 200 }), "defend"), { seed: 5, maxRounds: 10 })
      .events.filter((e) => e.kind === "hit" && e.actor.startsWith("common")).reduce((s, e) => s + (e.amount ?? 0), 0);
    expect(dmg(withLeader)).toBeGreaterThan(dmg(without));
  });

  it("makes the dark ones stronger at night", () => {
    const crypt: Lair = { cell: "1:1", kind: "crypt", name: "", faction: "dark", level: 3, foes: ["skeleton", "skeleton", "wraith", "bone_knight"] };
    let dayWins = 0, nightWins = 0;
    for (let seed = 0; seed < 60; seed++) {
      const a = fighters(party(8), "attack");
      if (simulateBattle(a, lairFighters(crypt), { seed }).winner === "attack") dayWins++;
      if (simulateBattle(a, lairFighters(crypt), { seed, night: true }).winner === "attack") nightWins++;
    }
    expect(nightWins).toBeLessThan(dayWins);
  });

  it("rates a stronger group higher", () => {
    expect(combatPower(fighters(party(10), "attack"))).toBeGreaterThan(combatPower(fighters(party(5), "attack")));
    expect(combatPower(fighters(party(5, "brute", { might: 1.6, health: 5 }), "attack"))).toBeGreaterThan(combatPower(fighters(party(5), "attack")));
  });
});

describe("expedition", () => {
  const slimes: Lair = { cell: "1:1", kind: "slime_pit", name: "史萊姆坑", faction: "monster", level: 1, foes: ["slime", "slime", "slime"] };

  it("clears a weak lair, brings loot and experience home, and may settle", () => {
    const out = resolveExpedition({ worldSeed: 1, expeditionId: "e1", party: { player: "p", residents: party(8), race: { ranged: 0 } }, target: { kind: "lair", lair: slimes } });
    expect(out.won).toBe(true);
    expect(out.cell).toBe("cleared");
    expect(out.xp.attacker).toBe(20);
    expect(out.canSettle).toBe(out.battle.standing.attack.length >= GARRISON_MIN);
  });

  it("fails against a troll with a small party, and the cell stays held", () => {
    const troll: Lair = { cell: "1:1", kind: "troll_bridge", name: "巨魔橋", faction: "monster", level: 8, foes: ["troll"] };
    const out = resolveExpedition({ worldSeed: 1, expeditionId: "e2", party: { player: "p", residents: party(2), race: { ranged: 0 } }, target: { kind: "lair", lair: troll } });
    expect(out.won).toBe(false);
    expect(out.cell).toBe("held");
    expect(out.loot).toEqual({});
  });

  it("can take another player's cell", () => {
    const out = resolveExpedition({
      worldSeed: 1, expeditionId: "e3",
      party: { player: "a", residents: party(15, "brute", { might: 1.6, health: 5 }), race: { ranged: 0 } },
      target: { kind: "player", cell: "1:1", defender: { player: "b", residents: party(5), race: { ranged: 34 } } },
    });
    expect(out.won).toBe(true);
    expect(out.cell).toBe("taken");
    expect(out.xp.attacker).toBe(60);
  });
});

describe("territory", () => {
  const open: PlayerWorldState = { open: true, shieldedSince: null, lastShieldEnded: null };

  it("opens the big world at 90 residents", () => {
    expect(canOpenWorld(89)).toBe(false);
    expect(canOpenWorld(90)).toBe(true);
  });

  it("settles only free, cleared cells with enough settlers", () => {
    const base = { hasLair: false, lairBack: false, settlers: 5, player: open };
    expect(checkOccupy({ ...base, cell: null })).toBeNull();
    expect(checkOccupy({ ...base, cell: null, settlers: 4 })).toBe("too_few");
    expect(checkOccupy({ ...base, cell: null, hasLair: true })).toBe("lair");
    const taken = { cell: "1:1", owner: "b", garrison: [], nest: null, town: false, clearedAt: null };
    expect(checkOccupy({ ...base, cell: taken })).toBe("held");
    expect(checkOccupy({ ...base, cell: { ...taken, owner: null, clearedAt: "2026-09-27T00:00:00Z" }, hasLair: true })).toBeNull();
    expect(checkOccupy({ ...base, cell: null, player: { ...open, open: false } })).toBe("not_open");
    expect(maxCells(52)).toBe(10);
  });

  it("raises residents at a nest over time, up to the cell's room", () => {
    const t0 = new Date("2026-09-27T00:00:00Z");
    expect(nestBirths(t0, new Date(t0.getTime() + 95 * 60_000), 10)).toBe(3);
    expect(nestBirths(t0, new Date(t0.getTime() + 100 * 3_600_000), 25)).toBe(5);
  });

  it("builds a town from four cells", () => {
    const rich = { scrap_wood: 500, scrap_iron: 500, scrap_rag: 500, crystal_shard: 5 };
    expect(canBuildTown(3, rich, false)).toBe(false);
    expect(canBuildTown(4, rich, false)).toBe(true);
    expect(canBuildTown(4, rich, true)).toBe(false);
    expect(canBuildTown(4, {}, false)).toBe(false);
  });

  it("walks longer to farther cells, never past the cap, faster with carrots", () => {
    const here = cellAt(DAAN.middle);
    const near = travelMinutes(here, cellAt(DAAN.east));
    const far = travelMinutes(here, cellAt({ lat: 25.08, lng: 121.56 }));
    expect(near).toBeLessThan(far);
    expect(travelMinutes(here, cellAt({ lat: 35.68, lng: 139.76 }))).toBe(180);
    expect(travelMinutes(here, cellAt({ lat: 25.08, lng: 121.56 }), 1.15)).toBeLessThan(far);
  });

  it("shields a camp after a loss (camp and cells) until it opens the world again, and not twice in a row", () => {
    const t0 = new Date("2026-09-27T00:00:00Z");
    const lost = afterDefeat(open, t0);
    expect(lost.shieldedSince).not.toBeNull();
    expect(checkAttack("a", open, "b", lost)).toBe("target_shielded");
    const back = openWorld(lost, new Date(t0.getTime() + 3_600_000));
    expect(checkAttack("a", open, "b", back)).toBeNull();
    // losing again soon after: no new shield (so losing on purpose does not hide a camp)
    expect(afterDefeat(back, new Date(t0.getTime() + 2 * 3_600_000)).shieldedSince).toBeNull();
    expect(afterDefeat(back, new Date(t0.getTime() + 20 * 3_600_000)).shieldedSince).not.toBeNull();
    expect(checkAttack("a", open, "a", open)).toBe("own");
    expect(checkAttack("a", lost, "b", open)).toBe("you_closed");
  });
});

describe("leaderboard", () => {
  it("levels up quickly at first, then slowly", () => {
    expect(raceLevel(0)).toBe(1);
    expect(raceLevel(49)).toBe(1);
    expect(raceLevel(50)).toBe(2);
    expect(raceLevel(xpForLevel(5))).toBe(5);
    expect(xpForLevel(3) - xpForLevel(2)).toBeLessThan(xpForLevel(6) - xpForLevel(5));
  });

  it("ranks by score, sharing ranks on ties", () => {
    const ranked = rank([
      { player: "a", name: "阿", race: "goblin", population: 100, power: 500, xp: 0, cells: 3 },
      { player: "b", name: "貝", race: "elf", population: 60, power: 900, xp: 450, cells: 2 },
      { player: "c", name: "可", race: "goblin", population: 100, power: 500, xp: 0, cells: 1 },
    ]);
    expect(ranked[0]?.player).toBe("b");
    expect(ranked[1]?.rank).toBe(2);
    expect(ranked[2]?.rank).toBe(2);
  });
});

describe("api shapes", () => {
  it("accepts a proper expedition and rejects a bad cell", () => {
    const from = cellAt(DAAN.middle), to = cellAt(DAAN.east);
    expect(expeditionInput.safeParse({ from, to, party: party(3) }).success).toBe(true);
    expect(expeditionInput.safeParse({ from: "nope", to, party: party(3) }).success).toBe(false);
  });

  it("describes a real expedition's report", () => {
    const lair = lairAt(9, cellAt(DAAN.east), "park") ?? { cell: cellAt(DAAN.east), kind: "slime_pit", name: "史萊姆坑", faction: "monster" as const, level: 1, foes: ["slime"] };
    const out = resolveExpedition({ worldSeed: 9, expeditionId: "x", party: { player: "p", residents: party(8), race: { ranged: 0 } }, target: { kind: "lair", lair } });
    const report = {
      id: "x", from: cellAt(DAAN.middle), to: lair.cell, setOutAt: "2026-09-27T10:00:00+08:00", arriveAt: "2026-09-27T10:05:00+08:00",
      attacker: "p", defender: null, lair: { kind: lair.kind, name: lair.name, level: lair.level }, won: out.won, cell: out.cell,
      loot: out.loot, events: out.battle.events, fallen: out.battle.fallen,
    };
    expect(expeditionReportSchema.safeParse(report).success).toBe(true);
  });
});
