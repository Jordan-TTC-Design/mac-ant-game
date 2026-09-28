import { randomInt } from "node:crypto";
import { and, desc, eq, gt, inArray, isNull, sql } from "drizzle-orm";
import {
  advance,
  aliveAt,
  BASE_LIFESPAN_HOURS,
  fall,
  fightBoosts,
  gearRule,
  planRaid,
  raidTime,
  SANCTUARY_REST_HOURS,
  redistribute,
  type GearItem,
  type GearSlot,
  type Wearer,
  campStage,
  raceRules,
  startHome,
  type CampEvent,
  type CampView,
  type MigrateInput,
  type Place,
  type Population,
  type RaidReport,
  type Resident,
} from "@goblincamp/shared/camp";
import { hashString, randomFrom } from "@goblincamp/shared/world";
import type { Tx } from "../auth/session.ts";
import { campEvents, campResidents, camps, expeditions, worldCells, worldPlayers } from "../db/schema.ts";
import { resolveRaid, type RaidOutcome } from "./raids.ts";

export type CampRow = typeof camps.$inferSelect;
export type ResidentRow = typeof campResidents.$inferSelect;

const HOUR = 3_600_000;

/** Caps for moving an old save in (server/CAMP.md §6). Residents: the race's home cap. */
export const MIGRATE_CAPS = { material: 200, larder: 16, armoryPerGear: 10, romanceChars: 20_000 };

/** A piece as an old save has it (just an id, or an id and the wear points left), or null for gear the workshop no longer knows. */
function asGear(saved: string | { id: string; left?: number | null }): GearItem | null {
  const id = typeof saved === "string" ? saved : saved.id;
  const rule = gearRule(id);
  if (!rule) return null;
  const left = typeof saved === "string" ? rule.durability : (saved.left ?? rule.durability);
  return { id, left: Math.min(rule.durability, Math.max(1, left)) };
}

/** The princess's children live longer than their race's plain residents (the Mac's manifests). */
export const HALF_BREED_LIFESPAN: Record<string, Record<string, number>> = {
  goblin: { half_gob: 1.4, half_mix: 1.5, half_hum: 1.6 },
  elf: { half_gob: 2.8, half_mix: 3, half_hum: 3 },
  undead: { half_gob: 1, half_mix: 1, half_hum: 1 },
};

function homePlace(camp: CampRow): Place {
  const rules = raceRules(camp.race);
  return { race: camp.race, key: "home", startedAt: camp.startedAt.getTime(), birthMinutes: rules.homeBirthMinutes, cap: rules.homeCap, sanctuary: !!camp.sanctuarySince };
}

export function toResident(row: ResidentRow): Resident {
  return { id: row.id, breed: row.breed, seed: row.seed, bornAt: row.bornAt.getTime(), diesAt: row.diesAt?.getTime() ?? null, diedAt: row.diedAt?.getTime() ?? null };
}

export async function addEvent(tx: Tx, userId: string, at: Date, kind: CampEvent["kind"], data: unknown) {
  await tx.execute(sql`insert into camp_events (seq, user_id, at, kind, data) values (nextval('camp_event_seq'), ${userId}, ${at.toISOString()}::timestamptz, ${kind}, ${JSON.stringify(data)}::jsonb)`);
}

/** The account's camp, locked for this transaction (so two devices' requests take turns), or null. */
export async function lockCamp(tx: Tx, userId: string): Promise<CampRow | null> {
  const [camp] = await tx.select().from(camps).where(eq(camps.userId, userId)).for("update");
  return camp ?? null;
}

/**
 * Works the home camp out up to `now` and writes it down: births and deaths of age (the rules in shared/src/camp), and the
 * monster raids that came meanwhile (fought by the server; who fell and what they dropped go into the books).
 * Returns whether anything changed.
 */
