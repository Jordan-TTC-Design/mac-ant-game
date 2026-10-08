/**
 * 動態 (server/CAMP.md §23): what happened at the camp, one line each, newest first, for the phone and the Mac's main window
 * (`GET /api/camp/feed`). Made from the camp's events (camp_events): the server keeps nothing more for it. Births and deaths
 * of age come every few minutes, so a run of them makes one line.
 */
import { FOES } from "../world/contents.ts";
import { materialName } from "../world/drops.ts";
import type { CampEvent } from "./api.ts";
import { FOCUS_MERCHANT_ROUNDS, FOCUS_RANCH_ROUNDS, FOCUS_RARE_ROUNDS } from "./focus.ts";
import { RANCH_KINDS } from "./ranch.ts";

/** What a race's residents are called. */
export const RACE_NOUNS: Record<string, string> = { goblin: "哥布林", elf: "精靈", undead: "死靈" };

export interface FeedEntry {
  seq: number;
  at: string;
  icon: string;
  text: string;
  /** What sort of thing (for the page to colour or filter): camp, merchant, focus, ranch, raid, world, quest. */
  sort: "camp" | "merchant" | "focus" | "ranch" | "raid" | "world" | "quest";
}

/** `GET /api/camp/feed`: the newest first; `more` when there is older to ask for (`?before=<the last seq>`). */
export interface FeedResponse {
  entries: FeedEntry[];
  more: boolean;
}

const list = (items: Record<string, number>, top = 4) =>
  Object.entries(items)
    .filter(([, n]) => n > 0)
    .sort((a, b) => b[1] - a[1])
    .slice(0, top)
    .map(([id, n]) => `${materialName(id)} ×${n}`)
    .join("、");
const kinds = (ids: string[]) => {
  const counts = new Map<string, number>();
  for (const id of ids) counts.set(id, (counts.get(id) ?? 0) + 1);
  return [...counts].map(([id, n]) => `${RANCH_KINDS[id]?.name ?? id}${n > 1 ? ` ${n} 隻` : ""}`).join("、");
};

type Data = Record<string, any>; // eslint-disable-line @typescript-eslint/no-explicit-any

