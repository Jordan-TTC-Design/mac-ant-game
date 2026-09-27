import type { Context } from "hono";
import { getConnInfo } from "@hono/node-server/conninfo";
import type { ContentfulStatusCode } from "hono/utils/http-status";
import type { z } from "zod";
import type { ApiError } from "@goblincamp/shared";

export function apiError(c: Context, status: ContentfulStatusCode, error: ApiError["error"], message: string, extra: Partial<ApiError> = {}) {
  const body: ApiError = { error, message, ...extra };
  return c.json(body, status);
}

/** The JSON body checked against `schema`; or the error response to send back. */
export async function readJson<T extends z.ZodType>(c: Context, schema: T): Promise<{ data: z.infer<T> } | { response: Response }> {
  if (!(c.req.header("content-type") ?? "").toLowerCase().startsWith("application/json")) {
    return { response: apiError(c, 415, "unsupported_media_type", "請用 JSON 送出（Content-Type: application/json）。") };
  }
  let raw: unknown;
  try {
    raw = await c.req.json();
  } catch {
    return { response: apiError(c, 400, "invalid_input", "送來的 JSON 格式不對。") };
  }
  const parsed = schema.safeParse(raw);
  if (!parsed.success) {
    const fields: Record<string, string> = {};
    for (const issue of parsed.error.issues) fields[issue.path.join(".") || "_"] ??= issue.message;
    return { response: apiError(c, 400, "invalid_input", "有欄位沒填好。", { fields }) };
  }
  return { data: parsed.data };
}

/** Who is asking: the visitor's address (from Caddy's header when behind it). */
export function clientIp(c: Context, trustProxy: boolean): string {
  if (trustProxy) {
    const forwarded = c.req.header("x-forwarded-for")?.split(",")[0]?.trim();
    if (forwarded) return forwarded;
  }
  try {
    return getConnInfo(c).remote.address ?? "unknown";
  } catch {
    return "unknown"; // (requests made directly by tests have no socket)
  }
}
