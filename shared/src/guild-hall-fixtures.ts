/**
 * Worked examples of the guild hall rules (guild-hall.ts, and the level table in guild.ts), written to
 * guild-hall-fixtures.json. The Mac's Swift copy (mac/Sources/GuildRules) must give the very same hall at the same moment
 * (`swift run guild-rules-check` in mac/); the test here makes sure the JSON matches the TypeScript rules, so after changing
 * a rule run `node --experimental-strip-types scripts/write-guild-hall-fixtures.ts` in shared/ and commit the new file.
 *
 * Each hall is stored as the pieces put down in it (where, turned or not, and what each is: HallPieceSpec), so the Swift
 * side works out the furnishing itself with hallFurnishing.
 */
import { GUILD_LEVELS } from "./guild.ts";
import { guildDecorKind, guildFurnishing, starterDecor, type GuildDecorPlaced } from "./guild-decor.ts";
import {
  ACTIVITY_SECONDS,
  hallFurnishing,
  hallHash,
  hallInteract,
  hallLayout,
  hallPose,
  hallRoute,
  hallStep,
  hallWalkable,
  WALK_SPEED,
  WALL_ROWS,
  type HallLayout,
  type HallMember,
  type HallPieceSpec,
  type Point,
} from "./guild-hall.ts";

export const HALL_FIXTURE_START = Date.parse("2026-10-08T09:00:00Z");

interface Piece {
  x: number;
  y: number;
  flip: boolean;
  spec: HallPieceSpec;
}

/** The decorations as hallFurnishing takes them (only what it reads, so the JSON says just that). */
function piecesOf(items: readonly GuildDecorPlaced[]): Piece[] {
  return items.map((d) => {
    const k = guildDecorKind(d.kind);
    if (!k) throw new Error(`no decoration ${d.kind}`);
    const seat = k.seat && { x: k.seat.x, y: k.seat.y };
    return { x: d.x, y: d.y, flip: !!d.flip, spec: { w: k.w, h: k.h, flat: k.flat, wall: k.wall, ceiling: k.ceiling, living: k.living, seat, desk: k.desk, drink: k.drink } };
  });
}

const placed = (kind: string, x: number, y: number, flip?: boolean): GuildDecorPlaced => ({ uid: "fixture", kind, x, y, flip });

/** A starter hall with more in it, some of it in the way: a wall of shelves across the middle, sofas, desks turned round, a pen
 * closed all round (nobody gets in), and little living things (which are not in the way). */
function busyDecor(level: number): GuildDecorPlaced[] {
  const { width, height } = GUILD_LEVELS[level - 1]!;
  const mid = Math.floor(width / 2);
  const out = [...starterDecor(level)];
  for (let x = 4; x < width - 6; x += 2) out.push(placed("bookshelf_low", x, 12));
  out.push(
    placed("sofa", 8, height - 4),
    placed("armchair", 12.5, height - 4, true),
    placed("guild_desk", mid - 6, 9, true),
    placed("guild_desk", mid + 6, 9),
    placed("oak_desk", 5.0625, 16.3125, true),
    placed("water_cooler", width - 5, 16, true),
    placed("cat", 20, 9),
    placed("slime", 21.5, 15),
    placed("red_rug", 30, 18),
    placed("office_stool", 18, 18),
  );
  // the pen: barrels all round a square, a beanbag inside nobody can reach
  for (let i = 0; i < 6; i++) out.push(placed("barrel", width - 12 + i, height - 8), placed("barrel", width - 12 + i, height - 3));
  for (let i = 1; i < 10; i++) out.push(placed("barrel", width - 12, height - 8 + i / 2), placed("barrel", width - 7, height - 8 + i / 2));
  out.push(placed("beanbag", width - 9.5, height - 5));
  return out;
}

/** The halls the examples are worked out in: the starter hall at every level, an empty one, and a busy one. */
const HALLS: { name: string; level: number; decor: GuildDecorPlaced[] }[] = [
  ...GUILD_LEVELS.map((l) => ({ name: `starter ${l.level}`, level: l.level, decor: starterDecor(l.level) })),
  { name: "empty", level: 2, decor: [] },
  { name: "busy", level: 4, decor: busyDecor(4) },
];
const hallIndex = (name: string) => HALLS.findIndex((h) => h.name === name);

