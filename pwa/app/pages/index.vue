<script setup lang="ts">
import { DEFAULT_POMODORO, pomodoroPartName, type PomodoroPlan } from "@goblincamp/shared";
import { ApiError } from "~/utils/api";
import { noteTime } from "~/utils/time";

// 今天 (pwa/UI.md §4.1): the pomodoro to start right here, Claude waiting, 公告, and "現在可以做": what waits in each of the
// big parts (they are all in the tab bar), one tap to it.
const ok = await useSignedIn();
const { user } = useAccount();
const notes = useNotes();
const live = useLive();
const nav = useNav();
const camp = useCamp();
const { race, ensure } = useRace();
void ensure();
const now = ref(Date.now());
let clock: ReturnType<typeof setInterval> | undefined;
onMounted(() => {
  clock = setInterval(() => (now.value = Date.now()), 1000);
  live.refresh();
  nav.refresh();
});
onUnmounted(() => {
  clearInterval(clock);
  camp.close();
});
if (ok && user.value) void camp.open(user.value.id);

const todo = computed(() => notes.list.value.filter((n) => n.kind !== "memo" && !n.done));
const nextReminder = computed(() =>
  todo.value
    .filter((n) => n.remindAt && Date.parse(n.remindAt) > now.value)
    .sort((a, b) => Date.parse(a.remindAt!) - Date.parse(b.remindAt!))[0],
);
const run = computed(() => live.pomodoroNow(now.value));
const clockText = computed(() => {
  const s = Math.ceil((run.value?.left ?? 0) / 1000);
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
});
const view = computed(() => camp.state.saved?.view ?? null);
const atHome = computed(() => view.value?.residents.filter((r) => r.place === "home").length ?? 0);
const lastRaid = computed(() => camp.state.saved?.raids[0] ?? null);
const waiting = computed(() => live.state.claude?.waiting ?? []);

// the pomodoro, started from here with the plan last used on this phone (the 番茄鐘 page keeps the same one)
const plan = ref<PomodoroPlan>({ ...DEFAULT_POMODORO });
onMounted(() => {
  try {
    const saved = JSON.parse(localStorage.getItem("gc-pomodoro-plan") ?? "null") as PomodoroPlan | null;
    if (saved) plan.value = saved;
  } catch {
    // (none kept)
  }
});
const planName = computed(() => `${plan.value.focusMinutes} 分專注${plan.value.rounds > 1 ? `・${plan.value.rounds} 輪` : ""}`);
const pomBusy = ref(false);
const pomProblem = ref("");
async function pom(action: Parameters<typeof live.pomodoro>[0]) {
  pomBusy.value = true;
  pomProblem.value = "";
  try {
    await live.pomodoro(action);
  } catch (e) {
    pomProblem.value = e instanceof ApiError ? e.message : String(e);
  } finally {
    pomBusy.value = false;
  }
}

