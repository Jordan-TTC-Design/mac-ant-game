<script setup lang="ts">
import { FEEDBACK_KIND_LABEL, FEEDBACK_STATUS_LABEL, FEEDBACK_STATUSES, FEEDBACK_VOTE_LABEL, type FeedbackDetail, type FeedbackStatus } from "@goblincamp/shared";
import { ApiError, api } from "~/utils/api";
import { noteTime } from "~/utils/time";

// One report: what was sent, and the thread under it (answers, and each status an admin set). Admins change the status
// here; the author and admins can write.
const ok = await useSignedIn();
const route = useRoute();
const id = computed(() => String(route.params.id));
const item = ref<FeedbackDetail | null>(null);
const admin = computed(() => !!item.value?.admin);
const problem = ref("");

async function load() {
  try {
    item.value = await api<FeedbackDetail>("GET", `feedback/${id.value}`);
    nextStatus.value = item.value.status;
  } catch (e) {
    problem.value = e instanceof ApiError ? e.message : String(e);
  }
}
onMounted(load);

const canWrite = computed(() => !!item.value && (item.value.mine || admin.value));
const reply = ref("");
const nextStatus = ref<FeedbackStatus>("open");
const busy = ref(false);
const actError = ref("");

async function run(fn: () => Promise<FeedbackDetail>, clear = true) {
  busy.value = true;
  actError.value = "";
  try {
    item.value = await fn();
    nextStatus.value = item.value.status;
    if (clear) reply.value = "";
  } catch (e) {
    actError.value = e instanceof ApiError ? e.message : String(e);
  } finally {
    busy.value = false;
  }
}
/** An admin with a new status sends both at once (the text becomes the note on the change). */
function send() {
  if (admin.value && nextStatus.value !== item.value?.status)
    return run(() => api("POST", `feedback/${id.value}/status`, { status: nextStatus.value, note: reply.value.trim() || undefined }));
  if (!reply.value.trim()) return;
  return run(() => api("POST", `feedback/${id.value}/replies`, { body: reply.value }));
}
/** 我也遇到 / 我也想要, or taking it back. */
function vote() {
  if (!item.value) return;
  const method = item.value.voted ? "DELETE" : "PUT";
  return run(() => api(method, `feedback/${id.value}/vote`), false);
}
async function remove() {
  if (!confirm("要刪除這則回報嗎？")) return;
  try {
    await api("DELETE", `feedback/${id.value}`);
    await navigateTo("/feedback");
  } catch (e) {
    actError.value = e instanceof ApiError ? e.message : String(e);
  }
}
const statusChanging = computed(() => admin.value && item.value && nextStatus.value !== item.value.status);
</script>

<template>
  <main v-if="ok" class="page">
    <header class="topbar">
      <NuxtLink to="/feedback" class="icon-btn">← 回報</NuxtLink>
      <h1>回報</h1>
    </header>
    <div v-if="!item" class="panel">{{ problem || "讀取中…" }}</div>
    <template v-else>
      <section class="panel">
        <div class="tags">
          <span :class="['tag', 'k-' + item.kind]">{{ FEEDBACK_KIND_LABEL[item.kind] }}</span>
          <span :class="['tag', 's-' + item.status]">{{ FEEDBACK_STATUS_LABEL[item.status] }}</span>
        </div>
        <h2>{{ item.title }}</h2>
        <p class="muted small">{{ item.author }}{{ item.mine ? "（你）" : "" }}・{{ noteTime(item.createdAt) }}</p>
        <p v-if="item.body" class="body">{{ item.body }}</p>
        <p v-if="item.device" class="muted tiny">裝置：{{ item.device }}</p>
        <div class="vote">
          <button v-if="!item.mine" :class="['btn', { voted: item.voted }]" :disabled="busy" :aria-pressed="item.voted" @click="vote">
            👍 {{ FEEDBACK_VOTE_LABEL[item.kind] }}{{ item.voted ? "（已 +1）" : "" }}
          </button>
          <span class="muted small">{{ item.votes ? `${item.votes} 人${FEEDBACK_VOTE_LABEL[item.kind].slice(1)}` : item.mine ? "還沒有人 +1" : "" }}</span>
        </div>
        <div class="steps" aria-label="處理進度">
          <span v-for="s in FEEDBACK_STATUSES.filter((s) => s !== 'declined')" :key="s" :class="{ on: s === item.status, past: FEEDBACK_STATUSES.indexOf(s) < FEEDBACK_STATUSES.indexOf(item.status) && item.status !== 'declined' }">
            {{ FEEDBACK_STATUS_LABEL[s] }}
          </span>
        </div>
      </section>

      <section class="panel">
        <h3>回覆與進度</h3>
        <p v-if="!item.thread.length" class="muted small">還沒有回覆。</p>
        <div v-for="r in item.thread" :key="r.id" :class="['msg', { admin: r.admin }]">
          <p class="who">
            <b>{{ r.author }}</b><span v-if="r.admin" class="tag gold">管理員</span>
            <small class="muted">{{ noteTime(r.at) }}</small>
          </p>
          <p v-if="r.status" class="change">狀態改為 <span :class="['tag', 's-' + r.status]">{{ FEEDBACK_STATUS_LABEL[r.status] }}</span></p>
          <p v-if="r.body" class="body">{{ r.body }}</p>
        </div>

        <div v-if="canWrite" class="write">
          <label v-if="admin" class="field">
            <span>狀態</span>
            <select v-model="nextStatus">
              <option v-for="s in FEEDBACK_STATUSES" :key="s" :value="s">{{ FEEDBACK_STATUS_LABEL[s] }}</option>
            </select>
          </label>
          <textarea v-model="reply" rows="3" maxlength="4000" :placeholder="admin ? '回覆（改狀態時會一起送出，可留空）' : '補充說明…'" aria-label="回覆" />
          <p v-if="actError" class="status error">{{ actError }}</p>
          <div class="actions">
            <button v-if="admin || (item.mine && item.status === 'open')" class="btn danger" :disabled="busy" @click="remove">刪除</button>
            <button class="btn primary" :disabled="busy || (!statusChanging && !reply.trim())" @click="send">{{ statusChanging ? "更新狀態" : "送出" }}</button>
          </div>
        </div>
        <p v-else class="muted small">只有回報的人和管理員能回覆。</p>
      </section>
    </template>
  </main>