/** Who is in each hall the poses are worked out for: online ones (wandering, visiting each other), focusing, away, offline. */
const SCENES: { hall: string; members: HallMember[] }[] = [
  {
    hall: "starter 3",
    members: [
      { id: "幽幽", presence: "online", seat: 0 },
      { id: "u_7f3a9c", presence: "online", seat: 4 },
      { id: "goblin-king", presence: "online", seat: 7 }, // (past the desks: no desk of their own)
      { id: "🍄菇菇", presence: "online", seat: 2 },
      { id: "a", presence: "focus", seat: 1 },
      { id: "b", presence: "away", seat: 3 },
      { id: "c", presence: "offline", seat: 5 },
      { id: "d", presence: "focus", seat: 9 }, // (no desk: by the wall)
    ],
  },
  // alone in the hall: nobody's desk to chat at
  { hall: "starter 1", members: [{ id: "lonely", presence: "online", seat: 2 }] },
  { hall: "starter 7", members: [{ id: "x1", presence: "online", seat: 29 }, { id: "x2", presence: "online", seat: 0 }, { id: "x3", presence: "focus", seat: 4 }] },
  // nothing in the hall at all: no desk, no water, no seat
  {
    hall: "empty",
    members: [
      { id: "幽幽", presence: "online", seat: 0 },
      { id: "sofa-lover", presence: "online", seat: 1 },
      { id: "a", presence: "focus", seat: 0 },
      { id: "b", presence: "away", seat: 1 },
    ],
  },
  {
    hall: "busy",
    members: [
      { id: "幽幽", presence: "online", seat: 0 },
      { id: "sofa-lover", presence: "online", seat: 6 },
      { id: "u_7f3a9c", presence: "online", seat: 3 },
      { id: "goblin-king", presence: "online", seat: 11 },
      { id: "🍄菇菇", presence: "online", seat: 5 },
      { id: "a", presence: "focus", seat: 2 },
      { id: "b", presence: "away", seat: 6 },
    ],
  },
];

/** Every 0.61 s over three minutes, the first half minute from 0 (where the activity before the first is the −1st), and a few far off. */
function times(): number[] {
  const out: number[] = [];
  for (let i = 0; i <= 295; i++) out.push(HALL_FIXTURE_START + i * 610);
  for (let i = 0; i <= 49; i++) out.push(i * 610);
  out.push(1, 999.5, 23_999, 24_000, 1e12, 1.8e12 + 0.25, Date.parse("2030-01-01T00:00:00Z"), 4_102_444_800_000);
  return out;
}

const pt = (p: Point) => ({ x: p.x, y: p.y });

