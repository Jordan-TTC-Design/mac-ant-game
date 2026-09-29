/**
 * The big world on the server (server/WORLD.md §15): opening it, holding cells, nests raising residents on them, parties
 * walking out and what happens when they get there. Residents are the camp's own (camp_residents): where they are is their
 * `place` — "home", "cell:<id>" on a held cell, "exp:<id>" while walking.
 */
import { and, desc, eq, inArray, isNotNull, isNull, lte, ne, or, sql } from "drizzle-orm";
import type { PushSubscriptionJSON, WorldPush } from "@goblincamp/shared";
import { advance, fightBoosts, RACE_RANGE, residentAsFighter, type GearItem, type GearSlot, type Place, type Population } from "@goblincamp/shared/camp";
import {
  afterDefeat,
  bossAt,
  BOSSES_BY_DEFAULT,
  bossFighters,
  bossIn,
  bossWindow,
  cellDistance,
  regionOf,
  bossKind,
  bossMaxHp,
  BOSS_ROUNDS,
  bossShares,
  canAfford,
  canOpenWorld,
  cellCapacity,
  cellCenter,
  cellsWithin,
  metersBetween,
  checkAttack,
  combatPower,
  garrisonMin,
  lairAt,
  lairDrops,
  lootFor,
  lairFighters,
  materialName,
  HOME_MOVE_DAYS,
  isFood,
  lairWoundsView,
  OPENING_FOOD,
  partyCap,
  planSupplies,
  woundedLairFighters,
  slowed,
  pvpFront,
  lairEntry,
  estimateBattle,
  type FightBoosts,
  NEST_BUILD_HOURS,
  NEST_COST,
  nestBirthMinutes,
  openWorld,
  raceLevel,
  rank,
  rankByRace,
  residentFighter,
  resolveExpedition,
  respawnHours,
  simulateBattle,
  hashString,
  terrainAt,
  TOWN_COST,
  TOWN_MIN_CELLS,
  TERRAIN_YIELD,
  travelMinutes,
  cellYield,
  buildingYield,
  buildingsFor,
  cellBonus,
  cellBuildingBlurb,
  cellBuildingName,
  cellBuildingRule,
  CELL_BUILDING_COSTS,
  CELL_BUILDING_HOURS,
  CELL_BUILDING_MAX,
  workingLevel,
  landmarkRule,
  neighbors,
  connectedCells,
  heldNeighbours,
  REINFORCE_PER_CELL,
  eatRations,
  fedYield,
  RATIONS,
  UPKEEP_FREE_CELLS,
  UPKEEP_RATIONS,
  UPKEEP_EVERY,
  upkeepDue,
  GUESTS_MAX,
  type Fighter,
  type CellSurroundings,
  seeded,
  YIELD_HOURS,
  WORLD_SEED,
  worldUnlockPeak,
  XP,
  xpForLevel,
  type BossSighting,
  type BossView,
  type CellDetail,
  type CellHappening,
  type CellView,
  type NearbyLandmark,
  type TerritoryList,
  type ExpeditionReport,
  type ExpeditionSummary,
  type Lair,
  type LairView,
  type LatLng,
  type LeaderboardEntry,
  type PlayerWorldState,
  type Terrain,
  type WorldMe,
  type WorldOwner,
} from "@goblincamp/shared/world";
import type { AppDeps } from "../app.ts";
import { landmarksFor, terrainOf, terrainsFor } from "./osm.ts";
import type { Tx } from "../auth/session.ts";
import { addEvent, advanceCamp, lockCamp, toResident, type CampRow, type ResidentRow } from "../camp/service.ts";
import { campEvents, campResidents, camps, devices, expeditions, friendships, users, worldBosses, worldCells, worldPlayers, worldRewards } from "../db/schema.ts";

const MINUTE = 60_000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;
/** Residents who always stay home (they carried the princess in; the camp is never emptied). */
export const HOME_KEEP = 2;
/** Parties one camp may have on the road at once. */
export const MAX_WALKING = 5;
/** How far around a point the map may be asked for. */
export const MAX_MAP_RADIUS = 2500;

type PlayerRow = typeof worldPlayers.$inferSelect;
type CellRow = typeof worldCells.$inferSelect;
type ExpeditionRow = typeof expeditions.$inferSelect;
type BossRow = typeof worldBosses.$inferSelect;

export const cellPlace = (cell: string) => `cell:${cell}`;
export const walkingPlace = (id: string) => `exp:${id}`;
/** Guarding a friend's cell (holdings.ts GUESTS_MAX); fallen there, their gear still to come home (see advanceWorld). */
export const guardPlace = (cell: string) => `guard:${cell}`;
const fellPlace = (cell: string) => `fell:${cell}`;

export class WorldError extends Error {
  constructor(
    readonly status: 400 | 403 | 404 | 409,
    readonly code: string,
    message: string,
  ) {
    super(message);
  }
}

function state(p: PlayerRow | undefined | null): PlayerWorldState {
  return { open: !!p?.open, shieldedSince: p?.shieldedSince?.toISOString() ?? null, lastShieldEnded: p?.lastShieldEnded?.toISOString() ?? null };
}

async function lockPlayer(tx: Tx, userId: string): Promise<PlayerRow | null> {
  const [row] = await tx.select().from(worldPlayers).where(eq(worldPlayers.userId, userId)).for("update");
  return row ?? null;
}

async function lockCell(tx: Tx, cell: string): Promise<CellRow | null> {
  const [row] = await tx.select().from(worldCells).where(eq(worldCells.cell, cell)).for("update");
  return row ?? null;
}

/** A cell row to write into (made if the cell was never touched). */
async function touchCell(tx: Tx, cell: string): Promise<CellRow> {
  await tx.insert(worldCells).values({ cell }).onConflictDoNothing();
  return (await lockCell(tx, cell))!;
}

const aliveAt = (tx: Tx, userId: string, place: string) =>
  tx.select().from(campResidents).where(and(eq(campResidents.userId, userId), eq(campResidents.place, place), isNull(campResidents.diedAt))).orderBy(campResidents.id);

/** Where a camp stands on the map (null: it never opened the big world). */
async function homeCellOf(tx: Tx, userId: string): Promise<string | null> {
  const [row] = await tx.select({ cell: worldPlayers.homeCell }).from(worldPlayers).where(eq(worldPlayers.userId, userId));
  return row?.cell ?? null;
}

/** Who lives on a cell: those settled there, and on the camp's own cell everybody at home as well (the camp stands there). */
async function dwellers(tx: Tx, userId: string, cell: string, homeCell: string | null): Promise<ResidentRow[]> {
  const there = await aliveAt(tx, userId, cellPlace(cell));
  return cell === homeCell ? [...(await aliveAt(tx, userId, "home")), ...there] : there;
}

const countAt = async (tx: Tx, userId: string, place: string) =>
  (
    (await tx
      .select({ n: sql<number>`count(*)::int` })
      .from(campResidents)
      .where(and(eq(campResidents.userId, userId), eq(campResidents.place, place), isNull(campResidents.diedAt)))) as [{ n: number }]
  )[0].n;

function nestState(cell: Pick<CellRow, "nestStartedAt">, now: Date): "none" | "building" | "ready" {
  if (!cell.nestStartedAt) return "none";
  return now.getTime() - cell.nestStartedAt.getTime() >= NEST_BUILD_HOURS * HOUR ? "ready" : "building";
}

/** The lair in a cell nobody holds, unless it was beaten and has not come back yet. */
export function lairHere(cell: string, row: Pick<CellRow, "clearedAt" | "owner"> | null | undefined, now: Date, terrain: Terrain): { lair: Lair | null; backAt: Date | null } {
  if (row?.owner) return { lair: null, backAt: null };
  const lair = lairAt(WORLD_SEED, cell, terrain);
  if (!lair) return { lair: null, backAt: null };
  if (row?.clearedAt) {
    const backAt = new Date(row.clearedAt.getTime() + respawnHours(lair) * HOUR);
    if (backAt > now) return { lair: null, backAt };
  }
  return { lair, backAt: null };
}

/** A lair as the map shows it: `standing` = its foes as they stand now (wounded), else fresh. */
export function lairView(lair: Lair, standing?: ReturnType<typeof lairFighters>): LairView {
  const foes: Record<string, number> = {};
  for (const f of lair.foes) foes[f] = (foes[f] ?? 0) + 1;
  return {
    kind: lair.kind,
    name: lair.name,
    faction: lair.faction,
    level: lair.level,
    count: lair.foes.length,
    foes,
    power: Math.round(combatPower(standing ?? lairFighters(lair))),
    ...(lair.boss ? { boss: true } : {}),
  };
}

const bossKey = (b: BossSighting) => `${b.region}@${b.window}`;
/** Great monsters are out only when the server says so (WORLD_BOSSES=on); off for a start (bosses.ts). */
const bossesOn = () => (process.env.WORLD_BOSSES ?? (BOSSES_BY_DEFAULT ? "on" : "off")) === "on";

/** The great monster standing in a cell at `at` (none on a held cell: it keeps away from camps), with its row (made the first time). */
async function bossHere(tx: Tx, cell: string, at: Date, lock: boolean): Promise<{ sighting: BossSighting; row: BossRow } | null> {
  const sighting = bossAt(WORLD_SEED, cell, at.getTime(), bossesOn());
  if (!sighting) return null;
  const key = bossKey(sighting);
  await tx
    .insert(worldBosses)
    .values({ key, kind: sighting.kind, cell, hp: bossMaxHp(sighting.kind), maxHp: bossMaxHp(sighting.kind), endsAt: new Date(sighting.endsAt) })
    .onConflictDoNothing();
  const q = tx.select().from(worldBosses).where(eq(worldBosses.key, key));
  const [row] = lock ? await q.for("update") : await q;
  return row ? { sighting, row } : null;
}

async function bossView(tx: Tx, sighting: BossSighting, row: BossRow | undefined): Promise<BossView> {
  const kind = bossKind(sighting.kind)!;
  const foes: Record<string, number> = {};
  for (const m of kind.minions) foes[m.foe] = (foes[m.foe] ?? 0) + m.count;
  const top = Object.entries(row?.damage ?? {}).sort((a, b) => b[1] - a[1]).slice(0, 5);
  const fighters = [];
  for (const [id, damage] of top) fighters.push({ name: (await ownerOf(tx, id)).name, damage });
  return {
    kind: sighting.kind,
    name: sighting.name,
    hp: row?.hp ?? bossMaxHp(sighting.kind),
    maxHp: row?.maxHp ?? bossMaxHp(sighting.kind),
    endsAt: new Date(sighting.endsAt).toISOString(),
    foes,
    fighters,
  };
}

/** Night where the fight is (by the cell's longitude): the dark ones hit harder. */
function nightAt(cell: string, at: Date): boolean {
  const { lng } = cellCenter(cell);
  const hour = (at.getUTCHours() + at.getUTCMinutes() / 60 + lng / 15 + 48) % 24;
  return hour >= 18 || hour < 6;
}

type Gear = Partial<Record<GearSlot, GearItem>> | null;

/** The camp's own food boosts (put down on the Mac) with what the party carries: the stronger of each. */
function withCarried(camp: FightBoosts, carried: FightBoosts | null | undefined): FightBoosts {
  const out: FightBoosts = { ...camp };
  for (const [k, v] of Object.entries(carried ?? {}) as [keyof FightBoosts, number][]) out[k] = Math.max(out[k] ?? 0, v);
  return out;
}
const fighterOf = (race: string, r: ResidentRow, prefix = "") => {
  const f = residentAsFighter(race, { id: r.id, breed: r.breed, gear: r.gear as Gear }, r.name ?? "");
  return { ...f, id: `${prefix}${r.id}` };
};
const traitsOf = (race: string) => ({ id: race, ranged: RACE_RANGE[race] ?? 0 });
const hpOf = (race: string, r: ResidentRow) => residentFighter(fighterOf(race, r), "attack", traitsOf(race)).maxHp;

/** Residents who died away from home: their gear goes back to the camp's store. */
async function bury(tx: Tx, camp: CampRow, rows: ResidentRow[], at: Date) {
  if (rows.length === 0) return;
  const store = [...camp.armory];
  for (const r of rows) for (const item of Object.values(r.gear ?? {})) if (item) store.push(item);
  await tx.update(campResidents).set({ diedAt: at, gear: null }).where(and(eq(campResidents.userId, camp.userId), inArray(campResidents.id, rows.map((r) => r.id))));
  if (store.length !== camp.armory.length) {
    await tx.update(camps).set({ armory: store }).where(eq(camps.userId, camp.userId));
    camp.armory = store;
  }
}

async function bumpVersion(tx: Tx, camp: CampRow) {
  camp.version += 1;
  await tx.update(camps).set({ version: camp.version, nextId: camp.nextId, materials: camp.materials, kills: camp.kills }).where(eq(camps.userId, camp.userId));
}

/** What stands on and around a camp's held cells: each one's landmark, and whether one of its own temples is next to it. */
async function surroundings(tx: Tx, held: string[]): Promise<(cell: string) => CellSurroundings> {
  const landmarks = await landmarksFor(tx, held);
  const mine = new Set(held);
  return (cell) => ({
    landmark: landmarks.get(cell) ?? null,
    templeNear: neighbors(cell).some((n) => mine.has(n) && landmarks.get(n)?.kind === "temple"),
    neighbours: heldNeighbours(cell, mine),
  });
}

/** Whether two accounts are friends (an ask answered yes). */
async function areFriends(tx: Tx, a: string, b: string): Promise<boolean> {
  const [userA, userB] = a < b ? [a, b] : [b, a];
  const [row] = await tx.select({ at: friendships.acceptedAt }).from(friendships).where(and(eq(friendships.userA, userA), eq(friendships.userB, userB)));
  return !!row?.at;
}

