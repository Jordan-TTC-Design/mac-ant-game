/**
 * Worked examples of the camp rules, written to fixtures.json. The Mac's Swift copy of the rules must give the very same
 * numbers (`swift run camp-rules-check` in mac/); the test here makes sure fixtures.json matches the TypeScript rules, so
 * after changing a rule run `pnpm --filter @goblincamp/shared fixtures` and commit the new file.
 */
import { hashString, randomFrom } from "../world/random.ts";
import { advance, aliveAt, fall, residentFor, startHome, type Place } from "./population.ts";
import { BASE_LIFESPAN_HOURS, RACE_RULES, RACES, raceRules } from "./races.ts";

const HOUR = 3_600_000;
export const FIXTURE_SEED = 2026;
export const FIXTURE_START = Date.UTC(2026, 9, 1, 0, 0, 0);

export function buildFixtures() {
  const random = randomFrom(12345);
  const basics = {
    hashes: ["", "a", "goblin|home|birth|7", "2026|home|birth|0", "哥布林"].map((text) => ({ text, hash: hashString(text) })),
    randoms: { seed: 12345, first: [random(), random(), random(), random()] },
  };

  const races = RACES.map((race) => {
    const { place, population } = startHome(race, FIXTURE_SEED, FIXTURE_START);
    const checkpoints = [];
    for (const hours of [1, 12, 30, 72, 24 * 7]) {
      const step = advance(place, population, FIXTURE_SEED, FIXTURE_START + hours * HOUR);
      checkpoints.push({
        hours,
        born: step.born.length,
        died: step.died.length,
        alive: aliveAt(population).length,
        peak: population.peak,
        nextId: population.nextId,
        nextSlot: population.nextSlot,
        lastBorn: step.born.at(-1) ?? null,
      });
    }
    // a battle: three residents fall, the camp fills up again
    const battle = startHome(race, FIXTURE_SEED, FIXTURE_START);
    advance(battle.place, battle.population, FIXTURE_SEED, FIXTURE_START + 6 * HOUR);
    const fallen = fall(battle.population, [3, 4, 5], FIXTURE_START + 6 * HOUR).map((r) => r.id);
    const after = advance(battle.place, battle.population, FIXTURE_SEED, FIXTURE_START + 7 * HOUR);
    const nest: Place = { race, key: "cell:38344:1015372", startedAt: FIXTURE_START, birthMinutes: raceRules(race).nestBirthMinutes, cap: raceRules(race).cellCap };
    return {
      race,
      firstResidents: startHome(race, FIXTURE_SEED, FIXTURE_START).population.residents.concat(
        [1, 2, 3, 4, 5].map((slot) => residentFor(place, FIXTURE_SEED, slot, slot + 2, FIXTURE_START + slot * place.birthMinutes * 60_000)),
      ),
      checkpoints,
      battle: { fallen, bornAfter: after.born.length, alive: aliveAt(battle.population).length, nextSlot: battle.population.nextSlot },
      nestResidents: [0, 1, 2].map((slot) => residentFor(nest, FIXTURE_SEED, slot, 100 + slot, FIXTURE_START + slot * nest.birthMinutes * 60_000)),
    };
  });
  return { seed: FIXTURE_SEED, startedAt: FIXTURE_START, rules: { baseLifespanHours: BASE_LIFESPAN_HOURS, races: RACE_RULES }, basics, races };
}