export function buildGuildHallFixtures() {
  const rules = { wallRows: WALL_ROWS, walkSpeed: WALK_SPEED, activitySeconds: ACTIVITY_SECONDS, levels: GUILD_LEVELS };

  // the parts as JavaScript writes them when joining (so the Swift side need not know how numbers are written)
  const hashInputs: (string | number)[][] = [
    [],
    [""],
    ["a"],
    ["a", 1],
    ["a", 2],
    ["幽幽", "offset"],
    ["幽幽", -1],
    ["u_7f3a9c", -12, "bench"],
    ["🍄菇菇", 75_000_123, "who"],
    ["goblin-king", 0, "aisle"],
    ["x", 1.5, "x"],
    ["é", "é"],
    ["幽幽", "wall", "x", 0],
    ["幽幽", 3, "y", 7],
  ];
  const hashes = hashInputs.map((parts) => ({ parts: parts.map(String), hash: hallHash(...parts) }));

  // the halls: their pieces, and what the rules make of them (the starter halls by way of guildFurnishing, as the apps do)
  const layouts: HallLayout[] = HALLS.map(({ level, decor }) => hallLayout(level, guildFurnishing(decor)));
  const halls = HALLS.map(({ name, level, decor }, i) => {
    const { width, height, desks, seats, drinks, solids } = layouts[i]!;
    return { name, level, pieces: piecesOf(decor), layout: { width, height, desks, seats, drinks, solids } };
  });

  // pieces of every sort, turned and not (seats, desks, water, living things, flat, on the wall, on the ceiling, tiny, tall)
  const sample: Piece[] = [
    ...piecesOf([
      placed("guild_desk", 5, 6),
      placed("guild_desk", 9.0625, 6.4375, true),
      placed("crystal_desk", 14.5, 7.125, true),
      placed("sofa", 4.25, 12, true),
      placed("armchair", 7.3125, 12.5),
      placed("long_bench", 10, 14, true),
      placed("office_stool", 3, 9),
      placed("water_elemental", 20, 5),
      placed("water_elemental", 24, 5, true),
      placed("water_cooler", 26.5, 9.0625),
      placed("elf_spring_basin", 12, 16, true),
      placed("cat", 16, 10),
      placed("slime", 17, 11, true),
      placed("red_rug", 15, 15),
      placed("guild_banner", 6, 2, true),
      placed("bookshelf_tall", 1.2, 2.4),
    ]),
    { x: 3.3, y: 17.7, flip: true, spec: { w: 4, h: 30, flat: false, wall: false, ceiling: false, living: false, seat: { x: 1, y: 22 }, desk: true, drink: true } },
    { x: 8.1, y: 4.05, flip: false, spec: { w: 50, h: 6, flat: false, wall: false, ceiling: true, living: false, seat: null, desk: false, drink: false } },
  ];
  const furnishings = [{ pieces: sample, furnishing: hallFurnishing(sample) }];

  // what each one is doing, over time; the same with the ways kept between frames as without
  const poses = SCENES.map(({ hall, members }) => {
    const layout = layouts[hallIndex(hall)]!;
    const present = members.filter((m) => m.presence !== "offline");
    const ways = new Map<string, Point[]>();
    return {
      hall: hallIndex(hall),
      members,
      present: present.map((m) => m.id),
      times: times().map((now) => ({
        now,
        poses: members.map((m) => {
          const fresh = hallPose(layout, m, present, now);
          const kept = hallPose(layout, m, present, now, ways);
          if (JSON.stringify(fresh) !== JSON.stringify(kept)) throw new Error(`the kept way differs for ${m.id} at ${now}`);
          return fresh;
        }),
      })),
    };
  });

  // the ways round things: between desks (from inside one: one starts sitting), seats, water, into a piece, into the pen
  // nobody can get into, from outside the hall, and nowhere at all
  const routes = ["starter 2", "busy"].map((name) => {
    const hall = hallIndex(name);
    const l = layouts[hall]!;
    const spots: Point[] = [
      ...l.desks.slice(0, 3),
      ...l.seats,
      ...l.drinks,
      { x: l.width / 2, y: WALL_ROWS + 0.1 }, // (inside the fireplace)
      { x: 1.2, y: WALL_ROWS + 0.3 }, // (inside the bookshelf)
      { x: 7.77, y: 6.1 },
      { x: l.width - 2.25, y: l.height - 0.5 },
      { x: l.width / 2 + 0.25, y: 11.9 },
      { x: l.width - 9.5, y: l.height - 6 }, // (in the busy hall's pen)
      { x: -3, y: 50 }, // (outside the hall)
      { x: 5, y: 0.5 }, // (in the wall)
    ];
    const cases = [];
    for (const a of spots) for (const b of spots) cases.push({ from: pt(a), to: pt(b), route: hallRoute(l, a, b) });
    return { hall, cases };
  });

  const walkable = ["starter 1", "starter 4", "busy"].map((name) => {
    const hall = hallIndex(name);
    const l = layouts[hall]!;
    const fine = name === "busy" ? 1 : 1.5;
    const cases = [];
    for (let y = 0; y <= l.height + 0.5; y += 0.75 * fine) for (let x = -0.2; x <= l.width + 0.3; x += 0.85 * fine) cases.push({ x, y, ok: hallWalkable(l, { x, y }) });
    return { hall, cases };
  });

  const steps = ["starter 1", "busy"].map((name) => {
    const hall = hallIndex(name);
    const l = layouts[hall]!;
    const moves = [
      [0.2, 0],
      [-0.2, 0],
      [0, 0.2],
      [0, -0.2],
      [0.15, 0.15],
      [-0.15, 0.15],
      [0.15, -0.15],
      [-0.15, -0.15],
      [0, 0],
    ];
    // (across the hall, and just outside each thing in the way, to slide along it)
    const from: Point[] = [];
    for (let y = WALL_ROWS + 0.3; y <= l.height; y += 2.9) for (let x = 0.3; x <= l.width; x += 3.7) from.push({ x, y });
    for (const r of l.solids.slice(0, 30)) from.push({ x: (r.x0 + r.x1) / 2, y: r.y0 - 0.05 }, { x: (r.x0 + r.x1) / 2, y: r.y1 + 0.05 }, { x: r.x0 - 0.05, y: (r.y0 + r.y1) / 2 }, { x: r.x1 + 0.05, y: r.y1 - 0.01 });
    const cases = [];
    for (const p of from) for (const [dx, dy] of moves) cases.push({ from: pt(p), dx, dy, to: hallStep(l, p, dx!, dy!) });
    return { hall, cases };
  });

  const interacts = ["starter 1", "empty", "busy"].map((name) => {
    const hall = hallIndex(name);
    const l = layouts[hall]!;
    const cases = [];
    for (let y = WALL_ROWS + 0.5; y <= l.height; y += 1.1)
      for (let x = 0.4; x <= l.width; x += 1.3) {
        const p = { x, y };
        cases.push({ p, ...hallInteract(l, p) });
      }
    return { hall, cases };
  });

  return { rules, hashes, halls, furnishings, poses, routes, walkable, steps, interacts };
}
