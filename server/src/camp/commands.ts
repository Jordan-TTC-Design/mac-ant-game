import { randomInt } from "node:crypto";
import { and, desc, eq, isNull, sql } from "drizzle-orm";
import {
  canAfford,
  buildableKinds,
  farmParts,
  siteName,
  siteNext,
  slotsFor,
  type Site,
  FOOD_BOOST_MINUTES,
  FOOD_COOLDOWN_MINUTES,
  gearRule,
  give,
  neediest,
  BASE_LIFESPAN_HOURS,
  PRINCESS_CHILD_HOURS,
  placeableFoods,
  raceRules,
  redistribute,
  repairCost,
  spend,
  type CampCommand,
  type GearItem,
  type Wearer,
} from "@goblincamp/shared/camp";
import { materialName } from "@goblincamp/shared/world";
import type { Tx } from "../auth/session.ts";
import { campEvents, campResidents, camps } from "../db/schema.ts";
import { addEvent, campRaceLevel, HALF_BREED_LIFESPAN, refundFor } from "./service.ts";

type CampRow = typeof camps.$inferSelect;
const MINUTE = 60_000;

export type CommandResult =
  | { ok: true; message: string; resident?: number; repeated?: boolean }
  | { ok: false; code: "unknown_gear" | "not_enough" | "nobody_needs" | "not_found" | "not_allowed" | "cooling_down" | "too_big" | "too_soon" | "busy" | "at_top" | "no_room"; message: string };

const cost = (c: Record<string, number>) => Object.entries(c).map(([id, n]) => `${materialName(id)} ×${n}`).join("、");

/**
 * Does one thing the player asked for, checked against the books (server/CAMP.md §3.3). The camp must be locked and
 * advanced to `now` first. On success the books are written and the camp's version goes up.
 */
