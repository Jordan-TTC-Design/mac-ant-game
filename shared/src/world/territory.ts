/**
 * The rules of holding land in the big world (WORLD.md §3, §6): when a camp may open the big world, how cells are taken and
 * held, nests on held cells, towns, how long a party walks, and the protection a camp gets after losing.
 */
import { raceRules } from "../camp/races.ts";
import { cellDistance, type CellId } from "./grid.ts";

// --- opening the big world ---------------------------------------------------------------------------------------

// Every number that depends on the race comes from the camp's race table (camp/races.ts, server/CAMP.md §11).

/** A camp may open the big world once it has ever had its race's third look (goblins 150, elves 90, undead 120). */
export function worldUnlockPeak(race: string): number {
  return raceRules(race).stage3;
}

export function canOpenWorld(race: string, peakResidents: number): boolean {
  return peakResidents >= worldUnlockPeak(race);
}

// --- holding cells -------------------------------------------------------------------------------------------------

/** Residents that must live on a cell to hold it (goblins 5, elves 3, undead 4; more hold it better). */
export function garrisonMin(race: string): number {
  return raceRules(race).cellMin;
}

/** Most residents one cell can house (goblins 50, elves 30, undead 40); a town cell twice that. */
export function cellCapacity(race: string, town = false): number {
  const r = raceRules(race);
  return town ? r.townCap : r.cellCap;
}

/** The state of one cell the server keeps (a cell nobody touched is not stored: see contents.ts). */
export interface CellState {
  cell: CellId;
  /** The player who holds it, or null. */
  owner: string | null;
  /** Residents living there (ids). */
  garrison: string[];
  /** A nest built there, and when it was finished (null while building or none). */
  nest: { builtAt: string | null; startedAt: string } | null;
  /** A town (needs TOWN_MIN_CELLS held cells). */
  town: boolean;
  /** When the lair that was here was cleared (it comes back after its respawn time), if it was. */
  clearedAt: string | null;
}

export type OccupyRefusal = "held" | "lair" | "too_few" | "too_many" | "not_open" | "shielded";

/**
 * Whether a camp may move `settlers` residents onto a cell. A cell is free if nobody holds it and its lair (if any) has been
 * cleared (and has not come back). A camp that has not opened the big world, or is shielded after a loss, cannot.
 */
export function checkOccupy(options: {
  race: string;
  cell: CellState | null;
  hasLair: boolean;
  lairBack: boolean;
  settlers: number;
  player: PlayerWorldState;
}): OccupyRefusal | null {
  const { cell, settlers, player } = options;
  if (!player.open) return "not_open";
  if (player.shieldedSince) return "shielded";
  if (cell?.owner) return "held";
  if (options.hasLair && (!cell?.clearedAt || options.lairBack)) return "lair";
  if (settlers < garrisonMin(options.race)) return "too_few";
  if (settlers > cellCapacity(options.race)) return "too_many";
  return null;
}

/** How many cells a camp could hold with this many residents to spare (every held cell needs its garrison). */
export function maxCells(race: string, spareResidents: number): number {
  return Math.max(0, Math.floor(spareResidents / garrisonMin(race)));
}

// --- nests on held cells ------------------------------------------------------------------------------------------

/** What a nest costs (material ids the camp already collects) and how long it takes. */
export const NEST_COST: Record<string, number> = { scrap_wood: 30, scrap_iron: 10, scrap_rag: 10 };
export const NEST_BUILD_HOURS = 2;
/** A cell with a finished nest raises a new resident this often (goblins 15, elves 30, undead 22.5 minutes; a town as fast as the home camp). */
export function nestBirthMinutes(race: string, town = false): number {
  const r = raceRules(race);
  return town ? r.townBirthMinutes : r.nestBirthMinutes;
}

export function canAfford(have: Record<string, number>, cost: Record<string, number>): boolean {
  return Object.entries(cost).every(([id, n]) => (have[id] ?? 0) >= n);
}

export function nestReady(nest: CellState["nest"], now: Date): boolean {
  if (!nest) return false;
  return now.getTime() - new Date(nest.startedAt).getTime() >= NEST_BUILD_HOURS * 3_600_000;
}

/**
 * How many new residents a finished nest has raised between two times (whole ones only), not past the cell's room.
 * A quick count; the server raises the actual residents (who they are, when they die) with camp/population.ts `advance`,
 * using a place with `nestBirthMinutes` and `cellCapacity`.
 */
export function nestBirths(race: string, since: Date, now: Date, garrison: number, town = false): number {
  const births = Math.floor((now.getTime() - since.getTime()) / (nestBirthMinutes(race, town) * 60_000));
  return Math.max(0, Math.min(births, cellCapacity(race, town) - garrison));
}

// --- towns ---------------------------------------------------------------------------------------------------------

/** A town can be built in a region of this many joined cells (and one more town for every TOWN_CELLS_EACH more: holdings.ts). */
export const TOWN_MIN_CELLS = 4;
export const TOWN_COST: Record<string, number> = { scrap_wood: 120, scrap_iron: 60, scrap_rag: 40, crystal_shard: 2 };

export function canBuildTown(heldCells: number, have: Record<string, number>, alreadyTown: boolean): boolean {
  return !alreadyTown && heldCells >= TOWN_MIN_CELLS && canAfford(have, TOWN_COST);
}

// --- walking there --------------------------------------------------------------------------------------------------

/** A party walks this many minutes per kilometre, plus a few to set out, and never more than the cap (WORLD.md §5). */
export const MINUTES_PER_KM = 4;
export const SETOUT_MINUTES = 3;
export const MAX_TRAVEL_MINUTES = 180;

