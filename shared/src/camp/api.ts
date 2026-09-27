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

/** `POST /api/camp/commands`: one thing the player does. The server checks it against the books (server/CAMP.md §3.3). */
export const campCommand = z.discriminatedUnion("kind", [
  /** The workshop makes a piece; it goes to whoever needs it most. */
  z.object({ kind: z.literal("craft"), gear: z.string().max(40) }),
  /** Mends a piece a resident wears (`resident` + `slot`) or one in the store (`stock`, its place in the list). */
  z.object({ kind: z.literal("repair"), resident: z.number().int().optional(), slot: z.enum(GEAR_SLOTS).optional(), stock: z.number().int().min(0).optional() }),
  /** Puts a food (or, for the undead, a soul) down. */
  z.object({ kind: z.literal("food"), food: z.enum([...FOODS, ...SOULS]) }),
  z.object({ kind: z.literal("princess-name"), name: z.string().trim().min(1).max(8) }),
  /** The princess had a child (her story runs on the Mac): it joins the camp. At most one every PRINCESS_CHILD_HOURS. */
  z.object({ kind: z.literal("princess-child"), breed: z.enum(["half_gob", "half_mix", "half_hum"]), parents: z.string().max(80).default("") }),
  /** The princess's story as the Mac has it now (kept as it is; it does not count for the ranking). */
  z.object({ kind: z.literal("story"), romance: z.unknown() }),
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
  gear: Record<string, { id: string; left: number }> | null;
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
  armory: { id: string; left: number }[];
  boosts: Record<string, string>;
  foodCooldowns: Record<string, string>;
  princessName: string;
  romance: unknown;
  kills: Record<string, number>;
  delivered: number;
  /** Everyone alive (at home and, later, in the big world). */
  residents: CampResidentView[];
}

export interface CampEvent {
  seq: number;
  at: string;
  kind: "started" | "migrated" | "population" | "raid" | "command";
  data: unknown;
}
