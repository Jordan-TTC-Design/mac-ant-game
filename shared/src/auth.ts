import { z } from "zod";

/** Letters and digits that cannot be mistaken for each other (no 0/O, 1/I/L, U). */
export const CODE_ALPHABET = "23456789ABCDEFGHJKMNPQRSTVWXYZ";

const email = z.string().trim().max(254).pipe(z.email());
const password = z.string().min(10, "密碼至少要 10 個字").max(200);
const displayName = z
  .string()
  .trim()
  .min(1)
  .max(20)
  .refine((s) => !/[\r\n\t]/.test(s), "名字不能換行");
/** What a code typed by a person may look like before it is cleaned up (spaces, dashes, lower case are fine). */
const typedCode = z.string().trim().min(4).max(40);
const token = z.string().trim().min(20).max(200);

export const deviceSchema = z.object({
  /** Made by the device itself and kept (a Mac keeps it in its settings, a phone in its storage). */
  id: z.uuid(),
  kind: z.enum(["mac", "pwa"]),
  /** 「Jordan 的 MacBook」「iPhone」 */
  name: z.string().trim().min(1).max(60),
});
export type DeviceInput = z.infer<typeof deviceSchema>;

export const registerInput = z.object({ email, password, displayName, inviteCode: typedCode });
export const verifyEmailInput = z.object({ token });
export const emailOnlyInput = z.object({ email });
export const loginInput = z.object({ email, password: z.string().min(1).max(200), device: deviceSchema });
export const resetPasswordInput = z.object({ token, password });

export type RegisterInput = z.infer<typeof registerInput>;
export type LoginInput = z.infer<typeof loginInput>;

export interface PublicUser {
  id: string;
  email: string;
  displayName: string;
  friendCode: string;
}

export interface LoginResult {
  user: PublicUser;
  /** For a Mac: send it as `Authorization: Bearer <token>`. A phone (PWA) gets a cookie instead and no token here. */
  token?: string;
  expiresAt: string;
}

export interface SessionInfo {
  id: string;
  device: { id: string; kind: "mac" | "pwa"; name: string } | null;
  createdAt: string;
  lastSeenAt: string;
  /** The session this request was made with. */
  current: boolean;
}

/** Every error the API sends: a code for programs and a sentence for people. */
export interface ApiError {
  error:
    | "invalid_input"
    | "invite_invalid"
    | "token_invalid"
    | "invalid_credentials"
    | "email_not_verified"
    | "unauthorized"
    | "forbidden"
    | "not_found"
    | "conflict"
    | "rate_limited"
    | "unsupported_media_type"
    | "unavailable"
    | "backup_failed";
  message: string;
  fields?: Record<string, string>;
  retryAfter?: number;
}
