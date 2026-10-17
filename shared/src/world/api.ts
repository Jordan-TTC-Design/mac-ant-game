/**
 * The big world's API (server/WORLD.md §15). The server keeps the camp (server/CAMP.md), so a device never sends numbers
 * about its residents: it names them (or asks for a count and the server picks), and the server looks up who they are.
 */
import { z } from "zod";
import type { BattleEvent } from "./battle.ts";
import type { Terrain } from "./contents.ts";
import type { TerrainDetail } from "./details.ts";
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
    /** To a friend's cell: stay there as guests and help guard it (holdings.ts GUESTS_MAX). */
    guard: z.boolean().default(false),
    /** Food taken along (supplies.ts): rations let more go, the rest make the party stronger. */
    supplies: z.record(z.string().max(40), z.number().int().min(0).max(60)).optional(),
    /** 劫掠 (talents.ts plunder): against another camp's cell, take from its store and leave (the cell is not taken). */
    plunder: z.boolean().default(false),
  })
  .refine((v) => v.residents || v.count, "residents or count");
export type ExpeditionInput = z.infer<typeof expeditionInput>;

export const routeInput = z.object({ from: z.union([z.literal("home"), cell]).default("home"), to: cell });

/** The way a party would walk (POST world/expeditions/route): round other camps' built-up land (route.ts). */
export interface RoutePreview {
  /** The cells walked between, or empty when there is no way round. */
  waypoints: string[];
  meters: number;
  straight: number;
  /** When there is no way: the first cell in the way and whose it is. */
  blockedBy: { cell: string; name: string } | null;
}

/**
 * `POST /api/world/cells/:cell/recall`: residents on a held cell (or, with `campers`, those camping beside it) walk to the camp
 * or to another held cell (`to`: "home" or a cell). No count, or too few left behind: all go and the cell is given up.
 */
export const recallInput = z.object({
  count: z.number().int().min(1).max(500).optional(),
  to: z.string().max(40).optional(),
  campers: z.boolean().optional(),
});

export const battleEventSchema = z.object({
  round: z.number().int(),
  actor: z.string(),
  target: z.string(),
  kind: z.enum(["hit", "miss", "heal", "down", "rage"]),
  amount: z.number().optional(),
});

export interface WorldOwner {
  id: string;
  name: string;
  race: string;
  /** Its race level, where the map shows it (its camp's building grows with it). */
  level?: number;
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
  /** A 初期魔王's lair (contents.ts): rare, tough, and it leaves the middle gear's makings. */
  boss?: boolean;
  /** The race level a camp needs to take it on (the middle band of lairs: contents.ts MID_RACE_LEVELS, MID_BOSS_RACE_LEVEL). */
  minRaceLevel?: number;
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
  /** Its 細分地形 (details.ts), if any: it changes what the ground gives and which rarer lairs stand there (lairAt). */
  detail?: TerrainDetail | null;
  owner: WorldOwner | null;
  garrison: number;
  nest: "none" | "building" | "ready";
  town: boolean;
  /** Its holder's home camp stands here (the map draws the camp with the race's flag). */
  home?: boolean;
  /** A real place standing in it (holdings.ts). */
  landmark?: Landmark | null;
  /** Friends' residents guarding it. */
  guests?: number;
  /** What its holder built on it. */
  building?: { kind: string; level: number; busy: boolean } | null;
  lair: LairView | null;
  /** A cleared lair comes back at this time. */
  lairBackAt: string | null;
  /** A lair that beat a party off and is still hurt: foes standing of how many, the share of its hit points left, whole again at. */
  lairWounds?: { standing: number; total: number; hpShare: number; healedAt: string } | null;
  /** A great monster standing here (a lair here is hidden while it is). */
  boss: BossView | null;
  /** Someone else's built-up land the viewer's parties must walk round (route.ts); not sent when it does not. */
  blocks?: boolean;
  /**
   * Others' talents reaching here (not the viewer's own or friends'; not sent when none): ambush, the viewer's parties walking
   * past are shot at (伏擊); blight, a cell of the viewer's here would yield less (腐化大地).
   */
  threats?: ("ambush" | "blight")[];
  /** A meteor lying here, not taken yet (events.ts): the first party to get here takes `loot`; gone at `endsAt`. */
  meteor?: { endsAt: string; loot: Record<string, number> };
}

