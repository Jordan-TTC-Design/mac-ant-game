/**
 * Friends and their messages (server/DESIGN.md §7): a friend is asked for by their friend code (or from their cell on the
 * big world's map) and becomes one when they say yes; only friends can write to each other. A message is at most 200
 * characters and arrives at once (the Mac may later play it as a messenger walking in).
 */
import { z } from "zod";

export const MESSAGE_MAX = 200;
/** Messages one account may send in a day (so nobody is flooded). */
export const MESSAGES_PER_DAY = 300;
/** Asks one account may have waiting at once. */
export const PENDING_ASKS_MAX = 20;

export const friendAskInput = z
  .object({
    /** The other's friend code, e.g. GOB-7K2QXM. */
    code: z
      .string()
      .trim()
      .regex(/^[A-Za-z]{3}-[A-Za-z0-9]{4,12}$/)
      .optional(),
    /** Or who they are (from their cell on the big world's map). */
    userId: z.uuid().optional(),
  })
  .refine((v) => !!v.code !== !!v.userId, "code or userId");

export const messageInput = z.object({ text: z.string().trim().min(1).max(MESSAGE_MAX) });

export interface Person {
  id: string;
  name: string;
  race: string;
}

export interface FriendView extends Person {
  since: string;
  /** Messages from them not read yet. */
  unread: number;
  last: { text: string; at: string; mine: boolean } | null;
}

/** `GET /api/friends`. */
export interface FriendsResponse {
  /** This account's own friend code, to give to others. */
  code: string;
  friends: FriendView[];
  /** Who asked to be friends, waiting for a yes. */
  incoming: (Person & { at: string })[];
  /** Whom this account asked. */
  outgoing: (Person & { at: string })[];
}

export interface ChatMessage {
  id: string;
  mine: boolean;
  text: string;
  at: string;
  /** Read by the one it was sent to. */
  read: boolean;
}

/** `GET /api/friends/:id/messages`: newest last. */
export interface ChatResponse {
  friend: Person;
  messages: ChatMessage[];
  /** There are older ones (ask with `before` = the first one's `at`). */
  more: boolean;
}

/** A push about a message or a friend ask: tapping it opens `url`. */
export interface SocialPush {
  type: "social";
  title: string;
  body: string;
  url: string;
  tag: string;
}
