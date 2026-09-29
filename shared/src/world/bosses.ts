/**
 * 世界魔王 (server/WORLD.md §16): now and then a great monster turns up somewhere in each part of the map (a region of
 * REGION_CELLS × REGION_CELLS cells, about 9 km across) and stays for BOSS_HOURS. It is far too strong for one party: its
 * wounds stay between fights, every camp that hurts it is remembered, and when it falls everyone who fought it shares the
 * spoils by the damage they did. Which one, where and when comes from the world's seed, like the lairs.
 */
import type { DropRule } from "../camp/combat.ts";
import { FOE_FOCUS, type Fighter } from "./battle.ts";
import { FOES, type Terrain } from "./contents.ts";
import { cellId, parseCell, type CellId } from "./grid.ts";
import { between, pickWeighted, seeded } from "./random.ts";
import { terrainAt } from "./terrain.ts";

export const REGION_CELLS = 52; // (about 9 km across with 174 m rows)
export const BOSS_HOURS = 12;
/** How likely a region is to have one in a given 12 hours. */
export const BOSS_CHANCE = 0.6;
/** A party gets this many rounds at it before the survivors fall back (a boss fight is an onslaught, not a fight to the death). */
export const BOSS_ROUNDS = 12;

export interface BossKind {
  id: string;
  name: string;
  /** Where it likes to turn up (its weight by terrain). */
  terrain: Partial<Record<Terrain, number>>;
  /** Its guard, fresh at every fight (they are not what is being worn down). */
  minions: { foe: string; count: number }[];
  /** What everybody who hurt it shares when it falls (the rolls are made once per share; see bossShares). */
  drops: DropRule[];
  /** Experience shared out by damage. */
  xp: number;
}

const d = (id: string, chance: number, min = 1, max = min): DropRule => ({ id, chance, min, max });

export const BOSSES: BossKind[] = [
  {
    id: "ancient_dragon", name: "古龍", terrain: { forest: 1, open: 2, park: 1 },
    minions: [{ foe: "drake", count: 2 }],
    drops: [d("dragon_scale", 1, 2, 5), d("dragon_heart", 0.25), d("crystal_shard", 0.8, 1, 3)], xp: 400,
  },
  {
    id: "lich_king", name: "巫妖王", terrain: { urban: 3, open: 1 },
    minions: [{ foe: "skeleton", count: 3 }, { foe: "wraith", count: 1 }],
    drops: [d("soul_gem", 0.8, 1, 2), d("lich_crown", 0.2), d("cursed_steel", 1, 1, 3)], xp: 380,
  },
  {
    id: "hill_giant", name: "山丘巨人", terrain: { open: 3, park: 1 },
    minions: [],
    drops: [d("giant_bone", 1, 2, 4), d("giant_heart", 0.2), d("scrap_iron", 1, 4, 8)], xp: 350,
  },
  {
    id: "hydra", name: "九頭蛇", terrain: { water: 4, park: 1 },
    minions: [{ foe: "water_snake", count: 2 }],
    drops: [d("hydra_fang", 1, 1, 3), d("hydra_blood", 0.3), d("snake_scale", 1, 2, 4)], xp: 360,
  },
  {
    id: "minotaur", name: "牛頭人", terrain: { urban: 1, open: 2, forest: 1 },
    minions: [{ foe: "boar", count: 2 }],
    drops: [d("minotaur_horn", 1, 1, 2), d("labyrinth_key", 0.2), d("leather_strap", 1, 2, 4)], xp: 340,
  },
];

export interface BossSighting {
  kind: string;
  name: string;
  cell: CellId;
  region: string;
  window: number;
  startsAt: number;
  endsAt: number;
}

export function regionOf(cell: CellId): string {
  const { row, col } = parseCell(cell);
  return `${Math.floor(row / REGION_CELLS)}:${Math.floor(col / REGION_CELLS)}`;
}

export function bossWindow(at: number): number {
  return Math.floor(at / (BOSS_HOURS * 3_600_000));
}

/**
 * Whether great monsters are out at all. Off for a start (2026-09-28: the world begins with small monsters only); the
 * server turns them on with WORLD_BOSSES=on.
 */
