import { bossLoot, campBoss, campFoe, MONSTER_DROPS, MONSTER_VARIANTS, RACE_RANGE, residentAsFighter, SCRAP_DROPS, type GearItem, type GearSlot, type RaidPlan } from "@goblincamp/shared/camp";
import { FOES, hashString, randomFrom, residentFighter, simulateBattle, type BattleEvent, type FightBoosts, type Fighter } from "@goblincamp/shared/world";

/** How many residents go out to meet each monster (the rest keep on with their day). */
export const DEFENDERS_PER_MONSTER = 1.5;
/**
 * Raiding monsters' attack and hit points × this (residents are plain and small: shared/src/world/battle.ts). Set so a raid
 * usually costs nobody, now and then one or two, and rarely wins (server/CAMP.md §4).
 */
export const RAID_POWER = 0.7;
/** What a raid level adds (attack; hit points 1.25 × this). */
export const RAID_LEVEL_STEP = 0.05;

/** A replay longer than this is cut (the fight is still decided in full). */
const MAX_EVENTS = 1500;

export interface RaidOutcome {
  index: number;
  at: string;
  monsters: RaidPlan["monsters"];
  /** The level boss that came (its race level), and whether the camp beat it. */
  boss?: number;
  bossBeaten?: boolean;
  /** Which residents went out to fight, and who of them fell. */
  defenders: number[];
  fallen: number[];
  /** Monsters killed, by kind, and what they left. */
  killed: Record<string, number>;
  loot: Record<string, number>;
  winner: "camp" | "monsters";
  rounds: number;
  /** The fight, blow by blow, for the Mac to play (fighter ids: residents by number, monsters m0, m1…). */
  events: BattleEvent[];
  /** What broke in the fight (filled in by the camp service). */
  broken?: { resident: number; gear: string }[];
  /** Wear the fight put on what the defenders wear: resident → slot → points. */
  wear: Record<number, Partial<Record<GearSlot, number>>>;
}

const ARMOUR: GearSlot[] = ["head", "chest", "chest", "legs", "feet", "hands"];

/**
 * A bigger camp draws tougher monsters: level 1 up to 59 residents, then one more level every 60 (like a lair's level); and
 * one more every four race levels (big world, DESKTOP.md §10.0).
 */
export function raidLevel(residents: number, raceLevel = 1): number {
  return 1 + Math.floor(residents / 60) + Math.floor(Math.max(0, raceLevel) / 4);
}

/** What the camp brings to a raid besides its residents: the 守營 talent's attack, the 營地之心's loot, and its special residents. */
export interface RaidHelp {
  /** Residents' attack × (1 + this). */
  attack?: number;
  /** Monsters' hit points × (1 − this). */
  weaken?: number;
  /** Loot × (1 + this). */
  loot?: number;
}

/** Defenders a boss draws, as if it were this many monsters. */
const BOSS_DRAWS = 8;

function monsterFighters(plan: RaidPlan, level: number, weaken = 0): { fighters: Fighter[]; kinds: string[] } {
  // (a level adds less than a lair's: a big camp meets more monsters, not much tougher ones)
  const hpScale = (1 + RAID_LEVEL_STEP * 1.25 * (level - 1)) * RAID_POWER;
  const attackScale = (1 + RAID_LEVEL_STEP * (level - 1)) * RAID_POWER;
  const fighters: Fighter[] = [];
  const kinds: string[] = [];
  const add = (id: string, foe: { name: string; hp: number; attack: number; range: number; speed: number; row: "front" | "back"; heal?: number; night?: number }, hpTimes: number, attackTimes: number) => {
    const hp = Math.max(1, Math.round(foe.hp * hpScale * hpTimes * (1 - weaken)));
    fighters.push({
      id: `m${fighters.length}`,
      name: foe.name,
      side: "attack",
      row: foe.row,
      hp,
      maxHp: hp,
      attack: foe.attack * attackScale * attackTimes,
      range: foe.range,
      speed: foe.speed,
      heal: foe.heal ?? 0,
      guard: 0,
      lead: 0,
      night: foe.night ?? 1,
      // (no focus: monsters blundering into a camp lash out at whoever is near — BALANCE.md: raids seldom kill)
    });
    kinds.push(id);
  };
  for (const { id, count, variant } of plan.monsters) {
    const foe = campFoe(id) ?? FOES[id];
    if (!foe) throw new Error(`unknown monster ${id}`);
    const v = variant ? MONSTER_VARIANTS[variant] : null;
    for (let i = 0; i < count; i++) add(id, v ? { ...foe, name: `${v.name}${foe.name}` } : foe, v?.hp ?? 1, v?.attack ?? 1);
  }
  // (the level boss: its own numbers, not the raid's power cut, only the camp's weakening)
  if (plan.boss) {
    const boss = campBoss(plan.boss);
    add(`boss:${boss.id}`, boss, 1 / RAID_POWER, 1 / RAID_POWER);
  }
  return { fighters, kinds };
}