export interface ExpeditionSummary {
  id: string;
  /**
   * recall: walking back from a cell (WORLD.md §24); reroute: those of a recall who found no room, walking on to a cell with room;
   * retreat: those of a cell that was overrun, falling back to a free cell beside it to settle it.
   */
  kind: "attack" | "move" | "guard" | "recall" | "reroute" | "retreat";
  from: string;
  to: string;
  party: number;
  setOutAt: string;
  arriveAt: string;
  /** The cells it walks between round other camps' land (route.ts); absent: straight there. */
  route?: string[];
  status: "walking" | "done";
  /** Filled in when it arrived. */
  outcome: null | {
    won: boolean;
    /** cleared: a lair beaten; taken: a player's cell won; settled: moved in; held: the defenders held; guarding: staying on a friend's cell; back: nothing to do there. */
    cell: "cleared" | "taken" | "settled" | "held" | "guarding" | "back" | "camping" | "plundered";
    against: string;
    loot: Record<string, number>;
    xp: number;
    fallen: number;
    killed: number;
    /** Damage done to a great monster. */
    damage?: number;
    /**
     * Where it was fought when it was a camp's cell: its home camp, or one of its towns or held cells, named as the holder's
     * workshop names them (城鎮 2, 領地 3); and the real place standing there. Older reports leave it out.
     */
    where?: { kind: "home" | "town" | "cell"; label: string; landmark?: string };
    /** A cell taken: where those of its garrison still standing fell back to (as the holder names it). */
    fled?: { count: number; how: "cell" | "free" | "home"; label: string };
    /** 伏擊: shot at on the way by camps with the talent whose cells it passed (who, and how many of the party fell). */
    ambushed?: { by: string; fallen: number }[];
    /** 戰場復甦: this many of the fallen rose and joined the camp that won. */
    raised?: number;
    /** A meteor lying there, taken first (events.ts). */
    meteor?: Record<string, number>;
  };
  /** Whether this camp was the one attacked (a report of someone else's expedition against it). */
  defending?: boolean;
  /** Who attacked, when `defending`. */
  by?: string;
}

/** Another camp's party on its way to attack: who, how many, to which of this camp's cells (named as its workshop names them), and when. */
export interface IncomingParty {
  id: string;
  by: WorldOwner;
  from: string;
  to: string;
  where: { kind: "home" | "town" | "cell"; label: string; landmark?: string };
  party: number;
  setOutAt: string;
  arriveAt: string;
  route?: string[];
  /** What it is made of, breed → how many (only with the 情報 talent: talents.ts "intel"). */
  breeds?: Record<string, number>;
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
  /** When the shield ends by itself (SHIELD_MAX_HOURS after it began); null when not shielded. */
  shieldEndsAt?: string | null;
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
    /** The towns in that region (one may stand for every TOWN_CELLS_EACH cells). */
    regionTowns: number;
    /** Parties setting out from it may be this many bigger, and walk this share of the time (its building). */
    party: number;
    travel: number;
    /** Most who may live there (all bonuses counted), and how many camp beside it waiting for room. */
    capacity: number;
    camping: number;
  }[];
  /** At home, free to go (not on an expedition). */
  atHome: number;
  /** Where this camp's residents guard friends' cells. */
  guarding: { cell: string; holder: string; count: number }[];
  /** Holding many cells eats rations (holdings.ts): how many cells pay, how many rations every yield, how many are in the store. */
  upkeep: { paying: number; perYield: number; everyHours: number; rations: number; freeCells: number };
  /** How many may go on one expedition now (by race and level), before rations. */
  partyCap: number;
  /** The food in the store for expeditions (supplies.ts), by id. */
  food: Record<string, number>;
  walking: ExpeditionSummary[];
  /** Other camps' parties on their way to attack one of this camp's cells (older servers leave it out). */
  incoming?: IncomingParty[];
  /** 種族天賦 (talents.ts): what is bought, the points the race level gives, and what resetting costs now. */
  talents?: { picks: Record<string, number>; points: number; resets: number; resetCost: Record<string, number> };
  /** Held cells beside the camp's own that eat no rations (freeCellsFor + talents). */
  freeCells?: number;
  /** 月光傳送 (talents.ts moonGate): moves between its towns left today; absent without the talent. */
  moonGatesLeft?: number;
  /** The season on now (events.ts SEASONS), and when it ends. */
  season?: { id: string; name: string; icon: string; blurb: string; endsAt: string } | null;
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
  rules: { garrisonMin: number; cellCapacity: number; nestCost: Record<string, number>; nestHours: number; nestBirthMinutes: number; townCost: Record<string, number>; townMinCells: number; townCellsEach: number };
}

