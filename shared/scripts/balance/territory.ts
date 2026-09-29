/**
 * Balance report: holding cells (server/WORLD.md §20, world/holdings.ts). What one cell yields a day by its ground, with
 * how many live there, its building, a landmark and held cells next to it; how the rations it yields stand against what a
 * paying cell eats; and how a garrison holds when its lair comes back, plain or with a watchtower, a temple, help from
 * the cells next to it, and friends guarding it.
 *
 *   cd shared && npm run balance:territory
 */
import { residentAsFighter } from "../../src/camp/combat.ts";
import { RACE_RANGE } from "../../src/camp/index.ts";
import {
  buildingsFor,
  buildingYield,
  cellBonus,
  cellCapacity,
  cellsWithin,
  cellYield,
  estimateBattle,
  garrisonMin,
  lairAt,
  lairFighters,
  RATIONS,
  residentFighter,
  seeded,
  UPKEEP_EVERY,
  UPKEEP_RATIONS,
  WORLD_SEED,
  YIELD_HOURS,
  type CellBuilding,
  type CellSurroundings,
  type FightBoosts,
  type Lair,
  type Terrain,
} from "../../src/world/index.ts";
import { MATERIALS } from "../../src/world/drops.ts";

const RACE = "goblin";
const TERRAINS: Terrain[] = ["forest", "park", "water", "urban", "open", "road"];
const YIELDS_A_DAY = 24 / YIELD_HOURS;
const DAYS = 30;
const name = (id: string) => MATERIALS[id]?.name ?? id;

/** A day's yield (the average of DAYS days) for one cell. */
function daily(terrain: Terrain, garrison: number, building: CellBuilding | null, around: CellSurroundings = {}): Record<string, number> {
  const bonus = cellBonus(RACE, building, 0, around);
  const out: Record<string, number> = {};
  for (let day = 0; day < DAYS; day++) {
    const got = cellYield(RACE, terrain, garrison, YIELDS_A_DAY, seeded(1, terrain, day, "y"), false, bonus.yieldBoost);
    if (garrison >= garrisonMin(RACE)) for (const [id, n] of Object.entries(buildingYield(bonus, YIELDS_A_DAY, seeded(2, terrain, day, "b")))) got[id] = (got[id] ?? 0) + n;
    for (const [id, n] of Object.entries(got)) out[id] = (out[id] ?? 0) + n / DAYS;
  }
  return out;
}
const text = (r: Record<string, number>) =>
  Object.entries(r)
    .filter(([, n]) => n >= 0.05)
    .sort((a, b) => b[1] - a[1])
    .map(([id, n]) => `${name(id)} ${n.toFixed(1)}`)
    .join("、");
const rations = (r: Record<string, number>) => Object.keys(RATIONS).reduce((n, id) => n + (r[id] ?? 0), 0);

const min = garrisonMin(RACE), full = cellCapacity(RACE);
console.log(`## 一格一天的產出（${RACE}，最少 ${min} 隻、住滿 ${full} 隻；${DAYS} 天平均）\n`);
for (const t of TERRAINS) {
  const [a, b] = buildingsFor(t);
  const maker = [a, b].find((r) => r!.makes)!;
  console.log(`### ${t}`);
  console.log(`- 最少的人：${text(daily(t, min, null))}`);
  console.log(`- 住滿：${text(daily(t, full, null))}`);
  console.log(`- 住滿＋${maker.name} Lv1：${text(daily(t, full, { kind: maker.kind, level: 1 }))}`);
  console.log(`- 住滿＋${maker.name} Lv3：${text(daily(t, full, { kind: maker.kind, level: 3 }))}`);
  console.log(`- 住滿＋旁邊 3 格自己的（+30%）：${text(daily(t, full, null, { neighbours: 3 }))}`);
  const r = rations(daily(t, min, null));
  const eats = (YIELDS_A_DAY / UPKEEP_EVERY) * UPKEEP_RATIONS;
  console.log(`- 乾糧：最少的人每天產 ${r.toFixed(1)} 份，要吃的格子每天吃 ${eats} 份 → ${r >= eats ? "自己養得起" : `差 ${(eats - r).toFixed(1)} 份`}\n`);
}
console.log(`地標另外加：市場每天乾糧麵包 ${YIELDS_A_DAY}、起司 ${YIELDS_A_DAY}；古蹟・博物館每天碎晶、琥珀各約 ${(YIELDS_A_DAY * 0.15).toFixed(1)}；大學每天經驗 +20。\n`);

// --- holding it -----------------------------------------------------------------------------------------------------
// the lairs that come back for a cell: the ones near 大安 at level 2 and 3 (the usual ones, not the 初期魔王)
const lairs: Lair[] = [];
const seen = new Set<string>();
for (const cell of cellsWithin({ lat: 25.0302, lng: 121.5357 }, 4000)) {
  for (const t of TERRAINS) {
    const l = lairAt(WORLD_SEED, cell, t);
    if (!l || l.boss || l.level < 2 || seen.has(`${l.kind}${l.level}`)) continue;
    seen.add(`${l.kind}${l.level}`);
    lairs.push(l);
  }
}
const KIT = { weapon: { id: "short_sword", left: 160 }, chest: { id: "leather_armor", left: 20 } };
const guards = (n: number, boosts: FightBoosts = {}, id = 0) =>
  Array.from({ length: n }, (_, i) =>
    residentFighter(residentAsFighter(RACE, { id: id + i + 1, breed: "common", gear: KIT as never }), "defend", { id: RACE, ranged: RACE_RANGE[RACE] ?? 0 }, boosts),
  );
const G = 8;
const setups: [string, () => ReturnType<typeof guards>][] = [
  [`${G} 隻`, () => guards(G)],
  ["＋瞭望塔 Lv3", () => guards(G, { fort: 0.35 })],
  ["＋廟宇", () => guards(G, { fort: 0.2 })],
  ["＋旁邊 2 格各 5 隻", () => [...guards(G), ...guards(10, {}, 100)]],
  ["＋好友 10 隻", () => [...guards(G), ...guards(10, {}, 200)]],
  ["住 30 隻", () => guards(30)],
];
console.log(`## 巢穴回來搶地盤：守住的機率（守軍都是短劍＋皮甲的普通哥布林，60 場）\n`);
console.log(`巢穴 | ${setups.map((s) => s[0]).join(" | ")}`);
const power = (l: Lair) => lairFighters(l).reduce((n, f) => n + f.hp * f.attack, 0);
for (const l of lairs.sort((a, b) => power(b) - power(a)).slice(0, 14)) {
  const foes = lairFighters(l).map((f) => ({ ...f, side: "attack" as const }));
  const cells = setups.map(([, make]) => {
    const r = estimateBattle(foes, make(), 60);
    return `${Math.round((1 - r.win) * 100)}%`;
  });
  console.log(`${l.name} L${l.level} ×${l.foes.length} | ${cells.join(" | ")}`);
}
