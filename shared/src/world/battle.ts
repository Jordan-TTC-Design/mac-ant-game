/**
 * A battle in the big world, worked out on the server (the one set of battle rules; the Macs only play the record back).
 * Nobody controls it while it runs: a party sets out, arrives, and the fight is simulated from a seed, so it can be replayed
 * exactly. Each round every fighter still standing acts once, the quickest first:
 *   - a healer patches up the most hurt of its side (if anyone is hurt enough), otherwise attacks;
 *   - someone who fights up close can only reach the enemy's front row while anyone is left in it;
 *   - someone who shoots (range > 0) can hit anyone, and goes for the weakest it can see;
 *   - a leader (the rare breed: 金皮, 銀月精靈…) makes its whole side hit harder while it stands.
 * The attackers win when every defender is down; if they are all down, or the fight runs out of rounds, the defenders hold.
 */
import { FOES } from "./contents.ts";
import type { Lair } from "./contents.ts";
import { randomFrom, type Random } from "./random.ts";

export type Side = "attack" | "defend";

export interface Fighter {
  id: string;
  name: string;
  side: Side;
  row: "front" | "back";
  hp: number;
  maxHp: number;
  attack: number;
  /** 0 = up close; more = shoots from the back row. */
  range: number;
  speed: number;
  /** Heals this much a round instead of attacking. */
  heal: number;
  /** Hits taken are cut by this share (cheese, armour). */
  guard: number;
  /** Adds this share to its whole side's attack while it stands (capped, see LEAD_CAP). */
  lead: number;
  /** Attack × this at night (the dark ones). */
  night: number;
}

/** A resident as the camp knows it (the numbers are its breed's stats; see RACES.md and the Mac's manifests). */
export interface Resident {
  id: string;
  name: string;
  /** Breed id: common, scout, brute, sage, golden, half_gob, half_mix, half_hum. */
  breed: string;
  might: number;
  health: number;
  speed: number;
  /** Extra attack and reach from what it wears (weapon), and a share of blows turned aside (shield). */
  gearAttack?: number;
  gearReach?: number;
  gearGuard?: number;
}

/** The camp-wide things that change how its residents fight. */
export interface RaceTraits {
  /** The race's character id (goblin, elf, undead): its numbers for holding land (camp/races.ts). Missing = goblin. */
  id?: string;
  /** Extra reach of the whole race (the elves shoot: 34). 0 = they fight up close. */
  ranged: number;
}

/** How strongly each food boost is on (0…1.5, as the Mac's `Colony.boost` gives it, already scaled for the race). */
export interface FightBoosts {
  meat?: number;
  cheese?: number;
  carrot?: number;
}

export const HP_PER_HEALTH = 10;
export const ATTACK_PER_MIGHT = 6;
export const LEAD_PER_LEADER = 0.1;
export const LEAD_CAP = 0.3;
export const HIT_CHANCE = 0.85;
export const MAX_ROUNDS = 60;
/** Healers only bother when someone is below this share of their health. */
const HEAL_BELOW = 0.8;

/** A resident as a fighter. Front row: the sturdy ones (and everyone of a race that fights up close, except its healers). */
export function residentFighter(r: Resident, side: Side, race: RaceTraits, boosts: FightBoosts = {}): Fighter {
  const healer = r.breed === "sage";
  const leader = r.breed === "golden";
  const sturdy = r.breed === "brute" || r.breed === "half_hum";
  const shooter = race.ranged > 0 && !sturdy;
  const range = shooter ? race.ranged + (r.gearReach ?? 0) : (r.gearReach ?? 0);
  return {
    id: r.id,
    name: r.name,
    side,
    row: healer || range > 0 ? "back" : "front",
    hp: r.health * HP_PER_HEALTH,
    maxHp: r.health * HP_PER_HEALTH,
    attack: (r.might * ATTACK_PER_MIGHT + (r.gearAttack ?? 0)) * (1 + 0.2 * (boosts.meat ?? 0)),
    range,
    speed: r.speed * (1 + 0.15 * (boosts.carrot ?? 0)),
    heal: healer ? Math.round(r.might * 5) : 0,
    guard: Math.min(0.6, (r.gearGuard ?? 0) + 0.2 * (boosts.cheese ?? 0)),
    lead: leader ? LEAD_PER_LEADER : 0,
    night: 1,
  };
}

/** A lair's foes as fighters (the defenders), made stronger by its level. */
export function lairFighters(lair: Lair): Fighter[] {
  const hpScale = 1 + 0.25 * (lair.level - 1);
  const attackScale = 1 + 0.2 * (lair.level - 1);
  return lair.foes.map((id, i) => {
    const foe = FOES[id];
    if (!foe) throw new Error(`unknown foe ${id}`);
    return {
      id: `${lair.cell}#${i}`,
      name: foe.name,
      side: "defend" as const,
      row: foe.row,
      hp: Math.round(foe.hp * hpScale),
      maxHp: Math.round(foe.hp * hpScale),
      attack: foe.attack * attackScale,
      range: foe.range,
      speed: foe.speed,
      heal: Math.round((foe.heal ?? 0) * attackScale),
      guard: 0,
      lead: 0,
      night: foe.night ?? 1,
    };
  });
}

