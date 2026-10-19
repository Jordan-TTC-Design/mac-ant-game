/**
 * 換族 (RACES_SWITCH.md): a camp of race level 10 or more may become another race. It hurts but does not start over: the
 * level, the residents and the land beyond the camp's own ring shrink, and it costs materials (by the level) and five of
 * the new race's 信物, dropped by the lairs that have to do with that race. The first switch of an account is lighter.
 */
import { RACES, type RaceId } from "../camp/races.ts";
import type { Random } from "./random.ts";

export const RACE_SWITCH = {
  /** The race level a camp needs to switch. */
  minLevel: 10,
  /** Days after a switch before the next. */
  cooldownDays: 14,
  /** 信物 of the new race a switch takes. */
  tokens: 5,
} as const;

/**
 * A cleared lair of the right kind drops a 信物 this often, by the lair's level (only for camps of minLevel or more, never
 * their own race's): the small ones many times over, the tougher ones fewer times — five take about 33 level 1–3 clears,
 * 17 of level 4–6, or 10 of level 7 and up.
 */
export function tokenChance(lairLevel: number): number {
  return lairLevel >= 7 ? 0.5 : lairLevel >= 4 ? 0.3 : 0.15;
}

export interface RaceToken {
  /** The material (drops.ts MATERIALS). */
  id: string;
  /** The lairs (contents.ts kinds) that drop it. */
  lairs: readonly string[];
}

/** Lairs of level 1 to 3 first (what most of the world is), then the tougher one of the same theme. */
export const RACE_TOKENS: Record<RaceId, RaceToken> = {
  goblin: { id: "token_goblin", lairs: ["highway_robbers", "robber_chief_camp", "orc_patrol", "barbarian_camp", "bandit_hideout", "orc_warband"] },
  elf: { id: "token_elf", lairs: ["mushroom_ring", "treant_grove"] },
  undead: { id: "token_undead", lairs: ["giant_bat_roost", "bat_cave", "crypt"] },
  beast: { id: "token_beast", lairs: ["wolf_den", "dire_wolf_den", "bear_cave"] },
};

/** Materials a switch costs at a race level (the first switch: half, rounded up). */
export function raceSwitchCost(level: number, first: boolean): Record<string, number> {
  const full =
    level >= 20
      ? { log: 10000, stone: 10000, crystal_shard: 50, amber: 15 }
      : level >= 15
        ? { log: 6000, stone: 6000, crystal_shard: 30, amber: 8 }
        : { log: 3000, stone: 3000, crystal_shard: 15, amber: 3 };
  return Object.fromEntries(Object.entries(full).map(([id, n]) => [id, first ? Math.ceil(n / 2) : n]));
}

/** Everything a switch to `race` takes: the materials and its 信物. */
export function raceSwitchPrice(level: number, first: boolean, race: RaceId): Record<string, number> {
  return { ...raceSwitchCost(level, first), [RACE_TOKENS[race].id]: RACE_SWITCH.tokens };
}

/** What is lost: the first switch takes a fifth of the level, a quarter of the residents and a sixth of the far land; later ones twice that. */
export function raceSwitchLoss(first: boolean) {
  return first ? { level: 1 / 5, residents: 1 / 4, cells: 1 / 6 } : { level: 2 / 5, residents: 1 / 2, cells: 1 / 3 };
}

/** The race level after a switch (the loss rounded down: Lv20 → 12, Lv10 → 6; the first: Lv20 → 16, Lv10 → 8). */
export function levelAfterSwitch(level: number, first: boolean): number {
  return Math.max(1, level - Math.floor(level * raceSwitchLoss(first).level));
}

/** Of `n` residents in one place, how many stay (the loss rounded down, so a lone one stays). */
export function residentsKept(n: number, first: boolean): number {
  return n - Math.floor(n * raceSwitchLoss(first).residents);
}

/** Of `n` cells beyond the camp's own ring, how many are given up (rounded down: 9 → 3, 2 → 0). */
export function cellsLost(n: number, first: boolean): number {
  return Math.floor(n * raceSwitchLoss(first).cells);
}

/** `count` of `items` picked at random (the same `random` picks the same). */
export function pickSome<T>(items: readonly T[], count: number, random: Random): T[] {
  const pool = [...items];
  for (let i = pool.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [pool[i], pool[j]] = [pool[j]!, pool[i]!];
  }
  return pool.slice(0, Math.max(0, count));
}

/** When the camp may switch again (null: now, as far as the cooldown goes). */
export function raceSwitchReadyAt(switchedAt: Date | null): Date | null {
  return switchedAt ? new Date(switchedAt.getTime() + RACE_SWITCH.cooldownDays * 86_400_000) : null;
}

/** Why the camp cannot switch to `to` now (null: it can). */
export function raceSwitchProblem(o: {
  race: string;
  to: string;
  level: number;
  switchedAt: Date | null;
  now: Date;
  materials: Record<string, number>;
  switches: number;
  /** Parties of the camp on the road. */
  travelling: number;
}): string | null {
  if (!(RACES as readonly string[]).includes(o.to)) return "沒有這個種族。";
  if (o.to === o.race) return "已經是這個種族了。";
  if (o.level < RACE_SWITCH.minLevel) return `種族要 ${RACE_SWITCH.minLevel} 級以上才能換（現在 ${o.level} 級）。`;
  const ready = raceSwitchReadyAt(o.switchedAt);
  if (ready && ready > o.now) return `換族之後要 ${RACE_SWITCH.cooldownDays} 天才能再換（${ready.toISOString()} 之後）。`;
  if (o.travelling > 0) return "還有隊伍在路上：等它們到了，或先撤回再換。";
  const price = raceSwitchPrice(o.level, o.switches === 0, o.to as RaceId);
  const short = Object.entries(price).filter(([id, n]) => (o.materials[id] ?? 0) < n);
  if (short.length) return "素材或信物不夠。";
  return null;
}

/** The 信物 a cleared lair drops for a camp (null: none this time). */
export function raceTokenDrop(lairKind: string, campRace: string, level: number, random: Random, lairLevel = 1): string | null {
  if (level < RACE_SWITCH.minLevel) return null;
  for (const race of RACES) {
    if (race === campRace || !RACE_TOKENS[race].lairs.includes(lairKind)) continue;
    return random() < tokenChance(lairLevel) ? RACE_TOKENS[race].id : null;
  }
  return null;
}
