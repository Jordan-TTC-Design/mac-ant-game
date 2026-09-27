/**
 * Putting food down (the Mac's Colony food rules): each kind has a cooldown, and the pieces carried home keep its boost on
 * for a while. The server keeps both as end times. Only the boosts that change a fight are used by the server so far
 * (meat, cheese, carrot; the undead's blue soul); the rest (honey, mushroom…) are the Mac's to show.
 */
export const FOODS = ["water", "honey", "bread", "meat", "cheese", "carrot", "mushroom", "berries", "fish", "cake"] as const;
export const SOULS = ["soul_blue", "soul_green", "soul_purple"] as const;
export type FoodId = (typeof FOODS)[number] | (typeof SOULS)[number];

/** After putting a food down, the same kind waits this long. */
export const FOOD_COOLDOWN_MINUTES = 20;
/** Twelve pieces carried home, four minutes each, up to an hour. */
export const FOOD_BOOST_MINUTES = 48;

/** What each race may put down (the undead eat nothing: they get coloured souls instead). */
export function placeableFoods(race: string): readonly FoodId[] {
  return race === "undead" ? SOULS : FOODS;
}

/** How strongly a food works for a race (elves: fruit and honey 1.5, meat and fish nothing). */
export function foodScale(race: string, food: string): number {
  if (race === "elf") return { honey: 1.5, berries: 1.5, water: 1.5, meat: 0, fish: 0 }[food] ?? 1;
  return 1;
}

/** The fight boosts on at `at` (for the battle rules' FightBoosts: 0…1.5). The undead's blue soul acts as meat. */
export function fightBoosts(race: string, boosts: Record<string, string>, at: number): { meat?: number; cheese?: number; carrot?: number } {
  const on = (food: string) => (boosts[food] && Date.parse(boosts[food]!) > at ? foodScale(race, food) : 0);
  return { meat: Math.max(on("meat"), on("soul_blue")), cheese: on("cheese"), carrot: on("carrot") };
}
