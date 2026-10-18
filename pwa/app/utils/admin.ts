import type { AdminLogRow } from "@goblincamp/shared";
import { ApiError } from "~/utils/api";

/** 後台's pages: words for what the server says. */
export const errText = (e: unknown) => (e instanceof ApiError ? e.message : String(e));

export const bytes = (n: number) =>
  n >= 1_073_741_824 ? `${(n / 1_073_741_824).toFixed(1)} GB` : n >= 1_048_576 ? `${(n / 1_048_576).toFixed(1)} MB` : `${Math.max(1, Math.round(n / 1024))} KB`;

export const RACES: Record<string, string> = { goblin: "哥布林", elf: "精靈", undead: "死靈", beast: "獸人" };

export const ACTIONS: Record<string, string> = {
  disable: "停用",
  enable: "恢復",
  "sign-out": "強制登出",
  "send-reset": "寄重設密碼信",
  verify: "標記已驗證",
  role: "改角色",
  name: "改名",
  email: "改信箱",
  delete: "刪除",
  restore: "復原",
  invites: "產生邀請碼",
  "invite-revoke": "收回邀請碼",
  backup: "手動備份",
  "backup-download": "下載備份",
  "backup-delete": "刪除備份",
  announce: "發公告",
  "announce-end": "下架公告",
  "feedback-status": "改回報狀態",
  "feedback-delete": "刪除回報",
};

/** The rest of a log line after who and what: to whom, how many, which file, from what to what. */
export function logDetail(l: Pick<AdminLogRow, "detail" | "target">): string {
  const d = l.detail ?? {};
  const parts: string[] = [];
  if (l.target) parts.push(l.target);
  if (d.role) parts.push(d.role === "admin" ? "（管理員）" : "（一般）");
  if (typeof d.count === "number") parts.push(`${d.count} 組${d.by === "cli" ? "（伺服器指令）" : ""}`);
  if (typeof d.name === "string") parts.push(d.name);
  if (typeof d.title === "string") parts.push(`「${d.title}」`);
  if (typeof d.from === "string" && typeof d.to === "string") parts.push(`${d.from} → ${d.to}`);
  return parts.join(" ");
}
