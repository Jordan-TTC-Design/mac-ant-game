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
