import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { BADGE_SIZE, DEFAULT_BADGE, defaultAvatar, GUILD_DECOR, PRESENCE_TTL_SECONDS, randomAvatar, type GuildChatLine, type GuildDecorLogEntry, type GuildDonations, type GuildResponse, type ServerEvent } from "@goblincamp/shared";
import { eq } from "drizzle-orm";
import type { Database } from "../src/db/client.ts";
import { camps } from "../src/db/schema.ts";
import { bearer, emptyTables, logIn, mac, openTestDatabase, signUp, testApp, type TestApp } from "./helpers.ts";

let database: Database;
let t: TestApp;
beforeAll(async () => {
  database = await openTestDatabase();
});
beforeEach(async () => {
  await emptyTables(database);
  t = testApp(database);
});
afterAll(async () => {
  await database?.close();
});

let macs = 0;
/** Someone with a camp of `race`, signed in on a Mac, and what it hears over the WebSocket. */
async function person(email: string, race = "goblin") {
  const password = await signUp(t, email);
  const signedIn = (await logIn(t, email, password, mac(++macs))).body;
  const auth = bearer(signedIn.token);
  expect((await t.call("POST", "/camp/start", { race }, auth)).status).toBe(201);
  const heard: ServerEvent[] = [];
  t.app.deps.hub.add(signedIn.user.id, "test", { send: (d: string) => heard.push(JSON.parse(d)), close: () => {} });
  return { id: signedIn.user.id as string, code: signedIn.user.friendCode as string, auth, heard };
}
const guildOf = async (p: { auth: Record<string, string> }) => (await t.call("GET", "/guild", undefined, p.auth)).body as GuildResponse;

