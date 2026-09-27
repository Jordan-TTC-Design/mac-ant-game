import { serve } from "@hono/node-server";
import { createApp } from "./app.ts";
import { loadConfig } from "./config.ts";
import { createDatabase } from "./db/client.ts";
import { runMigrations } from "./db/migrate.ts";
import { ConsoleMailer } from "./mail/mailer.ts";

const config = loadConfig();
const database = createDatabase(config.DATABASE_URL);
await runMigrations(database);

const app = createApp({ database, mailer: new ConsoleMailer(), config });
const server = serve({ fetch: app.fetch, port: config.PORT }, (info) => {
  console.log(`GoblinCamp server on http://localhost:${info.port}/api/health`);
});

async function shutdown() {
  server.close();
  await database.close();
  process.exit(0);
}
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
