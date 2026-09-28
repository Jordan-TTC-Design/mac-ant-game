// pnpm admin grant <email>    make an account an admin (後台); the account must exist (register first)
// pnpm admin revoke <email>   make it an ordinary account again
// pnpm admin list             who the admins are
import { eq } from "drizzle-orm";
import { loadConfig } from "../config.ts";
import { createDatabase } from "../db/client.ts";
import { runMigrations } from "../db/migrate.ts";
import { adminLog, users } from "../db/schema.ts";

const [command, email] = process.argv.slice(2);
const database = createDatabase(loadConfig().DATABASE_URL);
try {
  await runMigrations(database);
  const { db } = database;
  if ((command === "grant" || command === "revoke") && email) {
    const [user] = await db.select().from(users).where(eq(users.email, email));
    if (!user) {
      console.log(`沒有 ${email} 這個帳號：請先用這個信箱註冊（make invite 產生邀請碼給自己）。`);
      process.exitCode = 1;
    } else {
      const role = command === "grant" ? "admin" : "user";
      await db.update(users).set({ role }).where(eq(users.id, user.id));
      await db.insert(adminLog).values({ adminId: null, targetId: user.id, action: "role", detail: { role, by: "command line" } });
      console.log(role === "admin" ? `${email} 現在是管理員了：登入手機網頁 →「設定」→「後台」。` : `${email} 不再是管理員。`);
    }
  } else if (command === "list") {
    const admins = await db.select({ email: users.email, name: users.displayName }).from(users).where(eq(users.role, "admin"));
    console.log(admins.length ? admins.map((a) => `  ${a.email}（${a.name}）`).join("\n") : "還沒有管理員。");
  } else {
    console.log("用法：pnpm admin grant <信箱>　｜　pnpm admin revoke <信箱>　｜　pnpm admin list");
    process.exitCode = 1;
  }
} finally {
  await database.close();
}