describe("公會", () => {
  it("founds a guild, invites by friend code, joins; names are unique", async () => {
    const a = await person("a@example.com");
    const b = await person("b@example.com", "elf");
    expect((await guildOf(a)).guild).toBeNull();

    expect((await t.call("POST", "/guild", { name: "x" }, a.auth)).status).toBe(400);
    const made = await t.call("POST", "/guild", { name: "  月光酒館  " }, a.auth);
    expect(made.status).toBe(201);
    const g = (made.body as GuildResponse).guild!;
    expect(g).toMatchObject({ name: "月光酒館", level: 1, badge: DEFAULT_BADGE, rules: { members: 5 } });
    expect(g.members).toMatchObject([{ id: a.id, role: "leader", presence: "offline" }]);
    expect((await t.call("POST", "/guild", { name: "別的" }, a.auth)).status).toBe(409);
    expect((await t.call("POST", "/guild", { name: "月光酒館" }, b.auth)).status).toBe(409);

    expect((await t.call("POST", "/guild/invites", { code: b.code.toLowerCase() }, a.auth)).status).toBe(201);
    expect(b.heard.some((e) => e.type === "guild.changed")).toBe(true);
    const asked = await guildOf(b);
    expect(asked.invites).toMatchObject([{ guildId: g.id, name: "月光酒館", members: 1 }]);
    expect((await guildOf(a)).guild!.invited.map((i) => i.id)).toEqual([b.id]);

    const joined = await t.call("POST", `/guild/join/${g.id}`, undefined, b.auth);
    expect(joined.status).toBe(200);
    const view = (joined.body as GuildResponse).guild!;
    expect(view.members.map((m) => [m.id, m.role, m.race])).toEqual([
      [a.id, "leader", "goblin"],
      [b.id, "member", "elf"],
    ]);
    expect(view.members[1]!.avatar.race).toBe("elf");
    expect(view.invited).toEqual([]); // (members do not see invitations)
    // a member cannot invite
    const c = await person("c@example.com", "undead");
    expect((await t.call("POST", "/guild/invites", { code: c.code }, b.auth)).status).toBe(403);
  });

  it("is full at the level's number; an invitation can be said no to or taken back", async () => {
    const lead = await person("lead@example.com");
    const g = ((await t.call("POST", "/guild", { name: "五人小隊" }, lead.auth)).body as GuildResponse).guild!;
    const others = [];
    for (let i = 0; i < 5; i++) others.push(await person(`p${i}@example.com`));
    for (const p of others.slice(0, 4)) {
      expect((await t.call("POST", "/guild/invites", { userId: p.id }, lead.auth)).status).toBe(201);
      expect((await t.call("POST", `/guild/join/${g.id}`, undefined, p.auth)).status).toBe(200);
    }
    const fifth = others[4]!;
    expect((await t.call("POST", "/guild/invites", { userId: fifth.id }, lead.auth)).status).toBe(409);

    // room again after someone leaves; no to the invitation, then taken back
    expect((await t.call("POST", "/guild/leave", undefined, others[0]!.auth)).status).toBe(200);
    expect((await t.call("POST", "/guild/invites", { userId: fifth.id }, lead.auth)).status).toBe(201);
    expect((await t.call("DELETE", `/guild/join/${g.id}`, undefined, fifth.auth)).status).toBe(204);
    expect((await guildOf(fifth)).invites).toEqual([]);
    expect((await t.call("POST", `/guild/join/${g.id}`, undefined, fifth.auth)).status).toBe(404);
    await t.call("POST", "/guild/invites", { userId: fifth.id }, lead.auth);
    expect((await t.call("DELETE", `/guild/invites/${fifth.id}`, undefined, lead.auth)).status).toBe(204);
    expect((await guildOf(fifth)).invites).toEqual([]);
    // invitations run out
    await t.call("POST", "/guild/invites", { userId: fifth.id }, lead.auth);
    t.advance(8 * 86_400_000);
    expect((await guildOf(fifth)).invites).toEqual([]);
  });

  it("waits a day after leaving; the lead passes on; the last one out breaks it up", async () => {
    const a = await person("a@example.com");
    const b = await person("b@example.com");
    const c = await person("c@example.com");
    const g = ((await t.call("POST", "/guild", { name: "石爐" }, a.auth)).body as GuildResponse).guild!;
    for (const p of [b, c]) {
      await t.call("POST", "/guild/invites", { userId: p.id }, a.auth);
      await t.call("POST", `/guild/join/${g.id}`, undefined, p.auth);
      t.advance(1000);
    }
    // c is made an officer: it leads when a leaves, though b joined first
    expect((await t.call("PUT", `/guild/members/${c.id}/role`, { role: "officer" }, b.auth)).status).toBe(403);
    expect((await t.call("PUT", `/guild/members/${c.id}/role`, { role: "officer" }, a.auth)).status).toBe(200);
    expect((await t.call("POST", "/guild/leave", undefined, a.auth)).status).toBe(200);
    const left = await guildOf(a);
    expect(left.guild).toBeNull();
    expect(left.waitUntil).not.toBeNull();
    expect((await guildOf(c)).guild!.members.map((m) => [m.id, m.role])).toEqual([
      [c.id, "leader"],
      [b.id, "member"],
    ]);
    // a may not come back or found another for a day
    await t.call("POST", "/guild/invites", { userId: a.id }, c.auth);
    expect((await t.call("POST", `/guild/join/${g.id}`, undefined, a.auth)).status).toBe(409);
    expect((await t.call("POST", "/guild", { name: "新的" }, a.auth)).status).toBe(409);
    t.advance(24 * 3_600_000);
    expect((await t.call("POST", `/guild/join/${g.id}`, undefined, a.auth)).status).toBe(200);

    // handing over the lead
    expect((await t.call("PUT", `/guild/members/${a.id}/role`, { role: "leader" }, c.auth)).status).toBe(200);
    expect((await guildOf(a)).guild!.members.find((m) => m.id === c.id)!.role).toBe("officer");

    // an officer may send a member away, not the leader; the one sent away need not wait
    expect((await t.call("DELETE", `/guild/members/${a.id}`, undefined, c.auth)).status).toBe(403);
    expect((await t.call("DELETE", `/guild/members/${b.id}`, undefined, c.auth)).status).toBe(200);
    expect((await guildOf(b)).waitUntil).toBeNull();

    for (const p of [c, a]) await t.call("POST", "/guild/leave", undefined, p.auth);
    // the name is free again
    t.advance(24 * 3_600_000);
    expect((await t.call("POST", "/guild", { name: "石爐" }, b.auth)).status).toBe(201);
  });

  it("the leader renames it and draws its badge", async () => {
    const a = await person("a@example.com");
    const b = await person("b@example.com");
    const g = ((await t.call("POST", "/guild", { name: "龍巢" }, a.auth)).body as GuildResponse).guild!;
    await t.call("POST", "/guild/invites", { userId: b.id }, a.auth);
    await t.call("POST", `/guild/join/${g.id}`, undefined, b.auth);
    const badge = "6".repeat(BADGE_SIZE * BADGE_SIZE);
    expect((await t.call("PATCH", "/guild", { badge }, b.auth)).status).toBe(403);
    expect((await t.call("PATCH", "/guild", { badge: "6".repeat(10) }, a.auth)).status).toBe(400);
    expect((await t.call("PATCH", "/guild", { badge: "g".repeat(256) }, a.auth)).status).toBe(400);
    const res = await t.call("PATCH", "/guild", { badge, name: "紅龍巢" }, a.auth);
    expect((res.body as GuildResponse).guild).toMatchObject({ name: "紅龍巢", badge });
    expect(b.heard.some((e) => e.type === "guild.changed")).toBe(true);
  });

  it("keeps an avatar of the camp's race", async () => {
    const a = await person("a@example.com", "undead");
    const first = await guildOf(a);
    expect(first.avatarChosen).toBe(false);
    expect(first.avatar).toEqual(defaultAvatar("undead", "m"));
    expect(first.avatar.flame).toBe("cyan");

    expect((await t.call("PUT", "/guild/avatar", defaultAvatar("elf", "f"), a.auth)).status).toBe(400);
    expect((await t.call("PUT", "/guild/avatar", { ...defaultAvatar("undead", "f"), hair: "mohawk" }, a.auth)).status).toBe(400);
    expect((await t.call("PUT", "/guild/avatar", { ...defaultAvatar("undead", "f"), flame: "cyan" }, a.auth)).status).toBe(400);
    let n = 0;
    const spirit = randomAvatar("undead", "f", () => (n = (n * 7 + 3) % 10) / 10);
    const saved = await t.call("PUT", "/guild/avatar", spirit, a.auth);
    expect(saved.status).toBe(200);
    expect(saved.body).toMatchObject({ avatar: spirit, avatarChosen: true });
  });

  it("shows who is at their computer, and tells the others when it changes", async () => {
    const a = await person("a@example.com");
    const b = await person("b@example.com");
    const g = ((await t.call("POST", "/guild", { name: "番茄工坊" }, a.auth)).body as GuildResponse).guild!;
    await t.call("POST", "/guild/invites", { userId: b.id }, a.auth);
    await t.call("POST", `/guild/join/${g.id}`, undefined, b.auth);
    b.heard.length = 0;

    expect((await t.call("PUT", "/guild/presence", { state: "focus" }, a.auth)).status).toBe(204);
    expect(b.heard).toEqual([{ type: "guild.presence", userId: a.id, state: "focus", at: t.now().toISOString() }]);
    // the same again (a heartbeat) tells no one
    t.advance(60_000);
    await t.call("PUT", "/guild/presence", { state: "focus" }, a.auth);
    expect(b.heard).toHaveLength(1);
    expect((await guildOf(b)).guild!.members.find((m) => m.id === a.id)).toMatchObject({ presence: "focus", seenAt: t.now().toISOString() });

    // a Mac that went quiet counts as offline
    t.advance((PRESENCE_TTL_SECONDS + 1) * 1000);
    expect((await guildOf(b)).guild!.members.find((m) => m.id === a.id)!.presence).toBe("offline");
    await t.call("PUT", "/guild/presence", { state: "away" }, a.auth);
    expect(b.heard.at(-1)).toMatchObject({ type: "guild.presence", state: "away" });
  });

  it("everyone decorates; versions, locks, the log and going back", async () => {
    const a = await person("a@example.com");
    const b = await person("b@example.com", "elf");
    const g = ((await t.call("POST", "/guild", { name: "裝潢隊" }, a.auth)).body as GuildResponse).guild!;
    await t.call("POST", "/guild/invites", { userId: b.id }, a.auth);
    await t.call("POST", `/guild/join/${g.id}`, undefined, b.auth);
    expect((await guildOf(b)).guild).toMatchObject({ decor: [], decorVersion: 0, races: ["elf", "goblin"] });

    const kind = GUILD_DECOR.find((k) => k.level === 1 && !k.wall && !k.race)!.id;
    const lamp = { uid: "lamp0001", kind, x: 4, y: 6 };
    const plant = { uid: "plant001", kind, x: 8, y: 7 };
    // a member puts things down
    let res = await t.call("PUT", "/guild/decor", { version: 0, items: [lamp, plant] }, b.auth);
    expect(res.status).toBe(200);
    expect((res.body as GuildResponse).guild).toMatchObject({ decorVersion: 1, decor: [lamp, plant] });
    expect(a.heard.some((e) => e.type === "guild.changed")).toBe(true);
    // made from an old version: refused
    expect((await t.call("PUT", "/guild/decor", { version: 0, items: [] }, a.auth)).status).toBe(409);
    // a member may not lock; the leader may, and then the member cannot move it
    expect((await t.call("PUT", "/guild/decor", { version: 1, items: [{ ...lamp, locked: true }, plant] }, b.auth)).status).toBe(403);
    t.advance(1000);
    expect((await t.call("PUT", "/guild/decor", { version: 1, items: [{ ...lamp, locked: true }, plant] }, a.auth)).status).toBe(200);
    t.advance(1000);
    expect((await t.call("PUT", "/guild/decor", { version: 2, items: [{ ...lamp, locked: true, x: 5 }, plant] }, b.auth)).status).toBe(403);
    expect((await t.call("PUT", "/guild/decor", { version: 2, items: [{ ...lamp, locked: true }] }, b.auth)).status).toBe(200); // (the plant was not locked)
    // a kind there is not, or a piece off the floor
    expect((await t.call("PUT", "/guild/decor", { version: 3, items: [{ uid: "nope0001", kind: "no_such_thing", x: 4, y: 6 }] }, a.auth)).status).toBe(400);
    expect((await t.call("PUT", "/guild/decor", { version: 3, items: [{ uid: "off00001", kind, x: 4, y: 1 }] }, a.auth)).status).toBe(400);

    const log = (await t.call("GET", "/guild/decor/log", undefined, b.auth)).body.entries as GuildDecorLogEntry[];
    expect(log.map((e) => [e.by, e.added, e.moved, e.removed])).toEqual([
      ["咕嚕", 0, 0, 1],
      ["咕嚕", 0, 1, 0], // (the lock)
      ["咕嚕", 2, 0, 0],
    ]);
    // the leader goes back to before the plant was taken away; only the leader may
    expect((await t.call("POST", "/guild/decor/restore", { logId: log[0]!.id }, b.auth)).status).toBe(403);
    res = await t.call("POST", "/guild/decor/restore", { logId: log[0]!.id }, a.auth);
    expect((res.body as GuildResponse).guild!.decor.map((d) => d.uid)).toEqual(["lamp0001", "plant001"]);
    expect(((await t.call("GET", "/guild/decor/log", undefined, a.auth)).body.entries as GuildDecorLogEntry[])[0]).toMatchObject({ restored: true, added: 1 });
  });

  it("lays floor tiles with the decorations (logged, can go back); the wall is the leader's and officers'", async () => {
    const a = await person("a@example.com");
    const b = await person("b@example.com");
    const g = ((await t.call("POST", "/guild", { name: "地板隊" }, a.auth)).body as GuildResponse).guild!;
    await t.call("POST", "/guild/invites", { userId: b.id }, a.auth);
    await t.call("POST", `/guild/join/${g.id}`, undefined, b.auth);
    expect((await guildOf(b)).guild).toMatchObject({ floor: { base: "oak", tiles: {} }, wall: "stone" });

    const floor = { base: "stone", tiles: { "3,4": "carpet", "4,4": "carpet" } };
    let res = await t.call("PUT", "/guild/decor", { version: 0, items: [], floor }, b.auth);
    expect((res.body as GuildResponse).guild!.floor).toEqual(floor);
    // off the hall, under the wall, a race's floor without that race, or no such floor
    for (const bad of [{ base: "oak", tiles: { "80,4": "carpet" } }, { base: "oak", tiles: { "3,1": "carpet" } }, { base: "elf_moss", tiles: {} }, { base: "lava", tiles: {} }]) {
      expect((await t.call("PUT", "/guild/decor", { version: 1, items: [], floor: bad }, b.auth)).status).toBe(400);
    }
    const log = (await t.call("GET", "/guild/decor/log", undefined, a.auth)).body.entries as GuildDecorLogEntry[];
    expect(log[0]).toMatchObject({ added: 0, floor: 32 * 18 }); // (every tile of the 32×18 floor changed: stone, two of them carpet)
    res = await t.call("POST", "/guild/decor/restore", { logId: log[0]!.id }, a.auth);
    expect((res.body as GuildResponse).guild!.floor).toEqual({ base: "oak", tiles: {} });

    expect((await t.call("PUT", "/guild/wall", { wall: "wood" }, b.auth)).status).toBe(403);
    expect((await t.call("PUT", "/guild/wall", { wall: "elf_vines" }, a.auth)).status).toBe(400);
    expect((await t.call("PUT", "/guild/wall", { wall: "goblin_hide" }, a.auth)).body.guild.wall).toBe("goblin_hide");
  });

  it("talks in the hall, and passes hand-walked moves to the other members only", async () => {
    const a = await person("a@example.com");
    const b = await person("b@example.com");
    const outsider = await person("c@example.com");
    const g = ((await t.call("POST", "/guild", { name: "聊天室" }, a.auth)).body as GuildResponse).guild!;
    await t.call("POST", "/guild/invites", { userId: b.id }, a.auth);
    await t.call("POST", `/guild/join/${g.id}`, undefined, b.auth);
    b.heard.length = 0;

    const said = await t.call("POST", "/guild/say", { text: "  早安！  " }, a.auth);
    expect(said.body).toMatchObject({ userId: a.id, text: "早安！" });
    expect(b.heard).toContainEqual(expect.objectContaining({ type: "guild.say", userId: a.id, text: "早安！" }));
    expect(outsider.heard.some((e) => e.type === "guild.say")).toBe(false);
    expect((await t.call("POST", "/guild/say", { text: "" }, a.auth)).status).toBe(400);
    expect((await t.call("POST", "/guild/say", { text: "嗨" }, outsider.auth)).status).toBe(404);
    for (let i = 0; i < 20; i++) {
      t.advance(10); // (in order)
      await t.call("POST", "/guild/say", { text: `${i}` }, b.auth);
    }
    expect((await t.call("POST", "/guild/say", { text: "太多了" }, b.auth)).status).toBe(429);
    const lines = (await t.call("GET", "/guild/chat", undefined, a.auth)).body.lines as GuildChatLine[];
    expect(lines).toHaveLength(21);
    expect(lines[0]!.text).toBe("早安！");

    // a move from a's page reaches b, not a itself, not the outsider; junk is dropped
    b.heard.length = 0;
    a.heard.length = 0;
    await t.app.live.receive(a.id, JSON.stringify({ type: "guild.move", x: 3, y: 5, dir: "side", flip: true, anim: "walk" }));
    await t.app.live.receive(a.id, "not json");
    await t.app.live.receive(a.id, JSON.stringify({ type: "guild.move", x: "far" }));
    expect(b.heard).toEqual([{ type: "guild.move", userId: a.id, x: 3, y: 5, dir: "side", flip: true, anim: "walk" }]);
    expect(a.heard).toEqual([]);
    expect(outsider.heard.some((e) => e.type === "guild.move")).toBe(false);
    // too fast: dropped; later: passed on; letting go
    await t.app.live.receive(a.id, JSON.stringify({ type: "guild.move", x: 4, y: 5, dir: "side", flip: true, anim: "walk" }));
    expect(b.heard).toHaveLength(1);
    t.advance(200);
    await t.app.live.receive(a.id, JSON.stringify({ type: "guild.move", x: 4, y: 5, dir: "side", flip: true, anim: "walk" }));
    await t.app.live.receive(a.id, JSON.stringify({ type: "guild.release" }));
    expect(b.heard.map((e) => e.type)).toEqual(["guild.move", "guild.move", "guild.release"]);
  });

  it("donates camp materials: the camp pays, the guild gains contribution and levels up, the ledger shows it", async () => {
    const a = await person("a@example.com");
    const b = await person("b@example.com");
    const g = ((await t.call("POST", "/guild", { name: "捐獻隊" }, a.auth)).body as GuildResponse).guild!;
    await t.call("POST", "/guild/invites", { userId: b.id }, a.auth);
    await t.call("POST", `/guild/join/${g.id}`, undefined, b.auth);
    expect((await guildOf(a)).guild).toMatchObject({ points: 0, level: 1, toNext: 3000 });
    await database.db.update(camps).set({ materials: { log: 2500, stone: 1100, golden_fur: 3 } }).where(eq(camps.userId, b.id));
    a.heard.length = 0;

    // more than the camp has, a thing that is no material, nothing at all
    expect((await t.call("POST", "/guild/donate", { materials: { log: 9999 } }, b.auth)).status).toBe(409);
    expect((await t.call("POST", "/guild/donate", { materials: { moon_rock: 1 } }, b.auth)).status).toBe(400);
    expect((await t.call("POST", "/guild/donate", { materials: {} }, b.auth)).status).toBe(400);

    let res = await t.call("POST", "/guild/donate", { materials: { log: 2000, stone: 500 } }, b.auth);
    expect(res.status).toBe(200);
    expect(res.body.guild.guild).toMatchObject({ points: 2500, level: 1, toNext: 500 });
    expect(a.heard.some((e) => e.type === "guild.changed")).toBe(true);
    const camp = (await t.call("GET", "/camp", undefined, b.auth)).body;
    expect(camp.materials).toMatchObject({ log: 500, stone: 600 });

    // 3 golden furs (30 each) push it over 3000: level 2, more members and room
    res = await t.call("POST", "/guild/donate", { materials: { golden_fur: 3, stone: 410 } }, b.auth);
    expect(res.body.message).toMatch(/升到 2 級/);
    expect(res.body.guild.guild).toMatchObject({ points: 3000, level: 2, rules: { members: 8 } });

    const ledger = (await t.call("GET", "/guild/donations", undefined, a.auth)).body as GuildDonations;
    expect(ledger.members.map((m) => [m.id, m.points])).toEqual([
      [b.id, 3000],
      [a.id, 0],
    ]);
    expect(ledger.recent[0]).toMatchObject({ materials: { golden_fur: 3, stone: 410 }, points: 500 });
    // not in a guild: nothing to give to
    const c = await person("c@example.com");
    expect((await t.call("POST", "/guild/donate", { materials: { log: 1 } }, c.auth)).status).toBe(400);
  });
});