export const BOSSES_BY_DEFAULT = false;

/** The boss of a region in a window (or none): where it stands and which one, from the seed and the ground there. */
export function bossIn(worldSeed: number, region: string, window: number, enabled = true): BossSighting | null {
  if (!enabled) return null;
  const random = seeded(worldSeed, "boss", region, window);
  if (random() >= BOSS_CHANCE) return null;
  const [r, c] = region.split(":").map(Number) as [number, number];
  const cell = cellId(r * REGION_CELLS + between(random, 3, REGION_CELLS - 4), c * REGION_CELLS + between(random, 3, REGION_CELLS - 4));
  const terrain = terrainAt(worldSeed, cell);
  const choices = BOSSES.filter((b) => (b.terrain[terrain] ?? 0) > 0);
  const kind = pickWeighted(random, choices.length ? choices : BOSSES, (b) => b.terrain[terrain] ?? 1);
  const startsAt = window * BOSS_HOURS * 3_600_000;
  return { kind: kind.id, name: kind.name, cell, region, window, startsAt, endsAt: startsAt + BOSS_HOURS * 3_600_000 };
}

/** The boss standing in `cell` at `at`, if any. */
export function bossAt(worldSeed: number, cell: CellId, at: number, enabled = true): BossSighting | null {
  const sighting = bossIn(worldSeed, regionOf(cell), bossWindow(at), enabled);
  return sighting?.cell === cell ? sighting : null;
}

export function bossKind(id: string): BossKind | undefined {
  return BOSSES.find((b) => b.id === id);
}

export function bossMaxHp(id: string): number {
  return FOES[id]?.hp ?? 500;
}

/** The boss (with the wounds it has, `hp`) and its guard, as the defenders of a fight. */
export function bossFighters(kind: BossKind, hp: number): Fighter[] {
  const foe = FOES[kind.id]!;
  const out: Fighter[] = [
    { id: "boss", name: foe.name, side: "defend", row: foe.row, hp, maxHp: foe.hp, attack: foe.attack, range: foe.range, speed: foe.speed, heal: foe.heal ?? 0, guard: 0.1, lead: 0, night: foe.night ?? 1, focus: FOE_FOCUS },
  ];
  for (const m of kind.minions) {
    const t = FOES[m.foe]!;
    for (let i = 0; i < m.count; i++) {
      out.push({ id: `guard#${out.length}`, name: t.name, side: "defend", row: t.row, hp: t.hp * 1.5, maxHp: t.hp * 1.5, attack: t.attack * 1.3, range: t.range, speed: t.speed, heal: t.heal ?? 0, guard: 0, lead: 0, night: t.night ?? 1 });
    }
  }
  return out;
}

/**
 * The spoils of a fallen boss, shared by damage: each camp's share (0…1) scales how many of each drop it gets (at least one
 * of the plainest for anybody who hurt it) and its experience. Seeded, so it can be worked out again.
 */
export function bossShares(kind: BossKind, damage: Record<string, number>, key: string): Record<string, { loot: Record<string, number>; xp: number; share: number }> {
  const total = Object.values(damage).reduce((a, b) => a + b, 0) || 1;
  const out: Record<string, { loot: Record<string, number>; xp: number; share: number }> = {};
  for (const [who, dmg] of Object.entries(damage)) {
    const share = dmg / total;
    const roll = seeded(key, who, "boss-loot");
    const loot: Record<string, number> = {};
    for (const drop of kind.drops) {
      // a bigger share rolls more often (the plainest drop always comes, at least once)
      const tries = Math.max(1, Math.round(share * 4));
      for (let i = 0; i < tries; i++) {
        if (roll() >= drop.chance) continue;
        loot[drop.id] = (loot[drop.id] ?? 0) + between(roll, drop.min, drop.max);
      }
    }
    const plain = kind.drops[0]!;
    if (!loot[plain.id]) loot[plain.id] = plain.min;
    out[who] = { loot, xp: Math.max(20, Math.round(kind.xp * share)), share };
  }
  return out;
}
