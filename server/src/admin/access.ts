import type { AppDeps } from "../app.ts";

/** The addresses in ADMIN_EMAILS (lower case): they become admins the first time they open 後台. */
export function bootstrapAdmins(deps: Pick<AppDeps, "config">): Set<string> {
  return new Set((deps.config.ADMIN_EMAILS ?? "").split(",").map((e) => e.trim().toLowerCase()).filter(Boolean));
}

/** Whether this account may open 後台 (an admin, or about to become one through ADMIN_EMAILS). */
export function canAdmin(deps: Pick<AppDeps, "config">, user: { email: string; role: "user" | "admin" }): boolean {
  return user.role === "admin" || bootstrapAdmins(deps).has(user.email.toLowerCase());
}
