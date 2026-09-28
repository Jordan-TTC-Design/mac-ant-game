import { and, eq, isNotNull } from "drizzle-orm";
import type { PushSubscriptionJSON, ReminderPush } from "@goblincamp/shared";
import type { AppDeps } from "../app.ts";
import { camps, devices } from "../db/schema.ts";

/** Reminders older than this when found (the server was down) are not pushed any more. */
const STALE_HOURS = 24;

/** Who is on the note, by the account's race (the Mac's character manifests; a note's breed is one of these five). */
const BREED_NAMES: Record<string, Record<string, string>> = {
  goblin: { common: "哥布林", scout: "敏捷哥布林", brute: "壯碩哥布林", sage: "聰明哥布林", golden: "金皮哥布林" },
  elf: { common: "精靈", scout: "綠斗篷精靈", brute: "樹皮精靈", sage: "鹿角精靈", golden: "銀月精靈" },
  undead: { common: "骷髏", scout: "幽影", brute: "巨骨", sage: "鬼火", golden: "黑曜骨" },
};

/**
 * Finds the reminders that are due and not pushed yet, and pushes each to its owner's phones. Each reminder time is
 * pushed once (`pushed_for`); a snooze sets a new time, which is pushed again. Several servers could run this at once.
 * Returns how many reminders were due.
 */
export async function pushDueReminders(deps: Pick<AppDeps, "database" | "push">, now: Date): Promise<number> {
  const { db, sql: raw } = deps.database;
  const due = await raw<{ id: string; user_id: string; text: string; breed: string; goblin_name: string }[]>`
    update notes set pushed_for = remind_at
    where id in (
      select id from notes
      where remind_at <= ${now.toISOString()}::timestamptz
        and remind_at > ${new Date(now.getTime() - STALE_HOURS * 3_600_000).toISOString()}::timestamptz
        and not deleted and pushed_for is distinct from remind_at
      order by remind_at
      limit 200
      for update skip locked
    )
    returning id, user_id, text, breed, goblin_name`;
  for (const note of due) {
    const phones = await db
      .select({ id: devices.id, subscription: devices.pushSubscription })
      .from(devices)
      .where(and(eq(devices.userId, note.user_id), eq(devices.kind, "pwa"), isNotNull(devices.pushSubscription)));
    const [camp] = await db.select({ race: camps.race }).from(camps).where(eq(camps.userId, note.user_id));
    const names = BREED_NAMES[camp?.race ?? "goblin"] ?? BREED_NAMES.goblin!;
    const who = names[note.breed] ?? names.common!;
    const payload: ReminderPush = {
      type: "reminder",
      noteId: note.id,
      title: note.goblin_name ? `${note.goblin_name}・${who}` : who,
      body: note.text.split("\n").filter(Boolean).slice(0, 3).join("\n").slice(0, 120) || "時間到啦！便利貼上的事！",
    };
    for (const phone of phones) {
      const outcome = await deps.push.send(phone.subscription as PushSubscriptionJSON, payload);
      if (outcome === "gone") await db.update(devices).set({ pushSubscription: null }).where(eq(devices.id, phone.id));
    }
  }
  return due.length;
}

/** Runs `pushDueReminders` every 15 seconds; returns a function that stops it. */
export function startReminderLoop(deps: Pick<AppDeps, "database" | "push">, everyMs = 15_000): () => void {
  let running = false;
  const timer = setInterval(async () => {
    if (running) return;
    running = true;
    try {
      await pushDueReminders(deps, new Date());
    } catch (err) {
      console.error("reminder loop:", err);
    } finally {
      running = false;
    }
  }, everyMs);
  return () => clearInterval(timer);
}

