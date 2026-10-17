import { randomInt } from "node:crypto";
import { and, desc, eq, inArray, isNull, or, sql } from "drizzle-orm";
import {
  canAfford,
  enhanceCost,
  ENHANCE_MAX,
  gearMax,
  cannotWear,
  takeOff,
  buildableKinds,
  farmParts,
  siteName,
  siteNext,
  SITE_LEVEL_4_AT,
  SITE_LEVEL_5_AT,
  slotsFor,
  type Site,
  FOOD_BOOST_MINUTES,
  FOOD_COOLDOWN_MINUTES,
  gearRule,
  give,
  neediest,
  BASE_LIFESPAN_HOURS,
  campStage,
  MERCHANT_GAP_MINUTES,
  FOCUS_RARE_ROUNDS,
  focusToday,
  merchantVisitsToday,
  merchantMarks,
  breedName,
  SPECIAL_LIFESPAN,
  specialResident,
  visitorAt,
  buildingEffects,
  buildingLevel,
  buildingNext,
  campBuilding,
  MERCHANT_STAY_MINUTES,
  merchantGift,
  merchantName,
  merchantStock,
  taipeiDay,
  decorProblem,
  decorEarned,
  decorKind,
  RANCH_KINDS,
  RANCH_MAX_MINUTES,
  ranchGrown,
  ranchProblem,
  ranchYield,
  type RanchAnimal,
  PRINCESS_CHILD_HOURS,
  placeableFoods,
  raceRules,
  questRule,
  questShown,
  residentFor,
  redistribute,
  repairCost,
  REPAIR_BELOW,
  spend,
  type CampCommand,
  type GearItem,
  type Wearer,
  plainPiece,
} from "@goblincamp/shared/camp";
import { itemRule, materialName, MATERIALS } from "@goblincamp/shared/world";
import { donationPoints, guildLevelFor } from "@goblincamp/shared";
import type { Tx } from "../auth/session.ts";
import { campEvents, campResidents, camps, guildDonations, guildMembers, guilds } from "../db/schema.ts";
import { addEvent, campRaceLevel, gearPlaces, HALF_BREED_LIFESPAN, inGearPool, refundFor } from "./service.ts";
import { questMetrics } from "./quests.ts";
import { recordChange } from "./flows.ts";
import { talentBonusOf, talentEffect } from "../world/talents.ts";
import { merchantArrivals, merchantBought } from "./merchant.ts";

type CampRow = typeof camps.$inferSelect;
const MINUTE = 60_000;

export type CommandResult =
  | { ok: true; message: string; resident?: number; repeated?: boolean }
  | { ok: false; code: "unknown_gear" | "not_enough" | "nobody_needs" | "not_found" | "not_allowed" | "cooling_down" | "too_big" | "too_soon" | "busy" | "at_top" | "no_room"; message: string };

