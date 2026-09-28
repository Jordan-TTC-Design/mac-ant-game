import { describe, expect, it } from "vitest";
import { combatPower, lairFighters, residentFighter, simulateBattle, type Fighter, type Resident } from "./battle.ts";
import { BOSS_HOURS, BOSS_ROUNDS, bossAt, bossFighters, bossIn, bossKind, bossMaxHp, bossShares, bossWindow, regionOf } from "./bosses.ts";
import { FOES, LAIRS, lairAt, lootFor, OPEN_TIERS, type Lair } from "./contents.ts";
import { dropsOf, lairDrops, MATERIALS } from "./drops.ts";
import { WORLD_SEED, expeditionInput } from "./api.ts";
import { terrainAt } from "./terrain.ts";
import { resolveExpedition } from "./expedition.ts";
import { CELL_METERS, cellAt, cellCenter, cellDistance, cellsWithin, isCellId, metersBetween, neighbors } from "./grid.ts";
import { rank, raceLevel, xpForLevel } from "./leaderboard.ts";
import { seeded } from "./random.ts";
import {
  afterDefeat, canBuildTown, canOpenWorld, cellCapacity, cellYield, checkAttack, checkOccupy, garrisonMin, maxCells, nestBirths, openWorld, TERRAIN_YIELD, travelMinutes,
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
      expect(d).toBeGreaterThan(CELL_METERS * 0.85);
      expect(d).toBeLessThan(CELL_METERS * 1.25);
    }
  });

  it("makes cells about the same size in Taipei and in London", () => {
    const size = (p: { lat: number; lng: number }) => Math.min(...neighbors(cellAt(p)).map((n) => cellDistance(cellAt(p), n)));
    expect(Math.abs(size(DAAN.middle) - size({ lat: 51.5, lng: -0.12 }))).toBeLessThan(40);
  });

  it("lists the cells around a point", () => {
    const cells = cellsWithin(DAAN.middle, 1000);
    // (about 90: the cells are 0.035 km², a third of the first 350 m ones)
    expect(cells.length).toBeGreaterThan(75);
    expect(cells.length).toBeLessThan(110);
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
    const allowed = new Set(LAIRS.filter((l) => l.tier <= OPEN_TIERS && (l.terrain.forest ?? 0) > 0).map((l) => l.id));
    for (const l of forest) {
      expect(allowed.has(l.kind)).toBe(true);
      expect(l.foes.length).toBeGreaterThan(0);
    }
    // water only ever has what lives by water (and every one of those turns up)
    const byWater = new Set(LAIRS.filter((l) => l.tier <= OPEN_TIERS && (l.terrain.water ?? 0) > 0).map((l) => l.id));
    const seen = new Set<string>();
    for (const c of cells) {
      const l = lairAt(1, c, "water");
      if (!l) continue;
      expect(byWater.has(l.kind)).toBe(true);
      seen.add(l.kind);
    }
    expect([...seen].sort()).toEqual([...byWater].sort());
  });

  it("gives every kind of place its own foes, and every foe something to drop", () => {
    for (const t of ["forest", "park", "water", "urban", "open"] as const) {
      const only = LAIRS.filter((l) => (l.terrain[t] ?? 0) > 0 && Object.keys(l.terrain).length <= 2);
      expect(only.length, t).toBeGreaterThan(0);
    }
    for (const l of LAIRS) for (const m of l.members) {
      expect(FOES[m.foe], m.foe).toBeDefined();
      expect(dropsOf(m.foe).length, `${m.foe} drops`).toBeGreaterThan(0);
    }
  });

  it("drops each beaten foe's own things, more at higher levels", () => {
    const lair: Lair = { cell: cellAt(DAAN.east), kind: "spider_nest", name: "蜘蛛巢", faction: "beast", level: 1, foes: ["giant_spider", "giant_spider", "spider_queen"] };
    const fallen = lair.foes.map((_, i) => `${lair.cell}#${i}`);
    let low = 0, high = 0;
    for (let i = 0; i < 300; i++) {
      const a = lairDrops(lair, fallen, `x${i}`);
      const b = lairDrops({ ...lair, level: 7 }, fallen, `x${i}`);
      expect(Object.keys(a).every((id) => ["spider_silk", "venom_sac", "queen_silk"].includes(id))).toBe(true);
      low += Object.values(a).reduce((n, k) => n + k, 0);
      high += Object.values(b).reduce((n, k) => n + k, 0);
    }
    expect(high).toBeGreaterThan(low);
    expect(lairDrops(lair, [], "x")).toEqual({}); // nobody beaten, nothing dropped
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
      const a = fighters(party(24), "attack");
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
    expect(out.canSettle).toBe(out.battle.standing.attack.length >= garrisonMin("goblin"));
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

  it("opens the big world at each race's third look (goblins 150, elves 90, undead 120)", () => {
    expect([canOpenWorld("goblin", 149), canOpenWorld("goblin", 150)]).toEqual([false, true]);
    expect([canOpenWorld("elf", 89), canOpenWorld("elf", 90)]).toEqual([false, true]);
    expect([canOpenWorld("undead", 119), canOpenWorld("undead", 120)]).toEqual([false, true]);
  });

  it("settles only free, cleared cells with enough settlers", () => {
    const base = { race: "goblin", hasLair: false, lairBack: false, settlers: 5, player: open };
    expect(checkOccupy({ ...base, cell: null })).toBeNull();
    expect(checkOccupy({ ...base, cell: null, settlers: 4 })).toBe("too_few");
    expect(checkOccupy({ ...base, cell: null, hasLair: true })).toBe("lair");
    const taken = { cell: "1:1", owner: "b", garrison: [], nest: null, town: false, clearedAt: null };
    expect(checkOccupy({ ...base, cell: taken })).toBe("held");
    expect(checkOccupy({ ...base, cell: { ...taken, owner: null, clearedAt: "2026-09-27T00:00:00Z" }, hasLair: true })).toBeNull();
    expect(checkOccupy({ ...base, cell: null, player: { ...open, open: false } })).toBe("not_open");
    expect(maxCells("goblin", 52)).toBe(10);
    // each race holds cells with its own numbers (server/CAMP.md §11)
    expect([garrisonMin("goblin"), garrisonMin("elf"), garrisonMin("undead")]).toEqual([5, 3, 4]);
    expect([cellCapacity("goblin"), cellCapacity("elf"), cellCapacity("undead")]).toEqual([50, 30, 40]);
    expect([cellCapacity("goblin", true), cellCapacity("elf", true), cellCapacity("undead", true)]).toEqual([100, 60, 80]);
    expect(checkOccupy({ ...base, race: "elf", cell: null, settlers: 3 })).toBeNull();
    expect(checkOccupy({ ...base, cell: null, settlers: 51 })).toBe("too_many");
    expect(maxCells("elf", 52)).toBe(17);
  });

  it("raises residents at a nest over time, up to the cell's room", () => {
    const t0 = new Date("2026-09-27T00:00:00Z");
    // goblins: one every 15 minutes, up to 50 on a cell (100 in a town, one every 5 minutes)
    expect(nestBirths("goblin", t0, new Date(t0.getTime() + 95 * 60_000), 10)).toBe(6);
    expect(nestBirths("goblin", t0, new Date(t0.getTime() + 100 * 3_600_000), 45)).toBe(5);
    expect(nestBirths("goblin", t0, new Date(t0.getTime() + 60 * 60_000), 10, true)).toBe(12);
    expect(nestBirths("elf", t0, new Date(t0.getTime() + 95 * 60_000), 10)).toBe(3);
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
  it("accepts a proper expedition and rejects a bad cell or an empty party", () => {
    const to = cellAt(DAAN.east);
    expect(expeditionInput.safeParse({ to, count: 5 }).success).toBe(true);
    expect(expeditionInput.safeParse({ from: cellAt(DAAN.middle), to, residents: [3, 4], settle: true }).success).toBe(true);
    expect(expeditionInput.safeParse({ from: "nope", to, count: 3 }).success).toBe(false);
    expect(expeditionInput.safeParse({ to }).success).toBe(false);
  });
});

describe("terrain (the stand-in until OpenStreetMap)", () => {
  it("is the same every time, and comes in patches of every kind", () => {
    const cells = cellsWithin(DAAN.middle, 6000);
    const counts: Record<string, number> = {};
    for (const c of cells) counts[terrainAt(WORLD_SEED, c)] = (counts[terrainAt(WORLD_SEED, c)] ?? 0) + 1;
    for (const t of ["forest", "park", "water", "urban", "open"]) expect(counts[t] ?? 0).toBeGreaterThan(cells.length * 0.03);
    expect(terrainAt(WORLD_SEED, cells[10]!)).toBe(terrainAt(WORLD_SEED, cells[10]!));
    // patches: most cells share their terrain with at least one neighbour
    const alone = cells.filter((c) => !neighbors(c).some((n) => terrainAt(WORLD_SEED, n) === terrainAt(WORLD_SEED, c))).length;
    expect(alone).toBeLessThan(cells.length * 0.15);
  });
});

describe("the world's great monsters (世界魔王)", () => {
  const T = Date.UTC(2026, 9, 1, 3);
  it("turn up in about six regions of ten, the same everywhere for a window, and stay 12 hours", () => {
    const regions = new Set(cellsWithin(DAAN.middle, 60_000).map(regionOf));
    const seen = [...regions].map((r) => bossIn(WORLD_SEED, r, bossWindow(T)));
    const share = seen.filter(Boolean).length / seen.length;
    expect(share).toBeGreaterThan(0.4);
    expect(share).toBeLessThan(0.8);
    const one = seen.find(Boolean)!;
    expect(regionOf(one.cell)).toBe(one.region);
    expect(bossAt(WORLD_SEED, one.cell, one.startsAt + 3_600_000)).toEqual(one);
    expect(one.endsAt - one.startsAt).toBe(BOSS_HOURS * 3_600_000);
    // the next window is a new draw
    const later = [...regions].map((r) => bossIn(WORLD_SEED, r, bossWindow(T) + 1)?.cell);
    expect(later).not.toEqual(seen.map((s) => s?.cell));
  });

  it("keep their wounds between fights, and are far too much for one party", () => {
    const kind = bossKind("ancient_dragon")!;
    const fresh = bossFighters(kind, bossMaxHp(kind.id));
    const hurt = bossFighters(kind, 100);
    expect(fresh[0]!.hp).toBe(9000);
    expect(hurt[0]!.hp).toBe(100);
    expect(hurt[0]!.maxHp).toBe(9000);
    const attackers = party(30).map((r) => residentFighter(r, "attack", { ranged: 0 }));
    const fight = simulateBattle(attackers, fresh, { seed: 5, maxRounds: BOSS_ROUNDS });
    expect(fight.hpLeft.boss).toBeGreaterThan(0);
    expect(fight.hpLeft.boss).toBeLessThan(9000);
  });

  it("share the spoils by damage: everyone who hurt it gets something, the most to the one who did most", () => {
    const kind = bossKind("hill_giant")!;
    const shares = bossShares(kind, { a: 700, b: 300, c: 20 }, "k");
    expect(Object.keys(shares)).toEqual(["a", "b", "c"]);
    for (const s of Object.values(shares)) expect(s.loot.giant_bone).toBeGreaterThan(0);
    expect(shares.a!.xp).toBeGreaterThan(shares.b!.xp);
    expect(shares.c!.xp).toBe(20);
    expect(shares.a!.share + shares.b!.share + shares.c!.share).toBeCloseTo(1);
  });
});

describe("what held cells yield", () => {
  it("gives the ground's materials, more with more living there, nothing when too few hold it", () => {
    const r = seeded(1, "y");
    expect(cellYield("goblin", "forest", 4, 8, r)).toEqual({});
    const few = cellYield("goblin", "forest", 5, 40, seeded(2, "y"));
    const many = cellYield("goblin", "forest", 50, 40, seeded(2, "y"));
    expect(few.scrap_wood).toBeGreaterThan(0);
    expect(many.scrap_wood!).toBeGreaterThan(few.scrap_wood! * 1.6);
    expect(Object.keys(cellYield("elf", "urban", 3, 20, seeded(3, "y")))).toContain("scrap_iron");
    const town = cellYield("goblin", "park", 5, 20, seeded(4, "y"), true);
    const plain = cellYield("goblin", "park", 5, 20, seeded(4, "y"));
    expect(town.scrap_rag!).toBeGreaterThan(plain.scrap_rag!);
    for (const t of Object.keys(TERRAIN_YIELD)) for (const y of TERRAIN_YIELD[t]!) expect(MATERIALS[y.id], y.id).toBeDefined();
  });
});