/** 現在可以做: one line per thing waiting, the most pressing first. */
const todoLines = computed(() => {
  const out: { icon: string; to: string; text: string; note?: string; urgent?: boolean }[] = [];
  for (const p of nav.incoming.value.slice(0, 2)) {
    out.push({ icon: "⚔️", to: "/world", text: `${p.by.name} 的 ${p.party} 隻要打「${p.where.label}」`, note: `${noteTime(p.arriveAt)} 到`, urgent: true });
  }
  const v = nav.visitor.value;
  if (v) out.push({ icon: "🚪", to: "/camp", text: "有訪客在營地門口", note: `${noteTime(v.leaves)} 前回答`, urgent: true });
  if (nav.questsReady.value) out.push({ icon: "📜", to: "/quests", text: `${nav.questsReady.value} 個任務可以領獎勵` });
  if (nav.overdue.value) out.push({ icon: "📝", to: "/notes", text: `${nav.overdue.value} 件待辦過期了`, urgent: true });
  else if (nextReminder.value) out.push({ icon: "📝", to: "/notes", text: nextReminder.value.text.split("\n")[0]!.slice(0, 24) || "提醒", note: `${noteTime(nextReminder.value.remindAt!)} 提醒` });
  if (nav.unread.value) out.push({ icon: "💬", to: "/friends", text: `${nav.unread.value} 則新訊息` });
  if (nav.friendAsks.value) out.push({ icon: "🙋", to: "/friends", text: `${nav.friendAsks.value} 人想加你好友` });
  if (nav.guildInvites.value) out.push({ icon: "🏰", to: "/guild", text: `${nav.guildInvites.value} 個公會邀請你` });
  if (nav.merchant.value) out.push({ icon: "🛒", to: "/feed", text: "流浪商人在營地", note: `${noteTime(nav.merchant.value.leavesAt)} 走` });
  if (nav.talentPoints.value) out.push({ icon: "🌟", to: "/talents", text: `還有 ${nav.talentPoints.value} 個天賦點沒點` });
  return out;
});
// 公告 from 後台: shown until closed here (remembered on this phone only)
const closed = ref<string[]>([]);
try {
  closed.value = JSON.parse(localStorage.getItem("gc-announce-closed") ?? "[]") as string[];
} catch {
  closed.value = [];
}
const notices = computed(() => live.state.announcements.filter((a) => !closed.value.includes(a.id)));
function closeNotice(id: string) {
  closed.value = [...closed.value, id].slice(-50);
  try {
    localStorage.setItem("gc-announce-closed", JSON.stringify(closed.value));
  } catch {
    // (private browsing: closed for now only)
  }
}
const answering = ref(false);
const answerProblem = ref("");
async function answer(action: "allow" | "deny") {
  const q = waiting.value[0];
  if (!q) return;
  answering.value = true;
  answerProblem.value = "";
  try {
    await live.answerClaude(q.id, action);
  } catch (e) {
    answerProblem.value = e instanceof Error ? e.message : String(e);
    await live.loadClaude();
  } finally {
    answering.value = false;
  }
}
const hello = computed(() => {
  const h = new Date(now.value).getHours();
  return h < 5 ? "夜深了" : h < 11 ? "早安" : h < 14 ? "午安" : h < 18 ? "下午好" : "晚安";
});
</script>

<template>
  <main v-if="ok" class="page">
    <AppHeader :title="`${hello}，${user?.displayName ?? ''}`" :sub="view ? `在家 ${atHome} 隻${lastRaid ? `・突襲${lastRaid.winner === 'camp' ? '守住了' : '被打敗了'}（${noteTime(lastRaid.at)}）` : ''}` : '哥布林營地'">
      <template #lead><img :src="`/sprites/${race}/icon.png`" class="pixel" width="36" height="36" alt="" /></template>
      <template #actions><NuxtLink to="/settings" aria-label="設定">⚙️</NuxtLink></template>
    </AppHeader>

    <!-- the pomodoro first: started right here; the whole page for the rest -->
    <section class="card pom" :class="{ running: run }">
      <NuxtLink to="/pomodoro" class="pom-head">
        <span class="icon">🍅</span>
        <b class="grow">番茄鐘</b>
        <small class="more">完整頁面 ›</small>
      </NuxtLink>
      <div class="pom-body">
        <NuxtLink to="/pomodoro" class="big">{{ run ? clockText : `${String(plan.focusMinutes).padStart(2, "0")}:00` }}</NuxtLink>
        <div class="pom-side">
          <template v-if="run">
            <small>{{ pomodoroPartName(run.part, run.state.plan.rounds) }}{{ run.paused ? "・暫停" : "" }}</small>
            <button v-if="run.paused" class="btn primary" :disabled="pomBusy" @click="pom({ action: 'resume' })">繼續</button>
            <button v-else class="btn" :disabled="pomBusy" @click="pom({ action: 'pause' })">暫停</button>
          </template>
          <template v-else>
            <button class="btn primary start" :disabled="pomBusy" @click="pom({ action: 'start', plan: { ...plan } })">開始專注</button>
            <NuxtLink to="/pomodoro" class="plan">{{ planName }}・換 ›</NuxtLink>
          </template>
        </div>
      </div>
      <small v-if="pomProblem" class="accent">{{ pomProblem }}</small>
    </section>

    <div v-for="a in notices" :key="a.id" class="card notice">
      <span class="icon">📣</span>
      <component :is="a.url ? 'NuxtLink' : 'div'" :to="a.url ?? undefined" class="grow">
        <b>{{ a.title }}</b>
        <small v-if="a.body">{{ a.body }}</small>
      </component>
      <button class="close" aria-label="關掉這則公告" @click="closeNotice(a.id)">×</button>
    </div>

    <!-- Claude waiting for an answer comes first: a yes or no right here for a permission -->
    <div v-if="waiting.length" class="card claude-wait">
      <NuxtLink to="/claude" class="wait-head">
        <span class="icon">🤖</span>
        <span class="grow">
          <b>Claude 在等你（{{ waiting.length }}）</b>
          <small>{{ waiting[0]!.project }}：{{ waiting[0]!.text || (waiting[0]!.kind === "permission" ? "要你允許" : "停下來了") }}</small>
        </span>
        <span class="go">›</span>
      </NuxtLink>
      <div v-if="waiting[0]!.kind === 'permission'" class="wait-buttons">
        <button class="btn primary" :disabled="answering" @click="answer('allow')">允許這一次</button>
        <button class="btn danger" :disabled="answering" @click="answer('deny')">拒絕</button>
      </div>
      <NuxtLink v-else to="/claude" class="btn wait-reply">回它一句 ›</NuxtLink>
      <small v-if="answerProblem" class="accent">{{ answerProblem }}</small>
    </div>

    <h2 class="section">現在可以做</h2>
    <div class="card todo">
      <NuxtLink v-for="(t, k) in todoLines" :key="k" :to="t.to" class="todo-row">
        <span class="icon">{{ t.icon }}</span>
        <span class="grow">{{ t.text }}<small v-if="t.note" :class="{ accent: t.urgent }">{{ t.note }}</small></span>
        <span class="go">›</span>
      </NuxtLink>
      <p v-if="!todoLines.length" class="calm">沒有要處理的事，去營地看看大家吧 🎉</p>
    </div>
  </main>
