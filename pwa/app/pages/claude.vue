<script setup lang="ts">
import type { ClaudeAsk } from "@goblincamp/shared";
import { noteTime } from "~/utils/time";
import { ApiError } from "~/utils/api";

// Claude Code's questions from the Mac, while you are away from it (turned on in the Mac's menu 「Claude Code」). A yes here
// is for this once only; "always allow" is only on the Mac.
const ok = await useSignedIn();
const live = useLive();
const c = computed(() => live.state.claude);
const now = ref(Date.now());
let clock: ReturnType<typeof setInterval> | undefined;
onMounted(() => {
  void live.loadClaude();
  clock = setInterval(() => (now.value = Date.now()), 1000);
});
onUnmounted(() => clearInterval(clock));

const replies = reactive<Record<string, string>>({});
const busy = ref<string | null>(null);
const problem = ref("");
async function answer(q: ClaudeAsk, action: "allow" | "deny" | "reply" | "dismiss") {
  busy.value = q.id;
  problem.value = "";
  try {
    await live.answerClaude(q.id, action, action === "reply" ? replies[q.id] : undefined);
  } catch (e) {
    problem.value = e instanceof ApiError ? e.message : String(e);
    await live.loadClaude();
  } finally {
    busy.value = null;
  }
}
const left = (q: ClaudeAsk) => {
  const s = Math.max(0, Math.round((Date.parse(q.until ?? "") - now.value) / 1000));
  return s >= 60 ? `還等 ${Math.floor(s / 60)} 分鐘` : `還等 ${s} 秒`;
};
const answerText = (q: ClaudeAsk) => {
  if (!q.answer) return q.kind === "done" ? "做完了" : "沒人回答";
  const who = q.answer.by === "phone" ? "手機" : "電腦";
  return { allow: `${who}允許了`, deny: `${who}拒絕了`, reply: `${who}回覆：${q.answer.text ?? ""}`, dismiss: q.answer.by === "mac" ? "在電腦上處理了" : "略過" }[q.answer.action];
};
</script>

<template>
  <main v-if="ok" class="page">
    <header class="topbar">
      <NuxtLink to="/" class="icon-btn">← 首頁</NuxtLink>
      <div style="flex: 1">
        <h1>Claude</h1>
        <div class="sub">離開電腦時，Claude 的問題會送到這裡</div>
      </div>
    </header>

    <p v-if="problem" class="problem">{{ problem }}</p>
    <section v-for="q in c?.waiting ?? []" :key="q.id" class="panel ask">
      <div class="head">
        <b>{{ q.kind === "permission" ? "要你允許" : "Claude 停下來了" }}</b>
        <small>{{ q.project }}・{{ left(q) }}</small>
      </div>
      <p class="what">{{ q.text || (q.kind === "permission" ? "（沒有說明）" : "要不要跟它說什麼？") }}</p>
      <div v-if="q.kind === 'permission'" class="buttons">
        <button class="btn primary" :disabled="busy === q.id" @click="answer(q, 'allow')">允許這一次</button>
        <button class="btn danger" :disabled="busy === q.id" @click="answer(q, 'deny')">拒絕</button>
      </div>
      <form v-else class="reply" @submit.prevent="answer(q, 'reply')">
        <textarea v-model="replies[q.id]" rows="2" placeholder="例如：繼續，順便把測試補上" />
        <div class="buttons">
          <button class="btn primary" :disabled="busy === q.id || !replies[q.id]?.trim()">送給 Claude</button>
          <button type="button" class="btn" :disabled="busy === q.id" @click="answer(q, 'dismiss')">先不用</button>
        </div>
      </form>
    </section>
    <section v-if="c && !c.waiting.length" class="panel">
      <p class="muted">現在沒有在等你的問題。</p>
      <p class="muted small">
        要開啟：在 Mac 的選單「連接 Claude Code → 離開電腦時送到手機」打勾。之後你離開電腦超過 2 分鐘（或在專注模式），Claude 要你允許、或停下來問你時，就會推播到這支手機；回到電腦前就照常在電腦上回答。
      </p>
    </section>

    <section v-if="c?.recent.length" class="panel">
      <h2>最近</h2>
      <div v-for="q in c.recent" :key="q.id" class="past">
        <small>{{ noteTime(q.at) }}・{{ q.project }}</small>
        <p>{{ q.text }}</p>
        <small class="outcome">{{ answerText(q) }}</small>
      </div>
      <p class="muted small">這些紀錄一天後會自動刪掉。</p>
    </section>
  </main>
</template>

<style scoped>
.ask { border: 3px solid #e2a23f; }
h2 { margin: 0 0 6px; font-size: 17px; }
.head { display: flex; justify-content: space-between; align-items: baseline; gap: 8px; }
.head small { color: #888; }
.what { font-family: ui-monospace, Menlo, monospace; font-size: 14px; background: #f4f1e6; border-radius: 8px; padding: 8px 10px; word-break: break-word; }
.buttons { display: flex; gap: 8px; flex-wrap: wrap; }
.reply textarea { width: 100%; border: 1px solid var(--line); border-radius: 10px; padding: 8px 10px; font-size: 16px; margin-bottom: 8px; box-sizing: border-box; }
.past { border-top: 1px solid rgba(0, 0, 0, 0.06); padding: 8px 0; }
.past p { margin: 3px 0; font-size: 14px; word-break: break-word; }
.past small { color: #888; }
.outcome { color: #2f7a3a !important; font-weight: 700; }
.muted { color: #666; }
.small { font-size: 12px; line-height: 1.6; }
.problem { color: #ffd1c7; }
</style>