/** Friends' residents guarding a cell, as fighters beside its holder's (each with its own camp's race and food boosts). */
async function guestsAt(tx: Tx, cell: string, at: Date, fort = 0): Promise<{ rows: ResidentRow[]; fighters: Fighter[]; races: Map<string, string> }> {
  const rows = await tx.select().from(campResidents).where(and(eq(campResidents.place, guardPlace(cell)), isNull(campResidents.diedAt))).orderBy(campResidents.userId, campResidents.id);
  const races = new Map<string, string>();
  if (rows.length === 0) return { rows, fighters: [], races };
  const owners = [...new Set(rows.map((r) => r.userId))];
  const campsOf = new Map((await tx.select({ userId: camps.userId, race: camps.race, boosts: camps.boosts }).from(camps).where(inArray(camps.userId, owners))).map((c) => [c.userId, c]));
  for (const u of owners) races.set(u, campsOf.get(u)?.race ?? "goblin");
  const fighters = rows.map((r) => {
    const c = campsOf.get(r.userId);
    const race = c?.race ?? "goblin";
    return residentFighter(fighterOf(race, r, guestPrefix(owners, r)), "defend", traitsOf(race), { ...fightBoosts(race, c?.boosts ?? {}, at.getTime()), fort });
  });
  return { rows, fighters, races };
}
const guestPrefix = (owners: string[], r: ResidentRow) => `g${owners.indexOf(r.userId)}-`;
const guestId = (rows: ResidentRow[], r: ResidentRow) => `${guestPrefix([...new Set(rows.map((x) => x.userId))], r)}${r.id}`;

/**
 * Guests who fell guarding a cell: dead in their own camp's books (their camp is not locked here: their gear goes back to
 * its store the next time it is worked out), and their camp is told.
 */
async function guestsFell(tx: Tx, rows: ResidentRow[], cell: string, holder: string, at: Date) {
  const byOwner = new Map<string, number[]>();
  for (const r of rows) byOwner.set(r.userId, [...(byOwner.get(r.userId) ?? []), r.id]);
  for (const [owner, ids] of byOwner) {
    await tx.update(campResidents).set({ diedAt: at, place: fellPlace(cell) }).where(and(eq(campResidents.userId, owner), inArray(campResidents.id, ids)));
    await addEvent(tx, owner, at, "world", { guardFell: { cell, holder, fallen: ids.length } });
  }
}

/**
 * Who stands up to a party of `attackers` on another camp's cell: of everybody who would defend it (those living there —
 * on the camp's own cell everybody at home —, help from its held cells next door, friends guarding it) the strongest,
 * at most pvpFront(attackers) (world/expedition.ts). Read only: the fight itself buries whoever falls.
 */
async function playerDefense(tx: Tx, defender: CampRow, homeCell: string | null, row: CellRow, at: Date, attackers: number) {
  const campCell = homeCell === row.cell;
  const pool = [...(await dwellers(tx, defender.userId, row.cell, homeCell)), ...(campCell ? [] : await reinforcements(tx, defender, row.cell, homeCell))];
  const around = (await surroundings(tx, await heldCells(tx, defender.userId)))(row.cell);
  const fort = cellBonus(defender.race, campCell ? null : row.building, at.getTime(), around).fort;
  const boosts: FightBoosts = { ...fightBoosts(defender.race, defender.boosts, at.getTime()), fort };
  const guests = await guestsAt(tx, row.cell, at, fort);
  const worth = (f: Fighter) => f.attack * f.maxHp;
  const chosen = [
    ...pool.map((r) => ({ own: r, guest: null, f: residentFighter(fighterOf(defender.race, r, "d"), "defend", traitsOf(defender.race), boosts) })),
    ...guests.rows.map((r, i) => ({ own: null, guest: r, f: guests.fighters[i]! })),
  ]
    .sort((a, b) => worth(b.f) - worth(a.f))
    .slice(0, pvpFront(attackers));
  const guestRows = chosen.flatMap((c) => (c.guest ? [c.guest] : []));
  return {
    campCell,
    boosts,
    own: chosen.flatMap((c) => (c.own ? [c.own] : [])),
    guests: { rows: guestRows, fighters: chosen.flatMap((c) => (c.guest ? [c.f] : [])), races: guests.races, all: guests.rows },
    fighters: chosen.map((c) => c.f),
    total: pool.length + guests.rows.length,
  };
}

/** The held cells that eat rations: all but the camp's own and the UPKEEP_FREE_CELLS longest held (`held` oldest first). */
function payingCells(held: Pick<CellRow, "cell">[], homeCell: string | null): Set<string> {
  return new Set(held.filter((c) => c.cell !== homeCell).slice(UPKEEP_FREE_CELLS).map((c) => c.cell));
}
const rationsIn = (store: Record<string, number>) => Object.keys(RATIONS).reduce((n, id) => n + Math.max(0, store[id] ?? 0), 0);

/**
 * Those the camp's held cells next to `cell` can spare to help defend it: up to REINFORCE_PER_CELL from each, the
 * strongest, keeping what each must keep (the camp's own cell: those at home).
 */
async function reinforcements(tx: Tx, camp: CampRow, cell: string, homeCell: string | null): Promise<ResidentRow[]> {
  const held = new Set(await heldCells(tx, camp.userId));
  const out: ResidentRow[] = [];
  for (const n of neighbors(cell)) {
    if (!held.has(n)) continue;
    const there = n === homeCell ? await aliveAt(tx, camp.userId, "home") : await aliveAt(tx, camp.userId, cellPlace(n));
    const spare = Math.min(REINFORCE_PER_CELL, there.length - (n === homeCell ? HOME_KEEP : garrisonMin(camp.race)));
    if (spare > 0) out.push(...pickParty(camp.race, there, undefined, spare, true));
  }
  return out;
}
const heldCells = async (tx: Tx, userId: string) => (await tx.select({ cell: worldCells.cell }).from(worldCells).where(eq(worldCells.owner, userId))).map((r) => r.cell);

/**
 * Works the camp's world side out to `now`: residents away from home dying of age, nests raising residents on held cells,
 * cells left empty given up, and the experience held cells earn by the day. The home camp is advanced first.
 */
export async function advanceWorld(tx: Tx, camp: CampRow, now: Date): Promise<boolean> {
  let changed = await advanceCamp(tx, camp, now);
  // residents who fell guarding a friend's cell: their gear comes home to the store
  const fellAway = await tx
    .select()
    .from(campResidents)
    .where(and(eq(campResidents.userId, camp.userId), sql`${campResidents.place} like 'fell:%'`, isNotNull(campResidents.gear)));
  if (fellAway.length) {
    const store = [...camp.armory];
    for (const r of fellAway) for (const item of Object.values(r.gear ?? {})) if (item) store.push(item);
    await tx.update(campResidents).set({ gear: null }).where(and(eq(campResidents.userId, camp.userId), inArray(campResidents.id, fellAway.map((r) => r.id))));
    await tx.update(camps).set({ armory: store }).where(eq(camps.userId, camp.userId));
    camp.armory = store;
    changed = true;
  }
  // of age, away from home (the nests below work their own cells out with the birth rules)
  const old = await tx
    .select()
    .from(campResidents)
    .where(and(eq(campResidents.userId, camp.userId), ne(campResidents.place, "home"), isNull(campResidents.diedAt), lte(campResidents.diesAt, now)));
  for (const r of old) await bury(tx, camp, [r], r.diesAt!);
  if (old.length) changed = true;

  const held = await tx.select().from(worldCells).where(eq(worldCells.owner, camp.userId)).orderBy(worldCells.heldSince, worldCells.cell).for("update");
  const yields: Record<string, number> = {};
  const yieldsByCell: Record<string, Record<string, number>> = {};
  const upkeep: Record<string, number> = {};
  const hungry: string[] = [];
  const [home] = await tx.select({ cell: worldPlayers.homeCell }).from(worldPlayers).where(eq(worldPlayers.userId, camp.userId));
  const paying = payingCells(held, home?.cell ?? null);
  const ground = await terrainsFor(tx, held.map((c) => c.cell));
  const around = await surroundings(tx, held.map((c) => c.cell));
  let landmarkXp = 0;
  for (const cell of held) {
    const terrain = ground.get(cell.cell) ?? terrainAt(WORLD_SEED, cell.cell);
    // (a camp's cell opened before its nest came with it gets it now)
    if (cell.cell === home?.cell && !cell.nestStartedAt) {
      cell.nestStartedAt = new Date((cell.heldSince ?? now).getTime() - NEST_BUILD_HOURS * HOUR);
      await tx.update(worldCells).set({ nestStartedAt: cell.nestStartedAt }).where(eq(worldCells.cell, cell.cell));
    }
    const isHome = cell.cell === home?.cell;
    const bonus = cellBonus(camp.race, isHome ? null : cell.building, now.getTime(), around(cell.cell));
    // a lair beaten here comes back when its time is up and tries to take its ground back
    const back = await lairReturns(tx, camp, cell, now, home?.cell ?? null, terrain, around(cell.cell));
    if (back.fought) changed = true;
    if (back.lost) continue;
    landmarkXp += bonus.xp;
    const room = cellCapacity(camp.race, cell.town) + bonus.room;
    // (the camp's own cell raises no one of its own: the camp standing there does, at home)
    const readyAt = cell.nestStartedAt && !isHome ? new Date(cell.nestStartedAt.getTime() + NEST_BUILD_HOURS * HOUR) : null;
    if (readyAt && readyAt <= now) {
      const rows = await aliveAt(tx, camp.userId, cellPlace(cell.cell));
      const place: Place = {
        race: camp.race,
        key: cellPlace(cell.cell),
        startedAt: readyAt.getTime(),
        birthMinutes: nestBirthMinutes(camp.race, cell.town),
        cap: room,
      };
      const population: Population = { residents: rows.map(toResident), nextId: camp.nextId, nextSlot: cell.nextSlot, peak: rows.length };
      const step = advance(place, population, camp.seed, now.getTime());
      if (step.born.length) {
        await tx.insert(campResidents).values(
          step.born.map((b) => ({ userId: camp.userId, id: b.id, breed: b.breed, seed: b.seed, bornAt: new Date(b.bornAt), diesAt: b.diesAt === null ? null : new Date(b.diesAt), place: cellPlace(cell.cell) })),
        );
        camp.nextId = population.nextId;
        changed = true;
      }
      await tx.update(worldCells).set({ nextSlot: population.nextSlot, advancedTo: now }).where(eq(worldCells.cell, cell.cell));
    }
    const n = (await countAt(tx, camp.userId, cellPlace(cell.cell))) + (isHome ? await countAt(tx, camp.userId, "home") : 0);
    if (n === 0 && !isHome) {
      await releaseCell(tx, cell.cell);
      changed = true;
      continue;
    }
    // what the ground gave meanwhile (every YIELD_HOURS, by its terrain and how many work it, up to a cell's room)
    const since = cell.yieldedTo ?? cell.heldSince ?? now;
    const times = Math.floor((now.getTime() - since.getTime()) / (YIELD_HOURS * HOUR));
    if (times > 0) {
      const got = cellYield(camp.race, terrain, Math.min(n, room), times, seeded(WORLD_SEED, cell.cell, since.getTime(), "yield"), cell.town, bonus.yieldBoost);
      // and what its building adds (worked only by a garrison big enough to work the ground)
      if (n >= garrisonMin(camp.race)) {
        for (const [mat, k] of Object.entries(buildingYield(bonus, times, seeded(WORLD_SEED, cell.cell, since.getTime(), "building")))) got[mat] = (got[mat] ?? 0) + k;
      }
      // a cell beyond the free ones eats a ration every other yield; hungry, it yields less
      let fed = got;
      const need = paying.has(cell.cell) ? upkeepDue(Math.round((since.getTime() - (cell.heldSince ?? since).getTime()) / (YIELD_HOURS * HOUR)), times) : 0;
      if (need > 0) {
        const { eaten, paid } = eatRations(camp.materials, need);
        for (const [id, k] of Object.entries(eaten)) {
          camp.materials = { ...camp.materials, [id]: (camp.materials[id] ?? 0) - k };
          upkeep[id] = (upkeep[id] ?? 0) + k;
        }
        if (paid < need) hungry.push(cell.cell);
        fed = fedYield(got, paid / need);
        changed = true;
      }
      for (const [mat, k] of Object.entries(fed)) {
        camp.materials = { ...camp.materials, [mat]: (camp.materials[mat] ?? 0) + k };
        yields[mat] = (yields[mat] ?? 0) + k;
      }
      await tx.update(worldCells).set({ yieldedTo: new Date(since.getTime() + times * YIELD_HOURS * HOUR) }).where(eq(worldCells.cell, cell.cell));
      if (Object.keys(fed).length) {
        yieldsByCell[cell.cell] = fed;
        changed = true;
      }
    }
  }

  if (Object.keys(yields).length || Object.keys(upkeep).length || hungry.length) {
    await addEvent(tx, camp.userId, now, "world", { yields, cells: yieldsByCell, ...(Object.keys(upkeep).length ? { upkeep } : {}), ...(hungry.length ? { hungry } : {}) });
  }
  // spoils of great monsters this camp helped beat
  const rewards = await tx.select().from(worldRewards).where(and(eq(worldRewards.userId, camp.userId), isNull(worldRewards.claimedAt))).for("update");
  let rewardXp = 0;
  for (const r of rewards) {
    for (const [mat, n] of Object.entries(r.data.loot)) camp.materials = { ...camp.materials, [mat]: (camp.materials[mat] ?? 0) + n };
    rewardXp += r.data.xp;
    await tx.update(worldRewards).set({ claimedAt: now }).where(eq(worldRewards.id, r.id));
    await addEvent(tx, camp.userId, now, "world", { bossReward: r.data });
    changed = true;
  }
  const player = await lockPlayer(tx, camp.userId);
  if (player && rewardXp) {
    player.xp += rewardXp;
    await tx.update(worldPlayers).set({ xp: player.xp }).where(eq(worldPlayers.userId, camp.userId));
  }
  if (player) {
    const days = Math.floor((now.getTime() - player.xpCountedTo.getTime()) / DAY);
    if (days > 0) {
      const cells = held.length;
      await tx
        .update(worldPlayers)
        .set({ xp: player.xp + days * (cells * XP.cellDay + landmarkXp), xpCountedTo: new Date(player.xpCountedTo.getTime() + days * DAY) })
        .where(eq(worldPlayers.userId, camp.userId));
    }
  }
  if (changed) await bumpVersion(tx, camp);
  return changed;
}