/** One event as a line (null: nothing worth a line, e.g. the decorations moved or the story saved). */
export function feedEntry(e: CampEvent, noun = "居民"): FeedEntry | null {
  const d = (e.data ?? {}) as Data;
  const line = (icon: string, text: string, sort: FeedEntry["sort"]): FeedEntry => ({ seq: e.seq, at: e.at, icon, text, sort });
  switch (e.kind) {
    case "started":
      return line("🏕️", d.replaced ? "開了新的營地。" : "營地開張了！", "camp");
    case "migrated":
      return line("🏕️", `從這台 Mac 搬來了 ${d.came ?? d.residents ?? 0} 隻${noun}。`, "camp");
    case "population": {
      const born = (d.born ?? []).length, died = (d.died ?? []).length;
      const parts = [born ? `生了 ${born} 隻${noun}` : "", died ? `${died} 隻老死了` : ""].filter(Boolean);
      return parts.length ? line(born ? "🐣" : "🕯️", parts.join("，") + "。", "camp") : null;
    }
    case "raid": {
      const count = (d.monsters ?? []).reduce((n: number, m: { count: number }) => n + m.count, 0);
      const names = (d.monsters ?? []).map((m: { id: string; count: number }) => `${FOES[m.id]?.name ?? m.id}${m.count > 1 ? ` ×${m.count}` : ""}`).join("、");
      const won = d.winner === "camp";
      const fallen = (d.fallen ?? []).length;
      const loot = list(d.loot ?? {}, 3);
      return line("⚔️", `魔獸來襲（${names || `${count} 隻`}）：${won ? "打退了" : "被搶了一陣"}${fallen ? `，倒下 ${fallen} 隻` : ""}${loot ? `，撿到 ${loot}` : ""}。`, "raid");
    }
    case "site":
      return line("🏗️", d.kind === "farm" ? `${d.name}升級了（Lv${d.level}）。` : d.level <= 1 ? `${d.name}蓋好了！` : `${d.name}升到 Lv${d.level}。`, "camp");
    case "focus": {
      const r = d.rounds as number;
      const perk = r === FOCUS_MERCHANT_ROUNDS ? "商人會多來一次" : r === FOCUS_RANCH_ROUNDS ? "牧場今天生得快" : r === FOCUS_RARE_ROUNDS ? "商人會帶稀有貨" : "";
      return line("🍅", `專注完一輪 ${d.minutes} 分鐘（今天第 ${r} 輪）${perk ? `：${perk}！` : "。"}`, "focus");
    }
    case "command": {
      const kind = d.command?.kind as string | undefined;
      const message = (d.message as string) || "";
      switch (kind) {
        case "merchant-arrive":
          return d.visit ? line("🛒", message, "merchant") : null;
        case "merchant-trade":
          return line("🔁", `跟商人交易：${message.replace(/^用 /, "")}`, "merchant");
        case "quest-claim":
          return line("🎁", message, "quest");
        case "ranch-sync": {
          const born = d.born as string[] | undefined, caught = d.caught as string[] | undefined;
          const parts = [born?.length ? `${kinds(born)}出生了` : "", caught?.length ? `抓到${kinds(caught)}` : ""].filter(Boolean);
          return parts.length ? line("🐑", `牧場：${parts.join("，")}。`, "ranch") : null;
        }
        case "craft":
        case "repair":
          return message ? line("🔨", message, "camp") : null;
        case "site-build":
        case "site-upgrade":
        case "farm-upgrade":
          return message ? line("🏗️", message, "camp") : null;
        case "princess-name":
        case "princess-child":
          return message ? line("👑", message, "camp") : null;
        case "food":
          return message ? line("🍖", message, "camp") : null;
        case "guild-donate":
          return message ? line("🏰", message, "camp") : null;
        default:
          return null; // (gear moved about, the decorations, the story: not worth a line)
      }
    }
    case "expedition": {
      if (d.setOut) return line("🚶", `派出 ${d.party} 隻出發了。`, "world");
      if (d.defended) return line("🛡️", `${d.by}來攻打我們的領地：${d.won ? "守住了" : "被打下了"}${d.fallen ? `，倒下 ${d.fallen} 隻` : ""}。`, "world");
      if (!d.arrived || !d.against) return null;
      const loot = list(d.loot ?? {}, 3);
      const what = d.kind === "move" || d.cell === "settled" ? `住進了${d.against}` : d.cell === "back" ? `到了${d.against}，沒事做就回來了` : `${d.won ? "打贏" : "打輸"}${d.against}`;
      return line("⚔️", `出征的隊伍${what}${d.fallen ? `，倒下 ${d.fallen} 隻` : ""}${loot ? `，撿到 ${loot}` : ""}。`, "world");
    }
    case "world": {
      if (d.bossReward) return line("👑", `大家一起打倒了世界魔王${d.bossReward.name}，分到 ${list(d.bossReward.loot ?? {}, 3)}。`, "world");
      if (d.yields && Object.keys(d.yields).length) return line("📦", `領地送來了 ${list(d.yields)}。`, "world");
      if (d.lairBack) return line("🛡️", `${d.lairBack.name}（${d.lairBack.level} 級）回來搶領地：${d.lairBack.held ? "守住了" : "被搶回去了"}。`, "world");
      if (d.opened) return line("🌍", d.again ? "重新開啟了大世界。" : "開啟了大世界！", "world");
      if (d.built) return line("🏗️", `領地上蓋好了建築（Lv${d.built.level}）。`, "world");
      if (d.town) return line("🏰", "蓋好了一座城鎮！", "world");
      if (d.nest) return line("🥚", "領地的繁殖巢開工了。", "world");
      if (d.movedHome) return line("🏕️", "營地搬家了。", "world");
      return null;
    }
    default:
      return null;
  }
}

/** Events (newest first) as lines, a run of births and deaths as one. */
export function feedEntries(events: readonly CampEvent[], noun = "居民"): FeedEntry[] {
  const out: FeedEntry[] = [];
  let run: { born: number; died: number; first: CampEvent } | null = null;
  const flush = () => {
    if (!run) return;
    const merged = feedEntry({ ...run.first, kind: "population", data: { born: Array(run.born).fill(0), died: Array(run.died).fill(0) } }, noun);
    if (merged) out.push(merged);
    run = null;
  };
  for (const e of events) {
    if (e.kind === "population") {
      const d = (e.data ?? {}) as Data;
      run ??= { born: 0, died: 0, first: e };
      run.born += (d.born ?? []).length;
      run.died += (d.died ?? []).length;
      continue;
    }
    const entry = feedEntry(e, noun);
    if (!entry) continue;
    flush();
    out.push(entry);
  }
  flush();
  return out;
}
