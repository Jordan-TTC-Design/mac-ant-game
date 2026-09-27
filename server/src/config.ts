import { z } from "zod";

const schema = z.object({
  DATABASE_URL: z.string().url(),
  PORT: z.coerce.number().int().positive().default(8787),
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
