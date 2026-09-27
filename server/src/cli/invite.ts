// pnpm invite create [--count N] [--days D]   make invite codes (printed once; only their hashes are kept)
// pnpm invite list                            how many are unused, used and expired
import { and, count, gt, isNotNull, isNull, lte } from "drizzle-orm";
import { loadConfig } from "../config.ts";
import { createDatabase } from "../db/client.ts";
import { runMigrations } from "../db/migrate.ts";
import { invites } from "../db/schema.ts";
import { hashSecret, newInviteCode, normalizeCode } from "../lib/tokens.ts";

const [command, ...rest] = process.argv.slice(2);
function option(name: string, fallback: number): number {
  const i = rest.indexOf(`--${name}`);
  const value = i >= 0 ? Number(rest[i + 1]) : fallback;
  if (!Number.isInteger(value) || value < 1 || value > 1000) throw new Error(`--${name} must be a whole number from 1 to 1000`);
  return value;
}

const database = createDatabase(loadConfig().DATABASE_URL);
try {
  await runMigrations(database);
  const { db } = database;
  if (command === "create") {
    const howMany = option("count", 1);
    const days = option("days", 14);
    const expiresAt = new Date(Date.now() + days * 86_400_000);
    const codes = Array.from({ length: howMany }, newInviteCode);
    await db.insert(invites).values(codes.map((code) => ({ codeHash: hashSecret(normalizeCode(code)), expiresAt })));
    console.log(`${howMany} 組邀請碼，每組只能用一次，${days} 天內有效（${expiresAt.toLocaleString("zh-TW")} 之前）：\n`);
    for (const code of codes) console.log(`  ${code}`);
    console.log("\n只會顯示這一次，請現在複製下來。");
  } else if (command === "list") {
    const now = new Date();
    const [unused] = await db.select({ n: count() }).from(invites).where(and(isNull(invites.usedAt), gt(invites.expiresAt, now)));
    const [used] = await db.select({ n: count() }).from(invites).where(isNotNull(invites.usedAt));
    const [expired] = await db.select({ n: count() }).from(invites).where(and(isNull(invites.usedAt), lte(invites.expiresAt, now)));
    console.log(`可以用：${unused?.n ?? 0}　已使用：${used?.n ?? 0}　過期：${expired?.n ?? 0}`);
  } else {
    console.log("用法：pnpm invite create [--count 數量] [--days 天數]　｜　pnpm invite list");
    process.exitCode = 1;
  }
} finally {
  await database.close();
}