export async function advanceCamp(tx: Tx, camp: CampRow, now: Date): Promise<boolean> {
  if (now <= camp.advancedTo) return false;
  const rows = await tx
    .select()
    .from(campResidents)
    .where(and(eq(campResidents.userId, camp.userId), eq(campResidents.place, "home"), isNull(campResidents.diedAt)));
  const place = homePlace(camp);
  const population: Population = { residents: rows.map(toResident), nextId: camp.nextId, nextSlot: camp.nextSlot, peak: camp.peak };
  const born: Resident[] = [];
  const agedOut: Resident[] = [];
  const raids: RaidOutcome[] = [];
  const materials = { ...camp.materials };
  const kills = { ...camp.kills };
  const startedAt = camp.startedAt.getTime();
  let nextRaid = camp.nextRaid;

  // gear: who wears what; the store; newborns are handed gear, the dead give theirs back (as on the Mac)
  const store: GearItem[] = camp.armory.map((i) => ({ ...i }));
  const wearers = new Map<number, Wearer>(rows.map((r) => [r.id, { id: r.id, breed: r.breed, gear: structuredClone(r.gear ?? {}) as Wearer["gear"] }]));
  const gearBefore = new Map<number, string>(rows.map((r) => [r.id, JSON.stringify(r.gear ?? {})]));
  const settleGear = () => {
    for (const r of population.residents) {
      if (r.diedAt === null && !wearers.has(r.id)) wearers.set(r.id, { id: r.id, breed: r.breed, gear: {} });
      const w = wearers.get(r.id);
      if (r.diedAt !== null && w) {
        store.push(...(Object.values(w.gear) as GearItem[]));
        wearers.delete(r.id);
      }
    }
    redistribute(camp.race, [...wearers.values()], store);
  };

  const moveTo = (time: number) => {
    const step = advance(place, population, camp.seed, time);
    born.push(...step.born);
    agedOut.push(...step.died);
  };
  for (let t = raidTime(camp.race, camp.seed, startedAt, nextRaid); t <= now.getTime(); t = raidTime(camp.race, camp.seed, startedAt, nextRaid)) {
    moveTo(t);
    settleGear();
    const alive = aliveAt(population);
    // (聖光模式: no monster comes; the raid's time passes by)
    const plan = camp.sanctuarySince ? null : planRaid(camp.race, camp.seed, startedAt, nextRaid, alive.length);
    if (plan) {
      const outcome = resolveRaid(camp.race, camp.seed, plan, alive.map((r) => ({ ...r, gear: wearers.get(r.id)?.gear })), fightBoosts(camp.race, camp.boosts, t));
      // wear, and what broke (about a third of what it was made from can be picked out of the wreck)
      const broken: { resident: number; gear: string }[] = [];
      for (const [id, slots] of Object.entries(outcome.wear)) {
        const w = wearers.get(Number(id));
        for (const [slot, n] of Object.entries(slots) as [GearSlot, number][]) {
          const item = w?.gear[slot];
          if (!w || !item) continue;
          item.left -= n;
          if (item.left > 0) continue;
          delete w.gear[slot];
          broken.push({ resident: w.id, gear: item.id });
          const roll = randomFrom(hashString(`${camp.seed}|broken|${nextRaid}|${w.id}|${slot}`));
          for (const [mat, count] of Object.entries(gearRule(item.id)?.cost ?? {})) {
            for (let k = 0; k < count; k++) if (roll() < 0.3) materials[mat] = (materials[mat] ?? 0) + 1;
          }
        }
      }
      fall(population, outcome.fallen, t);
      for (const [id, n] of Object.entries(outcome.loot)) materials[id] = (materials[id] ?? 0) + n;
      for (const [id, n] of Object.entries(outcome.killed)) kills[id] = (kills[id] ?? 0) + n;
      raids.push({ ...outcome, broken } as RaidOutcome);
      settleGear();
    }
    nextRaid++;
  }
  moveTo(now.getTime());
  settleGear();

  if (born.length > 0) {
    await tx.insert(campResidents).values(
      born.map((r) => ({ userId: camp.userId, id: r.id, breed: r.breed, seed: r.seed, bornAt: new Date(r.bornAt), diesAt: r.diesAt === null ? null : new Date(r.diesAt) })),
    );
  }
  // everyone who died in this stretch, of age or in a raid (a resident born and dead within it is inserted above first)
  const byTime = new Map<number, number[]>();
  for (const r of population.residents) if (r.diedAt !== null) byTime.set(r.diedAt, [...(byTime.get(r.diedAt) ?? []), r.id]);
  for (const [at, ids] of byTime) {
    await tx.update(campResidents).set({ diedAt: new Date(at), gear: null }).where(and(eq(campResidents.userId, camp.userId), inArray(campResidents.id, ids)));
  }
  // what the living wear now, where it changed
  for (const w of wearers.values()) {
    const now = JSON.stringify(w.gear);
    if (now === (gearBefore.get(w.id) ?? "{}")) continue;
    await tx.update(campResidents).set({ gear: Object.keys(w.gear).length ? (w.gear as Record<string, GearItem>) : null }).where(and(eq(campResidents.userId, camp.userId), eq(campResidents.id, w.id)));
  }
  const armoryChanged = JSON.stringify(store) !== JSON.stringify(camp.armory);

  const changed = born.length > 0 || agedOut.length > 0 || raids.length > 0 || armoryChanged;
  const version = changed ? camp.version + 1 : camp.version;
  const set = { advancedTo: now, nextSlot: population.nextSlot, nextId: population.nextId, peak: population.peak, nextRaid, materials, kills, armory: store, version };
  await tx.update(camps).set(set).where(eq(camps.userId, camp.userId));
  if (born.length > 0 || agedOut.length > 0) {
    await addEvent(tx, camp.userId, now, "population", {
      born: born.map((r) => ({ id: r.id, breed: r.breed, at: new Date(r.bornAt).toISOString() })),
      died: agedOut.map((r) => ({ id: r.id, at: new Date(r.diedAt!).toISOString() })),
    });
  }
  for (const raid of raids) await addEvent(tx, camp.userId, new Date(raid.at), "raid", raid);
  Object.assign(camp, set);
  return changed;
}

