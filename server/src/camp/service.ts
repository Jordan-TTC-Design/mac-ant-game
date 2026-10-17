import { randomInt } from "node:crypto";
import { and, desc, eq, gt, inArray, isNull, sql } from "drizzle-orm";
import { focusView, decorEarned,
  advance,
  aliveAt,
  BASE_LIFESPAN_HOURS,
  fall,
  fightBoosts,
  gearRule,
  planRaid,
  specialEffects,
  visitorAt,
  levelOpens,
  raidTime,
  SANCTUARY_REST_HOURS,
  redistribute,
  type GearItem,
  type GearSlot,
  type Wearer,
  campStage,
  buildableKinds,
  campPerHour,
  farmParts,
  produce,
  siteMaxLevel,
  SITE_LEVEL_4_AT,
  SITE_LEVEL_5_AT,
  siteName,
  siteNext,
  sitePerHour,
  siteSpent,
  slotsFor,
  staffing,
  DEMOLISH_REFUND,
  type Site,
  raceRules,
  startHome,
  type CampEvent,
  type CampProduction,
  type CampView,
  type MigrateInput,
  type Place,
  type Population,
  type RaidReport,
  type Resident,
  decorKind,
} from "@goblincamp/shared/camp";
import { hashString, raceLevel, randomFrom, seeded } from "@goblincamp/shared/world";
import type { Tx } from "../auth/session.ts";
import { campEvents, campResidents, camps, expeditions, guildChat, guildMembers, users, worldCells, worldPlayers } from "../db/schema.ts";
import { resolveRaid, type RaidOutcome } from "./raids.ts";
import { talentBonusOf, talentEffect } from "../world/talents.ts";
import { merchantNow } from "./merchant.ts";

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
  // (the race level and talents shape the raids: their tiers, variants and bosses, and what the camp brings to them)
  const level = await campRaceLevel(tx, camp.userId);
  const bonus = await talentBonusOf(tx, camp.userId);
  const beaten = [...(camp.bossesBeaten ?? [])];

  // gear: who wears what; the store; newborns are handed gear, the dead give theirs back (as on the Mac)
  const store: GearItem[] = camp.armory.map((i) => ({ ...i }));
  const wearers = new Map<number, Wearer>(rows.map((r) => [r.id, { id: r.id, breed: r.breed, gear: structuredClone(r.gear ?? {}) as Wearer["gear"] }]));
  const gearBefore = new Map<number, string>(rows.map((r) => [r.id, JSON.stringify(r.gear ?? {})]));
  // those away the handing out reaches too (the towns, every held cell with the far switch): read once there is something to hand out
  let away: Wearer[] | null = null;
  const awayBefore = new Map<number, string>();
  const settleGear = async () => {
    for (const r of population.residents) {
      if (r.diedAt === null && !wearers.has(r.id)) wearers.set(r.id, { id: r.id, breed: r.breed, gear: {} });
      const w = wearers.get(r.id);
      if (r.diedAt !== null && w) {
        store.push(...(Object.values(w.gear) as GearItem[]).map((g) => ({ id: g.id, left: g.left }))); // (to be handed out again)
        wearers.delete(r.id);
      }
    }
    if (!away && camp.autoGear && store.some((i) => !i.held)) {
      const places = await gearPlaces(tx, camp.userId);
      const rows = Object.keys(places).some((p) => inGearPool(p, places, camp.autoGearFar))
        ? await tx.select().from(campResidents).where(and(eq(campResidents.userId, camp.userId), sql`${campResidents.place} like 'cell:%'`, isNull(campResidents.diedAt)))
        : [];
      away = rows.filter((r) => inGearPool(r.place, places, camp.autoGearFar)).map((r) => ({ id: r.id, breed: r.breed, gear: structuredClone(r.gear ?? {}) as Wearer["gear"] }));
      for (const r of rows) awayBefore.set(r.id, JSON.stringify(r.gear ?? {}));
    }
    redistribute(camp.race, [...wearers.values(), ...(away ?? [])], store, camp.autoGear);
  };

  // (the 長壽 talent: newborns live longer; 多產 and a 鼓手 at home: now and then twins — on top of the births' own times,
  // which stay as they are so a talent picked or reset never moves the camp's birth slots)
  const lifeMore = talentEffect(bonus, "campLife");
  const cap = raceRules(camp.race).homeCap;
  const moveTo = (time: number) => {
    const step = advance(place, population, camp.seed, time);
    const twins = talentEffect(bonus, "campBirths") + specialEffects(population.residents.filter((r) => r.diedAt === null).map((r) => r.breed)).births;
    for (const r of step.born) {
      if (lifeMore && r.diesAt !== null) r.diesAt = r.bornAt + Math.round((r.diesAt - r.bornAt) * (1 + lifeMore));
      if (!twins || seeded(camp.seed, "twin", r.id)() >= twins) continue;
      if (population.residents.filter((x) => x.diedAt === null).length >= cap) continue;
      const twin: Resident = { ...r, id: population.nextId++, seed: Math.floor(seeded(camp.seed, "twin-seed", r.id)() * 4294967296) };
      population.residents.push(twin);
      born.push(twin);
    }
    born.push(...step.born);
    agedOut.push(...step.died);
  };
  for (let t = raidTime(camp.race, camp.seed, startedAt, nextRaid); t <= now.getTime(); t = raidTime(camp.race, camp.seed, startedAt, nextRaid)) {
    moveTo(t);
    await settleGear();
    const alive = aliveAt(population);
    // (聖光模式: no monster comes; the raid's time passes by)
    const plan = camp.sanctuarySince ? null : planRaid(camp.race, camp.seed, startedAt, nextRaid, alive.length, level, beaten);
    if (plan) {
      const specials = specialEffects(alive.map((r) => r.breed));
      const help = { attack: talentEffect(bonus, "campGuard") + specials.raidAttack, weaken: specials.raidWeaken, loot: talentEffect(bonus, "campHeart") };
      const outcome = resolveRaid(camp.race, camp.seed, plan, alive.map((r) => ({ ...r, gear: wearers.get(r.id)?.gear })), fightBoosts(camp.race, camp.boosts, t), level, help);
      if (outcome.bossBeaten && plan.boss) beaten.push(plan.boss);
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
      await settleGear();
    }
    nextRaid++;
  }
  moveTo(now.getTime());
  await settleGear();

  // what the sites made meanwhile (by the hour, with those at home then); a site built or raised on the way splits it
  const workers = (at: number) => population.residents.filter((r) => r.bornAt <= at && (r.diedAt === null || r.diedAt > at)).length;
  let sites: Site[] = camp.sites.map((x) => ({ ...x }));
  let producedTo = camp.producedTo.getTime();
  let carry = { ...camp.productionCarry };
  const made: Record<string, number> = {};
  const produceTo = (to: number) => {
    const boost = talentEffect(bonus, "campYield") + specialEffects(population.residents.filter((r) => r.diedAt === null).map((r) => r.breed)).siteYield;
    const step = produce({ race: camp.race, seed: camp.seed, sites, workers, from: producedTo, to, carry, store: materials, boost });
    for (const [id, n] of Object.entries(step.got)) {
      materials[id] = (materials[id] ?? 0) + n;
      made[id] = (made[id] ?? 0) + n;
    }
    carry = step.carry;
    producedTo = step.to;
  };
  const finished: { site: Site; at: Date }[] = [];
  for (const site of [...sites].filter((x) => x.busyUntil && Date.parse(x.busyUntil) <= now.getTime()).sort((a, b) => Date.parse(a.busyUntil!) - Date.parse(b.busyUntil!))) {
    const at = Date.parse(site.busyUntil!);
    produceTo(at);
    sites = sites.map((x) => (x.id === site.id ? { id: x.id, kind: x.kind, level: x.level + 1 } : x));
    finished.push({ site: sites.find((x) => x.id === site.id)!, at: new Date(at) });
  }
  produceTo(now.getTime());

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
  // what the living wear now, where it changed (at home, and away)
  for (const w of [...wearers.values(), ...((away ?? []) as Wearer[])]) {
    const now = JSON.stringify(w.gear);
    if (now === (gearBefore.get(w.id) ?? awayBefore.get(w.id) ?? "{}")) continue;
    await tx.update(campResidents).set({ gear: Object.keys(w.gear).length ? (w.gear as Record<string, GearItem>) : null }).where(and(eq(campResidents.userId, camp.userId), eq(campResidents.id, w.id)));
  }
  const armoryChanged = JSON.stringify(store) !== JSON.stringify(camp.armory);

  const changed = born.length > 0 || agedOut.length > 0 || raids.length > 0 || armoryChanged || Object.keys(made).length > 0 || finished.length > 0;
  const version = changed ? camp.version + 1 : camp.version;
  const set = {
    advancedTo: now,
    nextSlot: population.nextSlot,
    nextId: population.nextId,
    peak: population.peak,
    nextRaid,
    materials,
    kills,
    armory: store,
    version,
    sites,
    producedTo: new Date(producedTo),
    productionCarry: carry,
    bossesBeaten: beaten,
    celebratedLevel: Math.max(camp.celebratedLevel, level),
  };
  await tx.update(camps).set(set).where(eq(camps.userId, camp.userId));
  // (the race level went up since: a 🎉 line in the camp's feed, and one in the guild's chat for the others to see)
  if (level > camp.celebratedLevel && camp.celebratedLevel >= 1) {
    const opens = Array.from({ length: level - camp.celebratedLevel }, (_, i) => levelOpens(camp.celebratedLevel + 1 + i)).flat();
    await addEvent(tx, camp.userId, now, "levelup", { level, from: camp.celebratedLevel, opens: opens.join("、") });
    const [member] = await tx.select({ guildId: guildMembers.guildId }).from(guildMembers).where(eq(guildMembers.userId, camp.userId));
    if (member) await tx.insert(guildChat).values({ guildId: member.guildId, userId: camp.userId, text: `🎉 種族等級升到 ${level} 級了！`, at: now });
  }
  if (born.length > 0 || agedOut.length > 0) {
    await addEvent(tx, camp.userId, now, "population", {
      born: born.map((r) => ({ id: r.id, breed: r.breed, at: new Date(r.bornAt).toISOString() })),
      died: agedOut.map((r) => ({ id: r.id, at: new Date(r.diedAt!).toISOString() })),
    });
  }
  for (const raid of raids) await addEvent(tx, camp.userId, new Date(raid.at), "raid", raid);
  for (const { site, at } of finished) {
    const part = site.kind === "farm" ? farmParts(camp.race, site.level).at(-1) : undefined;
    await addEvent(tx, camp.userId, at, "site", { site: site.id, kind: site.kind, level: site.level, name: siteName(camp.race, site.kind), part });
  }
  Object.assign(camp, set);
  return changed;
}