/** The store's piece at `index` if it is `gear`, else the first `gear` in the store (the list may have moved since). */
function findStock(store: GearItem[], index: number, gear: string): number {
  return store[index]?.id === gear ? index : store.findIndex((x) => x.id === gear);
}

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
  /** More to keep with the command's event (the merchant's visit id). */
  let extra: Record<string, unknown> = {};
  let gearBefore = new Map<number, string>();

  /** Who the handing out reaches (home, the towns, every held cell with the far switch on): a part of `wearers`. */
  let pool: Wearer[] = [];
  /** Everyone who can be handed gear: at home, on a held cell, guarding a friend's (gearPlaces). */
  const loadWearers = async () => {
    const places = await gearPlaces(tx, camp.userId);
    const rows = (
      await tx
        .select()
        .from(campResidents)
        .where(and(eq(campResidents.userId, camp.userId), or(eq(campResidents.place, "home"), inArray(campResidents.place, ["", ...Object.keys(places)])), isNull(campResidents.diedAt)))
    ).filter((r) => r.place === "home" || places[r.place]);
    gearBefore = new Map(rows.map((r) => [r.id, JSON.stringify(r.gear ?? {})]));
    wearers = rows.map((r) => ({ id: r.id, breed: r.breed, gear: structuredClone(r.gear ?? {}) as Wearer["gear"] }));
    const reached = new Set(rows.filter((r) => inGearPool(r.place, places, camp.autoGearFar)).map((r) => r.id));
    pool = wearers.filter((w) => reached.has(w.id));
    return wearers;
  };

  switch (command.kind) {
    case "craft": {
      // a 道具 (world/supplies.ts ITEMS) goes into the store like food
      const tool = itemRule(command.gear);
      if (tool) {
        if (tool.unlock && !camp.quests?.[tool.unlock]) return { ok: false, code: "not_allowed", message: `${tool.name}要先完成任務才能做（看「任務」頁）。` };
        if (!canAfford(materials, tool.cost)) return { ok: false, code: "not_enough", message: `素材不夠：${tool.name}要 ${cost(tool.cost)}。` };
        spend(materials, tool.cost);
        materials[tool.id] = (materials[tool.id] ?? 0) + 1;
        message = `做好了${tool.name}，放進倉庫（出征時可以帶）。`;
        break;
      }
      const rule = gearRule(command.gear);
      if (!rule) return { ok: false, code: "unknown_gear", message: "工坊不會做這個。" };
      if (!canAfford(materials, rule.cost)) return { ok: false, code: "not_enough", message: `素材不夠：${rule.name}要 ${cost(rule.cost)}。` };
      const item: GearItem = { id: rule.id, left: rule.durability };
      const all = await loadWearers();
      if (command.to !== undefined) {
        // for whoever the player picked (pinned there: the handing out leaves it be)
        const to = all.find((w) => w.id === command.to);
        if (!to) return { ok: false, code: "not_found", message: "找不到這位居民（可能在路上）。" };
        const why = cannotWear(to, item);
        if (why) return { ok: false, code: "not_allowed", message: why };
        spend(materials, rule.cost);
        give(to, item, store, true);
        resident = to.id;
      } else {
        // one or several, each for whoever needs it most by then (or into the store with the handing out off)
        const want = command.count ?? 1;
        let made = 0;
        let given = 0;
        while (made < want && canAfford(materials, rule.cost)) {
          const piece: GearItem = { id: rule.id, left: rule.durability };
          const pick = camp.autoGear ? neediest(camp.race, pool, piece) : null;
          if (camp.autoGear && !pick) break;
          spend(materials, rule.cost);
          if (pick) {
            give(pick, piece, store);
            given++;
          } else store.push(piece); // (the handing out is off: into the store)
          if (made === 0) resident = pick?.id; // (the devices say who by name: names come from the seed on them)
          made++;
        }
        if (made === 0) return { ok: false, code: "nobody_needs", message: `沒有人需要${rule.name}（大家都有一樣好或更好的）。` };
        if (made > 1) resident = undefined;
        redistribute(camp.race, pool, store, camp.autoGear);
        const stopped = made < want ? (canAfford(materials, rule.cost) ? "（其他人都有一樣好的了）" : "（材料用完了）") : "";
        message = made > 1 ? `做好了 ${made} 件${rule.name}${given ? `，發給了 ${given} 隻` : "，放進倉庫"}${stopped}。` : resident === undefined ? `做好了${rule.name}，放進倉庫。${stopped}` : `做好了${rule.name}。${stopped}`;
        break;
      }
      redistribute(camp.race, pool, store, camp.autoGear);
      message = `做好了${rule.name}。`;
      break;
    }
    case "equip": {
      const all = await loadWearers();
      const to = all.find((w) => w.id === command.resident);
      if (!to) return { ok: false, code: "not_found", message: "找不到這位居民（可能在路上）。" };
      const at = findStock(store, command.stock, command.gear);
      if (at < 0) return { ok: false, code: "not_found", message: "倉庫裡找不到這件。" };
      const item = store[at]!;
      const why = cannotWear(to, item);
      if (why) return { ok: false, code: "not_allowed", message: why };
      store.splice(at, 1);
      give(to, item, store, true);
      redistribute(camp.race, pool, store, camp.autoGear);
      message = `換上了${gearRule(item.id)!.name}。`;
      resident = to.id;
      break;
    }
    case "unequip": {
      const all = await loadWearers();
      const from = all.find((w) => w.id === command.resident);
      const piece = from && takeOff(from, command.slot, store);
      if (!piece) return { ok: false, code: "not_found", message: "那個位置沒有裝備。" };
      message = `${gearRule(piece.id)?.name ?? piece.id}收回倉庫了（保留，不會自動發出去）。`;
      resident = from!.id;
      break;
    }
    case "gear-hold": {
      const at = findStock(store, command.stock, command.gear);
      if (at < 0) return { ok: false, code: "not_found", message: "倉庫裡找不到這件。" };
      const name = gearRule(store[at]!.id)?.name ?? store[at]!.id;
      if (command.held) store[at] = { ...store[at]!, held: true };
      else {
        store[at] = plainPiece(store[at]!);
        await loadWearers();
        redistribute(camp.race, pool, store, camp.autoGear);
      }
      message = command.held ? `${name}保留在倉庫。` : `${name}交給自動分配。`;
      break;
    }
    case "auto-gear": {
      changes.autoGear = command.on;
      if (command.on) {
        await loadWearers();
        redistribute(camp.race, pool, store, true);
      }
      message = command.on ? "倉庫的裝備會自動發給最需要的居民（你手動給的、保留的不會動）。" : "倉庫的裝備不再自動分配，要自己發。";
      break;
    }
    case "auto-gear-far": {
      changes.autoGearFar = command.on;
      camp.autoGearFar = command.on; // (the pool below follows the new switch)
      if (command.on && camp.autoGear) {
        await loadWearers();
        redistribute(camp.race, pool, store, true);
      }
      message = command.on ? "自動分配也會發給每一塊領地的居民。" : "自動分配只發給營地和城鎮的居民。";
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
      item.left = gearMax(item);
      message = `修好了${rule.name}。`;
      break;
    }
    case "enhance": {
      // 強化 (ECONOMY.md §1.2): +1 at a time up to ENHANCE_MAX, never fails; mended as it goes
      let item: GearItem | undefined;
      if (command.stock !== undefined) item = store[command.stock];
      else if (command.resident !== undefined && command.slot) item = (await loadWearers()).find((w) => w.id === command.resident)?.gear[command.slot];
      const rule = item && gearRule(item.id);
      if (!item || !rule) return { ok: false, code: "not_found", message: "找不到要強化的東西。" };
      const price = enhanceCost(item);
      if (!price) return { ok: false, code: "at_top", message: `${rule.name}已經 +${ENHANCE_MAX} 了。` };
      if (!canAfford(materials, price)) return { ok: false, code: "not_enough", message: `素材不夠：強化${rule.name}要 ${cost(price)}。` };
      spend(materials, price);
      item.plus = (item.plus ?? 0) + 1;
      item.left = gearMax(item);
      extra = { gear: rule.id, plus: item.plus };
      message = `${rule.name}強化到 +${item.plus}。`;
      break;
    }
    case "refine": {
      // ★ 拼裝改造: for all it was made from, a piece becomes a refined one (and is as good as new)
      if (!((await talentBonusOf(tx, camp.userId)).refine ?? 0)) return { ok: false, code: "not_allowed", message: "要先點天賦「拼裝改造」。" };
      let item: GearItem | undefined;
      if (command.stock !== undefined) item = store[command.stock];
      else if (command.resident !== undefined && command.slot) item = (await loadWearers()).find((w) => w.id === command.resident)?.gear[command.slot];
      const rule = item && gearRule(item.id);
      if (!item || !rule) return { ok: false, code: "not_found", message: "找不到要改造的東西。" };
      if (item.refined) return { ok: false, code: "not_allowed", message: `這件${rule.name}已經是 ★ 精良的了。` };
      if (!canAfford(materials, rule.cost)) return { ok: false, code: "not_enough", message: `素材不夠：改造${rule.name}要 ${cost(rule.cost)}。` };
      spend(materials, rule.cost);
      item.refined = true;
      item.left = gearMax(item);
      message = `${rule.name}改造成 ★ 精良的了。`;
      break;
    }
    case "repair-all": {
      // the most worn first, while the materials last
      const jobs = [...(await loadWearers()).flatMap((w) => Object.values(w.gear) as GearItem[]), ...store]
        .filter((i) => gearRule(i.id) && i.left / gearMax(i) < REPAIR_BELOW)
        .sort((a, b) => a.left / gearMax(a) - b.left / gearMax(b));
      if (!jobs.length) return { ok: false, code: "not_found", message: "沒有要修的。" };
      let done = 0;
      for (const item of jobs) {
        const price = repairCost(gearRule(item.id)!);
        if (!canAfford(materials, price)) continue;
        spend(materials, price);
        item.left = gearMax(item);
        done++;
      }
      if (!done) return { ok: false, code: "not_enough", message: "材料不夠，一件都修不了。" };
      message = `修好了 ${done} 件${done < jobs.length ? `（還有 ${jobs.length - done} 件材料不夠）` : ""}。`;
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
    case "visitor-accept":
    case "visitor-decline": {
      // (the one at the gate now: worked out from the camp's seed and the day, as the view shows it)
      const level = await campRaceLevel(tx, camp.userId);
      const host = talentEffect(await talentBonusOf(tx, camp.userId), "campHost");
      const home = await tx
        .select({ id: campResidents.id, breed: campResidents.breed, gear: campResidents.gear })
        .from(campResidents)
        .where(and(eq(campResidents.userId, camp.userId), eq(campResidents.place, "home"), isNull(campResidents.diedAt)));
      const visitor = visitorAt(camp.seed, now, level, new Set(home.map((r) => r.breed)), host, buildingEffects(camp.buildings).visitorChance);
      if (!visitor || visitor.id !== command.visit || camp.visitors[visitor.id]) return { ok: false, code: "not_found", message: "門口已經沒有人了。" };
      const who = breedName(camp.race, visitor.breed);
      if (command.kind === "visitor-decline") {
        changes.visitors = { ...camp.visitors, [visitor.id]: "no" };
        extra = { visitor: visitor.breed, answer: "no" };
        message = `${who}離開了。`;
        break;
      }
      const rules = raceRules(camp.race);
      let leaving: (typeof home)[number] | undefined;
      if (home.length >= rules.homeCap) {
        leaving = home.find((r) => r.id === command.replace);
        if (!leaving) return { ok: false, code: "no_room", message: `營地住滿了（${rules.homeCap}），要先請一位離開，或選一位換掉。` };
      }
      if (!canAfford(materials, visitor.fee)) return { ok: false, code: "not_enough", message: `見面禮不夠：${who}想要 ${cost(visitor.fee)}。` };
      spend(materials, visitor.fee);
      if (leaving) {
        await tx.update(campResidents).set({ diedAt: now, gear: null }).where(and(eq(campResidents.userId, camp.userId), eq(campResidents.id, leaving.id)));
        changes.armory = [...camp.armory, ...Object.values(leaving.gear ?? {}).map(plainPiece)];
      }
      const special = specialResident(visitor.breed);
      const lifespan = special ? SPECIAL_LIFESPAN * (rules.breeds.find((b) => b.id === "common")?.lifespan ?? 1) : (rules.breeds.find((b) => b.id === visitor.breed)?.lifespan ?? 1);
      const jitter = 0.9 + 0.2 * (randomInt(0, 1_000_000) / 1_000_000);
      resident = camp.nextId;
      await tx.insert(campResidents).values({
        userId: camp.userId,
        id: resident,
        breed: visitor.breed,
        seed: randomInt(0, 2 ** 32),
        bornAt: now,
        diesAt: rules.ages ? new Date(now.getTime() + Math.floor(BASE_LIFESPAN_HOURS * 3_600_000 * lifespan * jitter)) : null,
      });
      changes.nextId = camp.nextId + 1;
      changes.visitors = { ...camp.visitors, [visitor.id]: "yes" };
      extra = { visitor: visitor.breed, answer: "yes", fee: visitor.fee, ...(leaving ? { replaced: leaving.id } : {}) };
      message = `${who}住進營地了。`;
      break;
    }
    case "building-build": {
      // 營地建設 (buildings.ts): one going up at a time
      const rule = campBuilding(command.building)!;
      const busy = Object.entries(camp.buildings ?? {}).find(([, b]) => b?.busyUntil);
      if (busy) return { ok: false, code: "busy", message: `${campBuilding(busy[0])?.name ?? "建設"}還在蓋，一次只能蓋一個。` };
      const level = buildingLevel(camp.buildings, command.building);
      const next = buildingNext(command.building, level, talentEffect(await talentBonusOf(tx, camp.userId), "campBuild"));
      if (!next) return { ok: false, code: "at_top", message: `${rule.name}已經是最高級了。` };
      if (!canAfford(materials, next.cost)) return { ok: false, code: "not_enough", message: `素材不夠：${level ? `升級${rule.name}` : `蓋${rule.name}`}要 ${cost(next.cost)}。` };
      spend(materials, next.cost);
      changes.buildings = { ...camp.buildings, [command.building]: { level, busyUntil: new Date(now.getTime() + next.hours * 3_600_000).toISOString() } };
      extra = { building: command.building, level: level + 1 };
      message = `開始蓋${rule.name} Lv${level + 1}，${+next.hours.toFixed(1)} 小時後完成。`;
      break;
    }
    case "resident-dismiss": {
      const [leaving] = await tx
        .select({ id: campResidents.id, breed: campResidents.breed, gear: campResidents.gear })
        .from(campResidents)
        .where(and(eq(campResidents.userId, camp.userId), eq(campResidents.id, command.resident), eq(campResidents.place, "home"), isNull(campResidents.diedAt)));
      if (!leaving) return { ok: false, code: "not_found", message: "營地裡沒有這位居民。" };
      await tx.update(campResidents).set({ diedAt: now, gear: null }).where(and(eq(campResidents.userId, camp.userId), eq(campResidents.id, leaving.id)));
      changes.armory = [...camp.armory, ...Object.values(leaving.gear ?? {}).map(plainPiece)];
      extra = { dismissed: leaving.id, breed: leaving.breed };
      message = `${breedName(camp.race, leaving.breed)}離開營地了，裝備收回倉庫。`;
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
      // (the 巧手 talent: built sooner)
      const hours = first.hours * (1 - Math.min(0.5, talentEffect(await talentBonusOf(tx, camp.userId), "campBuild")));
      const site: Site = { id: Math.max(0, ...camp.sites.map((x) => x.id)) + 1, kind: command.site, level: 0, busyUntil: new Date(now.getTime() + hours * 3_600_000).toISOString() };
      changes.sites = [...camp.sites, site];
      message = `開始蓋${name}，${+hours.toFixed(1)} 小時後完成。`;
      break;
    }
    case "site-upgrade":
    case "farm-upgrade": {
      const target = command.kind === "farm-upgrade" ? camp.sites.find((x) => x.kind === "farm") : camp.sites.find((x) => x.id === command.site);
      if (!target) return { ok: false, code: "not_found", message: "找不到這個場地。" };
      const name = siteName(camp.race, target.kind);
      const busy = camp.sites.find((x) => x.busyUntil);
      if (busy) return { ok: false, code: "busy", message: `${siteName(camp.race, busy.kind)}還在蓋，一次只能蓋一個。` };
      const level = await campRaceLevel(tx, camp.userId);
      const next = siteNext(target.kind, target.level, level);
      if (!next) {
        const opens = target.kind !== "farm" && target.level < 5 ? (target.level < 4 ? SITE_LEVEL_4_AT : SITE_LEVEL_5_AT) : null;
        return { ok: false, code: "at_top", message: opens ? `${name}要種族等級 ${opens} 級才能再升。` : `${name}已經是最高級了。` };
      }
      if (!canAfford(materials, next.cost)) return { ok: false, code: "not_enough", message: `素材不夠：升級${name}要 ${cost(next.cost)}。` };
      spend(materials, next.cost);
      const hours = next.hours * (1 - Math.min(0.5, talentEffect(await talentBonusOf(tx, camp.userId), "campBuild")));
      const until = new Date(now.getTime() + hours * 3_600_000).toISOString();
      changes.sites = camp.sites.map((x) => (x.id === target.id ? { ...x, busyUntil: until } : x));
      const what = target.kind === "farm" ? farmParts(camp.race, target.level + 1).at(-1) : `${name} Lv${target.level + 1}`;
      message = `開始蓋${what}，${+hours.toFixed(1)} 小時後完成。`;
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
    case "quest-claim": {
      const quest = questRule(command.quest);
      if (!quest) return { ok: false, code: "not_found", message: "沒有這個任務。" };
      const claimed = camp.quests ?? {};
      if (quest.id in claimed) return { ok: false, code: "not_allowed", message: "這個任務的獎勵已經領過了。" };
      if (!questShown(quest, claimed)) return { ok: false, code: "not_allowed", message: "這個任務還沒開放（先完成前一個）。" };
      const [have, need] = quest.goal(await questMetrics(tx, camp));
      if (have < need) return { ok: false, code: "not_allowed", message: `還沒完成「${quest.title}」（${have}/${need}）。` };
      const r = quest.reward;
      for (const [id, k] of Object.entries(r.materials ?? {})) materials[id] = (materials[id] ?? 0) + k;
      if (r.gear?.length) {
        for (const id of r.gear) store.push({ id, left: gearRule(id)!.durability });
        await loadWearers();
        redistribute(camp.race, pool, store, camp.autoGear);
      }
      if (r.residents) {
        // born at home now, as the race's births are (their own random numbers: "quest:<id>")
        const rules = raceRules(camp.race);
        const place = { race: camp.race, key: `quest:${quest.id}`, startedAt: camp.startedAt.getTime(), birthMinutes: rules.homeBirthMinutes, cap: rules.homeCap };
        const born = Array.from({ length: r.residents }, (_, k) => residentFor(place, camp.seed, k, camp.nextId + k, now.getTime()));
        await tx.insert(campResidents).values(
          born.map((b) => ({ userId: camp.userId, id: b.id, breed: b.breed, seed: b.seed, bornAt: new Date(b.bornAt), diesAt: b.diesAt === null ? null : new Date(b.diesAt) })),
        );
        changes.nextId = camp.nextId + born.length;
      }
      changes.quests = { ...claimed, [quest.id]: now.toISOString() };
      const decor = r.decor?.[camp.race] ? decorKind(r.decor[camp.race]!) : undefined;
      message = `完成「${quest.title}」，領到獎勵了！` + (decor ? `新裝飾「${decor.name}」可以放了。` : "");
      break;
    }
    case "merchant-arrive": {
      const name = merchantName(camp.race);
      const arrivals = await merchantArrivals(tx, camp.userId, now);
      const latest = arrivals[0];
      if (latest && now.getTime() - latest.at.getTime() < MERCHANT_STAY_MINUTES * 60_000) {
        return { ok: true, message: `${name}還在營地。`, repeated: true }; // (another Mac of the same account brought it already)
      }
      const level = await campRaceLevel(tx, camp.userId);
      if (arrivals.filter((a) => taipeiDay(a.at) === taipeiDay(now)).length >= merchantVisitsToday(camp.focus, now, level)) {
        return { ok: false, code: "not_allowed", message: `${name}今天已經來過了。` };
      }
      if (latest && now.getTime() - latest.at.getTime() < MERCHANT_GAP_MINUTES * 60_000) {
        return { ok: false, code: "too_soon", message: `${name}剛走不久。` };
      }
      // (a day of much focus: the merchant brings a rare find, marked in the visit's id)
      // (and a race level of MERCHANT_RARE_AT, MERCHANT_LEGEND_AT, or the 精打細算 talent: more of them, marked the same way)
      const trade = talentEffect(await talentBonusOf(tx, camp.userId), "campTrade");
      // (the 宴會廳 from level 2 brings one more too)
      const more = trade + (buildingEffects(camp.buildings).merchantMore ? 1 : 0);
      const visit = `${camp.userId.slice(0, 8)}-${now.getTime()}${merchantMarks(level, focusToday(camp.focus, now) >= FOCUS_RARE_ROUNDS, more)}`;
      const gift = merchantGift(visit, campStage(camp.race, camp.peak));
      for (const [id, n] of Object.entries(gift)) materials[id] = (materials[id] ?? 0) + n;
      extra = { visit, gift };
      message = `${name}來了，送你 ${cost(gift)}。`;
      break;
    }
    case "merchant-trade": {
      const [latest] = await merchantArrivals(tx, camp.userId, now);
      if (!latest || latest.visit !== command.visit || now.getTime() - latest.at.getTime() >= MERCHANT_STAY_MINUTES * 60_000) {
        return { ok: false, code: "not_found", message: "商人已經走了。" };
      }
      const offer = merchantStock(command.visit, camp.race)[command.offer];
      if (!offer) return { ok: false, code: "not_found", message: "商人沒有這樣東西。" };
      if ((await merchantBought(tx, camp.userId, command.visit)).includes(command.offer)) {
        return { ok: false, code: "not_allowed", message: "這個已經換過了。" };
      }
      if (!canAfford(materials, offer.give)) return { ok: false, code: "not_enough", message: `素材不夠：要 ${cost(offer.give)}。` };
      spend(materials, offer.give);
      for (const [id, n] of Object.entries(offer.get)) materials[id] = (materials[id] ?? 0) + n;
      message = `用 ${cost(offer.give)} 換到了 ${cost(offer.get)}。`;
      break;
    }
    case "ranch-sync": {
      const ranch = camp.ranch ?? { animals: [] };
      const known = new Map(ranch.animals.map((a) => [a.id, a]));
      // (one already on the books keeps its birthday; a new one is born, or caught full-grown, now)
      const next: RanchAnimal[] = command.animals.map((a) => {
        const { name: _old, ...kept } = known.get(a.id) ?? { id: a.id, kind: a.kind, bornAt: now.toISOString(), ...(a.caught ? { caught: true } : {}) };
        return a.name ? { ...kept, name: a.name } : kept; // (its name is the player's to give and change)
      });
      const problem = ranchProblem(next, campStage(camp.race, camp.peak));
      if (problem) return { ok: false, code: "not_allowed", message: problem };
      // what the herd on the books gave while the camp was open: never more minutes than really passed
      const passed = ranch.syncedAt ? (now.getTime() - Date.parse(ranch.syncedAt)) / 60_000 : 0;
      const minutes = Math.max(0, Math.min(command.minutes, RANCH_MAX_MINUTES, passed));
      const [master] = await tx
        .select({ id: campResidents.id })
        .from(campResidents)
        .where(and(eq(campResidents.userId, camp.userId), eq(campResidents.place, "home"), eq(campResidents.breed, "beastmaster"), isNull(campResidents.diedAt)))
        .limit(1);
      const boost = talentEffect(await talentBonusOf(tx, camp.userId), "campRanch") + (master ? 0.15 : 0);
      const { gain, carry } = ranchYield(ranch.animals, minutes, now, ranch.carry, boost);
      const kept = new Set(next.map((a) => a.id));
      for (const id of command.butchered ?? []) {
        const animal = known.get(id);
        const meat = animal && RANCH_KINDS[animal.kind]?.butcher;
        if (!animal || !meat || kept.has(id) || !ranchGrown(animal, now)) continue;
        for (const [m, n] of Object.entries(meat)) gain[m] = (gain[m] ?? 0) + n;
        known.delete(id); // (once)
      }
      for (const [id, n] of Object.entries(gain)) materials[id] = (materials[id] ?? 0) + n;
      changes.ranch = { animals: next, syncedAt: now.toISOString(), carry };
      // (newcomers on the books: born at the ranch, or caught; for the camp's 動態, shared/src/camp/feed.ts)
      const newcomers = command.animals.filter((a) => !known.has(a.id));
      const born = newcomers.filter((a) => !a.caught).map((a) => a.kind), caught = newcomers.filter((a) => a.caught).map((a) => a.kind);
      extra = { gain, ...(born.length ? { born } : {}), ...(caught.length ? { caught } : {}) };
      message = Object.keys(gain).length ? `牧場：${cost(gain)}。` : "";
      break;
    }
    case "decor-set": {
      // (a kind that is no more, from a Mac with an older catalogue, is simply left out)
      const items = command.items.filter((d) => decorKind(d.kind)).map((d) => ({ kind: d.kind, x: Math.round(d.x), y: Math.round(d.y), ...(d.flip ? { flip: true } : {}) }));
      const problem = decorProblem(items, camp.race, campStage(camp.race, camp.peak), decorEarned(camp.quests ?? {}, camp.race), await campRaceLevel(tx, camp.userId));
      if (problem) return { ok: false, code: problem.includes("點數") ? "no_room" : "not_allowed", message: problem };
      changes.decor = items;
      message = "";
      break;
    }
    case "guild-donate": {
      // camp materials to the player's guild: worth contribution, which raises its level (GUILD.md §4.1)
      const [member] = await tx.select({ guildId: guildMembers.guildId }).from(guildMembers).where(eq(guildMembers.userId, camp.userId));
      if (!member) return { ok: false, code: "not_allowed", message: "你還沒有加入公會。" };
      let points = 0;
      for (const [id, n] of Object.entries(command.materials)) {
        const each = donationPoints(id, (m) => m in MATERIALS);
        if (!each) return { ok: false, code: "not_allowed", message: `${materialName(id)}不能捐。` };
        points += each * n;
      }
      if (!points) return { ok: false, code: "not_allowed", message: "沒有要捐的東西。" };
      if (!canAfford(materials, command.materials)) return { ok: false, code: "not_enough", message: `素材不夠：要 ${cost(command.materials)}。` };
      spend(materials, command.materials);
      const [guild] = await tx.select().from(guilds).where(eq(guilds.id, member.guildId)).for("update");
      const total = guild!.points + points;
      const level = Math.max(guild!.level, guildLevelFor(total));
      await tx.update(guilds).set({ points: total, level }).where(eq(guilds.id, member.guildId));
      await tx.insert(guildDonations).values({ guildId: member.guildId, userId: camp.userId, materials: command.materials, points, at: now });
      extra = { guildId: member.guildId, points, ...(level > guild!.level ? { leveled: level } : {}) };
      message = `捐了 ${cost(command.materials)} 給公會（貢獻 +${points}）。${level > guild!.level ? `公會升到 ${level} 級了！` : ""}`;
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
  await recordChange(tx, camp.userId, now, command.kind, camp.materials, materials); // (for the economy dashboard)
  const set: Partial<CampRow> = { ...changes, materials, armory: store, version: camp.version + 1 };
  await tx.update(camps).set(set).where(eq(camps.userId, camp.userId));
  Object.assign(camp, set);
  await addEvent(tx, camp.userId, now, "command", { command, message, resident, ...extra });
  return { ok: true, message, resident };
}
