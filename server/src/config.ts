import { z } from "zod";

const schema = z.object({
  DATABASE_URL: z.url(),
  PORT: z.coerce.number().int().positive().default(8787),
  /** Where the PWA lives; the links in the emails point there, and cookie requests must come from it. */
  APP_URL: z.url().default("http://localhost:3000"),
  /** Behind Caddy: take the visitor's address from X-Forwarded-For (never set this when the server faces the internet directly). */
  /** Web Push (phones): make a pair with `pnpm --filter @goblincamp/server vapid`. Without them phones get no reminders. */
  VAPID_PUBLIC_KEY: z.string().optional().transform((v) => v || undefined),
  VAPID_PRIVATE_KEY: z.string().optional().transform((v) => v || undefined),
  /** Who runs the server, for the push services (mailto: or https:). */
  VAPID_SUBJECT: z.string().default("mailto:admin@goblincamp.invalid"),
  /** Resend for the confirmation and reset mails. Without a key the mails go to the log (`make logs`) instead. */
  RESEND_API_KEY: z.string().optional().transform((v) => v || undefined),
  MAIL_FROM: z.string().default("哥布林營地 <noreply@goblincamp.invalid>"),
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
