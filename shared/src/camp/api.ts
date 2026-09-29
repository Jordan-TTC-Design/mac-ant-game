import { z } from "zod";
import { FOODS, SOULS } from "./food.ts";
import { GEAR_SLOTS } from "./gear.ts";
import { RACES } from "./races.ts";

/** `POST /api/camp/start`: a new camp (for an account that has none). */
export const startCampInput = z.object({ race: z.enum(RACES) });

const count = z.number().int().min(0).max(1_000_000);
/** A piece as the Mac saves it: just the id (older saves), or the id and the wear points it has left (0 … its durability). */
const savedGear = z.union([z.string().max(40), z.object({ id: z.string().max(40), left: z.number().min(0).max(100_000).nullish() })]);

/**
 * `POST /api/camp/migrate`: a Mac moving its old camp (state.json) in. The fields are the Mac's `SavedState` as it is; the
 * server keeps what it may (server/CAMP.md §6). A resident's 64-bit seed must come as a string (JSON numbers lose digits).
 */
export const migrateInput = z.object({
  race: z.enum(RACES),
  /** An account that has a camp already: true replaces it (the Mac asks first), false answers 409. */
  replace: z.boolean().default(false),
  save: z.object({
    goblins: z
      .array(
        z.object({
          id: z.number().int().min(1).max(10_000_000),
          breed: z.string().min(1).max(20),
          age: z.number().min(0).max(1e9),
          seed: z.union([z.string().regex(/^\d{1,20}$/), z.number().int().min(0)]),
          name: z.string().max(40).nullish(),
          gear: z.record(z.string().max(20), savedGear).nullish(),
          parents: z.string().max(80).nullish(),
        }),
      )
      .max(5000)
      .default([]),
    princessName: z.string().max(40).nullish(),
    materials: z.record(z.string().max(40), count).nullish(),
    kills: z.record(z.string().max(40), count).nullish(),
    peak: count.nullish(),
    larder: z.record(z.string().max(40), count).nullish(),
    armory: z.record(z.string().max(40), count).nullish(),
    armoryItems: z.array(savedGear).max(5000).nullish(),
    romance: z.unknown().optional(),
    delivered: count.nullish(),
  }),
});
export type MigrateInput = z.infer<typeof migrateInput>;

/**
 * A number the device gives a command, so sending it again (a dropped connection, a queue sent twice) does it only once:
 * a command whose requestId the server has done answers as it did then.
 */
const requestId = z.uuid().optional();

/** `POST /api/camp/commands`: one thing the player does. The server checks it against the books (server/CAMP.md §3.3). */
export const campCommand = z.discriminatedUnion("kind", [
  /** The workshop makes a piece; it goes to `to` (a resident at home, by hand: pinned), or else to whoever needs it most. */
  z.object({ requestId, kind: z.literal("craft"), gear: z.string().max(40), to: z.number().int().min(1).optional() }),
  /** Puts a piece from the store (`stock`, its place in the list; `gear` checks it is the one meant) on a resident by hand. */
  z.object({ requestId, kind: z.literal("equip"), resident: z.number().int(), stock: z.number().int().min(0), gear: z.string().max(40) }),
  /** Takes a resident's piece off by hand: it goes to the store, held. */
  z.object({ requestId, kind: z.literal("unequip"), resident: z.number().int(), slot: z.enum(GEAR_SLOTS) }),
  /** Holds a piece in the store (the handing out leaves it be) or lets it go again. */
  z.object({ requestId, kind: z.literal("gear-hold"), stock: z.number().int().min(0), gear: z.string().max(40), held: z.boolean() }),
  /** Turns the handing out of the store on or off for the camp. */
  z.object({ requestId, kind: z.literal("auto-gear"), on: z.boolean() }),
  /** Mends a piece a resident wears (`resident` + `slot`) or one in the store (`stock`, its place in the list). */
  z.object({ requestId, kind: z.literal("repair"), resident: z.number().int().optional(), slot: z.enum(GEAR_SLOTS).optional(), stock: z.number().int().min(0).optional() }),
  /** Puts a food (or, for the undead, a soul) down. */
  z.object({ requestId, kind: z.literal("food"), food: z.enum([...FOODS, ...SOULS]) }),
  z.object({ requestId, kind: z.literal("princess-name"), name: z.string().trim().min(1).max(8) }),
  /** The princess had a child (her story runs on the Mac): it joins the camp. At most one every PRINCESS_CHILD_HOURS. */
  z.object({ requestId, kind: z.literal("princess-child"), breed: z.enum(["half_gob", "half_mix", "half_hum"]), parents: z.string().max(80).default("") }),
  /** The princess's story as the Mac has it now (kept as it is; it does not count for the ranking). */
  z.object({ requestId, kind: z.literal("story"), romance: z.unknown() }),
  /** Builds a site on a free plot (its cost is taken now; it works once built: sites.ts). */
  z.object({ requestId, kind: z.literal("site-build"), site: z.enum(["lumber", "quarry", "mine", "traps", "fishery", "hunter", "scrapyard", "grove", "soulwell"]) }),
  /** Raises a site a level (it goes on working meanwhile). */
  z.object({ requestId, kind: z.literal("site-upgrade"), site: z.number().int().min(1) }),
  /** Takes a site down (not the farm): the plot is free at once, half of what it cost comes back. */
  z.object({ requestId, kind: z.literal("site-demolish"), site: z.number().int().min(1) }),
  /** Takes a finished 任務's reward (camp/quests.ts). */
  z.object({ requestId, kind: z.literal("quest-claim"), quest: z.string().max(40) }),
  /** Raises the farm a level (the same as site-upgrade on the farm). */
  z.object({ requestId, kind: z.literal("farm-upgrade") }),
]);
export type CampCommand = z.infer<typeof campCommand>;

