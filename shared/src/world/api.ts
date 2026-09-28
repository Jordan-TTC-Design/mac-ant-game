/**
 * The big world's API (server/WORLD.md §15). The server keeps the camp (server/CAMP.md), so a device never sends numbers
 * about its residents: it names them (or asks for a count and the server picks), and the server looks up who they are.
 */
import { z } from "zod";
import type { BattleEvent } from "./battle.ts";
import type { Terrain } from "./contents.ts";
import { isCellId } from "./grid.ts";

/** The one world everybody shares. */
export const WORLD_SEED = 20_260_927;

const cell = z.string().refine(isCellId, "not a cell id");
/** Residents by number (the camp's resident ids). */
const residentIds = z.array(z.number().int().min(1)).min(1).max(60);

/**
 * `POST /api/world/open`: open the big world. The first time, pick the camp's cell on the map and how many residents move
 * there to hold it; after a defeat (turtling), open again with no body to end the protection.
 */
export const openWorldInput = z.object({
  cell: cell.optional(),
  settlers: z.number().int().min(1).max(100).optional(),
});

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
  lair: LairView | null;
  /** A cleared lair comes back at this time. */
  lairBackAt: string | null;
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
  homeCell: string | null;
  home: { lat: number; lng: number } | null;
  xp: number;
  level: number;
  nextLevelXp: number;
  cells: { cell: string; garrison: number; nest: "none" | "building" | "ready"; town: boolean; terrain: Terrain; nextYieldAt: string }[];
  /** At home, free to go (not on an expedition). */
  atHome: number;
  walking: ExpeditionSummary[];
  recent: ExpeditionSummary[];
  /** What happened in the big world lately (a lair coming back for a cell, a great monster's spoils, what the cells gave), newest first. */
  happenings: {
    at: string;
    lairBack?: { cell: string; name: string; level: number; held: boolean; fallen: number; killed: number; loot: Record<string, number> };
    bossReward?: { name: string; loot: Record<string, number>; xp: number; share: number };
    yields?: Record<string, number>;
  }[];
  /** The great monsters out now near the camp (the nearest few), to go and look at. */
  bosses: { cell: string; kind: string; name: string; lat: number; lng: number; km: number; hp: number; maxHp: number; endsAt: string }[];
  rules: { garrisonMin: number; cellCapacity: number; nestCost: Record<string, number>; nestHours: number; nestBirthMinutes: number; townCost: Record<string, number>; townMinCells: number };
}