/**
 * The lair that was on a held cell comes back every time its respawn hours pass and fights the garrison (server/WORLD.md
 * §15): held, it is beaten again (its drops go to the camp's store); not, the garrison is gone and the lair has its ground
 * back. The camp's own first cell is spared (the camp stands there).
 */
async function lairReturns(
  tx: Tx,
  camp: CampRow,
  cell: CellRow,
  now: Date,
  homeCell: string | null,
  terrain: Terrain,
  around: CellSurroundings,
): Promise<{ fought: boolean; lost: boolean }> {
  // (the camp's own cell, and every cell of a camp in 聖光模式, are left alone)
  if (cell.cell === homeCell || !cell.clearedAt || camp.sanctuarySince) return { fought: false, lost: false };
  const lair = lairAt(WORLD_SEED, cell.cell, terrain);
  if (!lair) return { fought: false, lost: false };
  const every = respawnHours(lair) * HOUR;
  let fought = false;
  // (counted from when it was beaten or from when this camp took the cell, whichever is later: a cell won from another camp
  // does not owe the fights of before)
  const from = Math.max(cell.clearedAt.getTime(), cell.heldSince?.getTime() ?? 0);
  for (let t = from + every, k = 0; t <= now.getTime() && k < 8; t += every, k++) {
    const guards = await aliveAt(tx, camp.userId, cellPlace(cell.cell));
    if (guards.length === 0) break;
    fought = true;
    const at = new Date(t);
    const foes = lairFighters(lair).map((f) => ({ ...f, side: "attack" as const }));
    const fort = cellBonus(camp.race, cell.building, t, around).fort;
    // (the held cells next to it send help)
    const helpers = await reinforcements(tx, camp, cell.cell, homeCell);
    // (and friends guarding it)
    const guests = await guestsAt(tx, cell.cell, at, fort);
    const defending = [
      ...[...guards, ...helpers].map((r) => residentFighter(fighterOf(camp.race, r), "defend", traitsOf(camp.race), { ...fightBoosts(camp.race, camp.boosts, t), fort })),
      ...guests.fighters,
    ];
    const battle = simulateBattle(foes, defending, { seed: hashString(`${cell.cell}|lair-back|${t}`), night: nightAt(cell.cell, at) });
    const fallen = new Set(battle.fallen.defend);
    await bury(tx, camp, [...guards, ...helpers].filter((r) => fallen.has(String(r.id))), at);
    const fellGuests = guests.rows.filter((r) => fallen.has(guestId(guests.rows, r)));
    if (fellGuests.length) await guestsFell(tx, fellGuests, cell.cell, (await ownerOf(tx, camp.userId)).name, at);
    const held = battle.winner === "defend";
    const loot: Record<string, number> = {};
    if (held) {
      const kept = lootFor(lair, seeded(WORLD_SEED, cell.cell, t, "lair-back-loot"));
      const dropped = lairDrops(lair, battle.fallen.attack, `${cell.cell}|${t}`);
      for (const [mat, n] of [...Object.entries(kept), ...Object.entries(dropped)]) loot[mat] = (loot[mat] ?? 0) + n;
      for (const [mat, n] of Object.entries(loot)) camp.materials = { ...camp.materials, [mat]: (camp.materials[mat] ?? 0) + n };
      for (const id of battle.fallen.attack) {
        const foe = lair.foes[Number(id.split("#")[1])];
        if (foe) camp.kills = { ...camp.kills, [foe]: (camp.kills[foe] ?? 0) + 1 };
      }
      await tx.update(worldCells).set({ clearedAt: at }).where(eq(worldCells.cell, cell.cell));
    }
    await addEvent(tx, camp.userId, at, "world", {
      lairBack: {
        cell: cell.cell,
        name: lair.name,
        level: lair.level,
        held,
        fallen: fallen.size - fellGuests.length,
        killed: battle.fallen.attack.length,
        loot,
        helped: helpers.length,
        ...(guests.rows.length ? { guests: guests.rows.length } : {}),
      },
    });
    if (!held) {
      await releaseCell(tx, cell.cell);
      await tx.update(worldCells).set({ clearedAt: null }).where(eq(worldCells.cell, cell.cell)); // (the lair is there again)
      return { fought, lost: true };
    }
  }
  return { fought, lost: false };
}

async function releaseCell(tx: Tx, cell: string) {
  // (friends guarding it walk home)
  await tx.update(campResidents).set({ place: "home" }).where(and(eq(campResidents.place, guardPlace(cell)), isNull(campResidents.diedAt)));
  await tx
    .update(worldCells)
    .set({ owner: null, heldSince: null, nestStartedAt: null, nextSlot: 0, advancedTo: null, town: false, yieldedTo: null, building: null, updatedAt: new Date() })
    .where(eq(worldCells.cell, cell));
}

async function takeCell(tx: Tx, cell: string, owner: string, now: Date) {
  await touchCell(tx, cell);
  await tx
    .update(worldCells)
    .set({ owner, heldSince: now, nestStartedAt: null, nextSlot: 0, advancedTo: null, town: false, yieldedTo: now, building: null, updatedAt: now })
    .where(eq(worldCells.cell, cell));
}

/** Who goes: the named residents (they must be at `place`), or the strongest `count` of those there. */
function pickParty(race: string, available: ResidentRow[], ids: number[] | undefined, count: number | undefined, strongest: boolean): ResidentRow[] {
  if (ids) {
    const byId = new Map(available.map((r) => [r.id, r]));
    const chosen = [...new Set(ids)].map((id) => byId.get(id));
    if (chosen.some((r) => !r)) throw new WorldError(409, "not_here", "有居民不在出發的地方（可能已經出門或不在了）。");
    return chosen as ResidentRow[];
  }
  const power = (r: ResidentRow) => {
    const f = residentFighter(fighterOf(race, r), "attack", traitsOf(race));
    return f.attack * 2 + f.maxHp + (f.heal ?? 0) * 3 + f.lead * 400;
  };
  // an attack takes the strongest; settlers moving in are the plain ones (the strong stay ready to fight)
  const sorted = [...available].sort((a, b) => (strongest ? power(b) - power(a) : power(a) - power(b)) || a.id - b.id);
  return sorted.slice(0, count);
}

// --- opening the big world ---------------------------------------------------------------------------------------

export async function openWorldFor(tx: Tx, userId: string, input: { cell?: string; settlers?: number }, now: Date): Promise<void> {
  const camp = await lockCamp(tx, userId);
  if (!camp) throw new WorldError(404, "no_camp", "這個帳號還沒有營地。");
  await advanceWorld(tx, camp, now);
  const player = await lockPlayer(tx, userId);
  if (player) {
    if (player.open) throw new WorldError(409, "already_open", "大世界已經開啟了。");
    const next = openWorld(state(player), now);
    await tx
      .update(worldPlayers)
      .set({ open: true, shieldedSince: null, lastShieldEnded: next.lastShieldEnded ? new Date(next.lastShieldEnded) : null })
      .where(eq(worldPlayers.userId, userId));
    await addEvent(tx, userId, now, "world", { opened: true, again: true });
    return;
  }
  if (!canOpenWorld(camp.race, camp.peak)) {
    throw new WorldError(403, "too_small", `營地要曾經有過 ${worldUnlockPeak(camp.race)} 隻（第三階段）才能開啟大世界。`);
  }
  if (!input.cell) throw new WorldError(400, "invalid_input", "第一次開啟要在地圖上選營地在哪一格。");
  await standCampOn(tx, userId, input.cell, now);
  await tx.insert(worldPlayers).values({ userId, open: true, homeCell: input.cell, openedAt: now, xpCountedTo: now });
  // something to take along on the first expeditions
  for (const [id, n] of Object.entries(OPENING_FOOD)) camp.materials = { ...camp.materials, [id]: (camp.materials[id] ?? 0) + n };
  await addEvent(tx, userId, now, "world", { opened: true, cell: input.cell });
  await bumpVersion(tx, camp);
}

/**
 * The camp stands on `cell` from now: nobody is sent, the whole camp is there (everybody at home lives on it and defends
 * it). A lair there is driven off, and the cell counts as having its nest (the camp raises residents; see advanceWorld).
 */
async function standCampOn(tx: Tx, userId: string, cell: string, now: Date) {
  const row = await lockCell(tx, cell);
  if (row?.owner && row.owner !== userId) throw new WorldError(409, "held", "這一格已經有主人了，選別格。");
  if (bossAt(WORLD_SEED, cell, now.getTime(), bossesOn())) throw new WorldError(409, "boss", "世界魔王正站在這一格，選別格。");
  if (row?.owner !== userId) await takeCell(tx, cell, userId, now);
  await tx
    .update(worldCells)
    .set({ clearedAt: now, nestStartedAt: row?.nestStartedAt ?? new Date(now.getTime() - NEST_BUILD_HOURS * HOUR) })
    .where(eq(worldCells.cell, cell));
}

/**
 * The camp moves to another cell (once every HOME_MOVE_DAYS): onto a free one, or one of its own. Those settled on the old
 * camp cell walk home with it and that cell is given up; parties on the road come home to the new one.
 */
export async function moveHome(tx: Tx, userId: string, cell: string, now: Date) {
  const camp = await lockCamp(tx, userId);
  if (!camp) throw new WorldError(404, "no_camp", "這個帳號還沒有營地。");
  await advanceWorld(tx, camp, now);
  const player = await lockPlayer(tx, userId);
  if (!player) throw new WorldError(403, "not_open", "還沒開啟大世界。");
  if (player.homeCell === cell) throw new WorldError(400, "invalid_input", "營地已經在這一格了。");
  const next = homeMoveAt(player);
  if (next && next > now) throw new WorldError(409, "too_soon", `營地 ${HOME_MOVE_DAYS} 天只能搬一次，${next.toISOString()} 之後才能再搬。`);
  const old = player.homeCell;
  await standCampOn(tx, userId, cell, now);
  // the old spot: its settlers come home with the camp, and it is nobody's any more
  const there = await aliveAt(tx, userId, cellPlace(old));
  if (there.length) await tx.update(campResidents).set({ place: "home" }).where(and(eq(campResidents.userId, userId), inArray(campResidents.id, there.map((r) => r.id))));
  const oldRow = await lockCell(tx, old);
  if (oldRow?.owner === userId) await releaseCell(tx, old);
  // the new spot's own settlers live at home now too (it is the camp)
  const settled = await aliveAt(tx, userId, cellPlace(cell));
  if (settled.length) await tx.update(campResidents).set({ place: "home" }).where(and(eq(campResidents.userId, userId), inArray(campResidents.id, settled.map((r) => r.id))));
  await tx.update(worldPlayers).set({ homeCell: cell, homeMovedAt: now }).where(eq(worldPlayers.userId, userId));
  await addEvent(tx, userId, now, "world", { movedHome: { from: old, to: cell } });
  await bumpVersion(tx, camp);
}

/** When the camp may move again (null: it may now). */
function homeMoveAt(player: Pick<PlayerRow, "homeMovedAt">): Date | null {
  return player.homeMovedAt ? new Date(player.homeMovedAt.getTime() + HOME_MOVE_DAYS * DAY) : null;
}

// --- sending a party ----------------------------------------------------------------------------------------------

