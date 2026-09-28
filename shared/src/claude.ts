/**
 * Claude Code's questions answered from the phone (server/DESIGN.md §15). When a Mac has it on and its person is away,
 * a question Claude asks on that Mac (may it run this, anything to say before it stops) is sent here with a short summary;
 * the phones get a push, and the first answer (from the phone, or on the Mac itself) goes back to the waiting Mac. Only
 * "allow this once": never "always allow" from afar. Kept for a day at most.
 */
import { z } from "zod";

export const CLAUDE_TEXT_MAX = 300;
/** The longest a Mac may keep Claude waiting for a phone's answer. */
export const CLAUDE_WAIT_MAX = 900;

export const claudeAskInput = z.object({
  /** The hook's own id for the question. */
  id: z.string().regex(/^[A-Za-z0-9-]{8,64}$/),
  /** permission: may it do this; reply: it stopped, anything to say; done: it finished (news only, no answer). */
  kind: z.enum(["permission", "reply", "done"]),
  project: z.string().max(60),
  /** What it wants to do, or the end of what it last said. */
  text: z.string().max(CLAUDE_TEXT_MAX),
  /** How long the Mac will wait for an answer (not for `done`). */
  waitSeconds: z.number().int().min(10).max(CLAUDE_WAIT_MAX).optional(),
});
export type ClaudeAskInput = z.infer<typeof claudeAskInput>;

export const claudeAnswerInput = z.object({
  action: z.enum(["allow", "deny", "reply", "dismiss"]),
  text: z.string().trim().max(500).optional(),
});
export type ClaudeAnswerInput = z.infer<typeof claudeAnswerInput>;

export interface ClaudeAsk {
  id: string;
  kind: "permission" | "reply" | "done";
  project: string;
  text: string;
  /** The Mac it came from. */
  device: string;
  at: string;
  /** No answer can go back after this (the Mac stopped waiting). */
  until: string | null;
  answer: null | { action: ClaudeAnswerInput["action"]; text?: string; by: "mac" | "phone"; at: string };
}

/** `GET /api/claude`: questions still waiting, then the latest few (answered, or news), newest first. */
export interface ClaudeResponse {
  waiting: ClaudeAsk[];
  recent: ClaudeAsk[];
}

/** The push a phone gets about a question (or news). */
export interface ClaudePush {
  type: "claude";
  title: string;
  body: string;
  url: string;
  tag: string;
  /** A question the notification's own buttons can answer (允許這一次 / 拒絕), where the phone shows them. */
  ask?: { id: string; kind: "permission" | "reply" };
}
