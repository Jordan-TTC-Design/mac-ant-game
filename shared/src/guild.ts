/**
 * Guilds and their hall (GUILD.md): a few players, of any race, who share a hall where each one's avatar shows whether they
 * are at their computer. Joining is by invitation only; one guild at a time, and a day's wait after leaving one. The rules
 * here are the one copy the server, the Mac and the phone use.
 */
import { z } from "zod";

// ── Levels (GUILD.md §4.1) ────────────────────────────────────────────────────────────────────────────────────────────

export interface GuildLevel {
  level: number;
  /** Members at most. */
  members: number;
  /** The hall's size in tiles. */
  width: number;
  height: number;
  /** Decoration room in the shared part of the hall (small 1, middle 2, big 4). */
  room: number;
}

export const GUILD_LEVELS: readonly GuildLevel[] = [
  { level: 1, members: 5, width: 32, height: 20, room: 160 },
  { level: 2, members: 8, width: 40, height: 24, room: 240 },
  { level: 3, members: 12, width: 48, height: 28, room: 340 },
  { level: 4, members: 16, width: 56, height: 32, room: 440 },
  { level: 5, members: 20, width: 64, height: 36, room: 560 },
  { level: 6, members: 25, width: 72, height: 40, room: 700 },
  { level: 7, members: 30, width: 80, height: 44, room: 880 },
];

export function guildLevel(level: number): GuildLevel {
  return GUILD_LEVELS[Math.min(Math.max(Math.trunc(level), 1), GUILD_LEVELS.length) - 1]!;
}

/** After leaving (or breaking up) a guild, this long before joining or founding another (GUILD.md §6). */
export const GUILD_REJOIN_HOURS = 24;
/** Invitations one guild may have waiting at once. */
export const GUILD_PENDING_INVITES_MAX = 10;
/** An invitation not answered in this many days goes away. */
export const GUILD_INVITE_DAYS = 7;

export const GUILD_NAME_MIN = 2;
export const GUILD_NAME_MAX = 16;

export type GuildRole = "leader" | "officer" | "member";
export const GUILD_ROLES: readonly GuildRole[] = ["leader", "officer", "member"];

// ── Badge (GUILD.md §5.4): 16 × 16 pixels the leader draws, 15 heraldic colours and see-through ────────────────────────

export const BADGE_SIZE = 16;
/** Index 0 is see-through; the badge is BADGE_SIZE² hex digits, one per pixel, row by row. */
export const BADGE_PALETTE: readonly string[] = [
  "transparent",
  "#f4e9cf", // 羊皮紙
  "#e8c547", // 金
  "#b8862b", // 暗金
  "#c9ced6", // 銀
  "#6d7480", // 鐵灰
  "#c0392b", // 紅
  "#7a1f1f", // 暗紅
  "#2e6fbf", // 藍
  "#1f3b6e", // 深藍
  "#3f9a4a", // 綠
  "#1f5a2c", // 深綠
  "#7b4fa8", // 紫
  "#d9822b", // 橘
  "#6b4226", // 棕
  "#1b1b22", // 黑
];
const BADGE_PIXELS = BADGE_SIZE * BADGE_SIZE;
export const badgeSchema = z.string().regex(new RegExp(`^[0-9a-f]{${BADGE_PIXELS}}$`), "徽章要是 16×16 格。");

/** A plain badge for a guild that has not drawn one: a blue shield with a gold edge and a gold star. */
export const DEFAULT_BADGE: string = (() => {
  const rows: string[] = [];
  for (let y = 0; y < BADGE_SIZE; y++) {
    let row = "";
    for (let x = 0; x < BADGE_SIZE; x++) {
      const half = y < 9 ? 6.5 : 6.5 - (y - 8) * 0.9; // the shield narrows to a point at the bottom
      const dx = Math.abs(x - 7.5);
      const inside = y >= 1 && y <= 15 && dx <= half;
      const edge = inside && (y === 1 || dx > half - 1 || y === 15);
      const star = (Math.abs(x - 7.5) < 1 && y >= 4 && y <= 10) || (Math.abs(y - 7) < 1 && x >= 4 && x <= 11);
      row += !inside ? "0" : edge ? "2" : star ? "2" : "8";
    }
    rows.push(row);
  }
  return rows.join("");
})();

