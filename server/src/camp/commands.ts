import { and, eq, isNull } from "drizzle-orm";
import {
  canAfford,
  FOOD_BOOST_MINUTES,
  FOOD_COOLDOWN_MINUTES,
  gearRule,
  give,
  neediest,
  placeableFoods,
  redistribute,
  repairCost,
  spend,
  type CampCommand,
  type GearItem,
  type Wearer,
} from "@goblincamp/shared/camp";
import type { Tx } from "../auth/session.ts";
import { campResidents, camps } from "../db/schema.ts";
import { addEvent } from "./service.ts";

type CampRow = typeof camps.$inferSelect;
const MINUTE = 60_000;

export type CommandResult =
  | { ok: true; message: string }
  | { ok: false; code: "unknown_gear" | "not_enough" | "nobody_needs" | "not_found" | "not_allowed" | "cooling_down" | "too_big"; message: string };

const cost = (c: Record<string, number>) => Object.entries(c).map(([id, n]) => `${id} ×${n}`).join("、");

/**
 * Does one thing the player asked for, checked against the books (server/CAMP.md §3.3). The camp must be locked and
 * advanced to `now` first. On success the books are written and the camp's version goes up.
 */
export async function runCommand(tx: Tx, camp: CampRow, command: CampCommand, now: Date): Promise<CommandResult> {
  const materials = { ...camp.materials };
  const store: GearItem[] = camp.armory.map((i) => ({ ...i }));
  const changes: Partial<CampRow> = {};
  let message = "";
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
      message = `做好了${rule.name}，給了 ${pick.id} 號。`;
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
  await addEvent(tx, camp.userId, now, "command", { command, message });
  return { ok: true, message };
}