export async function sendExpedition(
  tx: Tx,
  userId: string,
  input: { from: string; to: string; residents?: number[]; count?: number; settle: boolean; guard?: boolean; supplies?: Record<string, number> },
  now: Date,
): Promise<ExpeditionSummary> {
  const camp = await lockCamp(tx, userId);
  if (!camp) throw new WorldError(404, "no_camp", "這個帳號還沒有營地。");
  await advanceWorld(tx, camp, now);
  const player = await lockPlayer(tx, userId);
  if (!player) throw new WorldError(403, "not_open", "還沒開啟大世界。");
  if (!player.open || player.shieldedSince) throw new WorldError(403, "shielded", "龜縮中不能出征；先重新開啟大世界。");
  const [{ walking }] = (await tx
    .select({ walking: sql<number>`count(*)::int` })
    .from(expeditions)
    .where(and(eq(expeditions.userId, userId), eq(expeditions.status, "walking")))) as [{ walking: number }];
  if (walking >= MAX_WALKING) throw new WorldError(409, "too_many", `同時最多 ${MAX_WALKING} 支隊伍在路上。`);

  const fromCell = input.from === "home" ? player.homeCell : input.from;
  // (a building where it sets out: a dock or an inn shortens the walk, barracks let more go)
  const around = await surroundings(tx, await heldCells(tx, userId));
  let fromBonus = cellBonus(camp.race, null, now.getTime(), around(fromCell));
  if (input.from !== "home") {
    const from = await lockCell(tx, input.from);
    if (from?.owner !== userId) throw new WorldError(403, "not_yours", "只能從自己的格子出發。");
    fromBonus = cellBonus(camp.race, from.building, now.getTime(), around(fromCell));
  }
  if (input.to === input.from) throw new WorldError(400, "invalid_input", "出發和目的地是同一格。");
  const place = input.from === "home" ? "home" : cellPlace(input.from);
  const available = await aliveAt(tx, userId, place);
  const target = await lockCell(tx, input.to);
  // guarding a friend's cell: not a fight (no party cap), the strongest go
  const guarding = !!input.guard;
  if (guarding) {
    if (!target?.owner || target.owner === userId || !(await areFriends(tx, userId, target.owner))) throw new WorldError(409, "not_friend", "只能派去幫好友守他的格子。");
    const [{ there }] = (await tx
      .select({ there: sql<number>`count(*)::int` })
      .from(campResidents)
      .where(and(eq(campResidents.place, guardPlace(input.to)), isNull(campResidents.diedAt)))) as [{ there: number }];
    const n = input.residents?.length ?? input.count ?? 0;
    if (there + n > GUESTS_MAX) throw new WorldError(409, "too_many", `一格最多 ${GUESTS_MAX} 隻好友的居民幫守（現在有 ${there} 隻）。`);
  } else if (target?.owner && target.owner !== userId) {
    const [mine] = await tx.select({ id: campResidents.id }).from(campResidents).where(and(eq(campResidents.userId, userId), eq(campResidents.place, guardPlace(input.to)), isNull(campResidents.diedAt))).limit(1);
    if (mine) throw new WorldError(409, "guarding", "你有居民在那一格幫忙守，不能打它。");
  }
  const moving = target?.owner === userId || guarding;
  // a lair holds only so many (world/expedition.ts lairEntry): a count is cut to it, a list longer than it is refused
  let count = input.count;
  if (!moving && !target?.owner) {
    const entry = await entryOf(tx, input.to, target, now);
    if (entry !== null) {
      if (input.residents && input.residents.length > entry) throw new WorldError(409, "too_many", `這個巢穴很小，一次最多只能進去 ${entry} 隻。`);
      if (count !== undefined) count = Math.min(count, entry);
    }
  }
  const party = pickParty(camp.race, available, input.residents, count, !moving || guarding);
  if (party.length === 0) throw new WorldError(409, "too_few", "沒有人可以出發。");
  // a fighting party is small (by race and level); rations let more go, some foods make it stronger (moving in is not limited)
  let carried: FightBoosts | null = null;
  if (!moving) {
    const plan = planSupplies(camp.race, raceLevel(player.xp), party.length, input.supplies ?? {}, camp.materials, fromBonus.party);
    if (plan.problem) throw new WorldError(409, "too_many", plan.problem);
    for (const [id, n] of Object.entries(plan.spent)) camp.materials = { ...camp.materials, [id]: (camp.materials[id] ?? 0) - n };
    if (Object.keys(plan.boosts).length) carried = plan.boosts;
  }
  const keep = input.from === "home" ? HOME_KEEP : garrisonMin(camp.race);
  if (available.length - party.length < keep) {
    throw new WorldError(409, "too_few", input.from === "home" ? `營地至少要留 ${HOME_KEEP} 隻。` : `這一格至少要留 ${keep} 隻守著（要整格放棄請用「撤回」）。`);
  }
  if (!moving && target?.owner) {
    // 聖光模式 keeps a camp out of fights with other camps, both ways (server/CAMP.md §7)
    if (camp.sanctuarySince) throw new WorldError(409, "sanctuary", "聖光模式中不能攻打其他玩家（打怪可以）。");
    const [owner] = await tx.select({ since: camps.sanctuarySince }).from(camps).where(eq(camps.userId, target.owner));
    if (owner?.since) throw new WorldError(409, "target_sanctuary", "對方在聖光模式，打不了。");
    const [defender] = await tx.select().from(worldPlayers).where(eq(worldPlayers.userId, target.owner));
    const refusal = checkAttack(userId, state(player), target.owner, state(defender));
    if (refusal === "target_shielded" || refusal === "target_closed") throw new WorldError(409, refusal, "對方正在龜縮，現在打不了。");
  }

  const boosts = withCarried(fightBoosts(camp.race, camp.boosts, now.getTime()), carried);
  const slowest = Math.min(...party.map((r) => residentFighter(fighterOf(camp.race, r), "attack", traitsOf(camp.race), boosts).speed));
  const minutes = Math.max(1, Math.round(travelMinutes(fromCell, input.to, slowest) * fromBonus.travel));
  const [row] = await tx
    .insert(expeditions)
    .values({
      userId,
      kind: guarding ? "guard" : moving ? "move" : "attack",
      fromPlace: input.from,
      toCell: input.to,
      party: party.map((r) => r.id),
      boosts: carried,
      setOutAt: now,
      arriveAt: new Date(now.getTime() + minutes * MINUTE),
      defender: !moving && target?.owner ? target.owner : null,
      settle: guarding ? false : input.settle,
    })
    .returning();
  await tx.update(campResidents).set({ place: walkingPlace(row!.id) }).where(and(eq(campResidents.userId, userId), inArray(campResidents.id, party.map((r) => r.id))));
  // a cell left with nobody is given up (not the camp's own: the camp stands there)
  if (place !== "home" && input.from !== player.homeCell && available.length === party.length) await releaseCell(tx, input.from);
  await addEvent(tx, userId, now, "expedition", { id: row!.id, setOut: true, to: input.to, party: party.length, arriveAt: row!.arriveAt.toISOString() });
  await bumpVersion(tx, camp);
  return summary(row!);
}

/** How many may go into the lair on a free cell (null: no lair there, or a great monster: as many as can go). */
async function entryOf(tx: Tx, cell: string, row: CellRow | null, now: Date): Promise<number | null> {
  if (await bossHere(tx, cell, now, false).then((b) => b && !b.row.defeatedAt)) return null;
  const { lair } = lairHere(cell, row, now, await terrainOf(tx, cell));
  return lair ? lairEntry(lair.foes.length, lair.boss) : null;
}

/**
 * What a party would likely meet and how it would likely fare (the dispatch dialog asks before sending): who would stand
 * up to it on another camp's cell (frontage and all), or a lair or great monster as it stands now; fought out 40 times.
 * Nothing is changed.
 */
export async function estimateExpedition(
  tx: Tx,
  userId: string,
  input: { from: string; to: string; residents?: number[]; count?: number; supplies?: Record<string, number> },
  now: Date,
): Promise<{ win: number; fallen: number; killed: number; facing: number; total: number; entry: number | null }> {
  const [camp] = await tx.select().from(camps).where(eq(camps.userId, userId));
  const [player] = await tx.select().from(worldPlayers).where(eq(worldPlayers.userId, userId));
  if (!camp || !player) throw new WorldError(403, "not_open", "還沒開啟大世界。");
  const [target] = await tx.select().from(worldCells).where(eq(worldCells.cell, input.to));
  const entry = !target?.owner ? await entryOf(tx, input.to, target ?? null, now) : null;
  const available = await aliveAt(tx, userId, input.from === "home" ? "home" : cellPlace(input.from));
  const count = input.count !== undefined && entry !== null ? Math.min(input.count, entry) : input.count;
  const party = pickParty(camp.race, available, input.residents, count, true);
  if (party.length === 0) return { win: 0, fallen: 0, killed: 0, facing: 0, total: 0, entry };
  const plan = planSupplies(camp.race, raceLevel(player.xp), party.length, input.supplies ?? {}, { ...camp.materials, ...Object.fromEntries(Object.keys(input.supplies ?? {}).map((id) => [id, 999])) });
  const attackers = party.map((r) => residentFighter(fighterOf(camp.race, r), "attack", traitsOf(camp.race), withCarried(fightBoosts(camp.race, camp.boosts, now.getTime()), plan.boosts)));
  let defenders: Fighter[] = [];
  let total = 0;
  if (target?.owner && target.owner !== userId) {
    const [defender] = await tx.select().from(camps).where(eq(camps.userId, target.owner));
    const [dp] = await tx.select({ home: worldPlayers.homeCell }).from(worldPlayers).where(eq(worldPlayers.userId, target.owner));
    if (defender) {
      const defense = await playerDefense(tx, defender, dp?.home ?? null, target, now, party.length);
      defenders = defense.fighters;
      total = defense.total;
    }
  } else {
    const boss = await bossHere(tx, input.to, now, false);
    if (boss && !boss.row.defeatedAt) defenders = bossFighters(bossKind(boss.sighting.kind)!, boss.row.hp);
    else {
      const { lair } = lairHere(input.to, target ?? null, now, await terrainOf(tx, input.to));
      if (lair) defenders = woundedLairFighters(lair, target?.lairWounds, now.getTime());
    }
    total = defenders.length;
  }
  if (defenders.length === 0) return { win: 1, fallen: 0, killed: 0, facing: 0, total: 0, entry };
  const result = estimateBattle(attackers, slowed(defenders, plan.boosts), 40);
  return { win: result.win, fallen: result.fallen, killed: result.killed, facing: defenders.length, total, entry };
}

// --- arriving -----------------------------------------------------------------------------------------------------

function summary(row: ExpeditionRow, viewer?: string): ExpeditionSummary {
  const result = row.result as ExpeditionReport | null;
  return {
    id: row.id,
    kind: row.kind,
    from: row.fromPlace,
    to: row.toCell,
    party: row.party.length,
    setOutAt: row.setOutAt.toISOString(),
    arriveAt: row.arriveAt.toISOString(),
    status: row.status,
    outcome: result?.outcome ?? null,
    ...(viewer && row.defender === viewer && row.userId !== viewer ? { defending: true } : {}),
  };
}

async function ownerOf(tx: Tx, userId: string): Promise<WorldOwner> {
  const [row] = await tx.select({ name: users.displayName, race: camps.race }).from(users).leftJoin(camps, eq(camps.userId, users.id)).where(eq(users.id, userId));
  return { id: userId, name: row?.name ?? "？", race: row?.race ?? "goblin" };
}

/** What to tell whom on their phones when a party arrives. */
export interface WorldNews {
  user: string;
  title: string;
  body: string;
  url: string;
}

/**
 * Settles one party that has arrived (in its own transaction): moving in, a fight with a lair, a great monster or another
 * camp's garrison, the fallen buried, loot and experience, the cell cleared or taken, the survivors settling or walking home.
 */