</template>

<style scoped>
.card {
  display: grid; align-content: start; gap: 3px; padding: 12px; border-radius: 16px; background: #fffdf6; color: var(--ink);
  text-decoration: none; border: 3px solid #1f1f1f; box-shadow: 3px 3px 0 rgba(0, 0, 0, 0.35); margin-bottom: 12px;
}
.card .icon { font-size: 22px; line-height: 1.1; }
.card small { color: #666; font-size: 12px; line-height: 1.4; }
.card .accent, .accent { color: #c0392b; font-weight: 700; }
.grow { flex: 1; min-width: 0; }
.notice { display: flex; gap: 10px; background: #fff6d6; align-items: flex-start; }
.notice .grow { display: grid; gap: 2px; text-decoration: none; color: inherit; }
.notice small { white-space: pre-line; overflow-wrap: anywhere; }
.notice .close { border: 0; background: none; font-size: 22px; line-height: 1; padding: 0 4px; color: #8a6a00; cursor: pointer; }
.pom { background: #fdf0e9; gap: 8px; }
.pom.running { background: #fde7df; }
.pom-head { display: flex; align-items: center; gap: 8px; color: inherit; text-decoration: none; }
.pom-head b { font-size: 16px; }
.pom-head .more { color: #8a3b22; font-weight: 700; }
.pom-body { display: flex; align-items: center; gap: 14px; }
.big { font-size: 44px; font-weight: 900; letter-spacing: -1px; font-variant-numeric: tabular-nums; font-family: ui-monospace, Menlo, monospace; color: inherit; text-decoration: none; }
.pom-side { flex: 1; display: grid; gap: 6px; justify-items: stretch; text-align: center; }
.pom-side .start { min-height: 48px; font-size: 16px; font-weight: 800; border: 2px solid #1f1f1f; }
.pom-side .plan { font-size: 12px; color: #6b4a3a; text-decoration: none; }
.claude-wait { background: #ffe9b8; border-color: #b36b00; gap: 8px; }
.wait-head { display: flex; align-items: center; gap: 10px; color: inherit; text-decoration: none; }
.claude-wait .grow { display: grid; }
.claude-wait .grow small { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.wait-buttons { display: flex; gap: 8px; }
.wait-buttons .btn { flex: 1; min-height: 44px; }
.wait-reply { text-decoration: none; }
.go { font-weight: 800; color: #999; }
.section { margin: 4px 0 8px; color: #fff; font-size: 14px; opacity: 0.9; }
.todo { padding: 0; gap: 0; overflow: hidden; }
.todo-row { display: flex; align-items: center; gap: 10px; min-height: 52px; padding: 10px 14px; color: inherit; text-decoration: none; border-top: 1px solid rgba(0, 0, 0, 0.1); }
.todo-row:first-child { border-top: 0; }
.todo-row .grow { display: grid; font-size: 15px; }
.calm { margin: 0; padding: 16px; color: #666; text-align: center; }
</style>
