// Fills a throwaway database with camps to look at the phone app with (pwa/scripts/preview.sh): never the real one.
//   PREVIEW_DATABASE_URL=postgres://goblin:goblin@localhost:5433/goblin_preview tsx scripts/preview-seed.ts
// Logs in as demo@example.com / goblin preview: a goblin camp at race level 50 with its talents (掠奪, 工匠), cells round its
// camp (a town, a 瞭望塔, a 營火廣場), gear in its store; an elf camp with 伏擊, an undead one with 腐化大地 and a beast one with 夜襲 next door.
import { neighbors, cellAt } from "@goblincamp/shared/world";
import { cannotLearn, TALENTS, type TalentPicks } from "@goblincamp/shared/world";
import { bearer, emptyTables, logIn, mac, signUp, testApp } from "../test/helpers.ts";
import { createDatabase } from "../src/db/client.ts";
import { runMigrations } from "../src/db/migrate.ts";

const url = process.env.PREVIEW_DATABASE_URL;
if (!url || !/preview/.test(url)) throw new Error("PREVIEW_DATABASE_URL must name a database with 'preview' in it");
const database = createDatabase(url);
await runMigrations(database);
await emptyTables(database);
const t = testApp(database);
const HOUR = 3_600_000;
// (the camps were started a while ago, so they have grown (not so long that they starve unplayed); the real server goes on from now)
t.advance(Date.now() - 45 * HOUR - t.now().getTime());

const DAAN = { lat: 25.0302, lng: 121.5357 };
const PASSWORD = "goblin preview";
let macs = 0;
async function camp(email: string, race: string, at: { lat: number; lng: number }, trees: string[]) {
  await signUp(t, email, PASSWORD);
  const auth = bearer((await logIn(t, email, PASSWORD, mac(++macs))).body.token);
  await t.call("POST", "/camp/start", { race }, auth);
  t.advance(15 * HOUR);
  const opened = await t.call("POST", "/world/open", { cell: cellAt(at) }, auth);
  if (opened.status !== 201) throw new Error(`open ${email}: ${JSON.stringify(opened.body)}`);
  await database.sql`update world_players set xp = 120050 where user_id = (select id from users where email = ${email})`; // (Lv50)
  // (a camp that got there by playing has beaten the level bosses on the way; one put at Lv50 at once would meet the Lv10 boss
  // with every raid and lose some thirty a time: raids.ts bossDue)
  await database.sql`update camps set bosses_beaten = '[10, 20, 30, 40, 50]'::jsonb where user_id = (select id from users where email = ${email})`;
  const picks = fill(race, trees);
  const res = await t.call("POST", "/world/talents", { picks }, auth);
  if (res.status !== 200) throw new Error(`talents ${email}: ${JSON.stringify(res.body)}`);
  const [{ id }] = (await database.sql`select id from users where email = ${email}`) as [{ id: string }];
  return { auth, id, home: cellAt(at) };
}
/** Each tree bought top row first, every rank it can, down to its capstone. */
function fill(race: string, trees: string[]): TalentPicks {
  const picks: TalentPicks = {};
  for (const tree of trees)
    for (const rule of TALENTS.filter((x) => x.tree === tree).sort((a, b) => a.row - b.row))
      while (!cannotLearn(race, 50, picks, rule.id)) picks[rule.id] = (picks[rule.id] ?? 0) + 1;
  return picks;
}
async function hold(owner: string, cell: string, extra: { town?: boolean; building?: string } = {}) {
  const building = extra.building ? JSON.stringify({ kind: extra.building, level: 2 }) : null;
  await database.sql`insert into world_cells (cell, owner, held_since, yielded_to, town, building) values (${cell}, ${owner}, now(), now(), ${extra.town ?? false}, ${building}::jsonb)
    on conflict (cell) do update set owner = excluded.owner, held_since = now(), town = excluded.town, building = excluded.building`;
  await database.sql`update camp_residents set place = ${`cell:${cell}`} where user_id = ${owner} and id in (select id from camp_residents where user_id = ${owner} and place = 'home' and died_at is null limit 6)`;
}

const demo = await camp("demo@example.com", "goblin", DAAN, ["g_raid", "g_tinker"]);
const ring = neighbors(demo.home);
await hold(demo.id, ring[0]!, { town: true });
await hold(demo.id, ring[1]!, { building: "watchtower" });
await hold(demo.id, ring[2]!, { building: "campfire" });
await database.sql`update camps set armory = '[{"id": "bone_knife", "left": 40}, {"id": "wood_shield", "left": 9}, {"id": "bark_buckler", "left": 12}]'::jsonb where user_id = ${demo.id}`;
await database.sql`update camp_residents set gear = '{"weapon": {"id": "bone_knife", "left": 12}, "shield": {"id": "wood_shield", "left": 18, "refined": true}}'::jsonb
  where user_id = ${demo.id} and id in (select id from camp_residents where user_id = ${demo.id} and place = 'home' and died_at is null limit 3)`;

// next door, east: an elf camp with 伏擊; south: an undead camp with 腐化大地 holding the cells beside the demo's
const elf = await camp("elf@example.com", "elf", { lat: DAAN.lat, lng: DAAN.lng + 0.012 }, ["e_ranger", "e_grove"]);
await hold(elf.id, neighbors(elf.home)[3]!, { building: "sacred" });
const undead = await camp("undead@example.com", "undead", { lat: DAAN.lat - 0.012, lng: DAAN.lng }, ["u_crypt", "u_dread"]);
const beside = neighbors(ring[2]!).find((c) => c !== demo.home && !ring.includes(c))!;
await hold(undead.id, beside);
// west: a beast camp with 夜襲 (狼群 and 月), holding a 獵手小屋
const beast = await camp("beast@example.com", "beast", { lat: DAAN.lat, lng: DAAN.lng - 0.012 }, ["b_pack", "b_moon"]);
await hold(beast.id, neighbors(beast.home)[0]!, { building: "lodge" });
// the undead camp has a party on its way to the demo's town (set out now: still walking when you look)
t.advance(Date.now() - t.now().getTime());
const home = ((await t.call("GET", "/camp", undefined, undead.auth)).body.residents as { place: string }[]).filter((r) => r.place === "home").length;
const coming = await t.call("POST", "/world/expeditions", { to: ring[0], count: Math.min(12, home - 2) }, undead.auth);
if (coming.status !== 201) console.warn("no party on the way:", coming.body);

await database.close();
console.log(`ready: log in as demo@example.com / ${PASSWORD}`);