</template>

<style scoped>
h2 { font-size: 18px; margin: 8px 0 4px; overflow-wrap: anywhere; }
h3 { font-size: 15px; margin: 0 0 8px; }
.muted { color: var(--muted); }
.small { font-size: 13px; margin: 0; }
.tiny { font-size: 11px; overflow-wrap: anywhere; }
.body { white-space: pre-wrap; overflow-wrap: anywhere; margin: 10px 0 0; line-height: 1.55; }
.tags { display: flex; gap: 5px; flex-wrap: wrap; }
.tag { font-size: 11px; font-weight: 700; border-radius: 6px; padding: 1px 7px; background: #eee; color: #555; }
.tag.gold { background: #fff0b8; color: #8a6a00; margin-left: 6px; }
.k-bug { background: #fbe3df; color: #a8321f; }
.k-idea { background: #e1f3e6; color: #22683f; }
.k-balance { background: #ece4f8; color: #5e3fa0; }
.s-open { background: #eee; color: #555; }
.s-accepted { background: #e2ecfa; color: #2d5a9a; }
.s-working { background: #fff0b8; color: #8a6a00; }
.s-next { background: #ffe1c2; color: #a2530c; }
.s-done { background: #2f7d4f; color: #fff; }
.s-declined { background: #ddd; color: #777; text-decoration: line-through; }
.vote { display: flex; align-items: center; gap: 10px; margin-top: 12px; flex-wrap: wrap; }
.vote .btn { font-size: 14px; min-height: 36px; padding: 6px 12px; }
.vote .btn.voted { background: #fff0b8; color: #8a6a00; }
.steps { display: flex; gap: 4px; margin-top: 14px; }
.steps span { flex: 1; text-align: center; font-size: 11px; padding: 5px 0; border-radius: 6px; background: #f0efe8; color: #999; }
.steps span.past { background: #d9ecde; color: #2f7d4f; }
.steps span.on { background: var(--green); color: #fff; font-weight: 700; }
.msg { padding: 10px; border-radius: 10px; background: #f6f5ef; margin-top: 8px; }
.msg.admin { background: #fff8dc; border-left: 3px solid #e0b400; }
.who { margin: 0; display: flex; align-items: center; gap: 6px; flex-wrap: wrap; }
.who small { margin-left: auto; font-size: 11px; }
.msg .body { margin-top: 6px; }
.change { margin: 6px 0 0; font-size: 13px; }
.write { margin-top: 14px; display: grid; gap: 8px; }
.write .field { display: flex; align-items: center; gap: 8px; margin: 0; font-size: 14px; }
.write select { border: 1px solid var(--line); border-radius: 8px; padding: 6px 8px; font-size: 16px; }
.write textarea { width: 100%; box-sizing: border-box; border: 1px solid var(--line); border-radius: 10px; padding: 10px; font: inherit; font-size: 16px; resize: vertical; }
.actions { display: flex; gap: 8px; justify-content: flex-end; }
</style>
