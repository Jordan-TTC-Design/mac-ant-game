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
  /** 狂化: once it is down to RAGE_BELOW of its hit points it goes berserk — attack +this share, and quicker (a 初期魔王). */
  rage?: number;
  /**
   * How set it is on one foe (0…1): the chance a fighter up close keeps hitting the one it hit last. Residents fight
   * together (RESIDENT_FOCUS), beasts of little wit less so (FOE_FOCUS), a berserker not at all; left out, none (every blow
   * at someone new, as fights were before 2026-09-29, when a small party could lose without felling anyone).
   */
  focus?: number;
}

export const RESIDENT_FOCUS = 0.7;
export const FOE_FOCUS = 0.4;

/** A berserker goes wild below this share of its hit points, and acts this much quicker then. */
export const RAGE_BELOW = 0.5;
export const RAGE_SPEED = 1.25;

/** A resident as the camp knows it (the numbers are its breed's stats; see RACES.md and the Mac's manifests). */
export interface Resident {
  id: string;
  name: string;
  /** Breed id: common, scout, brute, sage, golden, half_gob, half_mix, half_hum. */
  breed: string;
  might: number;
  health: number;
  speed: number;
  /** Extra attack and reach from what it wears (weapon), extra hit points (armour), and a share of blows turned aside (shield). */
  gearAttack?: number;
  gearHp?: number;
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
  /** Hit points +20% (honey taken along). */
  honey?: number;
  /** Hit points +this share: defending a cell with a watchtower or near a temple (holdings.ts). */
  fort?: number;
  /** 道具 taken along (supplies.ts ITEMS): 蜂王漿 attack and hit points +10%; 草藥繃帶 hits taken −10%; 黏黏彈 the foes 25%
   * slower (sticky: see slowed); 幸運符 more loot and 夜光燈籠 no night for the dark ones (both worked out by the server). */
  tonic?: number;
  bandage?: number;
  sticky?: number;
  luck?: number;
  lantern?: number;
}

/** The foes a party with 黏黏彈 meets: a quarter slower. */
export function slowed(foes: Fighter[], boosts: FightBoosts | null | undefined): Fighter[] {
  return boosts?.sticky ? foes.map((f) => ({ ...f, speed: f.speed * 0.75 })) : foes;
}

/**
 * A resident's own numbers are small (a plain one is about a match for one wild rabbit, server/WORLD.md §19); what it wears
 * counts in full on top (GEAR_…), so gear is the way to grow strong.
 */
export const HP_PER_HEALTH = 5;
export const ATTACK_PER_MIGHT = 2.4;
export const GEAR_HP_PER_HEALTH = 6;
export const GEAR_ATTACK_PER_MIGHT = 3.5;
/** The wild's foes are this much stronger (attack and hit points) than their listed numbers. */
export const FOE_POWER = 1.6;
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
    hp: Math.round((r.health * HP_PER_HEALTH + (r.gearHp ?? 0)) * (1 + 0.2 * (boosts.honey ?? 0) + (boosts.fort ?? 0) + 0.1 * (boosts.tonic ?? 0))),
    maxHp: Math.round((r.health * HP_PER_HEALTH + (r.gearHp ?? 0)) * (1 + 0.2 * (boosts.honey ?? 0) + (boosts.fort ?? 0) + 0.1 * (boosts.tonic ?? 0))),
    attack: (r.might * ATTACK_PER_MIGHT + (r.gearAttack ?? 0)) * (1 + 0.2 * (boosts.meat ?? 0) + 0.1 * (boosts.tonic ?? 0)),
    range,
    speed: r.speed * (1 + 0.15 * (boosts.carrot ?? 0)),
    heal: healer ? Math.round(r.might * 5) : 0,
    guard: Math.min(0.6, (r.gearGuard ?? 0) + 0.2 * (boosts.cheese ?? 0) + 0.1 * (boosts.bandage ?? 0)),
    lead: leader ? LEAD_PER_LEADER : 0,
    night: 1,
    focus: RESIDENT_FOCUS,
  };
}

