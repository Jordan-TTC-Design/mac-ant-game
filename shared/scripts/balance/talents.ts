/**
 * Balance report: 種族天賦 (shared/src/world/talents.ts, WORLD.md §27). Each tree bought whole and as far as its top talent:
 * how many points, what it adds up to, and one number for how much harder a party fights (√(attack × hit points) × party
 * size, as combatPower counts it); the best a Lv20 and a Lv50 camp of each race can do; and the top talents' new abilities
 * in numbers (what a raid takes, how many an ambush shoots, how many rise, what blight costs).
 *
 *   cd shared && npm run balance:talents
 */
import { partyCap, PARTY_MAX } from "../../src/world/supplies.ts";
import { cellsWithin, lairAt, lairDrops, lootFor, seeded, terrainAt, WORLD_SEED } from "../../src/world/index.ts";
import {
  cannotLearn,
  talentBonus,
  talentFight,
  talentPoints,
  TALENT_ABILITIES,
  TALENT_ROW_LEVELS,
  TALENT_TREES,
  TALENTS,
  type TalentEffect,
  type TalentPicks,
} from "../../src/world/talents.ts";

const RACES = ["goblin", "elf", "undead", "beast"] as const;
const RACE_NAMES: Record<string, string> = { goblin: "哥布林", elf: "精靈", undead: "死靈", beast: "獸人" };
const pct = (n: number) => `${n >= 0 ? "+" : ""}${Math.round(n * 100)}%`;
const x = (n: number) => `×${n.toFixed(2)}`;

/** Every rank of `tree`, top row first, as far as the rules and `level` let (stops at `points` if given). */
function fill(race: string, level: number, trees: string[], points = Infinity): TalentPicks {
  const picks: TalentPicks = {};
  let spent = 0;
  for (const tree of trees)
    for (const rule of TALENTS.filter((t) => t.tree === tree).sort((a, b) => a.row - b.row || a.col - b.col))
      while (spent < points && !cannotLearn(race, level, picks, rule.id)) {
        picks[rule.id] = (picks[rule.id] ?? 0) + 1;
        spent++;
      }
  return picks;
}
/** The fewest points to reach `tree`'s top talent: every row above it filled to its gate, then the top itself. */
function toTop(tree: string): number {
  const top = TALENTS.filter((t) => t.tree === tree).reduce((a, b) => (b.row > a.row ? b : a));
  return top.row * 4 + top.ranks;
}
const spent = (p: TalentPicks) => Object.values(p).reduce((a, b) => a + b, 0);

/** How much harder a party fights: √((1+attack)(1+hp)) × its size against the size without talents. */
function fight(race: string, level: number, bonus: Partial<Record<TalentEffect, number>>, against: "player" | "lair"): number {
  const f = talentFight(bonus, against);
  const base = partyCap(race, level);
  const size = Math.min(PARTY_MAX + (bonus.party ?? 0), base + (bonus.party ?? 0));
  return Math.sqrt((1 + f.power) * (1 + f.vigor)) * (size / base);
}
const ECONOMY: TalentEffect[] = ["yield", "loot", "xp", "upkeep", "market", "travel", "regionTravel", "fort", "homeFort", "room", "nest", "reinforce", "freeCells", "wear"];
const effects = (b: Partial<Record<TalentEffect, number>>) =>
  ECONOMY.filter((e) => b[e])
    .map((e) => (["room", "reinforce", "freeCells", "party"].includes(e) ? `${e} +${b[e]}` : `${e} ${pct(e === "upkeep" || e === "wear" ? -b[e]! : b[e]!)}`))
    .join("、");

console.log("# 種族天賦平衡報告\n");
console.log(`天賦點 = 等級 − 1；每排開放等級 ${TALENT_ROW_LEVELS.join("／")}；樹頂端要 Lv${TALENT_ROW_LEVELS.at(-1)}。\n`);

console.log("## 1. 每棵樹（點滿，和點到頂端最少要幾點）\n");
console.log("| 種族 | 樹 | 滿 | 到頂端 | 打巢穴 | 打玩家 | 其他 |");
console.log("|---|---|---|---|---|---|---|");
for (const race of RACES)
  for (const tree of TALENT_TREES.filter((t) => t.race === race)) {
    const all = fill(race, 50, [tree.id]);
    const b = talentBonus(all);
    console.log(`| ${RACE_NAMES[race]} | ${tree.icon}${tree.name} | ${spent(all)} | ${toTop(tree.id)} | ${x(fight(race, 20, b, "lair"))} | ${x(fight(race, 20, b, "player"))} | ${effects(b)}${b.party ? `、party +${b.party}` : ""} |`);
  }

