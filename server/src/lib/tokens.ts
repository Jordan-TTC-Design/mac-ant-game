import { createHash, randomBytes, randomInt } from "node:crypto";
import { CODE_ALPHABET } from "@goblincamp/shared";

/** A secret for a session or an email link: 32 random bytes. The prefix makes a leaked one easy to recognise. */
export function newToken(prefix: "gcs" | "gce" | "gch"): string {
  return `${prefix}_${randomBytes(32).toString("base64url")}`;
}

/** Only this is stored, so the database alone never holds a usable token or code. */
export function hashSecret(secret: string): Buffer {
  return createHash("sha256").update(secret).digest();
}

/** `length` characters people can read aloud and type (see CODE_ALPHABET). */
export function newCode(length: number): string {
  let out = "";
  for (let i = 0; i < length; i++) out += CODE_ALPHABET[randomInt(CODE_ALPHABET.length)];
  return out;
}

/** 「gob-7k2q xm」→「GOB7K2QXM」: what was typed, the way it is hashed and compared. */
export function normalizeCode(typed: string): string {
  return typed.toUpperCase().replace(/[^0-9A-Z]/g, "");
}

/** An invite as it is handed out: GOBLIN-ABCD-EFGH (40 bits; each works once and they are rate limited). */
export function newInviteCode(): string {
  return `GOBLIN-${newCode(4)}-${newCode(4)}`;
}

/** A friend code: GOB-7K2QXM. */
export function newFriendCode(): string {
  return `GOB-${newCode(6)}`;
}