export async function settleExpedition(tx: Tx, id: string, now: Date): Promise<{ users: string[]; news: WorldNews[] } | null> {
  const [peek] = await tx.select().from(expeditions).where(eq(expeditions.id, id));
  if (!peek || peek.status !== "walking" || peek.arriveAt > now) return null;
  const [peekCell] = await tx.select().from(worldCells).where(eq(worldCells.cell, peek.toCell));
  // lock both camps in one order (two parties meeting cannot wait on each other)
  const others = [peek.userId, ...(peekCell?.owner && peekCell.owner !== peek.userId ? [peekCell.owner] : [])].sort();
  const locked = new Map<string, CampRow>();
  for (const u of others) {
    const c = await lockCamp(tx, u);
    if (c) locked.set(u, c);
  }
  const [exp] = await tx.select().from(expeditions).where(eq(expeditions.id, id)).for("update");
  if (!exp || exp.status !== "walking") return null;
  const camp = locked.get(exp.userId);
  if (!camp) return null;
  const at = exp.arriveAt;
  await advanceWorld(tx, camp, now);

  const party = await aliveAt(tx, camp.userId, walkingPlace(exp.id));
  const cell = await lockCell(tx, exp.toCell);
  const attacker = await ownerOf(tx, camp.userId);
  const player = await lockPlayer(tx, camp.userId);
  const min = garrisonMin(camp.race);
  const cap = cellCapacity(camp.race, cell?.town ?? false) + (cell?.owner === camp.userId ? cellBonus(camp.race, cell.building, at.getTime()).room : 0);
  const report: ExpeditionReport = {
    ...summary(exp),
    status: "done",
    attacker,
    defender: null,
    lair: null,
    fighters: [],
    events: [],
    fallen: { attack: [], defend: [] },
    outcome: { won: false, cell: "back", against: "", loot: {}, xp: 0, fallen: 0, killed: 0 },
  };
  const outcome = report.outcome!;
  const involved = [camp.userId];

  /**
   * The survivors stay on the cell (up to its room) or walk back: to the held cell they set out from while it is still the
   * camp's and has room, else home (onto the camp's own cell: they are home).
   */
  const placeSurvivors = async (survivors: ResidentRow[], stay: boolean) => {
    let staying: ResidentRow[] = [];
    if (stay && exp.toCell !== player?.homeCell) {
      const there = cell?.owner === camp.userId ? (await aliveAt(tx, camp.userId, cellPlace(exp.toCell))).length : 0;
      staying = survivors.slice(0, Math.max(0, cap - there));
      if (staying.length) {
        if (cell?.owner !== camp.userId) await takeCell(tx, exp.toCell, camp.userId, at);
        await tx.update(campResidents).set({ place: cellPlace(exp.toCell) }).where(and(eq(campResidents.userId, camp.userId), inArray(campResidents.id, staying.map((r) => r.id))));
      }
    }
    let back = survivors.filter((r) => !staying.includes(r));
    if (back.length && exp.fromPlace !== "home" && exp.fromPlace !== exp.toCell && exp.fromPlace !== player?.homeCell) {
      const from = await lockCell(tx, exp.fromPlace);
      if (from?.owner === camp.userId) {
        const there = (await aliveAt(tx, camp.userId, cellPlace(exp.fromPlace))).length;
        const room = cellCapacity(camp.race, from.town) + cellBonus(camp.race, from.building, at.getTime()).room - there;
        const returning = back.slice(0, Math.max(0, room));
        if (returning.length) {
          await tx.update(campResidents).set({ place: cellPlace(exp.fromPlace) }).where(and(eq(campResidents.userId, camp.userId), inArray(campResidents.id, returning.map((r) => r.id))));
          back = back.filter((r) => !returning.includes(r));
        }
      }
    }
    if (back.length) await tx.update(campResidents).set({ place: "home" }).where(and(eq(campResidents.userId, camp.userId), inArray(campResidents.id, back.map((r) => r.id))));
    return staying.length;
  };

  if (party.length === 0) {
    outcome.cell = "back"; // (everyone died of age on the road)
  } else if (exp.kind === "guard") {
    // to a friend's cell: stay as guests while it is still theirs and they are still friends (up to GUESTS_MAX in all)
    const holder = cell?.owner && cell.owner !== camp.userId && (await areFriends(tx, camp.userId, cell.owner)) ? await ownerOf(tx, cell.owner) : null;
    const [{ there }] = (await tx
      .select({ there: sql<number>`count(*)::int` })
      .from(campResidents)
      .where(and(eq(campResidents.place, guardPlace(exp.toCell)), isNull(campResidents.diedAt)))) as [{ there: number }];
    const staying = holder ? party.slice(0, Math.max(0, GUESTS_MAX - there)) : [];
    if (staying.length) {
      await tx.update(campResidents).set({ place: guardPlace(exp.toCell) }).where(and(eq(campResidents.userId, camp.userId), inArray(campResidents.id, staying.map((r) => r.id))));
      await addEvent(tx, holder!.id, at, "world", { guests: { cell: exp.toCell, from: attacker.name, count: staying.length } });
      involved.push(holder!.id);
    }
    await placeSurvivors(party.filter((r) => !staying.includes(r)), false);
    outcome.won = staying.length > 0;
    outcome.cell = staying.length ? "guarding" : "back";
    outcome.against = holder ? `${holder.name}的領地` : "那一格已經不是好友的了";
  } else if (cell?.owner === camp.userId) {
    await placeSurvivors(party, true);
    outcome.won = true;
    outcome.cell = "settled";
    outcome.against = "自己的領地";
  } else if (cell?.owner) {
    // another camp's cell
    const defenderCamp = locked.get(cell.owner);
    const defenderPlayer = await lockPlayer(tx, cell.owner);
    const refusal = checkAttack(camp.userId, state(player), cell.owner, state(defenderPlayer));
    const sanctuary = !!defenderCamp?.sanctuarySince || !!camp.sanctuarySince;
    if (!defenderCamp || refusal || sanctuary) {
      await placeSurvivors(party, false);
      outcome.cell = "back";
      outcome.against = sanctuary ? "聖光模式，打不了" : refusal === "target_shielded" || refusal === "target_closed" ? "對方已經龜縮" : "去不了";
    } else {
      involved.push(defenderCamp.userId);
      await advanceWorld(tx, defenderCamp, now);
      // the strongest of those who would defend it stand up to the party, as many as the cell has room for
      const defense = await playerDefense(tx, defenderCamp, defenderPlayer?.homeCell ?? null, cell, at, party.length);
      const { campCell, guests } = defense;
      const defenders = defense.own;
      report.defender = await ownerOf(tx, defenderCamp.userId);
      outcome.against = `${report.defender.name}的${campCell ? "營地" : "領地"}`;
      const result = resolveExpedition({
        worldSeed: WORLD_SEED,
        expeditionId: exp.id,
        party: { player: camp.userId, residents: party.map((r) => fighterOf(camp.race, r)), race: traitsOf(camp.race), boosts: withCarried(fightBoosts(camp.race, camp.boosts, at.getTime()), exp.boosts) },
        target: {
          kind: "player",
          cell: exp.toCell,
          defender: {
            player: defenderCamp.userId,
            residents: defenders.map((r) => fighterOf(defenderCamp.race, r, "d")),
            race: traitsOf(defenderCamp.race),
            boosts: defense.boosts,
          },
          allies: guests.fighters,
        },
        night: nightAt(exp.toCell, at) && !exp.boosts?.lantern,
      });
      report.fighters = [
        ...party.map((r) => ({ id: String(r.id), name: r.name ?? "", side: "attack" as const, hp: hpOf(camp.race, r), race: camp.race, breed: r.breed })),
        ...defenders.map((r) => ({ id: `d${r.id}`, name: r.name ?? "", side: "defend" as const, hp: hpOf(defenderCamp.race, r), race: defenderCamp.race, breed: r.breed })),
        ...guests.rows.map((r) => {
          const race = guests.races.get(r.userId) ?? "goblin";
          return { id: guestId(guests.all, r), name: r.name ?? "", side: "defend" as const, hp: hpOf(race, r), race, breed: r.breed };
        }),
      ];
      report.events = result.battle.events.slice(0, 1500);
      report.fallen = result.battle.fallen;
      const fallenA = new Set(result.battle.fallen.attack);
      const fallenD = new Set(result.battle.fallen.defend);
      await bury(tx, camp, party.filter((r) => fallenA.has(String(r.id))), at);
      await bury(tx, defenderCamp, defenders.filter((r) => fallenD.has(`d${r.id}`)), at);
      const fellGuests = guests.rows.filter((r) => fallenD.has(guestId(guests.all, r)));
      if (fellGuests.length) {
        await guestsFell(tx, fellGuests, exp.toCell, report.defender.name, at);
        for (const u of new Set(fellGuests.map((r) => r.userId))) if (!involved.includes(u)) involved.push(u);
      }
      outcome.fallen = fallenA.size;
      outcome.killed = fallenD.size;
      outcome.won = result.won;
      outcome.xp = result.xp.attacker;
      const survivors = party.filter((r) => !fallenA.has(String(r.id)));
      if (result.won && campCell) {
        // a camp cannot be taken, only beaten: the attackers walk home and the beaten camp turtles
        await placeSurvivors(survivors, false);
        outcome.cell = "cleared";
        await shield(tx, defenderCamp.userId, now);
      } else if (result.won) {
        // (those of its garrison who did not stand up to the party flee home: the cell is overrun)
        await tx.update(campResidents).set({ place: "home" }).where(and(eq(campResidents.userId, defenderCamp.userId), eq(campResidents.place, cellPlace(exp.toCell)), isNull(campResidents.diedAt)));
        await releaseCell(tx, exp.toCell);
        const stayed = exp.settle && result.canSettle ? await placeSurvivors(survivors, true) : await placeSurvivors(survivors, false);
        outcome.cell = stayed ? "taken" : "cleared";
        await shield(tx, defenderCamp.userId, now);
      } else {
        await placeSurvivors(survivors, false);
        outcome.cell = "held";
        await shield(tx, camp.userId, now);
        if (defenderPlayer) await tx.update(worldPlayers).set({ xp: defenderPlayer.xp + result.xp.defender }).where(eq(worldPlayers.userId, defenderCamp.userId));
      }
      await addEvent(tx, defenderCamp.userId, at, "expedition", { id: exp.id, cell: exp.toCell, defended: true, by: attacker.name, won: !result.won, fallen: fallenD.size });
      await bumpVersion(tx, defenderCamp);
    }
  } else if (await bossHere(tx, exp.toCell, at, false).then((b) => b && !b.row.defeatedAt)) {
    // a great monster: one onslaught of BOSS_ROUNDS, its wounds stay; when it falls everybody who hurt it shares the spoils
    const { sighting, row } = (await bossHere(tx, exp.toCell, at, true))!;
    const kind = bossKind(sighting.kind)!;
    const defenders = bossFighters(kind, row.hp);
    const attackers = party.map((r) => residentFighter(fighterOf(camp.race, r), "attack", traitsOf(camp.race), withCarried(fightBoosts(camp.race, camp.boosts, at.getTime()), exp.boosts)));
    const battle = simulateBattle(attackers, slowed(defenders, exp.boosts), { seed: hashString(`${exp.id}|boss`), maxRounds: BOSS_ROUNDS, night: nightAt(exp.toCell, at) && !exp.boosts?.lantern });
    const hpAfter = Math.max(0, Math.round(battle.hpLeft.boss ?? row.hp));
    const dealt = row.hp - hpAfter;
    const damage = { ...row.damage, [camp.userId]: (row.damage[camp.userId] ?? 0) + dealt };
    const defeated = hpAfter <= 0;
    await tx.update(worldBosses).set({ hp: hpAfter, damage, ...(defeated ? { defeatedAt: at, defeatedBy: camp.userId } : {}) }).where(eq(worldBosses.key, row.key));
    if (defeated) {
      const shares = bossShares(kind, damage, row.key);
      for (const [who, share] of Object.entries(shares)) {
        await tx.insert(worldRewards).values({ userId: who, createdAt: at, data: { boss: kind.id, name: kind.name, ...share } });
        if (!involved.includes(who)) involved.push(who);
      }
    }
    report.boss = { kind: kind.id, name: kind.name, hpBefore: row.hp, hpAfter, maxHp: row.maxHp, defeated };
    report.fighters = [
      ...party.map((r) => ({ id: String(r.id), name: r.name ?? "", side: "attack" as const, hp: hpOf(camp.race, r), race: camp.race, breed: r.breed })),
      ...defenders.map((f) => ({ id: f.id, name: f.name, side: "defend" as const, hp: f.id === "boss" ? row.hp : f.maxHp, foe: f.id === "boss" ? kind.id : kind.minions.flatMap((m) => Array(m.count).fill(m.foe) as string[])[Number(f.id.split("#")[1]) - 1] })),
    ];
    report.events = battle.events.slice(0, 1500);
    report.fallen = battle.fallen;
    const fallenA = new Set(battle.fallen.attack);
    await bury(tx, camp, party.filter((r) => fallenA.has(String(r.id))), at);
    await placeSurvivors(party.filter((r) => !fallenA.has(String(r.id))), false);
    outcome.won = defeated;
    outcome.cell = defeated ? "cleared" : "held";
    outcome.against = `${kind.name}（世界魔王）`;
    outcome.fallen = fallenA.size;
    outcome.killed = battle.fallen.defend.length;
    outcome.damage = dealt;
  } else {
    const { lair } = lairHere(exp.toCell, cell, at, await terrainOf(tx, exp.toCell));
    if (!lair) {
      const stay = exp.settle && party.length >= min;
      const stayed = await placeSurvivors(party, stay);
      outcome.won = true;
      outcome.cell = stayed ? "settled" : "back";
      outcome.against = "空地";
    } else {
      // (still hurt from an earlier wave: what is left of it, WORLD.md §19)
      const foes = woundedLairFighters(lair, cell?.lairWounds, at.getTime());
      report.lair = lairView(lair, foes);
      outcome.against = `${lair.name}（${lair.level} 級）`;
      const result = resolveExpedition({
        worldSeed: WORLD_SEED,
        expeditionId: exp.id,
        party: { player: camp.userId, residents: party.map((r) => fighterOf(camp.race, r)), race: traitsOf(camp.race), boosts: withCarried(fightBoosts(camp.race, camp.boosts, at.getTime()), exp.boosts) },
        target: { kind: "lair", lair, fighters: foes },
        night: nightAt(exp.toCell, at) && !exp.boosts?.lantern,
      });
      report.fighters = [
        ...party.map((r) => ({ id: String(r.id), name: r.name ?? "", side: "attack" as const, hp: hpOf(camp.race, r), race: camp.race, breed: r.breed })),
        ...foes.map((f) => ({ id: f.id, name: f.name, side: "defend" as const, hp: f.hp, foe: lair.foes[Number(f.id.split("#")[1])] })),
      ];
      report.events = result.battle.events.slice(0, 1500);
      report.fallen = result.battle.fallen;
      const fallenA = new Set(result.battle.fallen.attack);
      await bury(tx, camp, party.filter((r) => fallenA.has(String(r.id))), at);
      outcome.fallen = fallenA.size;
      outcome.killed = result.battle.fallen.defend.length;
      outcome.won = result.won;
      outcome.xp = result.xp.attacker;
      const survivors = party.filter((r) => !fallenA.has(String(r.id)));
      if (result.won) {
        // what the lair kept, and what each beaten foe drops (drops.ts)
        let loot = { ...result.loot };
        for (const [mat, n] of Object.entries(lairDrops(lair, result.battle.fallen.defend, exp.id))) loot[mat] = (loot[mat] ?? 0) + n;
        // (幸運符: half as much again)
        if (exp.boosts?.luck) loot = Object.fromEntries(Object.entries(loot).map(([m, n]) => [m, Math.ceil(n * 1.5)]));
        outcome.loot = loot;
        for (const [mat, n] of Object.entries(loot)) camp.materials = { ...camp.materials, [mat]: (camp.materials[mat] ?? 0) + n };
        for (const i of result.battle.fallen.defend.map((f) => Number(f.split("#")[1]))) {
          const foe = lair.foes[i];
          if (foe) camp.kills = { ...camp.kills, [foe]: (camp.kills[foe] ?? 0) + 1 };
        }
        await touchCell(tx, exp.toCell);
        await tx.update(worldCells).set({ clearedAt: at, lairWounds: null, updatedAt: now }).where(eq(worldCells.cell, exp.toCell));
        const stayed = exp.settle && result.canSettle ? await placeSurvivors(survivors, true) : await placeSurvivors(survivors, false);
        outcome.cell = stayed ? "settled" : "cleared";
      } else {
        // beaten off: the foes that fell still drop their things, and the lair keeps its wounds for a second wave
        const loot = lairDrops(lair, result.battle.fallen.defend, exp.id);
        outcome.loot = loot;
        for (const [mat, n] of Object.entries(loot)) camp.materials = { ...camp.materials, [mat]: (camp.materials[mat] ?? 0) + n };
        for (const i of result.battle.fallen.defend.map((f) => Number(f.split("#")[1]))) {
          const foe = lair.foes[i];
          if (foe) camp.kills = { ...camp.kills, [foe]: (camp.kills[foe] ?? 0) + 1 };
        }
        const hp = lair.foes.map((_, i) => {
          const id = `${exp.toCell}#${i}`;
          return foes.some((f) => f.id === id) ? Math.max(0, Math.round(result.battle.hpLeft[id] ?? 0)) : 0;
        });
        await touchCell(tx, exp.toCell);
        await tx.update(worldCells).set({ lairWounds: { hp, at: at.getTime() }, updatedAt: now }).where(eq(worldCells.cell, exp.toCell));
        await placeSurvivors(survivors, false);
        outcome.cell = "held";
      }
    }
  }
  if (outcome.xp && player) await tx.update(worldPlayers).set({ xp: player.xp + outcome.xp }).where(eq(worldPlayers.userId, camp.userId));
  await tx.update(expeditions).set({ status: "done", result: report }).where(eq(expeditions.id, exp.id));
  await addEvent(tx, camp.userId, at, "expedition", { id: exp.id, to: exp.toCell, arrived: true, ...outcome });
  await bumpVersion(tx, camp);

  // the phones' news: the party's camp, the camp it attacked, and everybody who shared a great monster's spoils
  const url = `/expedition/${exp.id}`;
  const loot = Object.entries(outcome.loot).sort((a, b) => b[1] - a[1]).slice(0, 3).map(([m, n]) => `${materialName(m)} ${n}`).join("、");
  const headline: Record<string, string> = {
    cleared: "打贏了，清掉了",
    taken: "打贏了，搶下了",
    settled: outcome.killed > 0 || outcome.fallen > 0 ? "打贏了，佔領了" : "住進了",
    held: outcome.damage ? `造成 ${outcome.damage} 點傷害：` : "沒打下",
    back: "回來了：",
  };
  const news: WorldNews[] = [
    {
      user: camp.userId,
      title: "出征的隊伍到了",
      body: `${headline[outcome.cell]}${outcome.against}${outcome.fallen ? `，倒下 ${outcome.fallen} 隻` : ""}${loot ? `，撿到 ${loot}` : ""}`,
      url,
    },
  ];
  if (report.defender) {
    news.push({ user: report.defender.id, title: "領地被攻擊了", body: `${attacker.name}來打你的領地：${outcome.won ? "被搶走了，你正在龜縮" : "守住了！"}`, url });
  }
  if (report.boss?.defeated) {
    for (const who of involved) if (who !== camp.userId) news.push({ user: who, title: `世界魔王${report.boss.name}被打倒了`, body: "你出過力，戰利品會收進營地倉庫。", url: "/world" });
    news[0]!.body = `打倒了世界魔王${report.boss.name}！戰利品照傷害分給大家。`;
  }
  return { users: involved, news };
}