/** A lair's foes as fighters (the defenders), made stronger by its level. */
export function lairFighters(lair: Lair): Fighter[] {
  const hpScale = (1 + 0.25 * (lair.level - 1)) * FOE_POWER;
  const attackScale = (1 + 0.2 * (lair.level - 1)) * FOE_POWER;
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
      focus: FOE_FOCUS,
      ...(foe.rage ? { rage: foe.rage } : {}),
      range: foe.range,
      speed: foe.speed,
      heal: Math.round((foe.heal ?? 0) * attackScale),
      guard: 0,
      lead: 0,
      night: foe.night ?? 1,
    };
  });
}

/**
 * A lair that beat a party off keeps its wounds for a while (server/WORLD.md §19), so a second wave sent soon after meets
 * it weaker: each foe's hit points as the fight left them (0: down), and when.
 */
export interface LairWounds {
  hp: number[];
  at: number;
}
/** Hurt foes get back this share of their hit points every LAIR_HEAL_MINUTES; foes that went down come back after LAIR_BACK_MINUTES. */
export const LAIR_HEAL_SHARE = 0.1;
export const LAIR_HEAL_MINUTES = 10;
export const LAIR_BACK_MINUTES = 30;

/** A lair's foes as they stand at `now`, wounds and all (the ones still down are left out). */
export function woundedLairFighters(lair: Lair, wounds: LairWounds | null | undefined, now: number): Fighter[] {
  const fresh = lairFighters(lair);
  if (!wounds) return fresh;
  const minutes = Math.max(0, (now - wounds.at) / 60_000);
  const healed = Math.floor(minutes / LAIR_HEAL_MINUTES) * LAIR_HEAL_SHARE;
  return fresh.flatMap((f, i) => {
    const left = wounds.hp[i] ?? f.maxHp;
    if (left <= 0) return minutes >= LAIR_BACK_MINUTES ? [f] : [];
    return [{ ...f, hp: Math.min(f.maxHp, Math.round(left + f.maxHp * healed)) }];
  });
}

/** When a wounded lair is whole again (ms), and how it stands now: foes up, of how many, and the share of its hit points left. */
export function lairWoundsView(lair: Lair, wounds: LairWounds, now: number): { healedAt: number; standing: number; total: number; hpShare: number } {
  const fresh = lairFighters(lair);
  let last = wounds.at + LAIR_BACK_MINUTES * 60_000 * (wounds.hp.some((h) => h <= 0) ? 1 : 0);
  fresh.forEach((f, i) => {
    const left = wounds.hp[i] ?? f.maxHp;
    if (left > 0 && left < f.maxHp) last = Math.max(last, wounds.at + Math.ceil((f.maxHp - left) / (f.maxHp * LAIR_HEAL_SHARE)) * LAIR_HEAL_MINUTES * 60_000);
  });
  const now_ = woundedLairFighters(lair, wounds, now);
  const max = fresh.reduce((s, f) => s + f.maxHp, 0);
  return { healedAt: last, standing: now_.length, total: fresh.length, hpShare: now_.reduce((s, f) => s + f.hp, 0) / Math.max(1, max) };
}

export type BattleEventKind = "hit" | "miss" | "heal" | "down" | "rage";

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

function pickTarget(actor: Fighter, enemies: Fighter[], random: Random, last?: Fighter, focus = 0): Fighter | undefined {
  const alive = enemies.filter((f) => f.hp > 0);
  if (alive.length === 0) return undefined;
  if (actor.range > 0) {
    // shooters go for the weakest few they can see
    const weakest = [...alive].sort((a, b) => a.hp - b.hp).slice(0, 3);
    return weakest[Math.floor(random() * weakest.length)];
  }
  const front = alive.filter((f) => f.row === "front");
  const reachable = front.length > 0 ? front : alive;
  if (focus > 0) {
    // one set on its foe keeps at it; else, as often as it is set, it goes for one already hurt (a few of the most hurt)
    if (last && last.hp > 0 && reachable.includes(last) && random() < focus) return last;
    if (random() < focus) {
      const hurt = [...reachable].sort((a, b) => a.hp / a.maxHp - b.hp / b.maxHp).slice(0, 3);
      return hurt[Math.floor(random() * hurt.length)];
    }
  }
  return reachable[Math.floor(random() * reachable.length)];
}

