/**
 * Balance report: the camp's sites (server/FARM.md §11). A new camp of each race grows from its first two residents
 * (births only: no raids, nobody dies, nobody goes out) and builds as soon as it can, in a fixed order: the race's first
 * picks, then raising whatever is lowest. When it gets its sites, what it makes a day, and how soon the sites alone pay for
 * a T0 kit (短劍＋皮甲). What the big world gives (皮帶, 強獸人獠牙…) is counted as had.
 *
 *   cd shared && ../server/node_modules/.bin/tsx scripts/balance/sites.ts
 */
import { advance, aliveAt, campStage, GEAR, produce, siteName, siteNext, slotsFor, staffing, startHome, type Site, type SiteKind } from "../../src/camp/index.ts";
import { MATERIALS } from "../../src/world/index.ts";

const HOUR = 3_600_000;
const T0 = Date.UTC(2026, 8, 1);
const DAYS = 14;
const WORLD = new Set(["leather_strap", "orc_tusk", "crude_blade", "fox_tail"]);
const ORDER: Record<string, SiteKind[]> = {
  goblin: ["lumber", "quarry", "traps", "mine", "scrapyard", "fishery"],
  elf: ["lumber", "quarry", "traps", "grove", "mine", "hunter"],
  undead: ["lumber", "quarry", "traps", "mine", "soulwell", "fishery"],
};
const kit = [GEAR.find((g) => g.id === "short_sword")!, GEAR.find((g) => g.id === "leather_armor")!];
const kitCost: Record<string, number> = {};
for (const g of kit) for (const [id, n] of Object.entries(g.cost)) kitCost[id] = (kitCost[id] ?? 0) + n;
const name = (id: string) => MATERIALS[id]?.name ?? id;

for (const race of ["goblin", "elf", "undead"]) {
  const { place, population } = startHome(race, 1, T0);
  let sites: Site[] = [{ id: 1, kind: "farm", level: 1 }];
  const store: Record<string, number> = {};
  const made: Record<string, number> = {};
  let carry: Record<string, number> = {};
  const log: string[] = [];
  let kitAt: number | null = null;
  const perDay: Record<number, Record<string, number>> = {};
  for (let h = 1; h <= DAYS * 24; h++) {
    const t = T0 + h * HOUR;
    advance(place, population, 1, t);
    const workers = aliveAt(population).length;
    const step = produce({ race, seed: 1, sites, workers, from: t - HOUR, to: t, carry, store });
    carry = step.carry;
    for (const [id, n] of Object.entries(step.got)) {
      store[id] = (store[id] ?? 0) + n;
      made[id] = (made[id] ?? 0) + n;
    }
    const day = Math.ceil(h / 24);
    for (const [id, n] of Object.entries(step.got)) (perDay[day] ??= {})[id] = (perDay[day]![id] ?? 0) + n;
    if (kitAt === null && Object.entries(kitCost).every(([id, n]) => (made[id] ?? 0) >= n)) kitAt = h;
    // what is being built is done
    for (const s of sites) if (s.busyUntil && Date.parse(s.busyUntil) <= t) {
      s.level++;
      s.busyUntil = null;
      log.push(`${(h / 24).toFixed(1)} 天 ${siteName(race, s.kind)} Lv${s.level}（${workers} 隻，人手 ${Math.round(staffing(sites, workers).share * 100)}%）`);
    }
    if (sites.some((s) => s.busyUntil)) continue;
    const pay = (cost: Record<string, number>) => {
      if (!Object.entries(cost).every(([id, n]) => WORLD.has(id) || (store[id] ?? 0) >= n)) return false;
      for (const [id, n] of Object.entries(cost)) if (!WORLD.has(id)) store[id] = store[id]! - n;
      return true;
    };
    const slots = slotsFor(race, population.peak);
    const next = ORDER[race]![sites.length - 1];
    if (sites.length < slots && next) {
      const first = siteNext(next, 0)!;
      if (pay(first.cost)) sites.push({ id: sites.length + 1, kind: next, level: 0, busyUntil: new Date(t + first.hours * HOUR).toISOString() });
      continue;
    }
    // raise the lowest (the farm first among equals), while there are hands for it
    const up = sites.filter((s) => siteNext(s.kind, s.level)).sort((a, b) => a.level - b.level || (a.kind === "farm" ? -1 : 1))[0];
    if (!up || staffing(sites, workers).need + 10 > workers) continue;
    const n = siteNext(up.kind, up.level)!;
    if (pay(n.cost)) up.busyUntil = new Date(t + n.hours * HOUR).toISOString();
  }
  console.log(`## ${race}（${campStage(race, population.peak)} 階段，${aliveAt(population).length} 隻）\n`);
  console.log(log.join("\n"));
  console.log(`\n短劍＋皮甲的材料（${Object.entries(kitCost).map(([id, n]) => `${name(id)}×${n}`).join(" ")}）光靠場地：${kitAt ? `${(kitAt / 24).toFixed(1)} 天` : `>${DAYS} 天`}`);
  for (const day of [1, 3, 7, 14]) {
    const d = perDay[day] ?? {};
    console.log(`第 ${day} 天：${Object.entries(d).sort((a, b) => b[1] - a[1]).map(([id, n]) => `${name(id)} ${n}`).join("、")}`);
  }
  console.log(`第 ${DAYS} 天的場地：${sites.map((s) => `${siteName(race, s.kind)} Lv${s.level}`).join("、")}\n`);
}