console.log("\n## 2. 各種族最強的出征（Lv20：19 點、Lv50：49 點，照順序點滿幾棵大世界樹）\n");
console.log("| 種族 | 等級 | 點法 | 打巢穴 | 打玩家 |");
console.log("|---|---|---|---|---|");
for (const race of RACES) {
  const trees = TALENT_TREES.filter((t) => t.race === race && !t.id.endsWith("_camp")).map((t) => t.id);
  for (const level of [20, 50]) {
    const orders = trees.flatMap((a) => trees.filter((b) => b !== a).map((b) => [a, b, ...trees.filter((c) => c !== a && c !== b)]));
    for (const against of ["lair", "player"] as const) {
      const best = orders
        .map((o) => ({ o, b: talentBonus(fill(race, level, o, talentPoints(level))) }))
        .sort((p, q) => fight(race, level, q.b, against) - fight(race, level, p.b, against))[0]!;
      if (against === "lair" || best.o[0] !== orders[0]![0])
        console.log(`| ${RACE_NAMES[race]} | Lv${level} | ${against === "lair" ? "打巢穴最強" : "打玩家最強"}：${best.o.map((id) => TALENT_TREES.find((t) => t.id === id)!.name).join(" → ")} | ${x(fight(race, level, best.b, "lair"))} | ${x(fight(race, level, best.b, "player"))} |`);
    }
  }
}

console.log("\n## 3. 頂端能力的數字\n");
const A = TALENT_ABILITIES;
console.log("**劫掠**：打贏搶倉庫每種 " + pct(A.raidShare) + "（每種最多 " + A.raidCap + "、一次最多 " + A.raidTotal + "，城鎮／瞭望塔減半）");
for (const store of [50, 125, 400]) console.log(`- 對方某種素材 ${store} → 搶 ${Math.min(A.raidCap, Math.floor(store * A.raidShare))}（城鎮 ${Math.min(Math.floor(A.raidCap * A.raidGuarded), Math.floor(store * A.raidShare * A.raidGuarded))}）`);
// against what clearing a lair brings home (its loot and what its foes drop), by level, round 台北
const byLevel = new Map<number, number[]>();
for (const cell of cellsWithin({ lat: 25.04, lng: 121.53 }, 6000)) {
  const lair = lairAt(WORLD_SEED, cell, terrainAt(WORLD_SEED, cell));
  if (!lair || lair.boss) continue;
  const got = { ...lootFor(lair, seeded(WORLD_SEED, cell, "loot")) };
  for (const [id, n] of Object.entries(lairDrops(lair, lair.foes.map((_, i) => `d#${i}`), cell))) got[id] = (got[id] ?? 0) + n;
  byLevel.set(lair.level, [...(byLevel.get(lair.level) ?? []), Object.values(got).reduce((a, b) => a + b, 0)]);
}
const avg = (a: number[]) => a.reduce((p, q) => p + q, 0) / a.length;
console.log("- 對照：清掉一個巢穴帶回來（戰利品＋怪物掉落，台北附近平均）：" + [...byLevel].sort((a, b) => a[0] - b[0]).map(([lv, a]) => `${lv} 級 ${avg(a).toFixed(0)} 個`).join("、"));
for (const [kinds, each] of [[10, 60], [20, 150], [30, 400]] as const) {
  const take = Math.min(A.raidTotal, kinds * Math.min(A.raidCap, Math.floor(each * A.raidShare)));
  const guarded = Math.min(Math.floor(A.raidTotal * A.raidGuarded), kinds * Math.min(Math.floor(A.raidCap * A.raidGuarded), Math.floor(each * A.raidShare * A.raidGuarded)));
  console.log(`- 對方倉庫 ${kinds} 種、每種 ${each} → 一次搶 ${take} 個（城鎮 ${guarded}；${A.raidRestHours} 小時內不會再被搶）`);
}
console.log(`\n**伏擊**：每塊相鄰領地射倒 ${pct(A.ambushPerCell)}，最多 ${pct(A.ambushMax)}（拿盾的不射）`);
for (const cells of [1, 3, 6]) for (const party of [10, 25]) console.log(`- 隊伍 ${party} 隻經過 ${cells} 塊 → 倒 ${Math.min(party - 1, Math.round(party * Math.min(A.ambushMax, A.ambushPerCell * cells)))} 隻`);
console.log(`\n**戰場復甦**：雙方倒下的 ${pct(A.raiseShare)} 爬起來，最多 ${A.raiseMax}（營火廣場那格不會）`);
for (const fallen of [5, 20, 60]) console.log(`- 倒下 ${fallen} → 多 ${Math.min(A.raiseMax, Math.ceil(fallen * A.raiseShare))} 隻`);
console.log(`\n**夜襲**：晚上出發走路 ${x(A.nightTravel)}、對方沒有預警（目標那區有瞭望塔就有）`);
console.log(`**腐化大地**：旁邊別人的領地產出 ${pct(-A.blightYield)}；打旁邊的巢穴，牠們血量 ${pct(-A.blightLair)}（打巢穴約 ${x(1 / Math.sqrt(1 - A.blightLair))}）`);
console.log(`**月光傳送**：一天 ${A.moonGatesPerDay} 次`);
console.log(`**拼裝改造**：裝備 ×1.3，花做一件的全部材料（等於多做一件換 1.3 倍：裝備數不夠時才划算）`);
