/**
 * The shapes the big world's API will use (checked with zod on both ends). No routes exist yet; these fix what the Mac and
 * the server will send each other when they do (WORLD.md §12).
 */
import { z } from "zod";
import { isCellId } from "./grid.ts";

const cell = z.string().refine(isCellId, "not a cell id");
const isoDate = z.iso.datetime({ offset: true });

/** A resident as the Mac reports it (breed stats and what it wears). */
export const residentSchema = z.object({
  id: z.string().min(1).max(40),
  name: z.string().max(30),
  breed: z.string().min(1).max(20),
  might: z.number().min(0).max(10),
  health: z.number().min(0).max(30),
  speed: z.number().min(0).max(5),
  gearAttack: z.number().min(0).max(50).optional(),
  gearReach: z.number().min(0).max(100).optional(),
  gearGuard: z.number().min(0).max(0.6).optional(),
});

/** `POST /api/world/open`: open the big world, picking the first cell (a point the player chose on the map). */
export const openWorldInput = z.object({
  race: z.string().min(1).max(20),
  firstCell: cell,
  settlers: z.array(residentSchema).min(5).max(30),
});

/** `POST /api/world/expeditions`: send a party from a cell (or the camp) to a target cell. */
export const expeditionInput = z.object({
  from: cell,
  to: cell,
  party: z.array(residentSchema).min(1).max(40),
  /** Food boosts on when it sets out (already scaled for the race). */
  boosts: z.object({ meat: z.number().min(0).max(2), cheese: z.number().min(0).max(2), carrot: z.number().min(0).max(2) }).partial().optional(),
});

export const battleEventSchema = z.object({
  round: z.number().int(),
  actor: z.string(),
  target: z.string(),
  kind: z.enum(["hit", "miss", "heal", "down"]),
  amount: z.number().optional(),
});

/** What both sides get when an expedition arrives (the Mac plays `events` back). */
export const expeditionReportSchema = z.object({
  id: z.string(),
  from: cell,
  to: cell,
  setOutAt: isoDate,
  arriveAt: isoDate,
  attacker: z.string(),
  defender: z.string().nullable(),
  lair: z.object({ kind: z.string(), name: z.string(), level: z.number().int() }).nullable(),
  won: z.boolean(),
  cell: z.enum(["cleared", "taken", "held"]),
  loot: z.record(z.string(), z.number().int()),
  events: z.array(battleEventSchema),
  fallen: z.object({ attack: z.array(z.string()), defend: z.array(z.string()) }),
});
export type ExpeditionReport = z.infer<typeof expeditionReportSchema>;

/** `GET /api/world/cells?lat=&lng=&radius=`: what is on the map around a point. */
export const cellViewSchema = z.object({
  cell,
  owner: z.object({ id: z.string(), name: z.string(), race: z.string() }).nullable(),
  garrison: z.number().int(),
  nest: z.boolean(),
  town: z.boolean(),
  lair: z.object({ kind: z.string(), name: z.string(), faction: z.string(), level: z.number().int(), count: z.number().int() }).nullable(),
});
export type CellView = z.infer<typeof cellViewSchema>;