// ── Avatars (GUILD.md §2) ─────────────────────────────────────────────────────────────────────────────────────────────

export type AvatarSex = "m" | "f";

/** What a race's avatar may be put together from. The undead's men are bone, the women spirits (GUILD.md §2). */
export interface AvatarOptions {
  /** Hairstyles (for the bone type: what is on the skull instead), by sex. */
  hair: Record<AvatarSex, readonly string[]>;
  skin: readonly string[];
  mouth: Record<AvatarSex, readonly string[]>;
  /** The skeleton's eye-flame colours; empty: not this race. */
  flame: Record<AvatarSex, readonly string[]>;
}

export const AVATAR_FACES = ["round", "pointed", "square"] as const;
export const AVATAR_EYES = ["round", "narrow", "sparkle", "dot", "sleepy", "sharp", "lashes", "wide"] as const;
export const AVATAR_BROWS = ["thin", "thick", "faint", "none"] as const;
export const AVATAR_HAIR_COLORS = ["black", "darkbrown", "chestnut", "orange", "yellow", "blonde", "silver", "pink", "lavender", "mint", "navy", "forest"] as const;

const MOUTHS = ["line", "smile", "smirk", "open", "pout", "cat"] as const;
const SKULL_MOUTHS = ["teeth", "grin", "gap", "jaw", "fang", "stitch"] as const;

export const AVATAR_OPTIONS: Record<"goblin" | "elf" | "undead", AvatarOptions> = {
  goblin: {
    hair: {
      m: ["tuft", "mohawk", "topknot", "bald_ring", "dreads", "wild", "bun", "spikes"],
      f: ["braids", "bun", "dreads", "wild", "tuft", "pigtails", "mohawk", "bob"],
    },
    skin: ["light", "grass", "moss", "deep"],
    mouth: { m: MOUTHS, f: MOUTHS },
    flame: { m: [], f: [] },
  },
  elf: {
    hair: {
      m: ["neat", "long", "halfup", "ponytail", "side_braid", "waves", "messy", "braided_crown"],
      f: ["long_wreath", "braided_crown", "side_braid", "waves", "long", "ponytail", "halfup", "wreath_updo"],
    },
    skin: ["fair", "warm", "tan", "bronze"],
    mouth: { m: MOUTHS, f: MOUTHS },
    flame: { m: [], f: [] },
  },
  undead: {
    hair: {
      m: ["hood", "bare", "crack", "horns", "long_horns", "ragged_hood", "bone_crown", "candle"],
      f: ["drift", "flame", "mist", "wisp_twins", "glass_short", "long_wave", "side_wisp", "flame_crown"],
    },
    skin: ["bone", "ivory", "ash", "slate"],
    mouth: { m: SKULL_MOUTHS, f: MOUTHS },
    flame: { m: ["cyan", "violet", "green", "orange"], f: [] },
  },
};
/** The spirit's skins (the undead women). */
const SPIRIT_SKINS = ["pale_blue", "ice", "pale_violet", "lavender"] as const;

export function avatarOptions(race: string, sex: AvatarSex): { hair: readonly string[]; skin: readonly string[]; mouth: readonly string[]; flame: readonly string[] } {
  const o = AVATAR_OPTIONS[race as keyof typeof AVATAR_OPTIONS] ?? AVATAR_OPTIONS.goblin;
  return { hair: o.hair[sex], skin: race === "undead" && sex === "f" ? SPIRIT_SKINS : o.skin, mouth: o.mouth[sex], flame: o.flame[sex] };
}

