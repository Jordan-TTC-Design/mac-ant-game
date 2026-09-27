import { serve } from "@hono/node-server";
import { createApp } from "./app.ts";
import { loadConfig } from "./config.ts";
import { createDatabase } from "./db/client.ts";
import { runMigrations } from "./db/migrate.ts";
import { ConsoleMailer } from "./mail/mailer.ts";
import { startReminderLoop } from "./push/reminders.ts";
import { NoPushSender, WebPushSender } from "./push/sender.ts";

const config = loadConfig();
const database = createDatabase(config.DATABASE_URL);
await runMigrations(database);

const push =
  config.VAPID_PUBLIC_KEY && config.VAPID_PRIVATE_KEY
    ? new WebPushSender(config.VAPID_PUBLIC_KEY, config.VAPID_PRIVATE_KEY, config.VAPID_SUBJECT)
    : new NoPushSender();
if (!push.publicKey) console.warn("No VAPID keys (see server/.env.example): phones will not get reminders.");
const app = createApp({ database, mailer: new ConsoleMailer(), config, push });
const stopReminders = startReminderLoop(app.deps);
const server = serve({ fetch: app.fetch, port: config.PORT }, (info) => {
  console.log(`GoblinCamp server on http://localhost:${info.port}/api/health`);
});
app.injectWebSocket(server);

async function shutdown() {
  stopReminders();
  server.close();
  await database.close();
  process.exit(0);
}
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
