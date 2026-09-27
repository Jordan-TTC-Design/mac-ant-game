/**
 * The numbers each race lives by (server/CAMP.md §11). The Mac has the same table in Swift (mac/Sources/CampRules); the
 * fixtures in fixtures.json check that the two agree. First version: change them here (and there) as play shows.
 */

export type RaceId = "goblin" | "elf" | "undead";
export const RACES: readonly RaceId[] = ["goblin", "elf", "undead"];

export interface BreedRule {
  id: string;
  /** Share of ordinary births (the princess's children, weight 0, come only from her story). */
  weight: number;
  /** Times the base lifespan (the same numbers as the Mac's character manifests). */
  lifespan: number;
}

export interface RaceRules {
  /** The home camp: one birth every this many minutes, while there is room. */
  homeBirthMinutes: number;
  /** Most residents in the home camp. */
  homeCap: number;
  /** Residents needed for the camp's second and third look; the third opens the big world. */
  stage2: number;
  stage3: number;
  /** False: residents never die of age (they only fall in battle). */
  ages: boolean;
  /** A monster raid on the home camp comes about this often. */
  raidEveryMinutes: number;
  /** A held cell in the big world: most residents, fewest that hold it, and its nest's pace. */
  cellCap: number;
  cellMin: number;
  nestBirthMinutes: number;
  /** A town cell: most residents, and its pace (the home camp's). */
  townCap: number;
  townBirthMinutes: number;
  breeds: readonly BreedRule[];
}

/** A plain resident lives this long; each breed multiplies it (elves' multipliers already include their ×2). */
export const BASE_LIFESPAN_HOURS = 48;

const goblinBreeds: BreedRule[] = [
  { id: "common", weight: 100, lifespan: 1 },
  { id: "scout", weight: 10, lifespan: 0.8 },
  { id: "brute", weight: 8, lifespan: 1.25 },
  { id: "sage", weight: 5, lifespan: 1.15 },
  { id: "golden", weight: 1, lifespan: 2 },
];

export const RACE_RULES: Record<RaceId, RaceRules> = {
  goblin: {
    homeBirthMinutes: 5,
    homeCap: 300,
    stage2: 50,
    stage3: 150,
    ages: true,
    raidEveryMinutes: 90,
    cellCap: 50,
    cellMin: 5,
    nestBirthMinutes: 15,
    townCap: 100,
    townBirthMinutes: 5,
    breeds: goblinBreeds,
  },
  elf: {
    homeBirthMinutes: 10,
    homeCap: 180,
    stage2: 30,
    stage3: 90,
    ages: true,
    raidEveryMinutes: 120,
    cellCap: 30,
    cellMin: 3,
    nestBirthMinutes: 30,
    townCap: 60,
    townBirthMinutes: 10,
    breeds: [
      { id: "common", weight: 100, lifespan: 2 },
      { id: "scout", weight: 10, lifespan: 1.8 },
      { id: "brute", weight: 8, lifespan: 2.5 },
      { id: "sage", weight: 5, lifespan: 2.3 },
      { id: "golden", weight: 1, lifespan: 4 },
    ],
  },
  undead: {
    homeBirthMinutes: 7.5,
    homeCap: 240,
    stage2: 40,
    stage3: 120,
    ages: false,
    raidEveryMinutes: 90,
    cellCap: 40,
    cellMin: 4,
    nestBirthMinutes: 22.5,
    townCap: 80,
    townBirthMinutes: 7.5,
    breeds: goblinBreeds.map((b) => ({ ...b, lifespan: 1 })), // (they do not age; the number is not used)
  },
};

export function raceRules(race: string): RaceRules {
  return RACE_RULES[race as RaceId] ?? RACE_RULES.goblin;
}

/** Which of the camp's three looks it has grown into (1, 2 or 3) for the most residents it ever had. */
export function campStage(race: string, peak: number): 1 | 2 | 3 {
  const r = raceRules(race);
  return peak >= r.stage3 ? 3 : peak >= r.stage2 ? 2 : 1;
}
