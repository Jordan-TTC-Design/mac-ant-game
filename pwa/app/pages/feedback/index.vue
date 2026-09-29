<script setup lang="ts">
import {
  FEEDBACK_KIND_LABEL,
  FEEDBACK_KINDS,
  FEEDBACK_STATUS_LABEL,
  FEEDBACK_STATUSES,
  type FeedbackKind,
  type FeedbackList,
  type FeedbackStatus,
} from "@goblincamp/shared";
import { ApiError, api } from "~/utils/api";
import { noteTime } from "~/utils/time";

// 回報: send a bug, an idea or a balance note, and see where everyone's stand (fixed, being worked on, in the next update…).
const ok = await useSignedIn();
const list = ref<FeedbackList | null>(null);
const problem = ref("");
/** "active" is everything not yet done or declined. */
const status = ref<FeedbackStatus | "active" | "all">("active");
const kind = ref<FeedbackKind | "">("");
const mine = ref(false);
const sort = ref<"new" | "votes">("new");

async function load() {
  const q = new URLSearchParams();
  if (status.value !== "active" && status.value !== "all") q.set("status", status.value);
  if (kind.value) q.set("kind", kind.value);
  if (mine.value) q.set("mine", "1");
  if (sort.value === "votes") q.set("sort", "votes");
  try {
    list.value = await api<FeedbackList>("GET", `feedback?${q}`);
    problem.value = "";
  } catch (e) {
    problem.value = e instanceof ApiError ? e.message : String(e);
  }
}
onMounted(load);
watch([status, kind, mine, sort], load);

const items = computed(() => (list.value?.items ?? []).filter((i) => status.value !== "active" || (i.status !== "done" && i.status !== "declined")));
const activeCount = computed(() => (list.value ? FEEDBACK_STATUSES.filter((s) => s !== "done" && s !== "declined").reduce((n, s) => n + list.value!.counts[s], 0) : 0));
const total = computed(() => (list.value ? FEEDBACK_STATUSES.reduce((n, s) => n + list.value!.counts[s], 0) : 0));

// sending a new one
const writing = ref(false);
const form = reactive({ kind: "bug" as FeedbackKind, title: "", body: "" });
const sending = ref(false);
const sendError = ref("");
const HINT: Record<FeedbackKind, string> = {
  bug: "發生了什麼事？怎麼做會出現？原本以為會怎樣？",
  idea: "想要哪裡變得更好用？為什麼？",
  balance: "哪裡太強、太弱、太慢或太快？大概想調成怎樣？",
};
async function send() {
  sending.value = true;
  sendError.value = "";
  try {
    const { id } = await api<{ id: string }>("POST", "feedback", { ...form, device: navigator.userAgent.slice(0, 200) });
    Object.assign(form, { title: "", body: "" });
    writing.value = false;
    await navigateTo(`/feedback/${id}`);
  } catch (e) {
    sendError.value = e instanceof ApiError ? (e.code === "invalid_input" ? "標題至少要 2 個字。" : e.message) : String(e);
  } finally {
    sending.value = false;
  }
}
</script>