export function simulateBattle(attackers: Fighter[], defenders: Fighter[], options: BattleOptions): BattleResult {
  const random = randomFrom(options.seed);
  const maxRounds = options.maxRounds ?? MAX_ROUNDS;
  const all = [...attackers, ...defenders].map((f) => ({ ...f, raging: false, last: undefined as Fighter | undefined }));
  const events: BattleEvent[] = [];
  const alive = (side: Side) => all.some((f) => f.side === side && f.hp > 0);
  let round = 0;
  while (round < maxRounds && alive("attack") && alive("defend")) {
    round++;
    // the quickest act first; a little luck breaks ties and keeps it from being the same every round
    const order = all
      .filter((f) => f.hp > 0)
      .map((f) => ({ f, key: f.speed * (f.raging ? RAGE_SPEED : 1) + random() * 0.2 }))
      .sort((a, b) => b.key - a.key);
    for (const { f: actor } of order) {
      if (actor.hp <= 0) continue;
      // a berserker, badly hurt, goes wild
      if (actor.rage && !actor.raging && actor.hp < actor.maxHp * RAGE_BELOW) {
        actor.raging = true;
        events.push({ round, actor: actor.id, target: actor.id, kind: "rage" });
      }
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
      // (a berserker lashes out at anyone)
      const target = pickTarget(actor, enemies, random, actor.last, actor.raging ? 0 : (actor.focus ?? 0));
      if (!target) break;
      actor.last = target;
      if (random() >= HIT_CHANCE) {
        events.push({ round, actor: actor.id, target: target.id, kind: "miss" });
        continue;
      }
      const power = actor.attack * (actor.raging ? 1 + (actor.rage ?? 0) : 1) * (1 + leadOf(all, actor.side)) * (options.night ? actor.night : 1) * (0.8 + random() * 0.4);
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

/**
 * How strong a group is, as one number (for the leaderboard and for "is this lair too much for us?"): the square root of
 * all its hitting times all its hit points, since a group's blows and its staying power grow together (twice as many is
 * twice as strong; one alone is √(attack × hp)). Shooters count a little more (they are hit last), the quick ones too
 * (+30% of how much quicker than 1 they are), and a shield's share of blows turned aside as the hit points it saves.
 */
export function combatPower(fighters: Fighter[]): number {
  if (fighters.length === 0) return 0;
  const lead = 1 + Math.min(LEAD_CAP, fighters.reduce((sum, f) => sum + f.lead, 0));
  // (quicker ones strike first and more often before they fall; a share of blows turned aside makes hit points last longer)
  // (a berserker is wild for about half the fight)
  const hitting = fighters.reduce((total, f) => total + (f.attack * (1 + (f.rage ?? 0) / 2) * lead + f.heal) * (f.range > 0 ? 1.1 : 1) * (1 + 0.3 * (f.speed - 1)), 0);
  const lasting = fighters.reduce((total, f) => total + f.hp / (1 - Math.min(0.6, f.guard)), 0);
  return Math.round(Math.sqrt(hitting * lasting));
}

/**
 * The chance a party wins, by fighting it out `runs` times with different luck (what the dispatch dialog shows), and how
 * many of the party fall on average.
 */
export function estimateBattle(attackers: Fighter[], defenders: Fighter[], runs = 40, night = false): { win: number; fallen: number; killed: number } {
  if (attackers.length === 0) return { win: 0, fallen: 0, killed: 0 };
  let wins = 0, fallen = 0, killed = 0;
  for (let i = 0; i < runs; i++) {
    const result = simulateBattle(attackers, defenders, { seed: 7919 * (i + 1), night });
    if (result.winner === "attack") wins++;
    fallen += result.fallen.attack.length;
    killed += result.fallen.defend.length;
  }
  return { win: wins / runs, fallen: fallen / runs, killed: killed / runs };
}
