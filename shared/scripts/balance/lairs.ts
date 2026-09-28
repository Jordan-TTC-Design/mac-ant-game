/**
 * Balance report: big-world fights (BALANCE.md §2). Every tier-1 lair found within 4 km of 大安森林公園, from weakest to
 * strongest, against level-1 parties: plain, with rations, with some gear, fully geared. Each cell: how often it is won
 * and how many of the party fall on average (60 fights with different luck).
 *
 *   cd shared && ../server/node_modules/.bin/tsx scripts/balance/lairs.ts
 */
import { residentAsFighter } from "../../src/camp/combat.ts";
import { RACE_RANGE } from "../../src/camp/index.ts";
import { cellsWithin, combatPower, estimateBattle, lairAt, lairFighters, residentFighter, WORLD_SEED, type FightBoosts, type Lair } from "../../src/world/index.ts";

const DAAN = { lat: 25.0302, lng: 121.5357 };
const seen = new Map<string, Lair>();
for (const cell of cellsWithin(DAAN, 4000)) {
  for (const t of ["forest", "park", "water", "urban", "open", "road"] as const) {
    const lair = lairAt(WORLD_SEED, cell, t);
    if (lair) seen.set(`${lair.kind} L${lair.level} ×${lair.foes.length}`, lair);
  }
}
const KIT = {
  none: {},
  sling: { weapon: { id: "slingshot", left: 100 } },
  full: { weapon: { id: "slingshot", left: 100 }, chest: { id: "beetle_armor", left: 24 }, head: { id: "rabbit_cap", left: 14 }, hands: { id: "spine_gloves", left: 16 } },
  camp: { weapon: { id: "short_sword", left: 160 }, chest: { id: "leather_armor", left: 20 } }, // what camp raids alone pay for (T0)
  orc: { weapon: { id: "great_sword", left: 240 }, chest: { id: "iron_plate", left: 36 } }, // T1 top: needs orc drops
};
function party(race: string, n: number, kit: keyof typeof KIT, geared: number, boosts: FightBoosts = {}) {
  return Array.from({ length: n }, (_, i) =>
    residentFighter(residentAsFighter(race, { id: i + 1, breed: "common", gear: i < geared ? (KIT[kit] as never) : null }), "attack", { id: race, ranged: RACE_RANGE[race] ?? 0 }, boosts),
  );
}
const setups: [string, string, number, keyof typeof KIT, number][] = [
  ["精靈4 無裝", "elf", 4, "none", 0],
  ["精靈6 乾糧4", "elf", 6, "none", 0],
  ["精靈4 2把彈弓", "elf", 4, "sling", 2],
  ["精靈4 新手全套", "elf", 4, "full", 4],
  ["精靈4 營地裝T0", "elf", 4, "camp", 4],
  ["精靈4 雙手劍鐵甲", "elf", 4, "orc", 4],
  ["哥布林6 無裝", "goblin", 6, "none", 0],
  ["死靈5 無裝", "undead", 5, "none", 0],
];
console.log(`巢穴 | 戰力 | ${setups.map((s) => s[0]).join(" | ")}`);
for (const [key, lair] of [...seen.entries()].sort((a, b) => combatPower(lairFighters(a[1])) - combatPower(lairFighters(b[1])))) {
  const foes = lairFighters(lair);
  const cells = setups.map(([, race, n, kit, g]) => {
    const r = estimateBattle(party(race, n, kit, g), foes, 60);
    return `${Math.round(r.win * 100)}%/${r.fallen.toFixed(1)}`;
  });
  console.log(`${lair.name} ${key.split(" ").slice(1).join(" ")} | ${combatPower(foes)} | ${cells.join(" | ")}`);
}
console.log("\n我方戰力：" + setups.map(([n, race, k, kit, g]) => `${n} ${combatPower(party(race, k, kit, g))}`).join("、"));
