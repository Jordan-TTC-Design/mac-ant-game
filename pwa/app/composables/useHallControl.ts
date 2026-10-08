import {
  GUILD_MOVE_HEARTBEAT_MS,
  GUILD_MOVE_IDLE_MS,
  GUILD_MOVE_MS,
  hallInteract,
  hallPath,
  hallRoute,
  hallSolids,
  hallStep,
  hallWalkable,
  WALK_SPEED,
  type GuildMove,
  type HallLayout,
  type Point,
  type Rect,
} from "@goblincamp/shared";

/** Walking pace by hand, tiles a second (a little brisker than wandering). */
const SPEED = WALK_SPEED * 1.3;
/** How long a wave, a cheer or a drink plays before standing again. */
const ACT_MS = 3000;

export type Pad = "up" | "down" | "left" | "right";

/**
 * Walking one's own avatar in the guild hall (GUILD.md §3.1): arrow keys or WASD (or the phone's pad), a click or tap to
 * walk there round the desks, A to sit / drink / wave, B to cheer. The first input takes the avatar over from its own
 * wandering; where it is goes to the other members over the WebSocket (when it changes, and every few seconds), and after a
 * while without input — or leaving the page — it is let go again.
 */
export function useHallControl(layout: Ref<HallLayout | null>, startAt: () => Point | null, extraSolids: () => Rect[] = () => [], extraSeats: () => Point[] = () => []) {
  const pose = ref<(GuildMove & { since: number }) | null>(null);
  const held = new Set<Pad>();
  let path: Point[] = [];
  let thenSit = false;
  let lastInput = 0;
  let lastSent = 0;
  let sentKey = "";
  let raf = 0;
  let last = 0;

  const send = (detail: object) => window.dispatchEvent(new CustomEvent("gc:client-message", { detail }));

  /** Somewhere free to stand up to from a seat (beside it; else the aisle behind the desks). */
  function standUp(L: HallLayout, p: Point, solids: Rect[]): Point {
    const spots = [-1, 1].flatMap((s) => [{ x: p.x, y: p.y + s * 0.9 }, { x: p.x + s * 0.9, y: p.y }]).concat([{ x: p.x, y: p.y - 1.1 }]);
    const free = spots.find((q) => hallWalkable(L, q, solids));
    return free ?? { x: p.x, y: L.aisles.filter((a) => a < p.y).at(-1) ?? L.aisles[0]! };
  }

  /** Takes the avatar over (from where it was wandering) on the first input. */
  function take(): boolean {
    lastInput = Date.now();
    if (pose.value) return true;
    const from = startAt();
    const L = layout.value;
    if (!from || !L) return false;
    const solids = [...hallSolids(L), ...extraSolids()];
    // (if it was sitting, stand up beside the seat)
    const at = hallWalkable(L, from, solids) ? from : standUp(L, from, solids);
    pose.value = { ...at, dir: "front", flip: false, anim: "idle", since: Date.now() };
    return true;
  }
  function act(anim: GuildMove["anim"], at?: Point) {
    if (!pose.value) return;
    pose.value = { ...pose.value, ...(at ?? {}), anim, dir: "front", flip: false, since: Date.now() };
  }

  function press(pad: Pad, down: boolean) {
    if (down) {
      if (!take()) return;
      held.add(pad);
      path = [];
    } else held.delete(pad);
  }
  function pressA() {
    if (!take() || !layout.value) return;
    const { anim, at } = hallInteract(layout.value, pose.value!, extraSeats());
    act(anim, at);
  }
  function pressB() {
    if (take()) act("cheer");
  }
  /** Walks there round the desks and decorations; a tap on something to sit on (or its desk) walks up to it and sits. */
  function walkTo(x: number, y: number) {
    const L = layout.value;
    if (!L || !take()) return;
    const solids = [...hallSolids(L), ...extraSolids()];
    const target = { x, y };
    thenSit = false;
    let goal: Point = target;
    if (!hallWalkable(L, target, solids)) {
      const near = hallInteract(L, target, extraSeats());
      if (near.anim !== "sit") return;
      // (the nearest free spot by the seat)
      const spots = [-1, 1].flatMap((s) => [{ x: near.at.x, y: near.at.y + s * 0.9 }, { x: near.at.x + s * 0.9, y: near.at.y }, { x: near.at.x, y: near.at.y - 1.1 }]);
      const free = spots.filter((p) => hallWalkable(L, p, solids)).sort((a, b) => Math.hypot(a.x - pose.value!.x, a.y - pose.value!.y) - Math.hypot(b.x - pose.value!.x, b.y - pose.value!.y))[0];
      if (!free) return;
      goal = free;
      thenSit = true;
    }
    path = hallRoute(L, solids, pose.value!, goal) ?? hallPath(L, pose.value!, goal).slice(1);
  }

  function frame(t: number) {
    raf = requestAnimationFrame(frame);
    const dt = Math.min(0.1, (t - (last || t)) / 1000);
    last = t;
    const L = layout.value;
    const p = pose.value;
    if (!L || !p) return;
    const now = Date.now();
    let dx = (held.has("right") ? 1 : 0) - (held.has("left") ? 1 : 0);
    let dy = (held.has("down") ? 1 : 0) - (held.has("up") ? 1 : 0);
    if (!dx && !dy && path.length) {
      const next = path[0]!;
      const ax = next.x - p.x;
      const ay = next.y - p.y;
      const d = Math.hypot(ax, ay);
      if (d < 0.08) {
        path.shift();
        if (!path.length && thenSit) {
          thenSit = false;
          const { anim, at } = hallInteract(L, p, extraSeats());
          act(anim, at);
          return;
        }
      } else {
        dx = ax / d;
        dy = ay / d;
      }
    }
    const solids = [...hallSolids(L), ...extraSolids()];
    if ((dx || dy) && !hallWalkable(L, p, solids)) {
      // (sitting: stand up beside the seat first)
      pose.value = { ...p, ...standUp(L, p, solids), anim: "walk", dir: "front", since: now };
      return;
    }
    if (dx || dy) {
      const len = Math.hypot(dx, dy);
      const step = Math.min(SPEED * dt, path.length ? Math.hypot(path[0]!.x - p.x, path[0]!.y - p.y) : Infinity);
      const to = hallStep(L, p, (dx / len) * step, (dy / len) * step, solids);
      const dir = Math.abs(dx) >= Math.abs(dy) ? "side" : dy < 0 ? "back" : "front";
      pose.value = { ...to, dir, flip: dx > 0, anim: "walk", since: p.anim === "walk" ? p.since : now };
      if (to.x === p.x && to.y === p.y) path = []; // (stuck: give up on the way)
    } else if (p.anim === "walk" || (["wave", "cheer", "drink", "stretch"].includes(p.anim) && now - p.since > ACT_MS)) {
      pose.value = { ...p, anim: "idle", since: now };
    }
    // tell the others: when it changed (at most every GUILD_MOVE_MS), and now and then anyway
    const q = pose.value!;
    const key = `${q.x.toFixed(2)},${q.y.toFixed(2)},${q.anim},${q.dir},${q.flip}`;
    if ((key !== sentKey && now - lastSent >= GUILD_MOVE_MS) || now - lastSent >= GUILD_MOVE_HEARTBEAT_MS) {
      send({ type: "guild.move", x: q.x, y: q.y, dir: q.dir, flip: q.flip, anim: q.anim });
      sentKey = key;
      lastSent = now;
    }
    if (now - lastInput > GUILD_MOVE_IDLE_MS) release();
  }

  function release() {
    if (!pose.value) return;
    pose.value = null;
    held.clear();
    path = [];
    sentKey = "";
    send({ type: "guild.release" });
  }

  // the keyboard (not while typing in a box)
  const KEYS: Record<string, Pad> = { ArrowUp: "up", ArrowDown: "down", ArrowLeft: "left", ArrowRight: "right", w: "up", s: "down", a: "left", d: "right" };
  const typing = (e: KeyboardEvent) => e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement;
  function keydown(e: KeyboardEvent) {
    if (typing(e) || e.metaKey || e.ctrlKey || e.altKey) return;
    const pad = KEYS[e.key] ?? KEYS[e.key.toLowerCase()];
    if (pad) {
      e.preventDefault();
      if (!e.repeat) press(pad, true);
    } else if (e.key === " " || e.key.toLowerCase() === "e") {
      e.preventDefault();
      pressA();
    } else if (e.key.toLowerCase() === "q") pressB();
  }
  function keyup(e: KeyboardEvent) {
    const pad = KEYS[e.key] ?? KEYS[e.key.toLowerCase()];
    if (pad) press(pad, false);
  }

  onMounted(() => {
    window.addEventListener("keydown", keydown);
    window.addEventListener("keyup", keyup);
    window.addEventListener("blur", () => held.clear());
    raf = requestAnimationFrame(frame);
  });
  onUnmounted(() => {
    window.removeEventListener("keydown", keydown);
    window.removeEventListener("keyup", keyup);
    cancelAnimationFrame(raf);
    release();
  });

  return { pose, press, pressA, pressB, walkTo, release };
}