/** Losing a fight with another camp: it turtles (shared/src/world/territory.ts afterDefeat). */
async function shield(tx: Tx, userId: string, now: Date) {
  const player = await lockPlayer(tx, userId);
  if (!player) return;
  const next = afterDefeat(state(player), now);
  await tx
    .update(worldPlayers)
    .set({ open: next.open, shieldedSince: next.shieldedSince ? new Date(next.shieldedSince) : null })
    .where(eq(worldPlayers.userId, userId));
}

/** The parties that have arrived by `now` (one camp's, or everybody's). */
export async function dueExpeditions(tx: Tx, now: Date, userId?: string, limit = 50): Promise<string[]> {
  const rows = await tx
    .select({ id: expeditions.id })
    .from(expeditions)
    .where(and(eq(expeditions.status, "walking"), lte(expeditions.arriveAt, now), userId ? or(eq(expeditions.userId, userId), eq(expeditions.defender, userId)) : undefined))
    .orderBy(expeditions.arriveAt)
    .limit(limit);
  return rows.map((r) => r.id);
}

// --- building -----------------------------------------------------------------------------------------------------

async function ownCell(tx: Tx, userId: string, cell: string): Promise<{ camp: CampRow; row: CellRow }> {
  const camp = await lockCamp(tx, userId);
  if (!camp) throw new WorldError(404, "no_camp", "這個帳號還沒有營地。");
  return { camp, row: await ownedRow(tx, userId, cell) };
}
async function ownedRow(tx: Tx, userId: string, cell: string): Promise<CellRow> {
  const row = await lockCell(tx, cell);
  if (row?.owner !== userId) throw new WorldError(403, "not_yours", "這不是你的格子。");
  return row;
}

function spend(have: Record<string, number>, cost: Record<string, number>): Record<string, number> {
  const out = { ...have };
  for (const [id, n] of Object.entries(cost)) out[id] = (out[id] ?? 0) - n;
  return out;
}

const costText = (cost: Record<string, number>) => Object.entries(cost).map(([id, n]) => `${materialName(id)} ×${n}`).join("、");

export async function buildNest(tx: Tx, userId: string, cell: string, now: Date) {
  const { camp } = await ownCell(tx, userId, cell);
  await advanceWorld(tx, camp, now);
  const row = await ownedRow(tx, userId, cell);
  if (row.nestStartedAt) throw new WorldError(409, "exists", "這一格已經有巢穴了。");
  if (!canAfford(camp.materials, NEST_COST)) throw new WorldError(409, "cannot_afford", `素材不夠：巢穴要 ${costText(NEST_COST)}。`);
  camp.materials = spend(camp.materials, NEST_COST);
  await tx.update(worldCells).set({ nestStartedAt: now, nextSlot: 0, advancedTo: null, updatedAt: now }).where(eq(worldCells.cell, cell));
  await addEvent(tx, userId, now, "world", { nest: cell });
  await bumpVersion(tx, camp);
}

export async function buildTown(tx: Tx, userId: string, cell: string, now: Date) {
  const { camp } = await ownCell(tx, userId, cell);
  await advanceWorld(tx, camp, now);
  const row = await ownedRow(tx, userId, cell);
  if (row.town) throw new WorldError(409, "exists", "這一格已經是城鎮了。");
  // a town stands in a region of its holder's: TOWN_MIN_CELLS held cells joined side by side (this one among them)
  const region = connectedCells(cell, new Set(await heldCells(tx, userId))).length;
  if (region < TOWN_MIN_CELLS) throw new WorldError(409, "too_few", `城鎮要蓋在至少 ${TOWN_MIN_CELLS} 格相連的領地裡（這裡連著 ${region} 格）。`);
  if (!canAfford(camp.materials, TOWN_COST)) throw new WorldError(409, "cannot_afford", `素材不夠：城鎮要 ${costText(TOWN_COST)}。`);
  camp.materials = spend(camp.materials, TOWN_COST);
  // a town has a nest of its own (it raises residents as fast as the home camp)
  await tx.update(worldCells).set({ town: true, nestStartedAt: row.nestStartedAt ?? new Date(now.getTime() - NEST_BUILD_HOURS * HOUR), updatedAt: now }).where(eq(worldCells.cell, cell));
  const player = await lockPlayer(tx, userId);
  if (player) await tx.update(worldPlayers).set({ xp: player.xp + XP.townBuilt }).where(eq(worldPlayers.userId, userId));
  await addEvent(tx, userId, now, "world", { town: cell });
  await bumpVersion(tx, camp);
}

/**
 * Builds `kind` on a held cell (its ground must allow it), or raises the one there a level (the same kind; one at a time,
 * not while it is still going up). Another kind means taking the old one down first.
 */
export async function buildOnCell(tx: Tx, userId: string, cell: string, kind: string, now: Date) {
  const { camp } = await ownCell(tx, userId, cell);
  await advanceWorld(tx, camp, now);
  const row = await ownedRow(tx, userId, cell);
  if ((await homeCellOf(tx, userId)) === cell) throw new WorldError(409, "camp_cell", "營地那一格蓋場地就好（營地頁）；建築蓋在其他領地上。");
  const rule = cellBuildingRule(kind);
  const terrain = await terrainOf(tx, cell);
  if (!rule || rule.terrain !== terrain) throw new WorldError(400, "invalid_input", "這種地形不能蓋這個。");
  const b = row.building;
  if (b && b.kind !== kind) throw new WorldError(409, "exists", `這一格已經有${cellBuildingName(b.kind, camp.race)}了；要換先拆掉。`);
  if (b && workingLevel(b, now.getTime()) < b.level) throw new WorldError(409, "busy", "還在蓋，蓋好才能再升級。");
  const level = (b?.level ?? 0) + 1;
  if (level > CELL_BUILDING_MAX) throw new WorldError(409, "top", "已經是最高級了。");
  const cost = CELL_BUILDING_COSTS[level - 1]!;
  if (!canAfford(camp.materials, cost)) throw new WorldError(409, "cannot_afford", `素材不夠：要 ${costText(cost)}。`);
  camp.materials = spend(camp.materials, cost);
  const building = { kind: rule.kind, level, busyUntil: new Date(now.getTime() + CELL_BUILDING_HOURS[level - 1]! * HOUR).toISOString() };
  await tx.update(worldCells).set({ building, updatedAt: now }).where(eq(worldCells.cell, cell));
  await addEvent(tx, userId, now, "world", { built: { cell, kind, level } });
  await bumpVersion(tx, camp);
}

/** Takes the building down (nothing comes back: the ground is cleared for another). */
export async function demolishOnCell(tx: Tx, userId: string, cell: string, now: Date) {
  const { camp } = await ownCell(tx, userId, cell);
  await advanceWorld(tx, camp, now);
  const row = await ownedRow(tx, userId, cell);
  if (!row.building) throw new WorldError(409, "none", "這一格沒有建築。");
  await tx.update(worldCells).set({ building: null, updatedAt: now }).where(eq(worldCells.cell, cell));
  await addEvent(tx, userId, now, "world", { demolished: { cell, kind: row.building.kind } });
  await bumpVersion(tx, camp);
}

/**
 * Guests on a cell walk home: the caller's own (guarding a friend's cell), or, for its holder, every friend's there.
 */
export async function unguard(tx: Tx, userId: string, cell: string, now: Date) {
  const camp = await lockCamp(tx, userId);
  if (!camp) throw new WorldError(404, "no_camp", "這個帳號還沒有營地。");
  const row = await lockCell(tx, cell);
  const holder = row?.owner === userId;
  const guests = await tx
    .select({ userId: campResidents.userId, id: campResidents.id })
    .from(campResidents)
    .where(and(eq(campResidents.place, guardPlace(cell)), isNull(campResidents.diedAt), ...(holder ? [] : [eq(campResidents.userId, userId)])));
  if (guests.length === 0) throw new WorldError(409, "none", holder ? "沒有好友在這一格幫守。" : "你沒有居民在這一格幫守。");
  await tx.update(campResidents).set({ place: "home" }).where(and(eq(campResidents.place, guardPlace(cell)), isNull(campResidents.diedAt), ...(holder ? [] : [eq(campResidents.userId, userId)])));
  for (const u of new Set(guests.map((g) => g.userId))) {
    await addEvent(tx, u, now, "world", { unguarded: { cell, count: guests.filter((g) => g.userId === u).length, byHolder: holder } });
    // (their books changed: residents came home)
    if (u !== userId) await tx.update(camps).set({ version: sql`${camps.version} + 1` }).where(eq(camps.userId, u));
  }
  await bumpVersion(tx, camp);
  return [...new Set(guests.map((g) => g.userId))];
}

/** Residents on a cell walk home (all of them, or `count` if enough stay to hold it). */
export async function recall(tx: Tx, userId: string, cell: string, count: number | undefined, now: Date) {
  const { camp } = await ownCell(tx, userId, cell);
  await advanceWorld(tx, camp, now);
  await ownedRow(tx, userId, cell);
  if ((await homeCellOf(tx, userId)) === cell) throw new WorldError(409, "camp_cell", "營地那一格不能放棄；要換地方請用「搬營地」。");
  const there = await aliveAt(tx, userId, cellPlace(cell));
  const all = count === undefined || there.length - count < garrisonMin(camp.race);
  const going = all ? there : pickParty(camp.race, there, undefined, count, false);
  if (going.length) await tx.update(campResidents).set({ place: "home" }).where(and(eq(campResidents.userId, userId), inArray(campResidents.id, going.map((r) => r.id))));
  if (all) await releaseCell(tx, cell);
  await addEvent(tx, userId, now, "world", { recalled: cell, residents: going.length, gaveUp: all });
  await bumpVersion(tx, camp);
  return { residents: going.length, gaveUp: all };
}

// --- looking ------------------------------------------------------------------------------------------------------