export const avatarSchema = z.object({
  race: z.enum(["goblin", "elf", "undead"]),
  sex: z.enum(["m", "f"]),
  face: z.enum(AVATAR_FACES),
  eyes: z.enum(AVATAR_EYES),
  brows: z.enum(AVATAR_BROWS),
  mouth: z.string().max(20),
  hair: z.string().max(20),
  hairColor: z.enum(AVATAR_HAIR_COLORS),
  skin: z.string().max(20),
  /** The skeleton's eye flame (other avatars: none). */
  flame: z.string().max(20).optional(),
});
export type Avatar = z.infer<typeof avatarSchema>;

/** Why this avatar cannot be (null: it can). */
export function avatarProblem(a: Avatar): string | null {
  const o = avatarOptions(a.race, a.sex);
  if (!o.hair.includes(a.hair)) return "這個種族沒有這種髮型。";
  if (!o.skin.includes(a.skin)) return "這個種族沒有這種膚色。";
  if (!o.mouth.includes(a.mouth)) return "沒有這種嘴巴。";
  if (o.flame.length ? !a.flame || !o.flame.includes(a.flame) : a.flame !== undefined) return "眼火的顏色不對。";
  return null;
}

/** The approved look of each race's two avatars (docs/images/guild/avatars_preview.png). */
export function defaultAvatar(race: string, sex: AvatarSex): Avatar {
  const r = (["goblin", "elf", "undead"] as const).find((x) => x === race) ?? "goblin";
  const o = avatarOptions(r, sex);
  const look: Record<string, Partial<Avatar>> = {
    goblinm: { hairColor: "darkbrown", skin: "grass", brows: "faint" },
    goblinf: { hairColor: "orange", skin: "grass", eyes: "lashes" },
    elfm: { hairColor: "chestnut", skin: "fair" },
    elff: { hairColor: "blonde", skin: "fair", eyes: "lashes" },
    undeadm: { hairColor: "black", skin: "bone", flame: "cyan" },
    undeadf: { hairColor: "mint", skin: "pale_blue", eyes: "lashes" },
  };
  return { race: r, sex, face: "round", eyes: "round", brows: "none", mouth: o.mouth[0]!, hair: o.hair[0]!, hairColor: "black", skin: o.skin[0]!, ...(o.flame.length ? { flame: o.flame[0] } : {}), ...look[r + sex] };
}

/** Hair colours that go badly with a skin, left out when choosing at random (GUILD.md §2: 配色會避開太難看的組合). */
const CLASHES: Record<string, readonly string[]> = {
  grass: ["forest", "mint"],
  moss: ["forest", "mint"],
  deep: ["forest", "navy", "black"],
  light: ["mint"],
  pale_blue: ["navy"],
  ice: ["mint", "navy"],
};

/** Every part chosen at random (`rand` gives 0 ≤ x < 1); `keep` names the parts to leave as they are in `from`. */
export function randomAvatar(race: string, sex: AvatarSex, rand: () => number = Math.random, from?: Avatar, keep: readonly (keyof Avatar)[] = []): Avatar {
  const pick = <T>(list: readonly T[]): T => list[Math.floor(rand() * list.length) % list.length]!;
  const base = defaultAvatar(race, sex);
  const o = avatarOptions(base.race, sex);
  const skin = pick(o.skin);
  const out: Avatar = {
    ...base,
    face: pick(AVATAR_FACES),
    eyes: pick(AVATAR_EYES),
    brows: pick(AVATAR_BROWS),
    mouth: pick(o.mouth),
    hair: pick(o.hair),
    skin,
    hairColor: pick(AVATAR_HAIR_COLORS.filter((c) => !CLASHES[skin]?.includes(c))),
    ...(o.flame.length ? { flame: pick(o.flame) } : {}),
  };
  if (from && from.race === out.race && from.sex === out.sex) for (const k of keep) (out as Record<string, unknown>)[k] = from[k];
  return out;
}

// ── Presence (GUILD.md §3) ────────────────────────────────────────────────────────────────────────────────────────────