export async function campView(tx: Tx, camp: CampRow): Promise<CampView> {
  const rows = await tx.select().from(campResidents).where(and(eq(campResidents.userId, camp.userId), isNull(campResidents.diedAt))).orderBy(campResidents.id);
  const level = await campRaceLevel(tx, camp.userId);
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
    autoGear: camp.autoGear,
    autoGearFar: camp.autoGearFar,
    places: await gearPlaces(tx, camp.userId),
    questsDone: Object.keys(camp.quests ?? {}),
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
    production: productionView(camp, rows.filter((r) => r.place === "home").length, level),
    merchant: await merchantNow(tx, camp, camp.advancedTo), // (the camp was just advanced to now)
    decor: camp.decor.filter((d) => decorKind(d.kind)), // (kinds taken out of the catalogue since are gone)
    raceLevel: level,
    visitor: await (async () => {
      const home = rows.filter((r) => r.place === "home");
      const v = visitorAt(camp.seed, camp.advancedTo, level, new Set(home.map((r) => r.breed)), talentEffect(await talentBonusOf(tx, camp.userId), "campHost"));
      return v && !camp.visitors[v.id] ? v : null;
    })(),
    bossesBeaten: camp.bossesBeaten,
    campBonus: await (async () => {
      const b = await talentBonusOf(tx, camp.userId);
      return { yield: talentEffect(b, "campYield"), births: talentEffect(b, "campBirths"), guard: talentEffect(b, "campGuard"), ranch: talentEffect(b, "campRanch"), build: talentEffect(b, "campBuild"), life: talentEffect(b, "campLife"), host: talentEffect(b, "campHost"), trade: talentEffect(b, "campTrade"), heart: talentEffect(b, "campHeart") };
    })(),
    ranch: { animals: camp.ranch?.animals ?? [] },
    focus: focusView(camp.focus, camp.advancedTo),
    decorEarned: [...decorEarned(camp.quests ?? {}, camp.race)],
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

/**
 * The places away from home where residents can be handed gear, as the workshop names them: the camp's held cells (bar
 * the home cell, whose residents live at "home"), numbered in the order they were taken, and the cells it guards for
 * friends. On the road (`exp:`, `bivouac:`) nobody can.
 */
export async function gearPlaces(tx: Tx, userId: string): Promise<Record<string, { label: string; town: boolean }>> {
  const [player] = await tx.select({ homeCell: worldPlayers.homeCell }).from(worldPlayers).where(eq(worldPlayers.userId, userId));
  if (!player) return {};
  const held = await tx
    .select({ cell: worldCells.cell, town: worldCells.town })
    .from(worldCells)
    .where(eq(worldCells.owner, userId))
    .orderBy(worldCells.heldSince, worldCells.cell);
  const out: Record<string, { label: string; town: boolean }> = {};
  held
    .filter((c) => c.cell !== player.homeCell)
    .forEach((c, i) => (out[`cell:${c.cell}`] = { label: `${c.town ? "城鎮" : "領地"} ${i + 1}`, town: c.town }));
  const guarding = await tx
    .selectDistinct({ place: campResidents.place, holder: users.displayName })
    .from(campResidents)
    .leftJoin(worldCells, sql`${worldCells.cell} = substring(${campResidents.place} from 7)`)
    .leftJoin(users, eq(users.id, worldCells.owner))
    .where(and(eq(campResidents.userId, userId), sql`${campResidents.place} like 'guard:%'`, isNull(campResidents.diedAt)));
  for (const g of guarding) out[g.place] = { label: `幫${g.holder ?? "朋友"}守`, town: false };
  return out;
}

/** Whether the handing out reaches residents at `place`: home and the towns always, the other held cells with the far switch on. */
export function inGearPool(place: string, places: Record<string, { town: boolean }>, far: boolean): boolean {
  if (place === "home") return true;
  if (!place.startsWith("cell:") || !places[place]) return false;
  return far || places[place].town;
}

/** The camp's race level in the big world (1 for a camp that never opened it): it gives more plots for sites and more decoration room. */
export async function campRaceLevel(tx: Tx, userId: string): Promise<number> {
  const [player] = await tx.select({ xp: worldPlayers.xp }).from(worldPlayers).where(eq(worldPlayers.userId, userId));
  return raceLevel(player?.xp ?? 0);
}

/** The camp's sites, what they make and what could be built (for the devices to show; the server does the sums). */
export function productionView(camp: CampRow, workers: number, level: number): CampProduction {
  const { need, share } = staffing(camp.sites, workers);
  const busy = camp.sites.find((x) => x.busyUntil);
  return {
    slots: slotsFor(camp.race, camp.peak, level),
    used: camp.sites.length,
    workers,
    need,
    share,
    perHour: campPerHour(camp.race, camp.sites, share),
    busy: busy ? { site: busy.id, until: new Date(busy.busyUntil!).toISOString() } : null,
    sites: camp.sites.map((site) => {
      const next = siteNext(site.kind, site.level, level);
      const { makes, finds } = sitePerHour(camp.race, site);
      const after = next ? sitePerHour(camp.race, { kind: site.kind, level: site.level + 1 }) : null;
      return {
        id: site.id,
        kind: site.kind,
        name: siteName(camp.race, site.kind),
        level: site.level,
        maxLevel: siteMaxLevel(site.kind, level),
        // (the race level that lets it go one higher, while that is still ahead)
        opensAt: site.kind !== "farm" && site.level >= siteMaxLevel(site.kind, level) && site.level < 5 ? (site.level < 4 ? SITE_LEVEL_4_AT : SITE_LEVEL_5_AT) : undefined,
        parts: site.kind === "farm" ? farmParts(camp.race, site.level) : undefined,
        makes: { ...makes, ...finds },
        busyUntil: site.busyUntil ? new Date(site.busyUntil).toISOString() : null,
        next: next && after ? { level: site.level + 1, cost: next.cost, hours: next.hours, makes: { ...after.makes, ...after.finds } } : null,
        refund: site.kind === "farm" ? null : refundFor(site),
      };
    }),
    buildable: buildableKinds(camp.race).map((kind) => {
      const first = siteNext(kind, 0)!;
      const at1 = sitePerHour(camp.race, { kind, level: 1 });
      return { kind, name: siteName(camp.race, kind), cost: first.cost, hours: first.hours, makes: { ...at1.makes, ...at1.finds } };
    }),
  };
}

/** What taking a site down gives back: half of all it cost, the level under way included. */
export function refundFor(site: Site): Record<string, number> {
  const spent = siteSpent(site.kind, site.level + (site.busyUntil ? 1 : 0));
  return Object.fromEntries(Object.entries(spent).map(([id, n]) => [id, Math.floor(n * DEMOLISH_REFUND)]).filter(([, n]) => (n as number) > 0));
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
    .values({ userId, race, seed, startedAt: now, advancedTo: now, producedTo: now, nextSlot: population.nextSlot, nextId: population.nextId, peak: population.peak })
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
      producedTo: now,
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
    ...(data.boss ? { boss: data.boss, bossBeaten: !!data.bossBeaten } : {}),
    defenders: data.defenders.length,
    fallen: data.fallen.map((id) => who.get(id) ?? { id, breed: "common", name: null }),
    killed: data.killed,
    loot: data.loot,
    broken: data.broken ?? [],
    winner: data.winner,
  }));
}
