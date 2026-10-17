/**
 * Births and deaths over time (server/CAMP.md §3.1), for the home camp and for a nest on a held cell alike.
 *
 * Births come on fixed slots — `startedAt + slot × interval` — and a slot passes by when the place is full. Who is born on a
 * slot (breed, seed, lifespan) comes only from the camp's seed, the place and the slot number, so the server and a Mac that
 * was offline work out the very same residents. The Mac has this in Swift (mac/Sources/CampRules); keep the arithmetic
 * identical (same order of operations, `Math.floor`, no other rounding): fixtures.json checks it.
 */
import { hashString, pickWeighted, randomFrom, type Random } from "../world/random.ts";
import { BASE_LIFESPAN_HOURS, raceRules } from "./races.ts";

const HOUR = 3_600_000;
const MINUTE = 60_000;

export interface Resident {
  id: number;
  breed: string;
  /** Everything else about it (its name, looks, character) comes from this on the devices. */
  seed: number;
  /** Times in ms since 1970. */
  bornAt: number;
  /** When it dies of age (null: never, the undead). */
  diesAt: number | null;
  /** When it died (of age or in battle); null while alive. */
  diedAt: number | null;
}

/** One place that grows its own residents: the home camp, or a nest in the big world. */
export interface Place {
  race: string;
  /** Tells the places of one camp apart in the random numbers ("home", "cell:38344:1015372"…). */
  key: string;
  startedAt: number;
  birthMinutes: number;
  cap: number;
  /** 聖光模式 (server/CAMP.md §7): every other birth slot passes by while it has SANCTUARY_FULL_BELOW or more. */
  sanctuary?: boolean;
}

/** In 聖光模式 a camp below this many is born at full speed (so one that was beaten down can grow back). */
export const SANCTUARY_FULL_BELOW = 120;
/** After 聖光模式 is turned off, it may be turned on again this many hours later. */
export const SANCTUARY_REST_HOURS = 12;

export interface Population {
  residents: Resident[];
  nextId: number;
  /** The next birth slot to look at. */
  nextSlot: number;
  /** The most residents it has ever had at once. */
  peak: number;
}

function seeded(...parts: (string | number)[]): Random {
  return randomFrom(hashString(parts.join("|")));
}

/** The resident born on `slot` of `place` (the same every time it is asked). */
export function residentFor(place: Place, campSeed: number, slot: number, id: number, bornAt: number): Resident {
  const rules = raceRules(place.race);
  const random = seeded(campSeed, place.key, "birth", slot);
  const breed = pickWeighted(random, rules.breeds, (b) => b.weight);
  const seed = Math.floor(random() * 4294967296);
  const jitter = 0.9 + 0.2 * random();
  const diesAt = rules.ages ? bornAt + Math.floor(BASE_LIFESPAN_HOURS * HOUR * breed.lifespan * jitter) : null;
  return { id, breed: breed.id, seed, bornAt, diesAt, diedAt: null };
}

/** A new home camp: two residents to begin with (the two that carry the princess in), the first birth one interval later. */
export function startHome(race: string, campSeed: number, startedAt: number): { place: Place; population: Population } {
  const rules = raceRules(race);
  const place: Place = { race, key: "home", startedAt, birthMinutes: rules.homeBirthMinutes, cap: rules.homeCap };
  const starters = [0, 1].map((i) => residentFor({ ...place, key: "home-start" }, campSeed, i, i + 1, startedAt));
  return { place, population: { residents: starters, nextId: 3, nextSlot: 1, peak: 2 } };
}

export interface Advanced {
  born: Resident[];
  died: Resident[];
}

/**
 * Moves a place forward to `to`: deaths of age and births, in time order (a death at the same moment as a birth slot
 * comes first, so its place is free). Changes `population` in place and says what happened.
 */
