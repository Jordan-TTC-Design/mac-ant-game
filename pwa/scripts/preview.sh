#!/bin/sh
# Looks at the phone app with made-up camps (server/scripts/preview-seed.ts) without the real database:
#   pwa/scripts/preview.sh            then open http://localhost:3000 and log in as demo@example.com / goblin preview
#   pwa/scripts/preview.sh --screens  the same, then pwa/scripts/screens.mjs checks the main pages and saves pictures, and stops
# The test Postgres (server/compose.dev.yml, :5433) gets a goblin_preview database, filled afresh each run; the server runs
# on :8790 (8787 may be taken on this Mac) and the app on :3000. Ctrl-C stops both.
set -e
cd "$(dirname "$0")/../.."
DB=postgres://goblin:goblin@localhost:5433/goblin_preview
docker compose -f server/compose.dev.yml up -d --wait >/dev/null
docker compose -f server/compose.dev.yml exec -T postgres psql -U goblin -d postgres -tc "select 1 from pg_database where datname = 'goblin_preview'" | grep -q 1 \
  || docker compose -f server/compose.dev.yml exec -T postgres psql -U goblin -d postgres -c "create database goblin_preview" >/dev/null
(cd server && PREVIEW_DATABASE_URL=$DB ./node_modules/.bin/tsx scripts/preview-seed.ts)
(cd server && exec env DATABASE_URL=$DB PORT=8790 APP_URL=http://localhost:3000 ./node_modules/.bin/tsx src/index.ts > /tmp/gc-preview-server.log 2>&1) &
SERVER=$!
trap 'kill $SERVER 2>/dev/null' EXIT INT TERM
cd pwa && API_ORIGIN=http://localhost:8790 node scripts/copy-sprites.mjs
if [ "$1" != "--screens" ]; then
  API_ORIGIN=http://localhost:8790 exec ./node_modules/.bin/nuxt dev --port 3000
fi
API_ORIGIN=http://localhost:8790 ./node_modules/.bin/nuxt dev --port 3000 >/tmp/gc-preview-nuxt.log 2>&1 &
NUXT=$!
# (nuxt dev and tsx start children of their own: stop those too, or they keep the terminal waiting)
trap 'pkill -P $NUXT; pkill -P $SERVER; kill $SERVER $NUXT 2>/dev/null' EXIT INT TERM
until curl -sf http://localhost:3000/ >/dev/null; do sleep 1; done
node scripts/screens.mjs
