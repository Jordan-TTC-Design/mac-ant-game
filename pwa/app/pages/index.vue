<script setup lang="ts">
import { pomodoroPartName } from "@goblincamp/shared";
import { noteTime } from "~/utils/time";

// 首頁: the phone app's big parts, each a card with how it stands now, one tap into it.
const ok = await useSignedIn();
const { user } = useAccount();
const notes = useNotes();
const live = useLive();
const camp = useCamp();
const { race, noun, ensure } = useRace();
void ensure();
const now = ref(Date.now());
let clock: ReturnType<typeof setInterval> | undefined;
onMounted(() => {
  clock = setInterval(() => (now.value = Date.now()), 1000);
  live.refresh();
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
const farmLine = computed(() => {
  const farm = view.value?.production?.farm;
  if (!farm) return "";
  return `${farm.name} Lv${farm.level}・${farm.parts.at(-1)}${farm.upgradingUntil ? `（正在蓋${farm.next?.name}）` : ""}`;
});
const lastRaid = computed(() => camp.state.saved?.raids[0] ?? null);
const friends = computed(() => live.state.friends);
const unread = computed(() => friends.value?.friends.reduce((n, f) => n + f.unread, 0) ?? 0);
const waiting = computed(() => live.state.claude?.waiting ?? []);
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
    <header class="topbar">
      <img :src="`/sprites/${race}/icon.png`" class="pixel" width="36" height="36" alt="" />
      <div style="flex: 1">
        <h1>{{ hello }}，{{ user?.displayName }}</h1>
        <div class="sub">哥布林營地</div>
      </div>
      <NuxtLink to="/settings" class="icon-btn">設定</NuxtLink>
    </header>

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

    <div class="grid">
      <NuxtLink to="/notes" class="card">
        <span class="icon">📝</span>
        <b>便利貼</b>
        <small>{{ todo.length ? `${todo.length} 件待辦` : "沒有待辦" }}</small>
        <small v-if="nextReminder" class="accent">下個提醒 {{ noteTime(nextReminder.remindAt!) }}</small>
      </NuxtLink>

      <NuxtLink to="/pomodoro" class="card" :class="{ running: run }">
        <span class="icon">🍅</span>
        <b>番茄鐘</b>
        <template v-if="run">
          <small>{{ pomodoroPartName(run.part, run.state.plan.rounds) }}{{ run.paused ? "・暫停" : "" }}</small>
          <span class="big">{{ clockText }}</span>
        </template>
        <small v-else>開始專注・和 Mac 同步</small>
      </NuxtLink>

      <NuxtLink to="/camp" class="card">
        <span class="icon">🛖</span>
        <b>營地</b>
        <small>{{ view ? `在家 ${atHome} 隻${noun}` : "讀取中…" }}</small>
        <small v-if="farmLine">{{ farmLine }}</small>
        <small v-if="lastRaid">魔獸來襲 {{ noteTime(lastRaid.at) }}・{{ lastRaid.winner === "camp" ? "守住了" : "被打敗了" }}</small>
      </NuxtLink>

      <NuxtLink to="/world" class="card">
        <span class="icon">🗺️</span>
        <b>大世界</b>
        <small>真實地圖・出征・佔地</small>
      </NuxtLink>

      <NuxtLink to="/friends" class="card">
        <span class="icon">💬</span>
        <b>好友</b>
        <small v-if="unread" class="accent">{{ unread }} 則新訊息</small>
        <small v-else-if="friends?.incoming.length" class="accent">{{ friends.incoming.length }} 人想加你好友</small>
        <small v-else>{{ friends ? `${friends.friends.length} 位好友` : "…" }}</small>
      </NuxtLink>

      <NuxtLink to="/claude" class="card">
        <span class="icon">🤖</span>
        <b>Claude</b>
        <small>{{ waiting.length ? `${waiting.length} 個在等你` : "離開電腦時在這裡回答" }}</small>
      </NuxtLink>
    </div>

    <NuxtLink to="/leaderboard" class="wide-link">🏆 排行榜 ›</NuxtLink>
  </main>
</template>

<style scoped>
.grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
.card {
  display: grid; align-content: start; gap: 3px; min-height: 108px; padding: 12px; border-radius: 16px; background: #fffdf6; color: var(--ink);
  text-decoration: none; border: 3px solid #1f1f1f; box-shadow: 3px 3px 0 rgba(0, 0, 0, 0.35);
}
.card .icon { font-size: 26px; line-height: 1.1; }
.card b { font-size: 16px; }
.card small { color: #666; font-size: 12px; line-height: 1.4; }
.card .accent { color: #c0392b; font-weight: 700; }
.card.running { background: #fde7df; }
.big { font-size: 26px; font-weight: 900; font-variant-numeric: tabular-nums; font-family: ui-monospace, Menlo, monospace; }
.claude-wait { min-height: 0; margin-bottom: 10px; background: #ffe9b8; border-color: #b36b00; gap: 8px; }
.wait-head { display: flex; align-items: center; gap: 10px; color: inherit; text-decoration: none; }
.claude-wait .grow { flex: 1; min-width: 0; display: grid; }
.claude-wait .grow small { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.wait-buttons { display: flex; gap: 8px; }
.wait-buttons .btn { flex: 1; }
.wait-reply { text-decoration: none; }
.go { font-weight: 800; color: #8a4b00; }
.wide-link { display: block; margin-top: 12px; padding: 12px; border-radius: 12px; background: rgba(255, 255, 255, 0.12); color: #fff; text-decoration: none; font-weight: 700; text-align: center; }
</style>
