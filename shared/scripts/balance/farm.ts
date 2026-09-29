/**
 * Balance report: the farm (server/FARM.md §5). A new camp of each race grows from its first two residents (births only: no
 * raids, nobody dies, nobody goes out), fells and digs by the hour, and raises the farm as soon as it can. How many days to
 * each level, and how much food a day each level gives. Levels 4 and 5 need a little from the big world (皮帶, 強獸人獠牙):
 * counted as had.
 *
 *   cd shared && ../server/node_modules/.bin/tsx scripts/balance/farm.ts
 */
import { advance, aliveAt, FARM_LEVELS, FARM_MAX, farmCrops, farmName, farmPartName, nextFarmLevel, produce, productionPerHour, startHome, WORKERS_MAX } from "../../src/camp/index.ts";
import { MATERIALS } from "../../src/world/index.ts";

const HOUR = 3_600_000;
const T0 = Date.UTC(2026, 8, 1);
const DAYS = 21;
const WORLD = new Set(["leather_strap", "orc_tusk"]);

console.log("## 開營到每一級田地要幾天（只算出生，沒有來襲、老死、出征；大世界的材料當作有）\n");
console.log("種族\t" + FARM_LEVELS.slice(1).map((l) => `Lv${l.level}`).join("\t") + "\t第 1 天的木材／石頭\t滿 60 工人");
for (const race of ["goblin", "elf", "undead"]) {
  const { place, population } = startHome(race, 1, T0);
  const store: Record<string, number> = {};
  let carry: Record<string, number> = {};
  let level = 1;
  let upgradingUntil: number | null = null;
  const reached: (number | null)[] = [];
  let firstDay = "";
  let full: number | null = null;
  for (let h = 1; h <= DAYS * 24; h++) {
    const t = T0 + h * HOUR;
    advance(place, population, 1, t);
    const workers = aliveAt(population).length;
    if (full === null && workers >= WORKERS_MAX) full = h;
    const step = produce({ race, seed: 1, workers, farmLevel: level, from: t - HOUR, to: t, carry, store });
    carry = step.carry;
    for (const [id, n] of Object.entries(step.got)) store[id] = (store[id] ?? 0) + n;
    if (h === 24) firstDay = `${store.log ?? 0}／${store.stone ?? 0}`;
    if (upgradingUntil !== null && t >= upgradingUntil) {
      level++;
      reached[level] = h;
      upgradingUntil = null;
    }
    const next = nextFarmLevel(level);
    if (upgradingUntil === null && next && Object.entries(next.cost).every(([id, n]) => WORLD.has(id) || (store[id] ?? 0) >= n)) {
      for (const [id, n] of Object.entries(next.cost)) if (!WORLD.has(id)) store[id] = store[id]! - n;
      upgradingUntil = t + next.hours * HOUR;
    }
  }
  const days = (h: number | null | undefined) => (h ? (h / 24).toFixed(1) : `>${DAYS}`);
  console.log(`${race}\t${FARM_LEVELS.slice(1).map((l) => days(reached[l.level])).join("\t")}\t${firstDay}\t${days(full)} 天`);
}

console.log("\n## 每一級田地每天的糧食（每種最多存 20）\n");
for (const race of ["goblin", "elf", "undead"]) {
  console.log(`${race}（${farmName(race)}）`);
  for (let level = 1; level <= FARM_MAX; level++) {
    const p = productionPerHour(race, WORKERS_MAX, level);
    const foods = farmCrops(race, level).map((c) => `${MATERIALS[c.food]?.name ?? c.food} ${(p[c.food]! * 24).toFixed(1)}`).join("、");
    console.log(`  Lv${level} ${farmPartName(race, level)}\t${foods}`);
  }
}
