import { z } from "zod";

const schema = z.object({
  DATABASE_URL: z.url(),
  PORT: z.coerce.number().int().positive().default(8787),
  /** Where the PWA lives; the links in the emails point there, and cookie requests must come from it. */
  APP_URL: z.url().default("http://localhost:3000"),
  /** Behind Caddy: take the visitor's address from X-Forwarded-For (never set this when the server faces the internet directly). */
  TRUST_PROXY: z
    .enum(["true", "false"])
    .default("false")
    .transform((v) => v === "true"),
});

export type Config = z.infer<typeof schema>;

/** Reads the settings from the environment and stops with a clear message if one is missing or wrong. */
export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const parsed = schema.safeParse(env);
  if (!parsed.success) {
    const problems = parsed.error.issues.map((i) => `${i.path.join(".")}: ${i.message}`).join("; ");
    throw new Error(`Bad server settings (see server/.env.example): ${problems}`);
  }
  return parsed.data;
}
