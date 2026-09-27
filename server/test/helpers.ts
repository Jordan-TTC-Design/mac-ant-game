import type { DeviceInput } from "@goblincamp/shared";
import { createApp } from "../src/app.ts";
import { createDatabase, type Database } from "../src/db/client.ts";
import { runMigrations } from "../src/db/migrate.ts";
import { invites } from "../src/db/schema.ts";
import { RateLimiter } from "../src/lib/rate-limit.ts";
import { hashSecret, newInviteCode, normalizeCode } from "../src/lib/tokens.ts";
import { MemoryMailer } from "../src/mail/mailer.ts";
import { MemoryPushSender } from "../src/push/sender.ts";

// The test database from compose.dev.yml (`pnpm db:up`); never the development one.
const url = process.env.TEST_DATABASE_URL ?? "postgres://goblin:goblin@localhost:5433/goblin_test";
export const APP_URL = "http://localhost:3000";

export async function openTestDatabase(): Promise<Database> {
  const database = createDatabase(url);
  await runMigrations(database);
  return database;
}

export async function emptyTables(database: Database) {
  await database.sql`truncate users, devices, sessions, email_tokens, invites, notes, camps, camp_residents, camp_events cascade`;
}

/** An app with its own clock, mailbox and rate limits, plus shortcuts for requests. */
export function testApp(database: Database) {
  const mailer = new MemoryMailer();
  const push = new MemoryPushSender();
  let clock = new Date("2026-10-01T09:00:00Z");
  const app = createApp({
    database,
    mailer,
    push,
    config: { APP_URL, TRUST_PROXY: false },
    now: () => clock,
    limiter: new RateLimiter(() => clock.getTime()),
  });

  async function call(method: string, path: string, body?: unknown, headers: Record<string, string> = {}) {
    const res = await app.request(`/api${path}`, {
      method,
      headers: body === undefined ? headers : { "content-type": "application/json", ...headers },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await res.text();
    return { status: res.status, body: text ? JSON.parse(text) : null, headers: res.headers };
  }

  return {
    app,
    mailer,
    push,
    call,
    now: () => clock,
    /** Moves the clock forward. */
    advance(ms: number) {
      clock = new Date(clock.getTime() + ms);
    },
    /** The token in the link of the newest mail to `to`. */
    tokenFromMail(to: string): string {
      const text = mailer.last(to)?.text ?? "";
      const match = text.match(/token=([^\s]+)/);
      if (!match?.[1]) throw new Error(`no link in the mail to ${to}: ${text}`);
      return decodeURIComponent(match[1]);
    },
    async invite(days = 14): Promise<string> {
      const code = newInviteCode();
      await database.db.insert(invites).values({ codeHash: hashSecret(normalizeCode(code)), expiresAt: new Date(clock.getTime() + days * 86_400_000) });
      return code;
    },
  };
}

export type TestApp = ReturnType<typeof testApp>;

export const mac = (n = 1) => ({ id: `00000000-0000-4000-8000-00000000000${n}`, kind: "mac" as const, name: `Mac ${n}` });
export const phone = { id: "00000000-0000-4000-8000-0000000000aa", kind: "pwa" as const, name: "iPhone" };

/** Registers, confirms the address and returns the password used. */
export async function signUp(t: TestApp, email: string, password = "correct horse battery") {
  const reg = await t.call("POST", "/auth/register", { email, password, displayName: "咕嚕", inviteCode: await t.invite() });
  if (reg.status !== 202) throw new Error(`register: ${reg.status} ${JSON.stringify(reg.body)}`);
  const verify = await t.call("POST", "/auth/verify-email", { token: t.tokenFromMail(email) });
  if (verify.status !== 200) throw new Error(`verify: ${verify.status}`);
  return password;
}

export async function logIn(t: TestApp, email: string, password: string, device: DeviceInput = mac()) {
  const res = await t.call("POST", "/auth/login", { email, password, device });
  if (res.status !== 200) throw new Error(`login: ${res.status} ${JSON.stringify(res.body)}`);
  return res;
}

export const bearer = (token: string) => ({ authorization: `Bearer ${token}` });
