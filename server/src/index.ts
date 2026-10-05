import { serve } from "@hono/node-server";
import { createApp } from "./app.ts";
import { loadConfig } from "./config.ts";
import { createDatabase } from "./db/client.ts";
import { runMigrations } from "./db/migrate.ts";
import { ConsoleMailer, ResendMailer } from "./mail/mailer.ts";
import { startReminderLoop } from "./push/reminders.ts";
import { NoPushSender, WebPushSender } from "./push/sender.ts";
import { startWorldLoop } from "./world/service.ts";
import { startMaintenance } from "./maintenance.ts";
import { startPomodoroLoop } from "./pomodoro/routes.ts";
import { Backups, pgDump, startBackups } from "./backup.ts";

const config = loadConfig();
const database = createDatabase(config.DATABASE_URL);
await runMigrations(database);

const push =
  config.VAPID_PUBLIC_KEY && config.VAPID_PRIVATE_KEY
    ? new WebPushSender(config.VAPID_PUBLIC_KEY, config.VAPID_PRIVATE_KEY, config.VAPID_SUBJECT)
    : new NoPushSender();
if (!push.publicKey) console.warn("No VAPID keys (see server/.env.example): phones will not get reminders.");
const mailer = config.RESEND_API_KEY ? new ResendMailer(config.RESEND_API_KEY, config.MAIL_FROM) : new ConsoleMailer();
if (!config.RESEND_API_KEY) console.warn("No RESEND_API_KEY: mails are printed here instead of sent.");
const backups = config.BACKUP_DIR ? new Backups(config.BACKUP_DIR, pgDump(config.DATABASE_URL)) : undefined;
if (!backups) console.warn("No BACKUP_DIR: the database is not backed up.");
const app = createApp({ database, mailer, config, push, backups });
const stopReminders = startReminderLoop(app.deps);
const stopWorld = startWorldLoop(app.deps);
const stopMaintenance = startMaintenance(app.deps);
const stopPomodoro = startPomodoroLoop(app.deps);
const stopBackups = backups ? startBackups(backups) : () => {};
const server = serve({ fetch: app.fetch, port: config.PORT }, (info) => {
  console.log(`GoblinCamp server on http://localhost:${info.port}/api/health`);
});
app.injectWebSocket(server);

async function shutdown() {
  stopReminders();
  stopWorld();
  stopMaintenance();
  stopPomodoro();
  stopBackups();
  server.close();
  await database.close();
  process.exit(0);
}
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
