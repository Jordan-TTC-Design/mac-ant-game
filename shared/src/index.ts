import { z } from "zod";

export * from "./auth.ts";
export * from "./claude.ts";
export * from "./feedback.ts";
export * from "./friends.ts";
export * from "./guild.ts";
export * from "./guild-hall.ts";
export * from "./guild-decor.ts";
export * from "./notes.ts";
export * from "./pomodoro.ts";

/** Bumped when the API changes in a way older apps cannot follow. */
export const API_VERSION = 1;

/** `GET /api/health`: whether the server and its database are up. */
export const healthSchema = z.object({
  ok: z.boolean(),
  db: z.enum(["ok", "down"]),
  apiVersion: z.number().int(),
});
export type Health = z.infer<typeof healthSchema>;
