import { randomInt } from "node:crypto";
import { and, eq, gt, inArray, isNull, sql } from "drizzle-orm";
import {
  advance,
  aliveAt,
  BASE_LIFESPAN_HOURS,
  fall,
  planRaid,
  raidTime,
  campStage,
  raceRules,
  startHome,
  type CampEvent,
  type CampView,
  type MigrateInput,
  type Place,
  type Population,
  type Resident,
} from "@goblincamp/shared/camp";
import { hashString, randomFrom } from "@goblincamp/shared/world";
import type { Tx } from "../auth/session.ts";
import { campEvents, campResidents, camps } from "../db/schema.ts";
import { resolveRaid, type RaidOutcome } from "./raids.ts";

type CampRow = typeof camps.$inferSelect;
type ResidentRow = typeof campResidents.$inferSelect;

const HOUR = 3_600_000;

/** Caps for moving an old save in (server/CAMP.md §6). Residents: the race's home cap. */
export const MIGRATE_CAPS = { material: 200, larder: 16, armoryPerGear: 10, romanceChars: 20_000 };

/** The princess's children live longer than their race's plain residents (the Mac's manifests). */
const HALF_BREED_LIFESPAN: Record<string, Record<string, number>> = {
  goblin: { half_gob: 1.4, half_mix: 1.5, half_hum: 1.6 },
  elf: { half_gob: 2.8, half_mix: 3, half_hum: 3 },
  undead: { half_gob: 1, half_mix: 1, half_hum: 1 },
};

function homePlace(camp: CampRow): Place {
  const rules = raceRules(camp.race);
  return { race: camp.race, key: "home", startedAt: camp.startedAt.getTime(), birthMinutes: rules.homeBirthMinutes, cap: rules.homeCap };
}

function toResident(row: ResidentRow): Resident {
  return { id: row.id, breed: row.breed, seed: row.seed, bornAt: row.bornAt.getTime(), diesAt: row.diesAt?.getTime() ?? null, diedAt: row.diedAt?.getTime() ?? null };
}

async function addEvent(tx: Tx, userId: string, at: Date, kind: CampEvent["kind"], data: unknown) {
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

  const moveTo = (time: number) => {
    const step = advance(place, population, camp.seed, time);
    born.push(...step.born);
    agedOut.push(...step.died);
  };
  for (let t = raidTime(camp.race, camp.seed, startedAt, nextRaid); t <= now.getTime(); t = raidTime(camp.race, camp.seed, startedAt, nextRaid)) {
    moveTo(t);
    const alive = aliveAt(population);
    const plan = planRaid(camp.race, camp.seed, startedAt, nextRaid, alive.length);
    if (plan) {
      const outcome = resolveRaid(camp.race, camp.seed, plan, alive);
      fall(population, outcome.fallen, t);
      for (const [id, n] of Object.entries(outcome.loot)) materials[id] = (materials[id] ?? 0) + n;
      for (const [id, n] of Object.entries(outcome.killed)) kills[id] = (kills[id] ?? 0) + n;
      raids.push(outcome);
    }
    nextRaid++;
  }
  moveTo(now.getTime());

  if (born.length > 0) {
    await tx.insert(campResidents).values(
      born.map((r) => ({ userId: camp.userId, id: r.id, breed: r.breed, seed: r.seed, bornAt: new Date(r.bornAt), diesAt: r.diesAt === null ? null : new Date(r.diesAt) })),
    );
  }
  // everyone who died in this stretch, of age or in a raid (a resident born and dead within it is inserted above first)
  const byTime = new Map<number, number[]>();
  for (const r of population.residents) if (r.diedAt !== null) byTime.set(r.diedAt, [...(byTime.get(r.diedAt) ?? []), r.id]);
  for (const [at, ids] of byTime) {
    await tx.update(campResidents).set({ diedAt: new Date(at) }).where(and(eq(campResidents.userId, camp.userId), inArray(campResidents.id, ids)));
  }

  const changed = born.length > 0 || agedOut.length > 0 || raids.length > 0;
  const version = changed ? camp.version + 1 : camp.version;
  const set = { advancedTo: now, nextSlot: population.nextSlot, nextId: population.nextId, peak: population.peak, nextRaid, materials, kills, version };
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
    for (const [slot, item] of Object.entries(g.gear ?? {})) gear[slot] = typeof item === "string" ? { id: item, left: 1 } : { id: item.id, left: item.left ?? 1 };
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
  const items = save.armoryItems?.length
    ? save.armoryItems.map((i) => (typeof i === "string" ? { id: i, left: 1 } : { id: i.id, left: i.left ?? 1 }))
    : Object.entries(save.armory ?? {}).flatMap(([id, n]) => Array.from({ length: Math.min(n, MIGRATE_CAPS.armoryPerGear) }, () => ({ id, left: 1 })));
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