/** focus: a pomodoro or focus mode is running; online: the Mac app is open; away: open but the computer is idle. */
export type Presence = "focus" | "online" | "away" | "offline";
/** The Mac says how it is when that changes, and at least this often; quieter than this and it counts as offline. */
export const PRESENCE_HEARTBEAT_SECONDS = 120;
export const PRESENCE_TTL_SECONDS = 300;

export const presenceInput = z.object({ state: z.enum(["focus", "online", "away", "offline"]) });

/** What a member's last report means now. */
export function presenceNow(state: string | null | undefined, at: Date | null | undefined, now: Date): Presence {
  if (!state || !at || state === "offline") return "offline";
  if (now.getTime() - at.getTime() > PRESENCE_TTL_SECONDS * 1000) return "offline";
  return state as Presence;
}

// ── API ───────────────────────────────────────────────────────────────────────────────────────────────────────────────

export const guildNameSchema = z
  .string()
  .trim()
  .min(GUILD_NAME_MIN, `公會名字至少 ${GUILD_NAME_MIN} 個字。`)
  .max(GUILD_NAME_MAX, `公會名字最多 ${GUILD_NAME_MAX} 個字。`);

export const guildCreateInput = z.object({ name: guildNameSchema, badge: badgeSchema.optional() });
export const guildUpdateInput = z.object({ name: guildNameSchema.optional(), badge: badgeSchema.optional() });
export const guildInviteInput = z
  .object({
    /** Their friend code, e.g. GOB-7K2QXM. */
    code: z
      .string()
      .trim()
      .regex(/^[A-Za-z]{3}-[A-Za-z0-9]{4,12}$/)
      .optional(),
    userId: z.uuid().optional(),
  })
  .refine((v) => !!v.code !== !!v.userId, "code or userId");
export const guildRoleInput = z.object({ role: z.enum(["leader", "officer", "member"]) });

export interface GuildMemberView {
  id: string;
  name: string;
  race: string;
  role: GuildRole;
  joinedAt: string;
  avatar: Avatar;
  presence: Presence;
  /** When their Mac last said anything (null: never). */
  seenAt: string | null;
  /** Focus rounds done today (Taipei). */
  focusToday: number;
}

export interface GuildView {
  id: string;
  name: string;
  badge: string;
  level: number;
  /** guildLevel(level), for the client's convenience. */
  rules: GuildLevel;
  createdAt: string;
  members: GuildMemberView[];
  /** Who was invited and has not answered (seen by the leader and officers). */
  invited: { id: string; name: string; race: string; at: string }[];
  /** The decorations put down (shared/src/guild-decor.ts), and the version to send back when changing them. */
  decor: import("./guild-decor.ts").GuildDecorPlaced[];
  decorVersion: number;
  floor: import("./guild-decor.ts").HallFloor;
  wall: string;
  /** The races among the members (each unlocks its decoration set). */
  races: string[];
}

export interface GuildInviteView {
  guildId: string;
  name: string;
  badge: string;
  members: number;
  by: string;
  at: string;
}

/** `GET /api/guild`. */
export interface GuildResponse {
  guild: GuildView | null;
  /** The invitations this account has (when not in a guild). */
  invites: GuildInviteView[];
  /** Until when this account may not join or found a guild (null: it may). */
  waitUntil: string | null;
  /** This account's avatar (its saved one, or the race's default). */
  avatar: Avatar;
  /** Whether `avatar` was chosen (false: the default, never saved). */
  avatarChosen: boolean;
}