/** One thing that happened on a held cell (newest first in `CellDetail.history`). */
export interface CellHappening {
  at: string;
  /**
   * yield: the ground gave; lairBack: the lair came back for it; incoming: another camp's party set out for it; attacked:
   * another camp came; settled: a party moved in or took it; nest / town: built; recalled: some walked home.
   */
  kind: "yield" | "lairBack" | "incoming" | "attacked" | "settled" | "nest" | "town" | "recalled" | "built" | "demolished" | "guests" | "staffed" | "raided";
  /** Auto staffing: those it sent walking home (with `residents` 0), and the number it keeps it at. */
  back?: number;
  target?: number;
  loot?: Record<string, number>;
  held?: boolean;
  /** A yield eaten short: there were not rations enough to keep it. */
  hungry?: boolean;
  /** Came from the held cells next to it to help defend it. */
  helped?: number;
  /** Friends guarding it who fought. */
  guests?: number;
  fallen?: number;
  killed?: number;
  by?: string;
  name?: string;
  residents?: number;
  expedition?: string;
}

/** `GET /api/world/cells/:cell`: a cell of one's own, looked at from inside (its residents are the camp's, place `cell:<id>`). */
export interface CellDetail {
  /** Its 細分地形 (details.ts), if any. */
  detail?: TerrainDetail | null;
  /** 腐化大地: another camp's cell next to it blights it (it yields less). */
  blighted?: boolean;
  /** The building is at the top its holder's race level allows, but a higher level opens at this race level. */
  nextNeedsLevel?: number;
  /** A town's market: how many swaps are left today (MARKET_TRADES_PER_DAY); absent on a cell that is not a town. */
  market?: { left: number };
  /** How many its holder wants living here (null: as it comes); the camp sends more or calls the rest home (auto staffing). */
  target?: number | null;
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
  /** The towns in its region, and the room they add to this cell (counted in `capacity`; at most TOWN_ROOM_MAX towns count). */
  regionTowns: number;
  townRoom: number;
  /** The holder's residents camping beside it, waiting for room (they help defend it and move in as room frees up). */
  camping: number;
  /** Friends' residents guarding it, by friend. */
  guests: { owner: string; name: string; count: number }[];
  /** Whether it eats rations (beyond the free cells), and how the store stands against all that do. */
  upkeep: { pays: boolean; paying: number; rations: number; freeCells: number; perYield: number; everyHours: number };
  history: CellHappening[];
}

/** `POST /api/world/cells/:cell/build`: build a kind on the cell, or raise the one there (the same kind) a level. */
export const buildInput = z.object({ kind: z.string().max(40) });

/** `POST /api/world/talents`: the talents wanted (all of them: more ranks only, nothing taken back but by a reset). */
export const talentsInput = z.object({ picks: z.record(z.string().max(60), z.number().int().min(0).max(5)) });

/** `POST /api/world/cells/:cell/target`: how many should live on a held cell (null: as it comes); the camp keeps it so by itself. */
export const targetInput = z.object({ target: z.number().int().min(1).max(500).nullable() });

/** `POST /api/world/cells/:cell/market`: `count` of `give` swapped at the town's market for `get` (holdings.ts marketQuote). */
export const marketInput = z.object({ give: z.string().max(40), count: z.number().int().min(1).max(10_000), get: z.string().max(40) });

/** `GET /api/world/landmarks?lat=&lng=`: the landmarks around a point (holdings.ts), the nearest first, and who holds each. */
export interface NearbyLandmark {
  cell: string;
  lat: number;
  lng: number;
  kind: string;
  name: string;
  /** From the point asked about. */
  km: number;
  owner: WorldOwner | null;
}

/** `GET /api/world/search?q=&lat=&lng=`: places by name (OpenStreetMap), those near the point favoured. */
export interface PlaceFound {
  name: string;
  /** The rest of the address (district, city…). */
  where: string;
  lat: number;
  lng: number;
  cell: string;
  /** From the point asked about (none given: null). */
  km: number | null;
}

/** One held cell as the territory list shows it (`GET /api/world/territory`). */
export interface TerritoryItem {
  cell: string;
  lat: number;
  lng: number;
  terrain: Terrain;
  detail?: TerrainDetail | null;
  /** The camp's own cell. */
  home: boolean;
  town: boolean;
  garrison: number;
  capacity: number;
  nest: "none" | "building" | "ready";
  building: { kind: string; name: string; level: number; busy: boolean } | null;
  landmark: (Landmark & { icon: string; label: string }) | null;
  /** Held cells joined to it (itself included), and next to it. */
  region: number;
  neighbours: number;
  /** The room the towns of its region add (counted in `capacity`). */
  townRoom: number;
  /** Residents camping beside it, waiting for room. */
  camping: number;
  /** It eats rations every yield. */
  upkeep: boolean;
  /** Friends' residents guarding it. */
  guests: number;
  nextYieldAt: string;
  heldSince: string | null;
}

export interface TerritoryList {
  items: TerritoryItem[];
  /** Everybody living on the cells (the camp's own cell: those at home), rations in the store and how many cells eat them. */
  residents: number;
  rations: number;
  paying: number;
}