export async function campView(tx: Tx, camp: CampRow): Promise<CampView> {
  const rows = await tx.select().from(campResidents).where(and(eq(campResidents.userId, camp.userId), isNull(campResidents.diedAt))).orderBy(campResidents.id);
  return {
    race: camp.race,
    seed: camp.seed,
    startedAt: camp.startedAt.toISOString(),
    advancedTo: camp.advancedTo.toISOString(),
    nextSlot: camp.nextSlot,
    nextId: camp.nextId,
    peak: camp.peak,
    stage: campStage(camp.race, camp.peak),
    version: camp.version,
    materials: camp.materials,
    larder: camp.larder,
    armory: camp.armory,
    boosts: camp.boosts,
    foodCooldowns: camp.foodCooldowns,
    princessName: camp.princessName,
    romance: camp.romance ?? null,
    kills: camp.kills,
    delivered: camp.delivered,
    sanctuary: {
      since: camp.sanctuarySince?.toISOString() ?? null,
      canTurnOnAt: camp.sanctuaryOffAt ? new Date(camp.sanctuaryOffAt.getTime() + SANCTUARY_REST_HOURS * 3_600_000).toISOString() : null,
    },
    residents: rows.map((r) => ({
      id: r.id,
      breed: r.breed,
      seed: r.seed,
      legacySeed: r.legacySeed,
      name: r.name,
      parents: r.parents,
      bornAt: r.bornAt.toISOString(),
      diesAt: r.diesAt?.toISOString() ?? null,
      gear: r.gear ?? null,
      place: r.place,
    })),
  };
}