export async function worldMe(tx: Tx, userId: string, now: Date): Promise<WorldMe> {
  const camp = await lockCamp(tx, userId);
  if (!camp) throw new WorldError(404, "no_camp", "這個帳號還沒有營地。");
  await advanceWorld(tx, camp, now);
  const player = await lockPlayer(tx, userId);
  const held = await tx.select().from(worldCells).where(eq(worldCells.owner, userId)).orderBy(worldCells.heldSince, worldCells.cell);
  const paying = payingCells(held, player?.homeCell ?? null);
  const ground = await terrainsFor(tx, held.map((c) => c.cell));
  const counts = await garrisons(tx, held.map((c) => c.cell));
  const around = await surroundings(tx, held.map((c) => c.cell));
  const guardingRows = await tx
    .select({ place: campResidents.place, n: sql<number>`count(*)::int`, holder: users.displayName })
    .from(campResidents)
    .leftJoin(worldCells, sql`${worldCells.cell} = substring(${campResidents.place} from 7)`)
    .leftJoin(users, eq(users.id, worldCells.owner))
    .where(and(eq(campResidents.userId, userId), sql`${campResidents.place} like 'guard:%'`, isNull(campResidents.diedAt)))
    .groupBy(campResidents.place, users.displayName);
  const [{ atHome }] = (await tx
    .select({ atHome: sql<number>`count(*)::int` })
    .from(campResidents)
    .where(and(eq(campResidents.userId, userId), eq(campResidents.place, "home"), isNull(campResidents.diedAt)))) as [{ atHome: number }];
  const walking = await tx.select().from(expeditions).where(and(eq(expeditions.userId, userId), eq(expeditions.status, "walking"))).orderBy(expeditions.arriveAt);
  const recent = await tx
    .select()
    .from(expeditions)
    .where(and(or(eq(expeditions.userId, userId), eq(expeditions.defender, userId)), eq(expeditions.status, "done")))
    .orderBy(desc(expeditions.arriveAt))
    .limit(10);
  const xp = player?.xp ?? 0;
  const level = raceLevel(xp);
  return {
    open: !!player?.open,
    canOpen: canOpenWorld(camp.race, camp.peak),
    unlockPeak: worldUnlockPeak(camp.race),
    peak: camp.peak,
    shielded: !!player?.shieldedSince,
    homeCell: player?.homeCell ?? null,
    home: player ? cellCenter(player.homeCell) : null,
    homeMoveAt: player ? (homeMoveAt(player)?.toISOString() ?? null) : null,
    xp,
    level,
    nextLevelXp: xpForLevel(level + 1),
    cells: held.map((c) => ({
      cell: c.cell,
      garrison: counts.get(c.cell)?.n ?? 0,
      nest: nestState(c, now),
      town: c.town,
      terrain: ground.get(c.cell) ?? terrainAt(WORLD_SEED, c.cell),
      nextYieldAt: new Date((c.yieldedTo ?? c.heldSince ?? now).getTime() + YIELD_HOURS * HOUR).toISOString(),
      region: connectedCells(c.cell, new Set(held.map((h) => h.cell))).length,
      upkeep: paying.has(c.cell),
      party: cellBonus(camp.race, c.building, now.getTime(), around(c.cell)).party,
      travel: cellBonus(camp.race, c.building, now.getTime(), around(c.cell)).travel,
    })),
    atHome,
    guarding: guardingRows.map((g) => ({ cell: g.place.slice(6), holder: g.holder ?? "？", count: g.n })),
    upkeep: { paying: paying.size, perYield: paying.size * UPKEEP_RATIONS, everyHours: UPKEEP_EVERY * YIELD_HOURS, rations: rationsIn(camp.materials), freeCells: UPKEEP_FREE_CELLS },
    partyCap: partyCap(camp.race, level),
    food: Object.fromEntries(Object.entries(camp.materials).filter(([id, n]) => isFood(id) && n > 0)),
    walking: walking.map((w) => summary(w, userId)),
    recent: recent.map((w) => summary(w, userId)),
    bosses: player ? await bossesNear(tx, player.homeCell, now) : [],
    happenings: (
      await tx
        .select({ at: campEvents.at, data: campEvents.data })
        .from(campEvents)
        .where(and(eq(campEvents.userId, userId), eq(campEvents.kind, "world"), sql`(${campEvents.data} ? 'lairBack' or ${campEvents.data} ? 'bossReward' or ${campEvents.data} ? 'yields')`))
        .orderBy(desc(campEvents.seq))
        .limit(10)
    ).map((e) => ({ at: e.at.toISOString(), ...(e.data as object) })),
    rules: {
      garrisonMin: garrisonMin(camp.race),
      cellCapacity: cellCapacity(camp.race),
      nestCost: NEST_COST,
      nestHours: NEST_BUILD_HOURS,
      nestBirthMinutes: nestBirthMinutes(camp.race),
      townCost: TOWN_COST,
      townMinCells: TOWN_MIN_CELLS,
    },
  };
}

/** All of a camp's held cells at a glance: the camp's own first, then the longest held. */
export async function territoryList(tx: Tx, userId: string, now: Date): Promise<TerritoryList> {
  const camp = await lockCamp(tx, userId);
  if (!camp) throw new WorldError(404, "no_camp", "這個帳號還沒有營地。");
  await advanceWorld(tx, camp, now);
  const homeCell = await homeCellOf(tx, userId);
  const held = await tx.select().from(worldCells).where(eq(worldCells.owner, userId)).orderBy(worldCells.heldSince, worldCells.cell);
  const cells = held.map((c) => c.cell);
  const mine = new Set(cells);
  const ground = await terrainsFor(tx, cells);
  const around = await surroundings(tx, cells);
  const counts = await garrisons(tx, cells);
  const paying = payingCells(held, homeCell);
  const guests = new Map(
    (cells.length
      ? await tx
          .select({ place: campResidents.place, n: sql<number>`count(*)::int` })
          .from(campResidents)
          .where(and(inArray(campResidents.place, cells.map(guardPlace)), isNull(campResidents.diedAt)))
          .groupBy(campResidents.place)
      : []
    ).map((g) => [g.place.slice(6), g.n]),
  );
  const items = held.map((c) => {
    const isHome = c.cell === homeCell;
    const a = around(c.cell);
    const rule = a.landmark ? landmarkRule(a.landmark.kind) : undefined;
    const b = isHome ? null : c.building;
    const at = cellCenter(c.cell);
    return {
      cell: c.cell,
      lat: at.lat,
      lng: at.lng,
      terrain: ground.get(c.cell) ?? terrainAt(WORLD_SEED, c.cell),
      home: isHome,
      town: c.town,
      garrison: counts.get(c.cell)?.n ?? 0,
      capacity: cellCapacity(camp.race, c.town) + cellBonus(camp.race, b, now.getTime(), a).room,
      nest: nestState(c, now),
      building: b ? { kind: b.kind, name: cellBuildingName(b.kind, camp.race), level: b.level, busy: workingLevel(b, now.getTime()) < b.level } : null,
      landmark: a.landmark && rule ? { ...a.landmark, icon: rule.icon, label: rule.name } : null,
      region: connectedCells(c.cell, mine).length,
      neighbours: a.neighbours ?? 0,
      upkeep: paying.has(c.cell),
      guests: guests.get(c.cell) ?? 0,
      nextYieldAt: new Date((c.yieldedTo ?? c.heldSince ?? now).getTime() + YIELD_HOURS * HOUR).toISOString(),
      heldSince: c.heldSince?.toISOString() ?? null,
    };
  });
  items.sort((x, y) => Number(y.home) - Number(x.home));
  return { items, residents: items.reduce((n, i) => n + i.garrison, 0), rations: rationsIn(camp.materials), paying: paying.size };
}

/** One held cell from inside: how many live there and how it grows, what the ground gives, and what happened there lately. */
export async function cellDetail(tx: Tx, userId: string, cell: string, now: Date): Promise<CellDetail> {
  const camp = await lockCamp(tx, userId);
  if (!camp) throw new WorldError(404, "no_camp", "這個帳號還沒有營地。");
  await advanceWorld(tx, camp, now);
  const [row] = await tx.select().from(worldCells).where(eq(worldCells.cell, cell));
  if (row?.owner !== userId) throw new WorldError(403, "not_yours", "這不是你的格子。");
  const homeCell = await homeCellOf(tx, userId);
  const isHome = cell === homeCell;
  const terrain = await terrainOf(tx, cell);
  const garrison = (await dwellers(tx, userId, cell, homeCell)).length;
  const capacity = cellCapacity(camp.race, row.town);
  const nest = nestState(row, now);
  const readyAt = row.nestStartedAt ? new Date(row.nestStartedAt.getTime() + NEST_BUILD_HOURS * HOUR) : null;
  const birthMinutes = row.nestStartedAt && !isHome ? nestBirthMinutes(camp.race, row.town) : null;
  let nextBirthAt: Date | null = null;
  if (readyAt && birthMinutes && garrison < capacity) {
    nextBirthAt = nest === "ready" ? new Date(Math.max(now.getTime(), readyAt.getTime() + row.nextSlot * birthMinutes * MINUTE)) : readyAt;
  }
  // what happened here: the camp's events that name this cell (kept 30 days), the newest 20
  const events = await tx
    .select({ at: campEvents.at, kind: campEvents.kind, data: campEvents.data })
    .from(campEvents)
    .where(
      and(
        eq(campEvents.userId, userId),
        sql`(${campEvents.data} -> 'cells' ? ${cell} or ${campEvents.data} -> 'lairBack' ->> 'cell' = ${cell} or ${campEvents.data} ->> 'cell' = ${cell}
          or ${campEvents.data} ->> 'nest' = ${cell} or ${campEvents.data} ->> 'town' = ${cell} or ${campEvents.data} ->> 'recalled' = ${cell}
          or ${campEvents.data} -> 'hungry' ? ${cell} or ${campEvents.data} -> 'guests' ->> 'cell' = ${cell} or ${campEvents.data} -> 'built' ->> 'cell' = ${cell} or ${campEvents.data} -> 'demolished' ->> 'cell' = ${cell}
          or (${campEvents.data} ->> 'to' = ${cell} and ${campEvents.data} ? 'arrived'))`,
      ),
    )
    .orderBy(desc(campEvents.seq))
    .limit(20);
  const history: CellHappening[] = [];
  for (const e of events) {
    const d = e.data as Record<string, any>;
    const at = e.at.toISOString();
    if (d.cells?.[cell] || d.hungry?.includes(cell)) history.push({ at, kind: "yield", loot: d.cells?.[cell] ?? {}, hungry: d.hungry?.includes(cell) || undefined });
    else if (d.lairBack) history.push({ at, kind: "lairBack", name: d.lairBack.name, held: d.lairBack.held, fallen: d.lairBack.fallen, killed: d.lairBack.killed, loot: d.lairBack.loot, helped: d.lairBack.helped, guests: d.lairBack.guests });
    else if (d.guests) history.push({ at, kind: "guests", by: d.guests.from, residents: d.guests.count });
    else if (d.defended) history.push({ at, kind: "attacked", by: d.by, held: d.won, fallen: d.fallen, expedition: d.id });
    else if (d.arrived && (d.cell === "settled" || d.cell === "taken")) history.push({ at, kind: "settled", fallen: d.fallen, killed: d.killed, expedition: d.id });
    else if (d.nest) history.push({ at, kind: "nest" });
    else if (d.town) history.push({ at, kind: "town" });
    else if (d.recalled) history.push({ at, kind: "recalled", residents: d.residents });
    else if (d.built) history.push({ at, kind: "built", name: cellBuildingName(d.built.kind, camp.race), residents: d.built.level });
    else if (d.demolished) history.push({ at, kind: "demolished", name: cellBuildingName(d.demolished.kind, camp.race) });
  }
  const center = cellCenter(cell);
  const b = isHome ? null : row.building;
  const mine = await heldCells(tx, userId);
  const heldRows = await tx.select({ cell: worldCells.cell }).from(worldCells).where(eq(worldCells.owner, userId)).orderBy(worldCells.heldSince, worldCells.cell);
  const paying = payingCells(heldRows, homeCell);
  const guestRows = await tx
    .select({ owner: campResidents.userId, name: users.displayName, n: sql<number>`count(*)::int` })
    .from(campResidents)
    .leftJoin(users, eq(users.id, campResidents.userId))
    .where(and(eq(campResidents.place, guardPlace(cell)), isNull(campResidents.diedAt)))
    .groupBy(campResidents.userId, users.displayName);
  const around = (await surroundings(tx, mine))(cell);
  const landmark = around.landmark ? landmarkRule(around.landmark.kind) : undefined;
  const top = (b?.level ?? 0) >= CELL_BUILDING_MAX;
  return {
    cell,
    lat: center.lat,
    lng: center.lng,
    terrain,
    home: isHome,
    town: row.town,
    garrison,
    capacity,
    garrisonMin: garrisonMin(camp.race),
    nest,
    nestReadyAt: nest === "building" && readyAt ? readyAt.toISOString() : null,
    nextBirthAt: nextBirthAt?.toISOString() ?? null,
    birthMinutes,
    heldSince: row.heldSince?.toISOString() ?? null,
    nextYieldAt: new Date((row.yieldedTo ?? row.heldSince ?? now).getTime() + YIELD_HOURS * HOUR).toISOString(),
    yields: (TERRAIN_YIELD[terrain] ?? []).map((y) => y.id),
    building: b
      ? {
          kind: b.kind,
          name: cellBuildingName(b.kind, camp.race),
          blurb: cellBuildingBlurb(b.kind, camp.race),
          level: b.level,
          working: workingLevel(b, now.getTime()),
          busyUntil: b.busyUntil && Date.parse(b.busyUntil) > now.getTime() ? b.busyUntil : null,
        }
      : null,
    canBuild: isHome ? [] : buildingsFor(terrain).map((r) => ({ kind: r.kind, name: cellBuildingName(r.kind, camp.race), blurb: cellBuildingBlurb(r.kind, camp.race) })),
    nextCost: isHome || top ? null : CELL_BUILDING_COSTS[b?.level ?? 0]!,
    nextHours: isHome || top ? null : CELL_BUILDING_HOURS[b?.level ?? 0]!,
    bonus: cellBonus(camp.race, b, now.getTime(), around),
    landmark: around.landmark && landmark ? { ...around.landmark, icon: landmark.icon, label: landmark.name, blurb: landmark.blurb } : null,
    templeNear: !!around.templeNear,
    neighbours: around.neighbours ?? 0,
    region: connectedCells(cell, new Set(mine)).length,
    guests: guestRows.map((g) => ({ owner: g.owner, name: g.name ?? "？", count: g.n })),
    upkeep: { pays: paying.has(cell), paying: paying.size, rations: rationsIn(camp.materials), freeCells: UPKEEP_FREE_CELLS, perYield: UPKEEP_RATIONS, everyHours: UPKEEP_EVERY * YIELD_HOURS },
    history,
  };
}

