// A ready-to-play account on the development database (never the test one, never production), for trying the Mac app and
// the web pages by hand: signed up and confirmed, a camp started, grown past the big world's unlock, and its camp put on
// the map (Taipei by default). Prints the email and password to sign in with.
//
//   cd server && node --import tsx --env-file-if-exists=.env scripts/dev-account.ts [email] [race] [lat,lng]
import { eq, sql } from "drizzle-orm";
import { cellAt, worldUnlockPeak } from "@goblincamp/shared/world";
import { createApp } from "../src/app.ts";
import { createDatabase } from "../src/db/client.ts";
import { runMigrations } from "../src/db/migrate.ts";
import { camps, invites, users } from "../src/db/schema.ts";
import { hashSecret, newInviteCode, normalizeCode } from "../src/lib/tokens.ts";
import { MemoryMailer } from "../src/mail/mailer.ts";
import { NoPushSender } from "../src/push/sender.ts";

const url = process.env.DATABASE_URL ?? "postgres://goblin:goblin@localhost:5433/goblin";
if (!/localhost|127\.0\.0\.1/.test(url) || url.endsWith("_test")) throw new Error(`only the local development database, not ${url}`);
const email = process.argv[2] ?? "dev@example.com";
const race = process.argv[3] ?? "goblin";
const [lat, lng] = (process.argv[4] ?? "25.0330,121.5654").split(",").map(Number) as [number, number];
const password = "correct horse battery";

const database = createDatabase(url);
await runMigrations(database);
const mailer = new MemoryMailer();
const app = createApp({ database, mailer, push: new NoPushSender(), config: { APP_URL: "http://localhost:3000", TRUST_PROXY: false, ADMIN_EMAILS: email } });
async function call(method: string, path: string, body?: unknown, token?: string) {
  const res = await app.request(`/api${path}`, {
    method,
    headers: { ...(body === undefined ? {} : { "content-type": "application/json" }), ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : null };
}

const [existing] = await database.db.select().from(users).where(eq(users.email, email));
if (!existing) {
  const code = newInviteCode();
  await database.db.insert(invites).values({ codeHash: hashSecret(normalizeCode(code)), expiresAt: new Date(Date.now() + 86_400_000) });
  const reg = await call("POST", "/auth/register", { email, password, displayName: "測試哥布林", inviteCode: code });
  if (reg.status !== 202) throw new Error(`register: ${reg.status} ${JSON.stringify(reg.body)}`);
  const token = decodeURIComponent(mailer.last(email)?.text.match(/token=([^\s]+)/)?.[1] ?? "");
  const verify = await call("POST", "/auth/verify-email", { token });
  if (verify.status !== 200) throw new Error(`verify: ${verify.status}`);
}
const login = await call("POST", "/auth/login", { email, password, device: { id: "00000000-0000-4000-8000-0000000000d1", kind: "mac", name: "dev script" } });
if (login.status !== 200) throw new Error(`login: ${login.status} ${JSON.stringify(login.body)}`);
const token: string = login.body.token;

if ((await call("GET", "/camp", undefined, token)).status === 404) {
  const made = await call("POST", "/camp/start", { race }, token);
  if (made.status !== 201) throw new Error(`camp: ${made.status} ${JSON.stringify(made.body)}`);
}
const [me] = await database.db.select().from(users).where(eq(users.email, email));
await database.db.update(camps).set({ peak: sql`greatest(${camps.peak}, ${worldUnlockPeak(race)})` }).where(eq(camps.userId, me!.id));
const world = await call("GET", "/world", undefined, token);
if (!world.body?.homeCell) {
  const opened = await call("POST", "/world/open", { cell: cellAt({ lat, lng }) }, token);
  if (opened.status !== 201) console.warn(`opening the world: ${opened.status} ${JSON.stringify(opened.body)}`);
}
console.log(`ready: ${email} / ${password}`);
await database.close();