export type BattleEventKind = "hit" | "miss" | "heal" | "down";

/** One thing that happened, for the replay: in round `round`, `actor` did `kind` to `target`. */
export interface BattleEvent {
  round: number;
  actor: string;
  target: string;
  kind: BattleEventKind;
  amount?: number;
}

export interface BattleResult {
  winner: Side;
  rounds: number;
  events: BattleEvent[];
  /** Who is still standing and who fell, by id. */
  standing: Record<Side, string[]>;
  fallen: Record<Side, string[]>;
  /** Health left, by id (for the wounded who walk home). */
  hpLeft: Record<string, number>;
}

export interface BattleOptions {
  seed: number;
  night?: boolean;
  maxRounds?: number;
}

function leadOf(fighters: Fighter[], side: Side): number {
  return Math.min(LEAD_CAP, fighters.filter((f) => f.side === side && f.hp > 0).reduce((sum, f) => sum + f.lead, 0));
}

function pickTarget(actor: Fighter, enemies: Fighter[], random: Random): Fighter | undefined {
  const alive = enemies.filter((f) => f.hp > 0);
  if (alive.length === 0) return undefined;
  if (actor.range > 0) {
    // shooters go for the weakest few they can see
    const weakest = [...alive].sort((a, b) => a.hp - b.hp).slice(0, 3);
    return weakest[Math.floor(random() * weakest.length)];
  }
  const front = alive.filter((f) => f.row === "front");
  const reachable = front.length > 0 ? front : alive;
  return reachable[Math.floor(random() * reachable.length)];
}

export function simulateBattle(attackers: Fighter[], defenders: Fighter[], options: BattleOptions): BattleResult {
  const random = randomFrom(options.seed);
  const maxRounds = options.maxRounds ?? MAX_ROUNDS;
  const all = [...attackers, ...defenders].map((f) => ({ ...f }));
  const events: BattleEvent[] = [];
  const alive = (side: Side) => all.some((f) => f.side === side && f.hp > 0);
  let round = 0;
  while (round < maxRounds && alive("attack") && alive("defend")) {
    round++;
    // the quickest act first; a little luck breaks ties and keeps it from being the same every round
    const order = all.filter((f) => f.hp > 0).map((f) => ({ f, key: f.speed + random() * 0.2 })).sort((a, b) => b.key - a.key);
    for (const { f: actor } of order) {
      if (actor.hp <= 0) continue;
      const own = all.filter((f) => f.side === actor.side);
      const enemies = all.filter((f) => f.side !== actor.side);
      if (enemies.every((f) => f.hp <= 0)) break;
      if (actor.heal > 0) {
        const hurt = own.filter((f) => f.hp > 0 && f.hp < f.maxHp * HEAL_BELOW).sort((a, b) => a.hp / a.maxHp - b.hp / b.maxHp)[0];
        if (hurt) {
          const amount = Math.min(actor.heal, hurt.maxHp - hurt.hp);
          hurt.hp += amount;
          events.push({ round, actor: actor.id, target: hurt.id, kind: "heal", amount });
          continue;
        }
      }
      const target = pickTarget(actor, enemies, random);
      if (!target) break;
      if (random() >= HIT_CHANCE) {
        events.push({ round, actor: actor.id, target: target.id, kind: "miss" });
        continue;
      }
      const power = actor.attack * (1 + leadOf(all, actor.side)) * (options.night ? actor.night : 1) * (0.8 + random() * 0.4);
      const amount = Math.max(1, Math.round(power * (1 - target.guard)));
      target.hp = Math.max(0, target.hp - amount);
      events.push({ round, actor: actor.id, target: target.id, kind: "hit", amount });
      if (target.hp === 0) events.push({ round, actor: actor.id, target: target.id, kind: "down" });
    }
  }
  const winner: Side = alive("defend") ? "defend" : "attack";
  const ids = (side: Side, standing: boolean) => all.filter((f) => f.side === side && (f.hp > 0) === standing).map((f) => f.id);
  return {
    winner,
    rounds: round,
    events,
    standing: { attack: ids("attack", true), defend: ids("defend", true) },
    fallen: { attack: ids("attack", false), defend: ids("defend", false) },
    hpLeft: Object.fromEntries(all.map((f) => [f.id, f.hp])),
  };
}

/** How strong a group is, as one number (for the leaderboard and for "is this lair too much for us?"). */
export function combatPower(fighters: Fighter[]): number {
  const lead = 1 + Math.min(LEAD_CAP, fighters.reduce((sum, f) => sum + f.lead, 0));
  const sum = fighters.reduce((total, f) => total + (f.attack * lead + f.heal) * f.maxHp * (1 + f.guard) * (f.range > 0 ? 1.2 : 1), 0);
  return Math.round(sum / 10);
}
