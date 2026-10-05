import { Hono, type Context } from "hono";
import { buildInput, expeditionInput, isCellId, openWorldInput, recallInput, routeInput } from "@goblincamp/shared/world";
import type { AppDeps, AppEnv } from "../app.ts";
import { requireAuth } from "../auth/session.ts";
import { apiError, readJson } from "../http.ts";
import {
  buildNest,
  buildOnCell,
  demolishOnCell,
  estimateExpedition,
  previewRoute,
  unguard,
  buildTown,
  cellDetail,
  cellsAround,
  landmarksAround,
  territoryList,
  LANDMARK_RADIUS,
  expeditionList,
  expeditionReport,
  leaderboard,
  MAX_MAP_RADIUS,
  moveHome,
  openWorldFor,
  recall,
  sendExpedition,
  notifyCamp,
  settleDue,
  worldMe,
  WorldError,
} from "./service.ts";
import { searchPlaces } from "./search.ts";

/** 大世界 (server/WORLD.md §15). Every answer first settles the parties that have arrived. */
export function worldRoutes(deps: AppDeps) {
  const app = new Hono<AppEnv>();
  const { db } = deps.database;
  const now = deps.now ?? (() => new Date());
  app.use("*", requireAuth(deps));

  /** Runs `work`; a WorldError becomes its answer, and the camps that changed hear about it. */
  async function run<T>(c: Context<AppEnv>, work: () => Promise<T>, changed: string[] = []): Promise<Response | T> {
    await settleDue(deps, now(), c.get("session").user.id);
    try {
      const out = await work();
      for (const u of changed) await notifyCamp(deps, u);
      return out;
    } catch (e) {
      // (the world's own codes: not_open, shielded, held, too_few, cannot_afford… besides the usual ones)
      if (e instanceof WorldError) return c.json({ error: e.code, message: e.message }, e.status);
      throw e;
    }
  }
  const respond = (c: Context<AppEnv>, out: unknown, status: 200 | 201 = 200) => (out instanceof Response ? out : c.json(out as object, status));

  app.get("/", async (c) => {
    const userId = c.get("session").user.id;
    return respond(c, await run(c, () => db.transaction((tx) => worldMe(tx, userId, now()))));
  });

  app.post("/open", async (c) => {
    const body = await readJson(c, openWorldInput);
    if ("response" in body) return body.response;
    const userId = c.get("session").user.id;
    const out = await run(c, () => db.transaction((tx) => openWorldFor(tx, userId, body.data, now())), [userId]);
    if (out instanceof Response) return out;
    return c.json(await db.transaction((tx) => worldMe(tx, userId, now())), 201);
  });

  /** The map around a point: `lat`, `lng`, `radius` in metres (up to 2500). */
  app.get("/cells", async (c) => {
    const lat = Number(c.req.query("lat"));
    const lng = Number(c.req.query("lng"));
    const radius = Number(c.req.query("radius") ?? "1000");
    if (!(Math.abs(lat) <= 85) || !(Math.abs(lng) <= 180) || !(radius > 0 && radius <= MAX_MAP_RADIUS)) {
      return apiError(c, 400, "invalid_input", `lat、lng 要是座標，radius 是 1～${MAX_MAP_RADIUS} 公尺。`);
    }
    return respond(c, await run(c, () => db.transaction((tx) => cellsAround(tx, { lat, lng }, radius, now(), c.get("session").user.id))));
  });

  /** All your cells at a glance (the phone's territory list). */
  app.get("/territory", async (c) => {
    const userId = c.get("session").user.id;
    return respond(c, await run(c, () => db.transaction((tx) => territoryList(tx, userId, now()))));
  });

  /** One of your own cells from inside (world/cell/[cell] on the phone). */
  app.get("/cells/:cell", async (c) => {
    const cell = c.req.param("cell");
    if (!isCellId(cell)) return apiError(c, 404, "not_found", "沒有這一格。");
    const userId = c.get("session").user.id;
    return respond(c, await run(c, () => db.transaction((tx) => cellDetail(tx, userId, cell, now()))));
  });

  /** The landmarks around a point (`lat`, `lng`; `radius` in metres, up to LANDMARK_RADIUS), the nearest first. */
  app.get("/landmarks", async (c) => {
    const lat = Number(c.req.query("lat"));
    const lng = Number(c.req.query("lng"));
    const radius = Number(c.req.query("radius") ?? String(LANDMARK_RADIUS));
    if (!(Math.abs(lat) <= 85) || !(Math.abs(lng) <= 180) || !(radius > 0 && radius <= LANDMARK_RADIUS)) {
      return apiError(c, 400, "invalid_input", `lat、lng 要是座標，radius 是 1～${LANDMARK_RADIUS} 公尺。`);
    }
    return respond(c, await run(c, async () => ({ landmarks: await db.transaction((tx) => landmarksAround(tx, { lat, lng }, radius)) })));
  });

  /** Places by name (`q`; `lat`, `lng`: where the map is, near places favoured), to go to on the map. */
  app.get("/search", async (c) => {
    const q = (c.req.query("q") ?? "").trim();
    const lat = Number(c.req.query("lat"));
    const lng = Number(c.req.query("lng"));
    if (!q || q.length > 80) return apiError(c, 400, "invalid_input", "請輸入要找的地方（80 字以內）。");
    const near = Math.abs(lat) <= 85 && Math.abs(lng) <= 180 && c.req.query("lat") && c.req.query("lng") ? { lat, lng } : null;
    const places = await searchPlaces(q, near);
    if (!places) return apiError(c, 503, "unavailable", "現在連不上地圖的搜尋，等一下再試。");
    return c.json({ places });
  });

  /** What a party would likely meet and how it would fare (nothing is sent). */
  app.post("/expeditions/estimate", async (c) => {
    const body = await readJson(c, expeditionInput);
    if ("response" in body) return body.response;
    const userId = c.get("session").user.id;
    return respond(c, await run(c, () => db.transaction((tx) => estimateExpedition(tx, userId, body.data, now()))));
  });

  /** The way a party would walk round other camps' land (nothing is sent). */
  app.post("/expeditions/route", async (c) => {
    const body = await readJson(c, routeInput);
    if ("response" in body) return body.response;
    const userId = c.get("session").user.id;
    return respond(c, await run(c, () => db.transaction((tx) => previewRoute(tx, userId, body.data))));
  });

  app.post("/expeditions", async (c) => {
    const body = await readJson(c, expeditionInput);
    if ("response" in body) return body.response;
    const userId = c.get("session").user.id;
    return respond(c, await run(c, () => db.transaction((tx) => sendExpedition(tx, userId, body.data, now())), [userId]), 201);
  });

  app.get("/expeditions", async (c) => {
    const limit = Math.min(50, Math.max(1, Number(c.req.query("limit") ?? "20") || 20));
    const userId = c.get("session").user.id;
    return respond(c, await run(c, async () => ({ expeditions: await db.transaction((tx) => expeditionList(tx, userId, limit)) })));
  });

  app.get("/expeditions/:id", async (c) => {
    const userId = c.get("session").user.id;
    const id = c.req.param("id");
    if (!/^[0-9a-f-]{36}$/.test(id)) return apiError(c, 404, "not_found", "沒有這次出征。");
    const out = await run(c, () => db.transaction((tx) => expeditionReport(tx, userId, id)));
    if (out instanceof Response) return out;
    return out ? c.json(out) : apiError(c, 404, "not_found", "沒有這次出征。");
  });

  const cellAction = (path: string, work: (userId: string, cell: string, body: unknown) => (tx: Parameters<Parameters<typeof db.transaction>[0]>[0]) => Promise<unknown>) =>
    app.post(`/cells/:cell/${path}`, async (c) => {
      const cell = c.req.param("cell");
      if (!isCellId(cell)) return apiError(c, 404, "not_found", "沒有這一格。");
      const userId = c.get("session").user.id;
      let body: unknown = {};
      if (path === "recall" || path === "build") {
        const parsed = await readJson(c, path === "recall" ? recallInput : buildInput);
        if ("response" in parsed) return parsed.response;
        body = parsed.data;
      }
      const out = await run(c, () => db.transaction(work(userId, cell, body)), [userId]);
      if (out instanceof Response) return out;
      return c.json(await db.transaction((tx) => worldMe(tx, userId, now())));
    });
  cellAction("nest", (userId, cell) => (tx) => buildNest(tx, userId, cell, now()));
  cellAction("town", (userId, cell) => (tx) => buildTown(tx, userId, cell, now()));
  cellAction("build", (userId, cell, body) => (tx) => buildOnCell(tx, userId, cell, (body as { kind: string }).kind, now()));
  /** Guests walk home: your own from a friend's cell; or, for its holder, every friend's from it. */
  app.post("/cells/:cell/unguard", async (c) => {
    const cell = c.req.param("cell");
    if (!isCellId(cell)) return apiError(c, 404, "not_found", "沒有這一格。");
    const userId = c.get("session").user.id;
    const out = await run(c, () => db.transaction((tx) => unguard(tx, userId, cell, now())));
    if (out instanceof Response) return out;
    for (const u of out) await notifyCamp(deps, u);
    return c.json(await db.transaction((tx) => worldMe(tx, userId, now())));
  });
  cellAction("demolish", (userId, cell) => (tx) => demolishOnCell(tx, userId, cell, now()));
  cellAction("recall", (userId, cell, body) => (tx) => recall(tx, userId, cell, body as { count?: number; to?: string; campers?: boolean }, now()));
  /** The camp moves here (once every HOME_MOVE_DAYS). */
  cellAction("home", (userId, cell) => (tx) => moveHome(tx, userId, cell, now()));

  app.get("/leaderboard", async (c) => respond(c, await run(c, () => db.transaction((tx) => leaderboard(tx)))));

  return app;
}