export async function runCommand(tx: Tx, camp: CampRow, command: CampCommand, now: Date): Promise<CommandResult> {
  if (command.requestId) {
    // done before (a device sending its queue again): answer as then, do nothing
    const [done] = await tx
      .select({ data: campEvents.data })
      .from(campEvents)
      .where(and(eq(campEvents.userId, camp.userId), eq(campEvents.kind, "command"), sql`${campEvents.data}->'command'->>'requestId' = ${command.requestId}`))
      .limit(1);
    if (done) {
      const data = done.data as { message?: string; resident?: number };
      return { ok: true, message: data.message ?? "", resident: data.resident, repeated: true };
    }
  }
  const materials = { ...camp.materials };
  const store: GearItem[] = camp.armory.map((i) => ({ ...i }));
  const changes: Partial<CampRow> = {};
  let message = "";
  let resident: number | undefined;
  let wearers: Wearer[] | null = null;
  let gearBefore = new Map<number, string>();

  const loadWearers = async () => {
    const rows = await tx.select().from(campResidents).where(and(eq(campResidents.userId, camp.userId), eq(campResidents.place, "home"), isNull(campResidents.diedAt)));
    gearBefore = new Map(rows.map((r) => [r.id, JSON.stringify(r.gear ?? {})]));
    wearers = rows.map((r) => ({ id: r.id, breed: r.breed, gear: structuredClone(r.gear ?? {}) as Wearer["gear"] }));
    return wearers;
  };

  switch (command.kind) {
    case "craft": {
      const rule = gearRule(command.gear);
      if (!rule) return { ok: false, code: "unknown_gear", message: "工坊不會做這個。" };
      if (!canAfford(materials, rule.cost)) return { ok: false, code: "not_enough", message: `素材不夠：${rule.name}要 ${cost(rule.cost)}。` };
      const item: GearItem = { id: rule.id, left: rule.durability };
      const pick = neediest(camp.race, await loadWearers(), item);
      if (!pick) return { ok: false, code: "nobody_needs", message: `沒有人需要${rule.name}（大家都有一樣好或更好的）。` };
      spend(materials, rule.cost);
      give(pick, item, store);
      redistribute(camp.race, wearers!, store);
      message = `做好了${rule.name}。`;
      resident = pick.id; // (the devices say who by name: names come from the seed on them)
      break;
    }
    case "repair": {
      let item: GearItem | undefined;
      if (command.stock !== undefined) item = store[command.stock];
      else if (command.resident !== undefined && command.slot) item = (await loadWearers()).find((w) => w.id === command.resident)?.gear[command.slot];
      const rule = item && gearRule(item.id);
      if (!item || !rule) return { ok: false, code: "not_found", message: "找不到要修的東西。" };
      const price = repairCost(rule);
      if (!canAfford(materials, price)) return { ok: false, code: "not_enough", message: `素材不夠：修${rule.name}要 ${cost(price)}。` };
      spend(materials, price);
      item.left = rule.durability;
      message = `修好了${rule.name}。`;
      break;
    }
    case "food": {
      if (!placeableFoods(camp.race).includes(command.food)) return { ok: false, code: "not_allowed", message: "這個種族不能放這個。" };
      const ready = camp.foodCooldowns[command.food];
      if (ready && Date.parse(ready) > now.getTime()) {
        const minutes = Math.ceil((Date.parse(ready) - now.getTime()) / MINUTE);
        return { ok: false, code: "cooling_down", message: `還要等 ${minutes} 分鐘才能再放。` };
      }
      const running = Math.max(now.getTime(), Date.parse(camp.boosts[command.food] ?? "") || 0);
      const ends = Math.min(now.getTime() + 60 * MINUTE, running + FOOD_BOOST_MINUTES * MINUTE); // (up to an hour, as on the Mac)
      changes.boosts = { ...camp.boosts, [command.food]: new Date(ends).toISOString() };
      changes.foodCooldowns = { ...camp.foodCooldowns, [command.food]: new Date(now.getTime() + FOOD_COOLDOWN_MINUTES * MINUTE).toISOString() };
      message = "放好了。";
      break;
    }
    case "princess-name":
      if (/[\r\n\t]/.test(command.name)) return { ok: false, code: "not_allowed", message: "名字不能換行。" };
      changes.princessName = command.name;
      message = `公主的名字改成「${command.name}」了。`;
      break;
    case "princess-child": {
      // at most one every few hours (her story on the Mac takes longer than that anyway)
      const recent = await tx
        .select({ at: campEvents.at, data: campEvents.data })
        .from(campEvents)
        .where(and(eq(campEvents.userId, camp.userId), eq(campEvents.kind, "command")))
        .orderBy(desc(campEvents.seq))
        .limit(200);
      const lastChild = recent.find((e) => (e.data as { command?: { kind?: string } }).command?.kind === "princess-child");
      if (lastChild && now.getTime() - lastChild.at.getTime() < PRINCESS_CHILD_HOURS * 3_600_000) {
        return { ok: false, code: "too_soon", message: "公主剛生過孩子，還太快了。" };
      }
      const rules = raceRules(camp.race);
      const lifespan = HALF_BREED_LIFESPAN[camp.race]?.[command.breed] ?? 1;
      const jitter = 0.9 + 0.2 * (randomInt(0, 1_000_000) / 1_000_000);
      resident = camp.nextId;
      await tx.insert(campResidents).values({
        userId: camp.userId,
        id: resident,
        breed: command.breed,
        seed: randomInt(0, 2 ** 32),
        parents: command.parents || null,
        bornAt: now,
        diesAt: rules.ages ? new Date(now.getTime() + Math.floor(BASE_LIFESPAN_HOURS * 3_600_000 * lifespan * jitter)) : null,
      });
      changes.nextId = camp.nextId + 1;
      message = "公主的孩子加入營地了。";
      break;
    }
    case "site-build": {
      if (!buildableKinds(camp.race).includes(command.site)) return { ok: false, code: "not_allowed", message: "這個種族不能蓋這個。" };
      const busy = camp.sites.find((x) => x.busyUntil);
      if (busy) return { ok: false, code: "busy", message: `${siteName(camp.race, busy.kind)}還在蓋，一次只能蓋一個。` };
      const slots = slotsFor(camp.race, camp.peak, await campRaceLevel(tx, camp.userId));
      if (camp.sites.length >= slots) return { ok: false, code: "no_room", message: `空地都用完了（${slots} 格）。營地長大或種族升級會多出空地。` };
      const first = siteNext(command.site, 0)!;
      const name = siteName(camp.race, command.site);
      if (!canAfford(materials, first.cost)) return { ok: false, code: "not_enough", message: `素材不夠：蓋${name}要 ${cost(first.cost)}。` };
      spend(materials, first.cost);
      const site: Site = { id: Math.max(0, ...camp.sites.map((x) => x.id)) + 1, kind: command.site, level: 0, busyUntil: new Date(now.getTime() + first.hours * 3_600_000).toISOString() };
      changes.sites = [...camp.sites, site];
      message = `開始蓋${name}，${first.hours} 小時後完成。`;
      break;
    }
    case "site-upgrade":
    case "farm-upgrade": {
      const target = command.kind === "farm-upgrade" ? camp.sites.find((x) => x.kind === "farm") : camp.sites.find((x) => x.id === command.site);
      if (!target) return { ok: false, code: "not_found", message: "找不到這個場地。" };
      const name = siteName(camp.race, target.kind);
      const busy = camp.sites.find((x) => x.busyUntil);
      if (busy) return { ok: false, code: "busy", message: `${siteName(camp.race, busy.kind)}還在蓋，一次只能蓋一個。` };
      const next = siteNext(target.kind, target.level);
      if (!next) return { ok: false, code: "at_top", message: `${name}已經是最高級了。` };
      if (!canAfford(materials, next.cost)) return { ok: false, code: "not_enough", message: `素材不夠：升級${name}要 ${cost(next.cost)}。` };
      spend(materials, next.cost);
      const until = new Date(now.getTime() + next.hours * 3_600_000).toISOString();
      changes.sites = camp.sites.map((x) => (x.id === target.id ? { ...x, busyUntil: until } : x));
      const what = target.kind === "farm" ? farmParts(camp.race, target.level + 1).at(-1) : `${name} Lv${target.level + 1}`;
      message = `開始蓋${what}，${next.hours} 小時後完成。`;
      break;
    }
    case "site-demolish": {
      const target = camp.sites.find((x) => x.id === command.site);
      if (!target) return { ok: false, code: "not_found", message: "找不到這個場地。" };
      if (target.kind === "farm") return { ok: false, code: "not_allowed", message: "田地不能拆。" };
      const back = refundFor(target);
      for (const [id, n] of Object.entries(back)) materials[id] = (materials[id] ?? 0) + n;
      changes.sites = camp.sites.filter((x) => x.id !== target.id);
      message = `拆掉了${siteName(camp.race, target.kind)}` + (Object.keys(back).length ? `，拿回 ${cost(back)}。` : "。");
      break;
    }
    case "story": {
      if (JSON.stringify(command.romance ?? null).length > 20_000) return { ok: false, code: "too_big", message: "故事的資料太大了。" };
      changes.romance = command.romance ?? null;
      message = "";
      break;
    }
  }

  if (wearers) {
    for (const w of wearers as Wearer[]) {
      const now_ = JSON.stringify(w.gear);
      if (now_ === gearBefore.get(w.id)) continue;
      await tx.update(campResidents).set({ gear: Object.keys(w.gear).length ? (w.gear as Record<string, GearItem>) : null }).where(and(eq(campResidents.userId, camp.userId), eq(campResidents.id, w.id)));
    }
  }
  const set: Partial<CampRow> = { ...changes, materials, armory: store, version: camp.version + 1 };
  await tx.update(camps).set(set).where(eq(camps.userId, camp.userId));
  Object.assign(camp, set);
  await addEvent(tx, camp.userId, now, "command", { command, message, resident });
  return { ok: true, message, resident };
}
