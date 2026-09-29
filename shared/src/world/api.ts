/**
 * The big world's API (server/WORLD.md §15). The server keeps the camp (server/CAMP.md), so a device never sends numbers
 * about its residents: it names them (or asks for a count and the server picks), and the server looks up who they are.
 */
import { z } from "zod";
import type { BattleEvent } from "./battle.ts";
import type { Terrain } from "./contents.ts";
import { isCellId } from "./grid.ts";
import type { CellBonus, Landmark } from "./holdings.ts";

/** The one world everybody shares. */
export const WORLD_SEED = 20_260_927;

const cell = z.string().refine(isCellId, "not a cell id");
/** Residents by number (the camp's resident ids). */
const residentIds = z.array(z.number().int().min(1)).min(1).max(60);

/**
 * `POST /api/world/open`: open the big world. The first time, pick where the camp stands on the map (the whole camp is
 * there: nobody has to be sent); after a defeat (turtling), open again with no body to end the protection.
 * (`settlers` is what older devices send; it is not used any more.)
 */
export const openWorldInput = z.object({
  cell: cell.optional(),
  settlers: z.number().int().min(1).max(100).optional(),
});

/** How often the camp may move to another cell (`POST /api/world/cells/:cell/home`). */
export const HOME_MOVE_DAYS = 7;

/**
 * `POST /api/world/expeditions`: a party walks from home (or a held cell) to a cell. Onto a cell of your own they move in;
 * anywhere else they fight what holds it. `settle`: if they win (or the cell is free), the survivors stay and hold it.
 */
export const expeditionInput = z
  .object({
    from: z.union([z.literal("home"), cell]).default("home"),
    to: cell,
    /** Who goes; or `count` and the server picks the strongest. */
    residents: residentIds.optional(),
    count: z.number().int().min(1).max(60).optional(),
    settle: z.boolean().default(false),
    /** Food taken along (supplies.ts): rations let more go, the rest make the party stronger. */
    supplies: z.record(z.string().max(40), z.number().int().min(0).max(60)).optional(),
  })
  .refine((v) => v.residents || v.count, "residents or count");
export type ExpeditionInput = z.infer<typeof expeditionInput>;

/** `POST /api/world/cells/:cell/recall`: residents on a held cell walk home (all of them: the cell is given up). */
export const recallInput = z.object({ count: z.number().int().min(1).max(100).optional() });

export const battleEventSchema = z.object({
  round: z.number().int(),
  actor: z.string(),
  target: z.string(),
  kind: z.enum(["hit", "miss", "heal", "down"]),
  amount: z.number().optional(),
});

export interface WorldOwner {
  id: string;
  name: string;
  race: string;
}

/** A lair as the map shows it. */
export interface LairView {
  kind: string;
  name: string;
  faction: string;
  level: number;
  /** How many foes, and of what kinds (a scout's report). */
  count: number;
  foes: Record<string, number>;
  /** The number to compare with a party's (combatPower). */
  power: number;
}

/** A great monster of the world as the map shows it (bosses.ts). */
export interface BossView {
  kind: string;
  name: string;
  hp: number;
  maxHp: number;
  endsAt: string;
  /** Its guard (fresh at every fight). */
  foes: Record<string, number>;
  /** Who has hurt it most (names and damage), the most first. */
  fighters: { name: string; damage: number }[];
}

/** `GET /api/world/cells`: one cell of the map. */
export interface CellView {
  cell: string;
  lat: number;
  lng: number;
  terrain: Terrain;
  owner: WorldOwner | null;
  garrison: number;
  nest: "none" | "building" | "ready";
  town: boolean;
  /** A real place standing in it (holdings.ts). */
  landmark?: Landmark | null;
  /** What its holder built on it. */
  building?: { kind: string; level: number; busy: boolean } | null;
  lair: LairView | null;
  /** A cleared lair comes back at this time. */
  lairBackAt: string | null;
  /** A lair that beat a party off and is still hurt: foes standing of how many, the share of its hit points left, whole again at. */
  lairWounds?: { standing: number; total: number; hpShare: number; healedAt: string } | null;
  /** A great monster standing here (a lair here is hidden while it is). */
  boss: BossView | null;
}

export interface ExpeditionSummary {
  id: string;
  kind: "attack" | "move";
  from: string;
  to: string;
  party: number;
  setOutAt: string;
  arriveAt: string;
  status: "walking" | "done";
  /** Filled in when it arrived. */
  outcome: null | {
    won: boolean;
    /** cleared: a lair beaten; taken: a player's cell won; settled: moved in; held: the defenders held; back: nothing to do there. */
    cell: "cleared" | "taken" | "settled" | "held" | "back";
    against: string;
    loot: Record<string, number>;
    xp: number;
    fallen: number;
    killed: number;
    /** Damage done to a great monster. */
    damage?: number;
  };
  /** Whether this camp was the one attacked (a report of someone else's expedition against it). */
  defending?: boolean;
}

/** `GET /api/world/expeditions/:id`: everything, with the blow-by-blow for playing it back. */
export interface ExpeditionReport extends ExpeditionSummary {
  attacker: WorldOwner;
  defender: WorldOwner | null;
  lair: LairView | null;
  boss?: { kind: string; name: string; hpBefore: number; hpAfter: number; maxHp: number; defeated: boolean };
  /** Fighter ids: residents by number; lair foes `<cell>#<n>`; a defending player's residents `d<number>`. */
  fighters: { id: string; name: string; side: "attack" | "defend"; hp: number; race?: string; breed?: string; foe?: string }[];
  events: BattleEvent[];
  fallen: { attack: string[]; defend: string[] };
}