/** The names the avatar maker shows for each option id. */
export const AVATAR_LABELS: Record<string, string> = {
  // faces, eyes, brows
  round: "圓", pointed: "尖", square: "方",
  narrow: "細長", sparkle: "大閃", dot: "豆豆", sleepy: "睏睏", sharp: "銳利", lashes: "長睫毛", wide: "圓睜",
  thin: "細眉", thick: "粗眉", faint: "淡眉", none: "無眉",
  // mouths
  line: "一字", smile: "微笑", smirk: "歪嘴笑", open: "張嘴", pout: "嘟嘴", cat: "貓嘴",
  teeth: "一排牙", grin: "咧嘴", gap: "缺牙", jaw: "下巴骨", fang: "尖牙", stitch: "縫線",
  // hair
  tuft: "亂翹一撮", mohawk: "莫霍克", topknot: "沖天辮", bald_ring: "光頭加耳環", dreads: "髒辮", wild: "狂野亂髮", bun: "頭頂小髻", spikes: "刺刺頭",
  braids: "雙麻花", pigtails: "雙馬尾", bob: "短鮑伯",
  neat: "短俐落", long: "長直髮", halfup: "半紮", ponytail: "長馬尾", side_braid: "側編辮", waves: "及腰波浪", messy: "蓬鬆", braided_crown: "編髮頭冠",
  long_wreath: "長直髮・花冠", wreath_updo: "花環盤髮",
  hood: "兜帽", bare: "光頭骨", crack: "頭骨裂痕", horns: "小角", long_horns: "長角", ragged_hood: "破兜帽", bone_crown: "骨冠", candle: "頭頂蠟燭",
  drift: "飄散的靈髮", flame: "火焰髮", mist: "霧狀長髮", wisp_twins: "雙馬尾鬼火", glass_short: "半透明短髮", long_wave: "長波浪", side_wisp: "側邊靈絲", flame_crown: "火焰冠",
  // skins
  light: "淺綠", grass: "草綠", moss: "苔綠", deep: "深綠",
  fair: "白皙", warm: "暖膚", tan: "小麥", bronze: "古銅",
  bone: "骨白", ivory: "象牙", ash: "灰骨", slate: "石灰",
  pale_blue: "淡藍", ice: "冰藍", pale_violet: "淡紫", lavender: "薰衣草",
  // hair colours and eye flames
  black: "黑", darkbrown: "深棕", chestnut: "栗色", orange: "橘紅", yellow: "蜜黃", blonde: "淡金", silver: "銀白", pink: "粉紅", mint: "薄荷", navy: "深藍", forest: "森綠",
  cyan: "青", violet: "紫", green: "綠",
};

// ── Walking one's avatar by hand, and talking (GUILD.md §3.1) ──────────────────────────────────────────────────────────

/** While someone walks their avatar, their page sends where it is this often at most, and at least every heartbeat. */
export const GUILD_MOVE_MS = 120;
export const GUILD_MOVE_HEARTBEAT_MS = 4000;
/** Heard nothing for this long: they let go (their avatar goes back to doing things by itself). */
export const GUILD_MOVE_STALE_MS = 12_000;
/** No key, tap or click for this long: the page lets go by itself. */
export const GUILD_MOVE_IDLE_MS = 120_000;

/** Where a hand-walked avatar is and what it is doing (tiles; the anims of shared/src/guild-hall.ts). */
export const guildMoveSchema = z.object({
  x: z.number().finite().min(0).max(64),
  y: z.number().finite().min(0).max(64),
  dir: z.enum(["front", "back", "side"]),
  flip: z.boolean(),
  anim: z.enum(["idle", "walk", "sit", "type", "doze", "drink", "wave", "stretch", "chat", "cheer"]),
});
export type GuildMove = z.infer<typeof guildMoveSchema>;

/** What a page sends up the WebSocket. */
export const guildClientMessage = z.discriminatedUnion("type", [
  z.object({ type: z.literal("guild.move") }).extend(guildMoveSchema.shape),
  z.object({ type: z.literal("guild.release") }),
]);

export const GUILD_SAY_MAX = 120;
/** Lines one account may say in a minute. */
export const GUILD_SAY_PER_MINUTE = 20;
/** How long a line stays over its sayer's head. */
export const GUILD_BUBBLE_MS = 6000;
export const guildSayInput = z.object({ text: z.string().trim().min(1).max(GUILD_SAY_MAX) });

export interface GuildChatLine {
  id: string;
  userId: string;
  name: string;
  text: string;
  at: string;
}