async function clearCamp(tx: Tx, userId: string) {
  // a new world starts outside the big world: its cells are given up and parties on the way are gone
  await tx.update(worldCells).set({ owner: null, heldSince: null, nestStartedAt: null, nextSlot: 0, advancedTo: null, town: false, yieldedTo: null, updatedAt: new Date() }).where(eq(worldCells.owner, userId));
  await tx.delete(expeditions).where(and(eq(expeditions.userId, userId), eq(expeditions.status, "walking")));
  await tx.delete(worldPlayers).where(eq(worldPlayers.userId, userId));
  await tx.delete(campEvents).where(eq(campEvents.userId, userId));
  await tx.delete(campResidents).where(eq(campResidents.userId, userId));
  await tx.delete(camps).where(eq(camps.userId, userId));
}

/** A new camp: a fresh seed, the two residents who carry the princess in. `replace` starts a new world over an old one. */
export async function startCamp(tx: Tx, userId: string, race: string, now: Date, replace = false): Promise<CampRow | "exists"> {
  if (await lockCamp(tx, userId)) {
    if (!replace) return "exists";
    await clearCamp(tx, userId);
  }
  const seed = randomInt(0, 2 ** 32);
  const { population } = startHome(race, seed, now.getTime());
  const [camp] = await tx
    .insert(camps)
    .values({ userId, race, seed, startedAt: now, advancedTo: now, nextSlot: population.nextSlot, nextId: population.nextId, peak: population.peak })
    .returning();
  await tx.insert(campResidents).values(
    population.residents.map((r) => ({ userId, id: r.id, breed: r.breed, seed: r.seed, bornAt: new Date(r.bornAt), diesAt: r.diesAt === null ? null : new Date(r.diesAt) })),
  );
  await addEvent(tx, userId, now, "started", { race, replaced: replace });
  return camp!;
}

/**
 * Moves an old save in as the account's camp (server/CAMP.md §6): residents up to the race's home cap (the oldest go
 * first), materials, larder and gear store capped, the most ever not above those that came, the story kept. A fresh
 * seed; births go on from now.
 */
export async function migrateCamp(tx: Tx, userId: string, input: MigrateInput, now: Date): Promise<CampRow | "exists"> {
  if (await lockCamp(tx, userId)) {
    if (!input.replace) return "exists";
    await clearCamp(tx, userId);
  }
  const { race, save } = input;
  const rules = raceRules(race);
  const known = new Set([...rules.breeds.map((b) => b.id), ...Object.keys(HALF_BREED_LIFESPAN[race] ?? {})]);
  const kept = [...save.goblins].sort((a, b) => a.age - b.age).slice(0, rules.homeCap); // (youngest first; the oldest go)

  const residents = kept.map((g) => {
    const legacySeed = String(g.seed);
    const random = randomFrom(hashString(`${legacySeed}|migrate`));
    const breed = known.has(g.breed) ? g.breed : "common";
    const lifespan = rules.breeds.find((b) => b.id === breed)?.lifespan ?? HALF_BREED_LIFESPAN[race]?.[breed] ?? 1;
    const bornAt = now.getTime() - Math.floor(g.age * 1000);
    let diesAt: number | null = null;
    if (rules.ages) {
      diesAt = bornAt + Math.floor(BASE_LIFESPAN_HOURS * HOUR * lifespan * (0.9 + 0.2 * random()));
      diesAt = Math.max(diesAt, now.getTime() + HOUR); // (the very old get an hour, instead of vanishing as they arrive)
    }
    const gear: Record<string, { id: string; left: number }> = {};
    for (const [slot, item] of Object.entries(g.gear ?? {})) {
      const piece = asGear(item);
      if (piece && gearRule(piece.id)?.slot === slot) gear[slot] = piece;
    }
    return {
      userId,
      id: g.id,
      breed,
      seed: hashString(legacySeed),
      legacySeed,
      name: g.name ?? null,
      parents: g.parents ?? null,
      bornAt: new Date(bornAt),
      diesAt: diesAt === null ? null : new Date(diesAt),
      gear: Object.keys(gear).length ? gear : null,
    };
  });

  const capEach = (record: Record<string, number> | null | undefined, cap: number) =>
    Object.fromEntries(Object.entries(record ?? {}).filter(([, n]) => n > 0).map(([id, n]) => [id, Math.min(n, cap)]));
  const armoryCounts = new Map<string, number>();
  const armory: { id: string; left: number }[] = [];
  const items = (
    save.armoryItems?.length
      ? save.armoryItems.map(asGear)
      : Object.entries(save.armory ?? {}).flatMap(([id, n]) => Array.from({ length: Math.min(n, MIGRATE_CAPS.armoryPerGear) }, () => asGear(id)))
  ).filter((i): i is GearItem => i !== null);
  for (const item of items) {
    const n = armoryCounts.get(item.id) ?? 0;
    if (n >= MIGRATE_CAPS.armoryPerGear) continue;
    armoryCounts.set(item.id, n + 1);
    armory.push(item);
  }
  const romance = save.romance !== undefined && JSON.stringify(save.romance).length <= MIGRATE_CAPS.romanceChars ? save.romance : null;

  const [camp] = await tx
    .insert(camps)
    .values({
      userId,
      race,
      seed: randomInt(0, 2 ** 32),
      startedAt: now,
      advancedTo: now,
      nextSlot: 1,
      nextId: Math.max(0, ...residents.map((r) => r.id)) + 1,
      peak: Math.min(save.peak ?? residents.length, residents.length),
      materials: capEach(save.materials, MIGRATE_CAPS.material),
      larder: capEach(save.larder, MIGRATE_CAPS.larder),
      armory,
      princessName: (save.princessName ?? "").slice(0, 20),
      romance,
      kills: capEach(save.kills, 100_000),
      delivered: save.delivered ?? 0,
      migratedFrom: { goblins: save.goblins.length, peak: save.peak ?? null, materials: save.materials ?? {}, armoryItems: items.length },
    })
    .returning();
  if (residents.length) await tx.insert(campResidents).values(residents);
  await addEvent(tx, userId, now, "migrated", { residents: residents.length, came: save.goblins.length });
  return camp!;
}