/**
 * Fights raid `plan` out: one and a half residents per monster go out (picked from the seed), the battle rules decide it,
 * and every monster that falls rolls its drops (and the scraps any monster may leave).
 */
export function resolveRaid(
  race: string,
  campSeed: number,
  plan: RaidPlan,
  alive: readonly { id: number; breed: string; gear?: Partial<Record<GearSlot, GearItem>> | null }[],
  boosts: FightBoosts = {},
  raceLevel = 1,
  help: RaidHelp = {},
): RaidOutcome {
  const { fighters: monsters, kinds } = monsterFighters(plan, raidLevel(alive.length, raceLevel), help.weaken ?? 0);
  const pick = randomFrom(hashString(`${campSeed}|raid-defenders|${plan.index}`));
  const pool = [...alive];
  for (let i = pool.length - 1; i > 0; i--) {
    const j = Math.floor(pick() * (i + 1));
    [pool[i], pool[j]] = [pool[j]!, pool[i]!];
  }
  const defenders = pool.slice(0, Math.min(pool.length, Math.ceil((monsters.length + (plan.boss ? BOSS_DRAWS - 1 : 0)) * DEFENDERS_PER_MONSTER)));
  const traits = { id: race, ranged: RACE_RANGE[race] ?? 0 };
  const defending = defenders.map((r) => {
    const f = residentFighter(residentAsFighter(race, r), "defend", traits, boosts);
    return help.attack ? { ...f, attack: f.attack * (1 + help.attack) } : f;
  });

  const battle = simulateBattle(monsters, defending, { seed: hashString(`${campSeed}|raid-battle|${plan.index}`) });

  const killed: Record<string, number> = {};
  const loot: Record<string, number> = {};
  const roll = randomFrom(hashString(`${campSeed}|raid-loot|${plan.index}`));
  const more = 1 + (help.loot ?? 0);
  let bossBeaten = false;
  for (const id of battle.fallen.attack) {
    const kind = kinds[Number(id.slice(1))]!;
    if (kind.startsWith("boss:")) {
      bossBeaten = true;
      for (const [mat, n] of Object.entries(bossLoot(plan.boss!))) loot[mat] = (loot[mat] ?? 0) + Math.round(n * more);
      continue;
    }
    killed[kind] = (killed[kind] ?? 0) + 1;
    for (const drop of [...(MONSTER_DROPS[kind] ?? []), ...SCRAP_DROPS]) {
      if (roll() >= drop.chance) continue;
      const n = drop.min + Math.floor(roll() * (drop.max - drop.min + 1));
      loot[drop.id] = (loot[drop.id] ?? 0) + (more > 1 ? Math.round(n * more) : n);
    }
  }
  // wear: a weapon one point per blow it strikes; for each hit taken, the shield and one piece of armour (as on the Mac)
  const wear: Record<number, Partial<Record<GearSlot, number>>> = {};
  const wearRoll = randomFrom(hashString(`${campSeed}|raid-wear|${plan.index}`));
  const byId = new Map(defenders.map((r) => [String(r.id), r]));
  const add = (id: number, slot: GearSlot, n: number) => ((wear[id] ??= {})[slot] = ((wear[id] ??= {})[slot] ?? 0) + n);
  for (const e of battle.events) {
    const striker = byId.get(e.actor);
    if (striker?.gear?.weapon && (e.kind === "hit" || e.kind === "miss")) add(striker.id, "weapon", 1);
    const struck = byId.get(e.target);
    if (struck && e.kind === "hit") {
      if (struck.gear?.shield) add(struck.id, "shield", 1);
      const worn = ARMOUR.filter((slot) => struck.gear?.[slot]);
      if (worn.length) add(struck.id, worn[Math.floor(wearRoll() * worn.length)]!, 1);
    }
  }
  return {
    wear,
    index: plan.index,
    at: new Date(plan.at).toISOString(),
    monsters: plan.monsters,
    ...(plan.boss ? { boss: plan.boss, bossBeaten } : {}),
    defenders: defenders.map((r) => r.id),
    fallen: battle.fallen.defend.map(Number),
    killed,
    loot,
    winner: battle.winner === "defend" ? "camp" : "monsters",
    rounds: battle.rounds,
    events: battle.events.slice(0, MAX_EVENTS),
  };
}
