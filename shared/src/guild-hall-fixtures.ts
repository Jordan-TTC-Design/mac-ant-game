/**
 * Worked examples of the guild hall rules (guild-hall.ts, and the level table in guild.ts), written to
 * guild-hall-fixtures.json. The Mac's Swift copy (mac/Sources/GuildRules) must give the very same hall at the same moment
 * (`swift run guild-rules-check` in mac/); the test here makes sure the JSON matches the TypeScript rules, so after changing
 * a rule run `pnpm guild:fixtures` and commit the new file.
 */
import { GUILD_LEVELS } from "./guild.ts";
import {
  ACTIVITY_SECONDS,
  hallHash,
  hallInteract,
  hallLayout,
  hallPath,
  hallPose,
  hallStep,
  hallWalkable,
  WALK_SPEED,
  WALL_ROWS,
  type HallMember,
  type Point,
} from "./guild-hall.ts";

export const HALL_FIXTURE_START = Date.parse("2026-10-08T09:00:00Z");

/** Who is in each hall the poses are worked out for: online ones (wandering, visiting each other), focusing, away, offline. */
const SCENES: { level: number; members: HallMember[] }[] = [
  {
    level: 3,
    members: [
      { id: "幽幽", presence: "online", seat: 0 },
      { id: "u_7f3a9c", presence: "online", seat: 4 },
      { id: "goblin-king", presence: "online", seat: 13 }, // (past the last seat: wraps round)
      { id: "🍄菇菇", presence: "online", seat: 7 },
      { id: "a", presence: "focus", seat: 2 },
      { id: "b", presence: "away", seat: 3 },
      { id: "c", presence: "offline", seat: 1 },
    ],
  },
  // alone in the hall: nobody's desk to chat at
  { level: 1, members: [{ id: "lonely", presence: "online", seat: 2 }] },
  { level: 7, members: [{ id: "x1", presence: "online", seat: 29 }, { id: "x2", presence: "online", seat: 0 }, { id: "x3", presence: "focus", seat: 15 }] },
];

/** Every 0.37 s over three minutes, the first minute from 0 (where the activity before the first is the −1st), and a few far off. */
function times(): number[] {
  const out: number[] = [];
  for (let i = 0; i <= 486; i++) out.push(HALL_FIXTURE_START + i * 370);
  for (let i = 0; i <= 162; i++) out.push(i * 370);
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
    ["é", "é"],
  ];
  const hashes = hashInputs.map((parts) => ({ parts: parts.map(String), hash: hallHash(...parts) }));

  const layouts = [0, ...GUILD_LEVELS.map((l) => l.level), 9].map((level) => {
    const l = hallLayout(level);
    return { level, width: l.width, height: l.height, pieces: l.pieces, seats: l.seats, drink: l.drink, bench: l.bench, aisles: l.aisles };
  });

  const poses = SCENES.map(({ level, members }) => {
    const layout = hallLayout(level);
    const present = members.filter((m) => m.presence !== "offline");
    return {
      level,
      members,
      present: present.map((m) => m.id),
      times: times().map((now) => ({ now, poses: members.map((m) => hallPose(layout, m, present, now)) })),
    };
  });

  // walking by hand, and the paths the wanderers take
  const paths = [2, 5].map((level) => {
    const l = hallLayout(level);
    const spots: Point[] = [...l.seats.slice(0, 5), l.drink, ...l.bench, { x: 1.5, y: l.aisles[0]! }, { x: l.width - 2.3, y: l.aisles.at(-1)! + 0.004 }, { x: 7.77, y: 6.1 }];
    const cases = [];
    for (const a of spots) for (const b of spots) cases.push({ from: pt(a), to: pt(b), path: hallPath(l, a, b) });
    return { level, cases };
  });

  const walkable = [1, 4].map((level) => {
    const l = hallLayout(level);
    const cases = [];
    for (let y = 0; y <= l.height + 0.5; y += 0.9) for (let x = -0.2; x <= l.width + 0.3; x += 1.1) cases.push({ x, y, ok: hallWalkable(l, { x, y }) });
    return { level, cases };
  });

  const steps = [1, 3].map((level) => {
    const l = hallLayout(level);
    const moves = [
      [0.2, 0],
      [-0.2, 0],
      [0, 0.2],
      [0, -0.2],
      [0.15, 0.15],
      [-0.15, 0.15],
      [0.15, -0.15],
      [-0.15, -0.15],
    ];
    const cases = [];
    for (let y = WALL_ROWS + 0.3; y <= l.height; y += 1.9)
      for (let x = 0.3; x <= l.width; x += 2.3) for (const [dx, dy] of moves) cases.push({ from: { x, y }, dx, dy, to: hallStep(l, { x, y }, dx!, dy!) });
    return { level, cases };
  });

  const interacts = [1, 3].map((level) => {
    const l = hallLayout(level);
    const extraSeats: Point[] = [
      { x: 6.4, y: l.height - 1.5 },
      { x: l.width - 4, y: WALL_ROWS + 1 },
    ];
    const cases = [];
    for (let y = WALL_ROWS + 0.5; y <= l.height; y += 1.1)
      for (let x = 0.4; x <= l.width; x += 1.3) {
        const p = { x, y };
        cases.push({ p, plain: hallInteract(l, p), extra: hallInteract(l, p, extraSeats) });
      }
    return { level, extraSeats, cases };
  });

  return { rules, hashes, layouts, poses, paths, walkable, steps, interacts };
}
