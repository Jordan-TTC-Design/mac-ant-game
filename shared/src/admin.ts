/**
 * 後台 (server/DESIGN.md §12): what the admin pages and the server say to each other. Reads only; the inputs are checked on
 * the server.
 */
import { z } from "zod";

export type AdminRole = "user" | "admin";

export interface AdminOverview {
  users: { all: number; verified: number; active1: number; active7: number };
  devices: { macs: number; phones: number };
  notes: number;
  camps: Record<string, number>;
  residents: number;
  world: { open: number; heldCells: number; walking: number; fought: number };
  invites: { free: number; used: number; expired: number };
  /** Reports nobody has looked at yet (status open). */
  feedbackOpen: number;
}

/** One day (Taiwan time) of the trend: who came that day, and who signed up. */
export interface AdminDay {
  day: string;
  active: number;
  signups: number;
}
export interface AdminStats {
  days: AdminDay[];
}

export const ADMIN_USER_STATUSES = ["all", "admin", "disabled", "deleting", "unverified"] as const;
export type AdminUserStatus = (typeof ADMIN_USER_STATUSES)[number];
export const ADMIN_USER_SORTS = ["created", "lastSeen"] as const;
export type AdminUserSort = (typeof ADMIN_USER_SORTS)[number];

export interface AdminUserRow {
  id: string;
  email: string;
  name: string;
  friendCode: string;
  createdAt: string;
  verified: boolean;
  deleting: boolean;
  role: AdminRole;
  disabled: boolean;
  camp: { race: string; population: number; peak: number; cells: number } | null;
  devices: number;
  lastSeenAt: string | null;
}
export interface AdminUserPage {
  users: AdminUserRow[];
  /** Pass as `cursor` for the next page (null: that was the last). */
  next: string | null;
  /** How many match, all pages together. */
  total: number;
}

export interface AdminUserDetail {
  id: string;
  email: string;
  name: string;
  friendCode: string;
  role: AdminRole;
  verified: boolean;
  verifiedAt: string | null;
  disabled: boolean;
  deletingAt: string | null;
  createdAt: string;
  devices: { id: string; kind: "mac" | "pwa"; name: string; lastSeenAt: string; signedIn: boolean; push: boolean }[];
  camp: { race: string; population: number; peak: number; startedAt: string } | null;
  world: { xp: number; cells: number; walking: number; homeCell: string } | null;
  guild: { id: string; name: string; level: number; role: "leader" | "officer" | "member" } | null;
  friends: number;
  blocked: number;
  notes: number;
  feedback: number;
  /** The camp's latest events, newest first. */
  events: { at: string; kind: string }[];
  history: { at: string; action: string; admin: string | null; detail: Record<string, unknown> | null }[];
}

export interface AdminLogRow {
  id: string;
  at: string;
  action: string;
  admin: string | null;
  target: string | null;
  targetId: string | null;
  detail: Record<string, unknown> | null;
}
export interface AdminLogPage {
  log: AdminLogRow[];
  next: string | null;
}

export interface AdminInviteRow {
  id: string;
  createdAt: string;
  expiresAt: string;
  usedAt: string | null;
  usedBy: string | null;
  /** Who made it (null: the server's command line). */
  createdBy: string | null;
  state: "free" | "used" | "expired";
}

export interface AdminBackupFile {
  kind: "auto" | "manual";
  name: string;
  size: number;
  at: string;
}
export type AdminBackupList =
  | { enabled: false }
  | {
      enabled: true;
      running: string | null;
      next: string;
      keepDays: number;
      manualMax: number;
      auto: AdminBackupFile[];
      manual: AdminBackupFile[];
      failures: { at: string; kind: string; error: string }[];
    };

/** Counts over the last 24 hours (kept in memory: they start again from 0 when the server restarts). */
export interface AdminSendCounts {
  sent: number;
  failed: number;
  gone?: number;
}
export interface AdminHealth {
  apiVersion: number;
  /** The commit the server was built from (null: not set at build time). */
  commit: string | null;
  startedAt: string;
  node: string;
  database: { bytes: number; tables: { name: string; bytes: number; rows: number }[] };
  /** Devices connected over the WebSocket right now, and how many accounts they are. */
  live: { sockets: number; users: number };
  maintenance: { at: string; cleared: Record<string, number> } | null;
  push: AdminSendCounts & { configured: boolean };
  mail: AdminSendCounts & { lastErrors: { at: string; error: string }[] };
  backups: { enabled: boolean; next: string | null; lastAuto: string | null; failures: number };
}

// ── 公告 ───────────────────────────────────────────────

export const ANNOUNCE_AUDIENCES = ["all", "admins"] as const;
export type AnnounceAudience = (typeof ANNOUNCE_AUDIENCES)[number];
export const ANNOUNCE_TITLE_MAX = 60;
export const ANNOUNCE_BODY_MAX = 500;
/** A push to everyone at most this often (so a slip of the finger does not wake everybody twice). */
export const ANNOUNCE_PUSH_EVERY_MS = 60_000;

export const announceInput = z.object({
  title: z.string().trim().min(1).max(ANNOUNCE_TITLE_MAX),
  body: z.string().trim().max(ANNOUNCE_BODY_MAX).default(""),
  /** A page of the app to open (a path like /guild), or nothing. */
  url: z
    .string()
    .trim()
    .max(200)
    .regex(/^\/[^\s]*$/, "要是 / 開頭的網址")
    .nullable()
    .default(null),
  audience: z.enum(ANNOUNCE_AUDIENCES).default("all"),
  /** Shown until then (null: until taken down). */
  endsAt: z.iso.datetime().nullable().default(null),
  push: z.boolean().default(false),
});
export type AnnounceInput = z.input<typeof announceInput>;

/** What a person sees: a banner on the phone's home page, a notice on the Mac. */
export interface Announcement {
  id: string;
  title: string;
  body: string;
  url: string | null;
  at: string;
}
export interface AnnouncementsResponse {
  announcements: Announcement[];
}

export interface AdminAnnouncement extends Announcement {
  audience: AnnounceAudience;
  endsAt: string | null;
  /** Taken down (or ended): no longer shown. */
  over: boolean;
  by: string | null;
  /** Phones it was pushed to (null: not pushed). */
  pushed: number | null;
}
export interface AdminAnnouncementList {
  announcements: AdminAnnouncement[];
}
/** How many would get it: accounts, and phones that take pushes. */
export interface AnnounceAudienceCount {
  users: number;
  phones: number;
}