/** How long a party takes between two cells; `speed` is the slowest member's pace (carrots help). */
export function travelMinutes(from: CellId, to: CellId, speed = 1): number {
  const km = cellDistance(from, to) / 1000;
  const minutes = Math.min(MAX_TRAVEL_MINUTES, SETOUT_MINUTES + km * MINUTES_PER_KM);
  return Math.max(1, Math.round(minutes / Math.max(0.2, speed)));
}

// --- losing, and the protection that follows -----------------------------------------------------------------------

/**
 * A player's standing in the big world. After losing a battle a camp "turtles": it goes back to its camp, and nobody can
 * attack its camp or any of its cells until it opens the big world again (decided 2026-09-27: protect everything for now).
 * Against someone losing on purpose to hide, a camp is only shielded again once SHIELD_COOLDOWN_HOURS have passed since the
 * last shield ended (a proposal, WORLD.md §11).
 */
export interface PlayerWorldState {
  open: boolean;
  /** When the current shield began, or null. */
  shieldedSince: string | null;
  /** When the last shield ended, or null. */
  lastShieldEnded: string | null;
}

export const SHIELD_COOLDOWN_HOURS = 12;

export function afterDefeat(state: PlayerWorldState, now: Date): PlayerWorldState {
  const last = state.lastShieldEnded ? new Date(state.lastShieldEnded).getTime() : -Infinity;
  if (now.getTime() - last < SHIELD_COOLDOWN_HOURS * 3_600_000) return state; // shielded too recently: no shield this time
  return { open: false, shieldedSince: now.toISOString(), lastShieldEnded: state.lastShieldEnded };
}

/** The player opens the big world (again): the shield, if any, ends. */
export function openWorld(state: PlayerWorldState, now: Date): PlayerWorldState {
  return { open: true, shieldedSince: null, lastShieldEnded: state.shieldedSince ? now.toISOString() : state.lastShieldEnded };
}

export type AttackRefusal = "own" | "you_closed" | "target_shielded" | "target_closed";

/** Whether `attacker` may send a party against something `target` holds. Everyone may attack everyone (teams come later). */
export function checkAttack(attackerId: string, attacker: PlayerWorldState, targetId: string, target: PlayerWorldState): AttackRefusal | null {
  if (attackerId === targetId) return "own";
  if (!attacker.open || attacker.shieldedSince) return "you_closed";
  if (target.shieldedSince) return "target_shielded";
  if (!target.open) return "target_closed";
  return null;
}

// --- what held cells yield ---------------------------------------------------------------------------------------

/** Every this many hours a held cell yields what its ground gives (to the camp's store). */
export const YIELD_HOURS = 3;

/** What one yield of a cell gives, by its terrain: the plain materials a nest and a town are built from, now and then a find. */
export const TERRAIN_YIELD: Record<string, { id: string; min: number; max: number; chance: number }[]> = {
  // (and food for expeditions, by the ground: supplies.ts)
  forest: [{ id: "scrap_wood", min: 2, max: 4, chance: 1 }, { id: "amber", min: 1, max: 1, chance: 0.05 }, { id: "ration_berry", min: 1, max: 2, chance: 0.6 }],
  park: [{ id: "scrap_rag", min: 1, max: 3, chance: 1 }, { id: "scrap_wood", min: 1, max: 2, chance: 0.6 }, { id: "ration_berry", min: 1, max: 1, chance: 0.5 }, { id: "food_honey", min: 1, max: 1, chance: 0.35 }],
  water: [{ id: "frog_skin", min: 1, max: 2, chance: 0.7 }, { id: "snake_scale", min: 1, max: 1, chance: 0.3 }, { id: "river_pearl", min: 1, max: 1, chance: 0.04 }, { id: "ration_fish", min: 1, max: 2, chance: 0.7 }],
  urban: [{ id: "scrap_iron", min: 2, max: 3, chance: 1 }, { id: "crystal_shard", min: 1, max: 1, chance: 0.06 }, { id: "ration_bread", min: 1, max: 1, chance: 0.5 }, { id: "food_cheese", min: 1, max: 1, chance: 0.2 }],
  open: [{ id: "scrap_rag", min: 1, max: 2, chance: 1 }, { id: "scrap_iron", min: 1, max: 2, chance: 0.5 }, { id: "food_carrot", min: 1, max: 2, chance: 0.5 }],
  road: [{ id: "scrap_iron", min: 1, max: 2, chance: 1 }, { id: "stolen_coin", min: 1, max: 2, chance: 0.2 }, { id: "ration_jerky", min: 1, max: 1, chance: 0.4 }],
};

/**
 * What a held cell yields for `times` yields with `garrison` living there: nothing below the race's minimum (nobody to
 * work it), then more the more live there, up to double at the cell's full room; a town twice that again.
 */
export function cellYield(race: string, terrain: string, garrison: number, times: number, random: () => number, town = false, boost = 0): Record<string, number> {
  const min = garrisonMin(race);
  if (garrison < min || times <= 0) return {};
  const scale = Math.min(2, 1 + (garrison - min) / Math.max(1, cellCapacity(race) - min)) * (town ? 2 : 1) * (1 + boost);
  const out: Record<string, number> = {};
  for (let k = 0; k < times; k++) {
    for (const y of TERRAIN_YIELD[terrain] ?? TERRAIN_YIELD.open!) {
      if (random() >= y.chance) continue;
      const n = Math.round((y.min + Math.floor(random() * (y.max - y.min + 1))) * scale);
      if (n > 0) out[y.id] = (out[y.id] ?? 0) + n;
    }
  }
  return out;
}
