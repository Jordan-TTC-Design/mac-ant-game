import { MONSTER_DROPS, RACE_RANGE, residentAsFighter, SCRAP_DROPS, type RaidPlan } from "@goblincamp/shared/camp";
import { FOES, hashString, randomFrom, residentFighter, simulateBattle, type BattleEvent, type Fighter } from "@goblincamp/shared/world";

/** How many residents go out to meet each monster (the rest keep on with their day). */
export const DEFENDERS_PER_MONSTER = 1.5;

/** A replay longer than this is cut (the fight is still decided in full). */
const MAX_EVENTS = 1500;

export interface RaidOutcome {
  index: number;
  at: string;
  monsters: { id: string; count: number }[];
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
}

/** A bigger camp draws tougher monsters: level 1 up to 59 residents, then one more level every 60 (like a lair's level). */
export function raidLevel(residents: number): number {
  return 1 + Math.floor(residents / 60);
}

function monsterFighters(plan: RaidPlan, level: number): { fighters: Fighter[]; kinds: string[] } {
  const hpScale = 1 + 0.25 * (level - 1);
  const attackScale = 1 + 0.2 * (level - 1);
  const fighters: Fighter[] = [];
  const kinds: string[] = [];
  for (const { id, count } of plan.monsters) {
    const foe = FOES[id];
    if (!foe) throw new Error(`unknown monster ${id}`);
    for (let i = 0; i < count; i++) {
      fighters.push({
        id: `m${fighters.length}`,
        name: foe.name,
        side: "attack",
        row: foe.row,
        hp: Math.round(foe.hp * hpScale),
        maxHp: Math.round(foe.hp * hpScale),
        attack: foe.attack * attackScale,
        range: foe.range,
        speed: foe.speed,
        heal: foe.heal ?? 0,
        guard: 0,
        lead: 0,
        night: foe.night ?? 1,
      });
      kinds.push(id);
    }
  }
  return { fighters, kinds };
}

/**
 * Fights raid `plan` out: one and a half residents per monster go out (picked from the seed), the battle rules decide it,
 * and every monster that falls rolls its drops (and the scraps any monster may leave).
 */
export function resolveRaid(race: string, campSeed: number, plan: RaidPlan, alive: readonly { id: number; breed: string }[]): RaidOutcome {
  const { fighters: monsters, kinds } = monsterFighters(plan, raidLevel(alive.length));
  const pick = randomFrom(hashString(`${campSeed}|raid-defenders|${plan.index}`));
  const pool = [...alive];
  for (let i = pool.length - 1; i > 0; i--) {
    const j = Math.floor(pick() * (i + 1));
    [pool[i], pool[j]] = [pool[j]!, pool[i]!];
  }
  const defenders = pool.slice(0, Math.min(pool.length, Math.ceil(monsters.length * DEFENDERS_PER_MONSTER)));
  const traits = { id: race, ranged: RACE_RANGE[race] ?? 0 };
  const defending = defenders.map((r) => residentFighter(residentAsFighter(race, r), "defend", traits));

  const battle = simulateBattle(monsters, defending, { seed: hashString(`${campSeed}|raid-battle|${plan.index}`) });

  const killed: Record<string, number> = {};
  const loot: Record<string, number> = {};
  const roll = randomFrom(hashString(`${campSeed}|raid-loot|${plan.index}`));
  for (const id of battle.fallen.attack) {
    const kind = kinds[Number(id.slice(1))]!;
    killed[kind] = (killed[kind] ?? 0) + 1;
    for (const drop of [...(MONSTER_DROPS[kind] ?? []), ...SCRAP_DROPS]) {
      if (roll() >= drop.chance) continue;
      loot[drop.id] = (loot[drop.id] ?? 0) + drop.min + Math.floor(roll() * (drop.max - drop.min + 1));
    }
  }
  return {
    index: plan.index,
    at: new Date(plan.at).toISOString(),
    monsters: plan.monsters,
    defenders: defenders.map((r) => r.id),
    fallen: battle.fallen.defend.map(Number),
    killed,
    loot,
    winner: battle.winner === "defend" ? "camp" : "monsters",
    rounds: battle.rounds,
    events: battle.events.slice(0, MAX_EVENTS),
  };
}