export function advance(place: Place, population: Population, campSeed: number, to: number): Advanced {
  const interval = place.birthMinutes * MINUTE;
  const born: Resident[] = [];
  const died: Resident[] = [];
  let alive = population.residents.filter((r) => r.diedAt === null);

  for (let guard = 0; guard < 1_000_000; guard++) {
    let nextDeath = Infinity;
    for (const r of alive) if (r.diesAt !== null && r.diesAt < nextDeath) nextDeath = r.diesAt;
    const slotAt = place.startedAt + population.nextSlot * interval;
    if (Math.min(nextDeath, slotAt) > to) break;

    if (nextDeath <= slotAt) {
      for (const r of alive) if (r.diesAt === nextDeath) {
        r.diedAt = nextDeath;
        died.push(r);
      }
      alive = alive.filter((r) => r.diedAt === null);
      continue;
    }

    if (place.sanctuary && alive.length >= SANCTUARY_FULL_BELOW && population.nextSlot % 2 === 1) {
      population.nextSlot++; // (half speed: this slot passes by)
      continue;
    }
    if (alive.length < place.cap) {
      const baby = residentFor(place, campSeed, population.nextSlot, population.nextId, slotAt);
      population.nextId++;
      population.residents.push(baby);
      alive.push(baby);
      born.push(baby);
      if (alive.length > population.peak) population.peak = alive.length;
      population.nextSlot++;
    } else {
      // full: nothing is born until someone dies, so jump to the first slot at or after the next death (or past `to`)
      const until = Math.min(nextDeath, to + interval);
      population.nextSlot = Math.max(population.nextSlot + 1, Math.ceil((until - place.startedAt) / interval));
    }
  }
  return { born, died };
}

/** Residents falling in battle at `at` (their places free up for the next birth slots). */
export function fall(population: Population, ids: readonly number[], at: number): Resident[] {
  const gone: Resident[] = [];
  for (const r of population.residents) if (r.diedAt === null && ids.includes(r.id)) {
    r.diedAt = at;
    gone.push(r);
  }
  return gone;
}

export function aliveAt(population: Population): Resident[] {
  return population.residents.filter((r) => r.diedAt === null);
}

/**
 * A full camp turns over (2026-10-17): while it is at its cap, a birth is rolled every TURNOVER_SLOWER birth intervals; a
 * common one is not born, a better one takes the place of the oldest common at home, who goes off into the world. So a
 * camp full of commons slowly gets better without anyone being sent away by hand, at a twentieth of the births or so —
 * and only on the days `allowed` (the server: days the camp was open on a Mac), so a camp left alone does not.
 */
export const TURNOVER_SLOWER = 4;
export const TURNOVER_MOST = 50;
/**
 * How much of those at home each breed may come to by turning over (about 1.5× what births give it; the rarer, the lower):
 * a breed already there is not born in a common's place. Together under a third, so commons stay most of a camp (the undead,
 * who never die of age, would otherwise end up all rare breeds).
 */
export const TURNOVER_MAX_SHARE: Record<string, number> = { scout: 0.12, brute: 0.1, sage: 0.07, golden: 0.02 };
/**
 * …times this by race (2026-10-17, the user: 不同種族要不同): goblins are many and short-lived, so a rare one matters less
 * and they may have more; the undead never die of age, so what turns over stays for good and they get the least.
 */
export const TURNOVER_RACE_SHARE: Record<string, number> = { goblin: 1.2, elf: 1, undead: 0.6 };

/** How much of those at home a breed may come to by turning over, for this race. */
export function turnoverShare(race: string, breed: string): number {
  return (TURNOVER_MAX_SHARE[breed] ?? 0) * (TURNOVER_RACE_SHARE[race] ?? 1);
}

export function turnover(place: Place, population: Population, campSeed: number, from: number, to: number, allowed: (at: number) => boolean = () => true): { born: Resident[]; left: Resident[] } {
  const born: Resident[] = [];
  const left: Resident[] = [];
  const every = place.birthMinutes * MINUTE * TURNOVER_SLOWER;
  const first = Math.floor((from - place.startedAt) / every) + 1;
  const last = Math.floor((to - place.startedAt) / every);
  for (let k = Math.max(first, last - TURNOVER_MOST + 1); k <= last; k++) {
    const at = place.startedAt + k * every;
    if (!allowed(at)) continue; // (only on a day the player had the camp open on a Mac: not for a camp left alone)
    const alive = population.residents.filter((r) => r.bornAt <= at && r.diedAt === null);
    if (alive.length < place.cap) continue;
    const baby = residentFor({ ...place, key: `${place.key}-turnover` }, campSeed, k, population.nextId, at);
    if (baby.breed === "common") continue;
    if (alive.filter((r) => r.breed === baby.breed).length + 1 > alive.length * turnoverShare(place.race, baby.breed)) continue; // (that breed has its share)
    const oldest = alive.filter((r) => r.breed === "common").sort((a, b) => a.bornAt - b.bornAt || a.id - b.id)[0];
    if (!oldest) continue;
    oldest.diedAt = at;
    left.push(oldest);
    population.nextId++;
    population.residents.push(baby);
    born.push(baby);
  }
  return { born, left };
}

