/**
 * Balance report: gear (BALANCE.md §3). For every piece: how much stronger it makes one plain resident, what it costs, and
 * where each material comes from now (the camp's own felling and digging, camp raids, held cells, big-world foes and lairs, or
 * nowhere open yet); then the
 * materials no gear uses, and a camp's raid income per day.
 *
 *   cd shared && ../server/node_modules/.bin/tsx scripts/balance/gear.ts
 */
import { CAMP_MONSTERS, campPerHour, GEAR, MONSTER_DROPS, RACE_RANGE, raceRules, residentAsFighter, SCRAP_DROPS, sitePerHour, type Site } from "../../src/camp/index.ts";
import { FOE_DROPS, LAIRS, MATERIALS, residentFighter, TERRAIN_YIELD, type Fighter } from "../../src/world/index.ts";

const CAMP_SIZE = 150;
const avg = (d: { chance: number; min: number; max: number }) => (d.chance * (d.min + d.max)) / 2;

// where each material comes from, and how much: raids per day (a CAMP_SIZE goblin camp, every monster killed), a held cell
// per day by terrain (8 yields), per kill of a big-world foe, per clear of a lair
const income: Record<string, Record<string, number>> = {};
const add = (src: string, id: string, n: number) => ((income[id] ??= {})[src] = (income[id]?.[src] ?? 0) + n);
const raidsPerDay = (24 * 60) / raceRules("goblin").raidEveryMinutes;
const campMonsters = CAMP_MONSTERS.filter((m) => m.level <= (CAMP_SIZE >= 60 ? 2 : 1));
const perRaid = Math.min(12, 2 + Math.floor(CAMP_SIZE / 30) + 1);
// the camp's sites: a CAMP_SIZE goblin camp with the six plots it has at the third look, all at level 2 (120 hands)
const SITES: Site[] = (["farm", "lumber", "quarry", "mine", "traps", "scrapyard"] as const).map((kind, i) => ({ id: i + 1, kind, level: 2 }));
for (const [id, n] of Object.entries(campPerHour("goblin", SITES, 1))) if (!id.startsWith("food_") && !id.startsWith("ration_")) add("營地生產", id, n * 24);
for (const m of campMonsters) for (const d of [...(MONSTER_DROPS[m.id] ?? []), ...SCRAP_DROPS]) add("來襲", d.id, (avg(d) * perRaid * raidsPerDay) / campMonsters.length);
for (const [t, list] of Object.entries(TERRAIN_YIELD)) for (const y of list) add(`領地(${t})/天`, y.id, (8 * y.chance * (y.min + y.max)) / 2);
const open = new Set(LAIRS.filter((l) => l.tier === 1).flatMap((l) => l.members.map((m) => m.foe)));
for (const f of open) for (const d of FOE_DROPS[f] ?? []) add(`打${f}/隻`, d.id, avg(d));
for (const l of LAIRS.filter((l) => l.tier === 1)) for (const d of l.loot) add(`清${l.id}`, d.id, avg(d));
for (const l of LAIRS.filter((l) => l.tier > 1)) for (const m of l.members) if (!open.has(m.foe)) for (const d of FOE_DROPS[m.foe] ?? []) add(`（未開放）${m.foe}`, d.id, avg(d));

/** √(attack × hp) of one plain resident (common breed), unrounded, with `gear` on. */
function strength(race: string, gear: object | null): number {
  const f: Fighter = residentFighter(residentAsFighter(race, { id: 1, breed: "common", gear: gear as never }), "attack", { id: race, ranged: RACE_RANGE[race] ?? 0 });
  return Math.sqrt(f.attack * (f.range > 0 ? 1.1 : 1) * (1 + 0.3 * (f.speed - 1)) * (f.hp / (1 - Math.min(0.6, f.guard))));
}

console.log(`## 裝備（普通居民穿上一件，戰力是原本的幾倍）\n`);
console.log("id\t名稱\t部位\t耐久\t哥布林\t精靈\t數值\t材料[來源]");
for (const g of GEAR) {
  const on = { [g.slot]: { id: g.id, left: g.durability } };
  const gob = strength("goblin", on) / strength("goblin", null);
  const elf = strength("elf", on) / strength("elf", null);
  const stats = Object.entries({ 力: g.might, 血: g.health, 擋: g.block, 速: g.speed, 距: g.reach }).filter(([, v]) => v).map(([k, v]) => `${k}${v}`).join(" ");
  const cost = Object.entries(g.cost).map(([id, n]) => {
    const s = income[id] ?? {};
    const reachable = Object.entries(s).filter(([k]) => !k.startsWith("（未開放）"));
    const tag =
      reachable.length === 0
        ? Object.keys(s).length ? "🔒只在未開放區" : "❌沒有來源"
        : (s["營地生產"] ?? 0) >= n ? `營地生產 ${s["營地生產"]!.toFixed(1)}/天` : (s["來襲"] ?? 0) >= n ? `來襲 ${s["來襲"]!.toFixed(1)}/天` : reachable.map(([k, v]) => `${k} ${v.toFixed(2)}`).slice(0, 2).join("，");
    return `${MATERIALS[id]?.name ?? id}×${n}[${tag}]`;
  });
  console.log(`${g.id}\t${g.name}\t${g.slot}\t${g.durability}\t×${gob.toFixed(2)}\t×${elf.toFixed(2)}\t${stats}\t${cost.join(" ")}`);
}

const used = new Set(GEAR.flatMap((g) => Object.keys(g.cost)));
console.log("\n## 裝備要用、但現在拿不到的材料");
for (const id of used) {
  const s = income[id] ?? {};
  if (!Object.keys(s).some((k) => !k.startsWith("（未開放）"))) console.log(`${MATERIALS[id]?.name ?? id}（${id}）：${Object.keys(s).join("，") || "完全沒有來源（世界魔王？）"}`);
}
console.log("\n## 沒有任何裝備要用的材料");
console.log(Object.keys(MATERIALS).filter((id) => !used.has(id) && !id.startsWith("ration_") && !id.startsWith("food_")).map((id) => `${MATERIALS[id]!.name}（${id}）`).join("、"));
console.log(`\n## 來襲的材料收入（哥布林 ${CAMP_SIZE} 隻，每天 ${raidsPerDay} 次，每次約 ${perRaid} 隻魔獸）`);
console.log(Object.entries(income).filter(([, s]) => s["來襲"]).sort((a, b) => b[1]["來襲"]! - a[1]["來襲"]!).map(([id, s]) => `${MATERIALS[id]?.name ?? id} ${s["來襲"]!.toFixed(1)}`).join("、"));
console.log(`\n## 每種場地每天的產量（人手滿；碎晶是期望值）`);
console.log("種族\t場地\tLv1\tLv2\tLv3");
for (const race of ["goblin", "elf", "undead"]) {
  for (const kind of ["lumber", "quarry", "mine", "traps", "fishery", "hunter", "scrapyard", "grove", "soulwell"] as const) {
    const cells = [1, 2, 3].map((level) => {
      const { makes, finds } = sitePerHour(race, { kind, level });
      return Object.entries({ ...makes, ...finds }).map(([id, n]) => `${MATERIALS[id]?.name ?? id} ${(n * 24).toFixed(1)}`).join(" ");
    });
    if (cells[0]) console.log(`${race}\t${kind}\t${cells.join("\t")}`);
  }
}