export async function eventsSince(tx: Tx, userId: string, since: number, limit = 500): Promise<CampEvent[]> {
  const rows = await tx
    .select()
    .from(campEvents)
    .where(and(eq(campEvents.userId, userId), gt(campEvents.seq, since)))
    .orderBy(campEvents.seq)
    .limit(limit);
  return rows.map((e) => ({ seq: e.seq, at: e.at.toISOString(), kind: e.kind as CampEvent["kind"], data: e.data }));
}

/** The latest raids, newest first, without the replay and the wear (which the phone does not need and are most of the size). */
export async function recentRaids(tx: Tx, userId: string, limit: number): Promise<RaidReport[]> {
  const rows = await tx
    .select({ seq: campEvents.seq, at: campEvents.at, data: sql<Omit<RaidOutcome, "events" | "wear">>`${campEvents.data} - 'events' - 'wear'` })
    .from(campEvents)
    .where(and(eq(campEvents.userId, userId), eq(campEvents.kind, "raid")))
    .orderBy(desc(campEvents.seq))
    .limit(limit);
  const fallenIds = [...new Set(rows.flatMap((r) => r.data.fallen))];
  const fallen = fallenIds.length
    ? await tx
        .select({ id: campResidents.id, breed: campResidents.breed, name: campResidents.name })
        .from(campResidents)
        .where(and(eq(campResidents.userId, userId), inArray(campResidents.id, fallenIds)))
    : [];
  const who = new Map(fallen.map((f) => [f.id, f]));
  return rows.map(({ seq, at, data }) => ({
    seq,
    at: at.toISOString(),
    monsters: data.monsters,
    defenders: data.defenders.length,
    fallen: data.fallen.map((id) => who.get(id) ?? { id, breed: "common", name: null }),
    killed: data.killed,
    loot: data.loot,
    broken: data.broken ?? [],
    winner: data.winner,
  }));
}