/** The princess's children come at most this often (her story on the Mac takes longer than that anyway). */
export const PRINCESS_CHILD_HOURS = 4;

export interface CampResidentView {
  id: number;
  breed: string;
  seed: number;
  legacySeed: string | null;
  name: string | null;
  parents: string | null;
  bornAt: string;
  diesAt: string | null;
  /** What it wears (`pinned`: put on by hand, the handing out leaves it be). */
  gear: Record<string, { id: string; left: number; pinned?: boolean }> | null;
  place: string;
}

/** `GET /api/camp`: the books as they are now (advanced to this moment first). */
export interface CampView {
  race: string;
  /** What a Mac needs to work births and deaths out itself while offline (shared/src/camp/population.ts). */
  seed: number;
  startedAt: string;
  advancedTo: string;
  nextSlot: number;
  nextId: number;
  peak: number;
  stage: 1 | 2 | 3;
  version: number;
  materials: Record<string, number>;
  larder: Record<string, number>;
  /** The store (`held`: taken off by hand, not handed out). */
  armory: { id: string; left: number; held?: boolean }[];
  /** Whether the store is handed out by itself (off: only by hand). Older servers leave it out (on). */
  autoGear?: boolean;
  /** 任務 whose reward was taken (camp/quests.ts): some open a 道具's recipe. */
  questsDone?: string[];
  boosts: Record<string, string>;
  foodCooldowns: Record<string, string>;
  princessName: string;
  romance: unknown;
  kills: Record<string, number>;
  delivered: number;
  /** 聖光模式 (server/CAMP.md §7): on since (null: off), and when it may be turned on again (null: now). */
  sanctuary: { since: string | null; canTurnOnAt: string | null };
  /** The camp's sites and what they make (server/FARM.md §11). Older servers leave it out. */
  production?: CampProduction;
  /** Everyone alive (at home and, later, in the big world). */
  residents: CampResidentView[];
}

/** The camp's sites, as the devices show them (shared/src/camp/sites.ts; the server does the sums). */
export interface CampProduction {
  /** Plots of ground, and how many have a site. */
  slots: number;
  used: number;
  /** Residents at home, the hands the sites need, and the share they get (0…1: every site works that fast). */
  workers: number;
  need: number;
  share: number;
  /** What the camp makes an hour now (the finds: their chance an hour). */
  perHour: Record<string, number>;
  /** A site being built or raised (one at a time), or null. */
  busy: { site: number; until: string } | null;
  sites: CampSiteView[];
  /** What may be built on a free plot. */
  buildable: { kind: string; name: string; cost: Record<string, number>; hours: number; makes: Record<string, number> }[];
}

export interface CampSiteView {
  id: number;
  kind: string;
  name: string;
  /** 0: still being built. */
  level: number;
  maxLevel: number;
  /** The farm: what each level added (菜園, 麥田, …). */
  parts?: string[];
  /** What it makes an hour with every hand at its level (the finds: their chance). */
  makes: Record<string, number>;
  busyUntil: string | null;
  /** The next level (null: at the top). */
  next: { level: number; cost: Record<string, number>; hours: number; makes: Record<string, number> } | null;
  /** What taking it down gives back (null: it cannot be, the farm). */
  refund: Record<string, number> | null;
}

export interface CampEvent {
  seq: number;
  at: string;
  kind: "started" | "migrated" | "population" | "raid" | "command" | "expedition" | "world" | "site";
  data: unknown;
}

/** `GET /api/camp/raids`: the latest monster raids, newest first, without the blow-by-blow (for the phone's report). */
export interface RaidReport {
  seq: number;
  at: string;
  monsters: { id: string; count: number }[];
  defenders: number;
  /** The residents who fell (their breed as they were). */
  fallen: { id: number; breed: string; name: string | null }[];
  killed: Record<string, number>;
  loot: Record<string, number>;
  broken: { resident: number; gear: string }[];
  winner: "camp" | "monsters";
}

/** `POST /api/camp/sanctuary`: 聖光模式 on or off. */
export const sanctuaryInput = z.object({ on: z.boolean() });

/** One 任務 as the phone shows it (`GET /api/camp/quests`). */
export interface QuestView {
  id: string;
  chapter: string;
  title: string;
  text: string;
  have: number;
  need: number;
  done: boolean;
  claimed: boolean;
  reward: { materials?: Record<string, number>; gear?: string[]; residents?: number };
  /** The 道具 whose recipe it opens. */
  unlocks?: string;
}