/** `GET /api/world`: this account's standing in the big world. */
export interface WorldMe {
  open: boolean;
  /** The camp may open the big world (it has had its race's third look). */
  canOpen: boolean;
  unlockPeak: number;
  peak: number;
  shielded: boolean;
  /** Where the camp stands: everybody at home lives and defends there. */
  homeCell: string | null;
  home: { lat: number; lng: number } | null;
  /** When the camp may move again (null: now). */
  homeMoveAt: string | null;
  xp: number;
  level: number;
  nextLevelXp: number;
  cells: {
    cell: string;
    garrison: number;
    nest: "none" | "building" | "ready";
    town: boolean;
    terrain: Terrain;
    nextYieldAt: string;
    /** It eats rations every yield (beyond the free cells). */
    upkeep: boolean;
    /** How many held cells are joined to it side by side (itself included): a town needs TOWN_MIN_CELLS. */
    region: number;
    /** Parties setting out from it may be this many bigger, and walk this share of the time (its building). */
    party: number;
    travel: number;
  }[];
  /** At home, free to go (not on an expedition). */
  atHome: number;
  /** Holding many cells eats rations (holdings.ts): how many cells pay, how many rations every yield, how many are in the store. */
  upkeep: { paying: number; perYield: number; rations: number; freeCells: number };
  /** How many may go on one expedition now (by race and level), before rations. */
  partyCap: number;
  /** The food in the store for expeditions (supplies.ts), by id. */
  food: Record<string, number>;
  walking: ExpeditionSummary[];
  recent: ExpeditionSummary[];
  /** What happened in the big world lately (a lair coming back for a cell, a great monster's spoils, what the cells gave), newest first. */
  happenings: {
    at: string;
    lairBack?: { cell: string; name: string; level: number; held: boolean; fallen: number; killed: number; loot: Record<string, number>; helped?: number };
    bossReward?: { name: string; loot: Record<string, number>; xp: number; share: number };
    yields?: Record<string, number>;
  }[];
  /** The great monsters out now near the camp (the nearest few), to go and look at. */
  bosses: { cell: string; kind: string; name: string; lat: number; lng: number; km: number; hp: number; maxHp: number; endsAt: string }[];
  rules: { garrisonMin: number; cellCapacity: number; nestCost: Record<string, number>; nestHours: number; nestBirthMinutes: number; townCost: Record<string, number>; townMinCells: number };
}

/** One thing that happened on a held cell (newest first in `CellDetail.history`). */
export interface CellHappening {
  at: string;
  /** yield: the ground gave; lairBack: the lair came back for it; attacked: another camp came; settled: a party moved in or took it; nest / town: built; recalled: some walked home. */
  kind: "yield" | "lairBack" | "attacked" | "settled" | "nest" | "town" | "recalled" | "built" | "demolished";
  loot?: Record<string, number>;
  held?: boolean;
  /** A yield eaten short: there were not rations enough to keep it. */
  hungry?: boolean;
  /** Came from the held cells next to it to help defend it. */
  helped?: number;
  fallen?: number;
  killed?: number;
  by?: string;
  name?: string;
  residents?: number;
  expedition?: string;
}

/** `GET /api/world/cells/:cell`: a cell of one's own, looked at from inside (its residents are the camp's, place `cell:<id>`). */
export interface CellDetail {
  cell: string;
  lat: number;
  lng: number;
  terrain: Terrain;
  /** The camp's own cell (everybody at home lives there: see the camp page). */
  home: boolean;
  town: boolean;
  garrison: number;
  capacity: number;
  garrisonMin: number;
  nest: "none" | "building" | "ready";
  /** When a nest being built is done. */
  nestReadyAt: string | null;
  /** The nest's next birth (null: no nest yet, or the cell is full). */
  nextBirthAt: string | null;
  birthMinutes: number | null;
  heldSince: string | null;
  nextYieldAt: string;
  /** What the ground may give every YIELD_HOURS (material ids). */
  yields: string[];
  /** What is built on it, and what may be (two kinds for each ground; raising costs the same for every kind). */
  building: { kind: string; name: string; blurb: string; level: number; working: number; busyUntil: string | null } | null;
  canBuild: { kind: string; name: string; blurb: string }[];
  /** What building it (level 1) or raising it to the next level costs, and takes (null: at the top). */
  nextCost: Record<string, number> | null;
  nextHours: number | null;
  /** What the cell gets now from what is on it. */
  bonus: CellBonus;
  /** The real place standing in it, and what it does for the holder. */
  landmark: (Landmark & { icon: string; label: string; blurb: string }) | null;
  /** One of the holder's temples is next to it. */
  templeNear: boolean;
  /** Held cells next to it (they add to its yield, and send help when it is fought over), and how many are joined to it. */
  neighbours: number;
  region: number;
  /** Whether it eats rations (beyond the free cells), and how the store stands against all that do. */
  upkeep: { pays: boolean; paying: number; rations: number; freeCells: number; perYield: number };
  history: CellHappening[];
}

/** `POST /api/world/cells/:cell/build`: build a kind on the cell, or raise the one there (the same kind) a level. */
export const buildInput = z.object({ kind: z.string().max(40) });
