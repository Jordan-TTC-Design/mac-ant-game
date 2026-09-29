/**
 * 回報 (feedback): anyone signed in tells us about a bug, something to make better, or how the game should be balanced;
 * everyone sees the list and where each one stands (fixed, being worked on, in the next update…). Admins move them along
 * and answer; the one who sent it can answer back.
 */
import { z } from "zod";

export const FEEDBACK_KINDS = ["bug", "idea", "balance"] as const;
export type FeedbackKind = (typeof FEEDBACK_KINDS)[number];
export const FEEDBACK_KIND_LABEL: Record<FeedbackKind, string> = { bug: "Bug", idea: "優化建議", balance: "遊戲平衡" };

/** In the order a report usually goes through them. */
export const FEEDBACK_STATUSES = ["open", "accepted", "working", "next", "done", "declined"] as const;
export type FeedbackStatus = (typeof FEEDBACK_STATUSES)[number];
export const FEEDBACK_STATUS_LABEL: Record<FeedbackStatus, string> = {
  open: "待確認",
  accepted: "已收到",
  working: "處理中",
  next: "下次更新",
  done: "已完成",
  declined: "不處理",
};
/** What +1 says on each kind. */
export const FEEDBACK_VOTE_LABEL: Record<FeedbackKind, string> = { bug: "我也遇到", idea: "我也想要", balance: "我也同意" };

/** Done or declined: nothing more will happen to it. */
export const feedbackClosed = (s: FeedbackStatus) => s === "done" || s === "declined";

export const feedbackInputSchema = z.object({
  kind: z.enum(FEEDBACK_KINDS),
  title: z.string().trim().min(2, "標題至少 2 個字").max(80, "標題最多 80 個字"),
  body: z.string().trim().max(4000, "內容最多 4000 個字").default(""),
  /** What it was sent from (app version, phone), to help find a bug. */
  device: z.string().trim().max(200).optional(),
});
export type FeedbackInput = z.input<typeof feedbackInputSchema>;

export const feedbackReplyInputSchema = z.object({ body: z.string().trim().min(1, "請寫點什麼").max(4000, "最多 4000 個字") });

/** An admin moves a report along, optionally saying why in the same step. */
export const feedbackStatusInputSchema = z.object({
  status: z.enum(FEEDBACK_STATUSES),
  note: z.string().trim().max(4000).optional(),
});

export interface FeedbackSummary {
  id: string;
  kind: FeedbackKind;
  title: string;
  status: FeedbackStatus;
  author: string;
  mine: boolean;
  replies: number;
  /** How many others said 我也遇到 / 我也想要, and whether the one asking is one of them. */
  votes: number;
  voted: boolean;
  createdAt: string;
  updatedAt: string;
}

/** One line under a report: somebody wrote, or an admin changed its status (then `status` is the new one). */
export interface FeedbackReply {
  id: string;
  author: string;
  admin: boolean;
  body: string;
  status: FeedbackStatus | null;
  at: string;
}

export interface FeedbackDetail extends FeedbackSummary {
  body: string;
  /** Only shown to admins and the one who sent it. */
  device: string | null;
  thread: FeedbackReply[];
  /** Whether the one asking can change its status. */
  admin: boolean;
}

export interface FeedbackList {
  items: FeedbackSummary[];
  /** How many of each status (for the filter tabs). */
  counts: Record<FeedbackStatus, number>;
  /** Whether the one asking can change statuses. */
  admin: boolean;
}