/** The great monsters out now within three regions of `home` (about 25 km; not yet beaten), the nearest three. */
async function bossesNear(tx: Tx, home: string, now: Date): Promise<WorldMe["bosses"]> {
  const [r, c] = regionOf(home).split(":").map(Number) as [number, number];
  const sightings: BossSighting[] = [];
  for (let dr = -3; dr <= 3; dr++) {
    for (let dc = -3; dc <= 3; dc++) {
      const b = bossIn(WORLD_SEED, `${r + dr}:${c + dc}`, bossWindow(now.getTime()), bossesOn());
      if (b) sightings.push(b);
    }
  }
  if (sightings.length === 0) return [];
  // (two queries for all of them: their wounds, and whether a camp holds the cell)
  const rows = new Map((await tx.select().from(worldBosses).where(inArray(worldBosses.key, sightings.map(bossKey)))).map((b) => [b.key, b]));
  const held = new Set(
    (await tx.select({ cell: worldCells.cell }).from(worldCells).where(and(inArray(worldCells.cell, sightings.map((b) => b.cell)), isNotNull(worldCells.owner)))).map((h) => h.cell),
  );
  return sightings
    .filter((b) => !rows.get(bossKey(b))?.defeatedAt && !held.has(b.cell))
    .map((b) => {
      const row = rows.get(bossKey(b));
      const at = cellCenter(b.cell);
      return { cell: b.cell, kind: b.kind, name: b.name, lat: at.lat, lng: at.lng, km: Math.round(cellDistance(home, b.cell) / 100) / 10, hp: row?.hp ?? bossMaxHp(b.kind), maxHp: row?.maxHp ?? bossMaxHp(b.kind), endsAt: new Date(b.endsAt).toISOString() };
    })
    .sort((a, b) => a.km - b.km)
    .slice(0, 3);
}

/** How many live on each cell (on a camp's own cell, everybody at home as well). */
async function garrisons(tx: Tx, cells: string[]): Promise<Map<string, { n: number }>> {
  if (cells.length === 0) return new Map();
  const rows = await tx
    .select({ place: campResidents.place, n: sql<number>`count(*)::int` })
    .from(campResidents)
    .where(and(inArray(campResidents.place, cells.map(cellPlace)), isNull(campResidents.diedAt)))
    .groupBy(campResidents.place);
  const out = new Map(rows.map((r) => [r.place.slice(5), { n: r.n }]));
  const camps = await tx.select({ userId: worldPlayers.userId, cell: worldPlayers.homeCell }).from(worldPlayers).where(inArray(worldPlayers.homeCell, cells));
  if (camps.length) {
    const home = await tx
      .select({ userId: campResidents.userId, n: sql<number>`count(*)::int` })
      .from(campResidents)
      .where(and(inArray(campResidents.userId, camps.map((c) => c.userId)), eq(campResidents.place, "home"), isNull(campResidents.diedAt)))
      .groupBy(campResidents.userId);
    const byUser = new Map(home.map((h) => [h.userId, h.n]));
    for (const c of camps) out.set(c.cell, { n: (out.get(c.cell)?.n ?? 0) + (byUser.get(c.userId) ?? 0) });
  }
  return out;
}

/** A lair on the map with its wounds (gone once it is whole again). */
function lairWith(lair: Lair | null, wounds: { hp: number[]; at: number } | null | undefined, now: Date): Pick<CellView, "lair" | "lairWounds"> {
  if (!lair) return { lair: null, lairWounds: null };
  if (!wounds) return { lair: lairView(lair), lairWounds: null };
  const view = lairWoundsView(lair, wounds, now.getTime());
  if (view.healedAt <= now.getTime()) return { lair: lairView(lair), lairWounds: null };
  return {
    lair: lairView(lair, woundedLairFighters(lair, wounds, now.getTime())),
    lairWounds: { standing: view.standing, total: view.total, hpShare: Math.round(view.hpShare * 100) / 100, healedAt: new Date(view.healedAt).toISOString() },
  };
}

/** How far around a point landmarks may be looked for, and how many are given back at most. */
export const LANDMARK_RADIUS = 3000;
const LANDMARKS_SHOWN = 40;

/** The landmarks within `radius` of a point, the nearest first, with who holds each. */
export async function landmarksAround(tx: Tx, point: LatLng, radius: number): Promise<NearbyLandmark[]> {
  const ids = cellsWithin(point, Math.min(radius, LANDMARK_RADIUS));
  const found = [...(await landmarksFor(tx, ids))].filter((e): e is [string, NonNullable<(typeof e)[1]>] => !!e[1]);
  const near = found
    .map(([cell, l]) => {
      const at = cellCenter(cell);
      return { cell, lat: at.lat, lng: at.lng, kind: l.kind, name: l.name, km: Math.round(metersBetween(point, at) / 100) / 10 };
    })
    .sort((a, b) => a.km - b.km)
    .slice(0, LANDMARKS_SHOWN);
  const rows = near.length ? await tx.select({ cell: worldCells.cell, owner: worldCells.owner }).from(worldCells).where(inArray(worldCells.cell, near.map((n) => n.cell))) : [];
  const owners = new Map<string, WorldOwner>();
  for (const r of rows) if (r.owner && !owners.has(r.owner)) owners.set(r.owner, await ownerOf(tx, r.owner));
  const ownerOfCell = new Map(rows.map((r) => [r.cell, r.owner ? owners.get(r.owner)! : null]));
  return near.map((n) => ({ ...n, owner: ownerOfCell.get(n.cell) ?? null }));
}

export async function cellsAround(tx: Tx, point: LatLng, radius: number, now: Date): Promise<CellView[]> {
  const ids = cellsWithin(point, Math.min(radius, MAX_MAP_RADIUS));
  const ground = await terrainsFor(tx, ids);
  const landmarks = await landmarksFor(tx, ids);
  const rows = ids.length ? await tx.select().from(worldCells).where(inArray(worldCells.cell, ids)) : [];
  const byCell = new Map(rows.map((r) => [r.cell, r]));
  const ownerIds = [...new Set(rows.map((r) => r.owner).filter((o): o is string => !!o))];
  const owners = new Map<string, WorldOwner>();
  for (const id of ownerIds) owners.set(id, await ownerOf(tx, id));
  const counts = await garrisons(tx, rows.filter((r) => r.owner).map((r) => r.cell));
  const guestCounts = new Map(
    (rows.some((r) => r.owner)
      ? await tx
          .select({ place: campResidents.place, n: sql<number>`count(*)::int` })
          .from(campResidents)
          .where(and(inArray(campResidents.place, rows.filter((r) => r.owner).map((r) => guardPlace(r.cell))), isNull(campResidents.diedAt)))
          .groupBy(campResidents.place)
      : []
    ).map((g) => [g.place.slice(6), g.n]),
  );
  // the great monsters standing in view (their wounds, if anybody has fought them)
  const bosses = new Map<string, BossView>();
  for (const cell of ids) {
    const sighting = bossAt(WORLD_SEED, cell, now.getTime(), bossesOn());
    if (!sighting || byCell.get(cell)?.owner) continue;
    const [row] = await tx.select().from(worldBosses).where(eq(worldBosses.key, bossKey(sighting)));
    if (row?.defeatedAt) continue;
    bosses.set(cell, await bossView(tx, sighting, row));
  }
  return ids.map((cell) => {
    const row = byCell.get(cell);
    const boss = bosses.get(cell) ?? null;
    const terrain = ground.get(cell) ?? terrainAt(WORLD_SEED, cell);
    const { lair, backAt } = boss ? { lair: null, backAt: null } : lairHere(cell, row, now, terrain);
    const center = cellCenter(cell);
    return {
      cell,
      lat: center.lat,
      lng: center.lng,
      terrain,
      owner: row?.owner ? (owners.get(row.owner) ?? null) : null,
      garrison: counts.get(cell)?.n ?? 0,
      nest: row ? nestState(row, now) : "none",
      town: row?.town ?? false,
      landmark: landmarks.get(cell) ?? null,
      guests: guestCounts.get(cell) ?? 0,
      building: row?.owner && row.building ? { kind: row.building.kind, level: row.building.level, busy: workingLevel(row.building, now.getTime()) < row.building.level } : null,
      ...lairWith(lair, row?.lairWounds, now),
      lairBackAt: backAt?.toISOString() ?? null,
      boss,
    };
  });
}

export async function expeditionReport(tx: Tx, userId: string, id: string): Promise<ExpeditionReport | ExpeditionSummary | null> {
  const [row] = await tx.select().from(expeditions).where(eq(expeditions.id, id));
  if (!row || (row.userId !== userId && row.defender !== userId)) return null;
  if (row.status !== "done") return summary(row, userId);
  return { ...(row.result as ExpeditionReport), ...summary(row, userId) };
}

export async function expeditionList(tx: Tx, userId: string, limit: number): Promise<ExpeditionSummary[]> {
  const rows = await tx
    .select()
    .from(expeditions)
    .where(or(eq(expeditions.userId, userId), eq(expeditions.defender, userId)))
    .orderBy(desc(expeditions.setOutAt))
    .limit(limit);
  return rows.map((r) => summary(r, userId));
}

/** Every camp, ranked (WORLD.md §7): everybody plays, whether or not they opened the big world. */
export async function leaderboard(tx: Tx) {
  const all = await tx.select({ userId: camps.userId, race: camps.race, name: users.displayName }).from(camps).innerJoin(users, eq(users.id, camps.userId));
  const players = new Map((await tx.select().from(worldPlayers)).map((p) => [p.userId, p]));
  const held = await tx.select({ owner: worldCells.owner, n: sql<number>`count(*)::int` }).from(worldCells).where(sql`${worldCells.owner} is not null`).groupBy(worldCells.owner);
  const cells = new Map(held.map((h) => [h.owner!, h.n]));
  const entries: LeaderboardEntry[] = [];
  for (const c of all) {
    const residents = await tx.select().from(campResidents).where(and(eq(campResidents.userId, c.userId), isNull(campResidents.diedAt)));
    const fighters = residents.map((r) => residentFighter(fighterOf(c.race, r), "attack", traitsOf(c.race)));
    entries.push({ player: c.userId, name: c.name, race: c.race, population: residents.length, power: Math.round(combatPower(fighters)), xp: players.get(c.userId)?.xp ?? 0, cells: cells.get(c.userId) ?? 0 });
  }
  return { all: rank(entries), byRace: rankByRace(entries) };
}

// --- the clock ----------------------------------------------------------------------------------------------------

/** Tells a camp's devices its books changed. */
export async function notifyCamp(deps: Pick<AppDeps, "database" | "hub">, userId: string) {
  const [row] = await deps.database.db.select({ version: camps.version }).from(camps).where(eq(camps.userId, userId));
  if (row) deps.hub.notify(userId, { type: "camp.changed", version: row.version });
}

/** Settles every party that has arrived by `now` (one camp's, or all of them), each in its own transaction. */
export async function settleDue(deps: Pick<AppDeps, "database" | "hub" | "push">, now: Date, userId?: string): Promise<number> {
  const { db } = deps.database;
  const ids = await db.transaction((tx) => dueExpeditions(tx, now, userId));
  const told = new Set<string>();
  const news: WorldNews[] = [];
  for (const id of ids) {
    const out = await db.transaction((tx) => settleExpedition(tx, id, now));
    for (const u of out?.users ?? []) told.add(u);
    news.push(...(out?.news ?? []));
  }
  for (const u of told) await notifyCamp(deps, u);
  for (const n of news) await pushNews(deps, n);
  return ids.length;
}

/** Pushes a piece of news to the account's phones that take notifications. */
async function pushNews(deps: Pick<AppDeps, "database" | "push">, n: WorldNews) {
  const { db } = deps.database;
  const phones = await db
    .select({ id: devices.id, subscription: devices.pushSubscription })
    .from(devices)
    .where(and(eq(devices.userId, n.user), eq(devices.kind, "pwa"), isNotNull(devices.pushSubscription)));
  const payload: WorldPush = { type: "world", title: n.title, body: n.body, url: n.url, tag: n.url };
  for (const phone of phones) {
    const outcome = await deps.push.send(phone.subscription as PushSubscriptionJSON, payload);
    if (outcome === "gone") await db.update(devices).set({ pushSubscription: null }).where(eq(devices.id, phone.id));
  }
}

/** Settles arrived parties every few seconds (so a camp hears of a fight even when nobody asks); returns a stop function. */
export function startWorldLoop(deps: Pick<AppDeps, "database" | "hub" | "push">, everyMs = 10_000): () => void {
  let running = false;
  const timer = setInterval(async () => {
    if (running) return;
    running = true;
    try {
      await settleDue(deps, new Date());
    } catch (err) {
      console.error("world loop:", err);
    } finally {
      running = false;
    }
  }, everyMs);
  return () => clearInterval(timer);
}
