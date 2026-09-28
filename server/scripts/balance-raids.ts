/**
 * Balance report: camp raids (BALANCE.md §4). For each race and camp size, 200 raids fought with every defender plain (no
 * gear): how often anyone falls, how many on average and at most, and how often the camp loses.
 *
 *   cd server && npx tsx scripts/balance-raids.ts
 */
import { planRaid, raceRules } from "@goblincamp/shared/camp";
import { pickWeighted, randomFrom } from "@goblincamp/shared/world";
import { resolveRaid } from "../src/camp/raids.ts";

for (const race of ["goblin", "elf", "undead"]) {
  for (const size of [40, 90, 150, 250]) {
    const rules = raceRules(race);
    const r = randomFrom(size * 7 + race.length);
    const alive = Array.from({ length: size }, (_, i) => ({ id: i + 1, breed: pickWeighted(r, rules.breeds, (b) => b.weight).id, gear: null }));
    let raids = 0, anyDeath = 0, deaths = 0, lost = 0, most = 0;
    for (let index = 0; index < 400 && raids < 200; index++) {
      const plan = planRaid(race, 12345 + size, 0, index, size);
      if (!plan) continue;
      raids++;
      const out = resolveRaid(race, 12345 + size, plan, alive);
      if (out.fallen.length) anyDeath++;
      deaths += out.fallen.length;
      most = Math.max(most, out.fallen.length);
      if (out.winner === "monsters") lost++;
    }
    console.log(`${race} ${size} 隻：${raids} 次，有人倒下 ${Math.round((100 * anyDeath) / raids)}%，平均 ${(deaths / raids).toFixed(2)}，最多 ${most}，守不住 ${Math.round((100 * lost) / raids)}%`);
  }
}
