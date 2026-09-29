<script setup lang="ts">
import type { CampView, QuestView } from "@goblincamp/shared/camp";
import { itemRule, materialName } from "@goblincamp/shared/world";
import { ApiError, api } from "~/utils/api";

// 任務: small goals for the first days (shared/src/camp/quests.ts), by chapter; a finished one's reward is taken here.
const ok = await useSignedIn();
const list = ref<QuestView[] | null>(null);
const problem = ref("");
const message = ref("");
const busy = ref<string | null>(null);

async function load() {
  try {
    list.value = (await api<{ quests: QuestView[] }>("GET", "camp/quests")).quests;
    problem.value = "";
  } catch (e) {
    problem.value = e instanceof ApiError ? e.message : String(e);
  }
}
const onChanged = () => void load();
onMounted(() => {
  window.addEventListener("gc:camp-changed", onChanged);
  void load();
});
onUnmounted(() => window.removeEventListener("gc:camp-changed", onChanged));

async function claim(q: QuestView) {
  busy.value = q.id;
  message.value = "";
  problem.value = "";
  try {
    const res = await api<{ message: string; camp: CampView }>("POST", "camp/commands", { kind: "quest-claim", quest: q.id, requestId: crypto.randomUUID() });
    message.value = `${res.message} ${rewardText(q)}`;
    await load();
  } catch (e) {
    problem.value = e instanceof ApiError ? e.message : String(e);
  } finally {
    busy.value = null;
  }
}

const CHAPTERS = ["營地", "大世界", "夥伴"];
const chapter = ref("營地");
/** Ready to claim first, then those under way (the most done first), then the claimed. */
const shown = computed(() =>
  (list.value ?? [])
    .filter((q) => q.chapter === chapter.value)
    .sort((a, b) => Number(b.done && !b.claimed) - Number(a.done && !a.claimed) || Number(a.claimed) - Number(b.claimed) || b.have / b.need - a.have / a.need),
);
const ready = (c: string) => (list.value ?? []).filter((q) => q.chapter === c && q.done && !q.claimed).length;
const claimedCount = computed(() => (list.value ?? []).filter((q) => q.claimed).length);

function rewardText(q: QuestView): string {
  const parts: string[] = [];
  for (const [id, n] of Object.entries(q.reward.materials ?? {})) parts.push(`${materialName(id)} ×${n}`);
  const gear = new Map<string, number>();
  for (const id of q.reward.gear ?? []) gear.set(id, (gear.get(id) ?? 0) + 1);
  for (const [id, n] of gear) parts.push(`${GEAR.find((g) => g.id === id)?.name ?? id}${n > 1 ? ` ×${n}` : ""}`);
  if (q.reward.residents) parts.push(`新居民 ${q.reward.residents} 隻`);
  if (q.unlocks) parts.push(`解鎖道具「${itemRule(q.unlocks)?.name ?? q.unlocks}」`);
  return parts.join("、");
}
</script>

<template>
  <main v-if="ok" class="page">
    <header class="topbar">
      <NuxtLink to="/camp" class="icon-btn">← 營地</NuxtLink>
      <div style="flex: 1">
        <h1>任務</h1>
        <div v-if="list" class="sub">完成了 {{ claimedCount }} 個・做完就能領獎勵</div>
      </div>
    </header>

    <nav class="tabs">
      <button v-for="c in CHAPTERS" :key="c" :class="{ on: chapter === c }" @click="chapter = c">
        {{ c }}<i v-if="ready(c)" class="dot">{{ ready(c) }}</i>
      </button>
    </nav>
    <p v-if="message" class="panel ok">{{ message }}</p>
    <p v-if="problem" class="panel warn">{{ problem }}</p>

    <div v-if="!list" class="panel">{{ problem || "讀取中…" }}</div>
    <template v-else>
      <article v-for="q in shown" :key="q.id" class="quest" :class="{ ready: q.done && !q.claimed, claimed: q.claimed }">
        <div class="grow">
          <b>{{ q.claimed ? "✅ " : q.done ? "🎁 " : "" }}{{ q.title }}</b>
          <p class="text">{{ q.text }}</p>
          <div v-if="!q.claimed" class="bar" :aria-label="`${q.have}/${q.need}`"><i :style="{ width: `${(100 * q.have) / q.need}%` }" /></div>
          <small class="muted">{{ q.claimed ? "已領" : `${q.have}/${q.need}` }}・獎勵：{{ rewardText(q) }}</small>
        </div>
        <button v-if="!q.claimed" class="btn" :class="{ primary: q.done }" :disabled="!q.done || busy === q.id" @click="claim(q)">
          {{ q.done ? "領獎勵" : "進行中" }}
        </button>
      </article>
      <p class="muted small note">做完一個，同一條線的下一個任務才會出現。</p>
    </template>
  </main>
</template>

<style scoped>
.tabs { display: flex; gap: 6px; margin-bottom: 10px; }
.tabs button { position: relative; flex: 1; border: 0; border-radius: 9px; padding: 8px 0; background: rgba(255, 255, 255, 0.14); color: #fff; font-weight: 700; cursor: pointer; }
.tabs button.on { background: var(--paper-yellow); color: var(--ink); }
.dot { position: absolute; top: -6px; right: 6px; min-width: 18px; height: 18px; border-radius: 9px; background: #e2553f; color: #fff; font-size: 11px; font-style: normal; line-height: 18px; }
.quest { display: flex; align-items: center; gap: 10px; padding: 12px; margin-bottom: 8px; border-radius: 14px; background: var(--card); box-shadow: 0 2px 0 rgba(0, 0, 0, 0.25); }
.quest.ready { border: 2px solid #e0b400; }
.quest.claimed { opacity: 0.6; }
.grow { flex: 1; min-width: 0; display: grid; gap: 4px; }
.text { margin: 0; font-size: 13px; }
.bar { height: 6px; border-radius: 3px; background: #ece9dc; overflow: hidden; }
.bar i { display: block; height: 100%; background: var(--green); }
.muted { color: var(--muted); }
small { font-size: 12px; }
.ok { color: var(--green); font-weight: 700; }
.warn { color: #b3412c; }
.note { color: #fff; opacity: 0.8; text-align: center; }
</style>