<template>
  <main v-if="ok" class="page">
    <header class="topbar">
      <NuxtLink to="/" class="icon-btn">← 首頁</NuxtLink>
      <h1>回報</h1>
      <button v-if="!writing" class="icon-btn" @click="writing = true">＋ 回報</button>
    </header>

    <section v-if="writing" class="panel">
      <h2>回報問題或建議</h2>
      <div class="kinds">
        <button v-for="k in FEEDBACK_KINDS" :key="k" :class="['kind', k, { on: form.kind === k }]" @click="form.kind = k">{{ FEEDBACK_KIND_LABEL[k] }}</button>
      </div>
      <div class="field">
        <label for="fb-title">標題</label>
        <input id="fb-title" v-model="form.title" maxlength="80" placeholder="一句話說明" />
      </div>
      <div class="field">
        <label for="fb-body">詳細說明（選填）</label>
        <textarea id="fb-body" v-model="form.body" rows="5" maxlength="4000" :placeholder="HINT[form.kind]" />
      </div>
      <p v-if="sendError" class="status error">{{ sendError }}</p>
      <div class="actions">
        <button class="btn" @click="writing = false">取消</button>
        <button class="btn primary" :disabled="sending || form.title.trim().length < 2" @click="send">送出</button>
      </div>
      <p class="muted small">所有人都看得到回報的標題和內容；管理員會更新處理狀態並回覆你。</p>
    </section>

    <div class="filters">
      <div class="chips">
        <button :class="{ on: status === 'active' }" @click="status = 'active'">進行中 {{ activeCount }}</button>
        <button v-for="s in FEEDBACK_STATUSES" :key="s" :class="[s, { on: status === s }]" @click="status = s">
          {{ FEEDBACK_STATUS_LABEL[s] }} {{ list?.counts[s] ?? "" }}
        </button>
        <button :class="{ on: status === 'all' }" @click="status = 'all'">全部 {{ total }}</button>
      </div>
      <div class="row">
        <select v-model="kind" aria-label="類型">
          <option value="">所有類型</option>
          <option v-for="k in FEEDBACK_KINDS" :key="k" :value="k">{{ FEEDBACK_KIND_LABEL[k] }}</option>
        </select>
        <select v-model="sort" aria-label="排序">
          <option value="new">最新動態</option>
          <option value="votes">最多人 +1</option>
        </select>
        <label class="mine"><input v-model="mine" type="checkbox" /> 只看我的</label>
      </div>
    </div>

    <div v-if="!list" class="panel">{{ problem || "讀取中…" }}</div>
    <section v-else class="panel">
      <p v-if="problem" class="status error">{{ problem }}</p>
      <p v-if="!items.length" class="muted">{{ mine ? "你還沒有這樣的回報。" : "這裡還沒有回報。" }}</p>
      <NuxtLink v-for="i in items" :key="i.id" :to="`/feedback/${i.id}`" class="item">
        <div class="tags">
          <span :class="['tag', 'k-' + i.kind]">{{ FEEDBACK_KIND_LABEL[i.kind] }}</span>
          <span :class="['tag', 's-' + i.status]">{{ FEEDBACK_STATUS_LABEL[i.status] }}</span>
          <span v-if="i.mine" class="tag me">我的</span>
        </div>
        <b class="title">{{ i.title }}</b>
        <small class="muted">{{ i.author }}・{{ noteTime(i.updatedAt) }}{{ i.replies ? `・💬 ${i.replies}` : "" }}</small>
        <span v-if="i.votes" :class="['votes', { on: i.voted }]">👍 {{ i.votes }}</span>
      </NuxtLink>
    </section>
  </main>
</template>

<style scoped>
h2 { font-size: 16px; margin: 0 0 10px; }
.muted { color: var(--muted); }
.small { font-size: 12px; margin: 10px 0 0; }
.kinds { display: flex; gap: 6px; margin-bottom: 12px; }
.kind { flex: 1; border: 2px solid var(--line); background: #fff; border-radius: 10px; padding: 8px 0; font-weight: 700; cursor: pointer; color: var(--ink); }
.kind.on.bug { border-color: #c0392b; background: #fbe3df; }
.kind.on.idea { border-color: #2f7d4f; background: #e1f3e6; }
.kind.on.balance { border-color: #7a5ab8; background: #ece4f8; }
.actions { display: flex; gap: 8px; justify-content: flex-end; }
.filters { margin-bottom: 12px; }
.chips { display: flex; gap: 6px; overflow-x: auto; padding-bottom: 4px; scrollbar-width: none; }
.chips button { flex: none; border: 0; border-radius: 999px; padding: 7px 12px; background: rgba(255, 255, 255, 0.14); color: #fff; font-weight: 700; font-size: 13px; cursor: pointer; }
.chips button.on { background: var(--paper-yellow); color: var(--ink); }
.row { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; margin-top: 8px; color: #fff; }
.row select { border-radius: 9px; border: 0; padding: 7px 10px; font-size: 14px; }
.mine { display: flex; align-items: center; gap: 5px; font-size: 14px; }
.item { position: relative; display: grid; gap: 4px; padding: 11px 52px 11px 2px; border-top: 1px solid var(--line); color: var(--ink); text-decoration: none; }
.item:first-of-type { border-top: 0; }
.title { font-size: 15px; overflow-wrap: anywhere; }
.item small { font-size: 12px; }
.tags { display: flex; gap: 5px; flex-wrap: wrap; }
.tag { font-size: 11px; font-weight: 700; border-radius: 6px; padding: 1px 7px; background: #eee; color: #555; }
.k-bug { background: #fbe3df; color: #a8321f; }
.k-idea { background: #e1f3e6; color: #22683f; }
.k-balance { background: #ece4f8; color: #5e3fa0; }
.s-open { background: #eee; color: #555; }
.s-accepted { background: #e2ecfa; color: #2d5a9a; }
.s-working { background: #fff0b8; color: #8a6a00; }
.s-next { background: #ffe1c2; color: #a2530c; }
.s-done { background: #2f7d4f; color: #fff; }
.s-declined { background: #ddd; color: #777; text-decoration: line-through; }
.votes { position: absolute; right: 2px; top: 50%; transform: translateY(-50%); font-size: 13px; font-weight: 700; padding: 3px 8px; border-radius: 999px; background: #f0efe8; color: #555; }
.votes.on { background: #fff0b8; color: #8a6a00; }
.me { background: #fff6c8; color: #7a6500; }
</style>
