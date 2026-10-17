<script setup lang="ts">
import type { AdminInviteRow } from "@goblincamp/shared";
import { api } from "~/utils/api";
import { errText } from "~/utils/admin";
import { noteTime } from "~/utils/time";

// 後台 › 邀請碼: make some (shown once), see how the ones made were used, take back one not used yet.
const { ask } = useConfirm();
const invites = ref<AdminInviteRow[]>([]);
const problem = ref("");
const count = ref(3);
const days = ref(14);
const fresh = ref<string[]>([]);
const copied = ref(false);
const busy = ref(false);

async function load() {
  try {
    invites.value = (await api<{ invites: AdminInviteRow[] }>("GET", "admin/invites")).invites;
  } catch (e) {
    problem.value = errText(e);
  }
}
onMounted(load);

async function make() {
  busy.value = true;
  problem.value = "";
  try {
    fresh.value = (await api<{ codes: string[] }>("POST", "admin/invites", { count: count.value, days: days.value })).codes;
    copied.value = false;
    await load();
  } catch (e) {
    problem.value = errText(e);
  } finally {
    busy.value = false;
  }
}
async function copyAll() {
  await navigator.clipboard.writeText(fresh.value.join("\n"));
  copied.value = true;
}
async function revoke(i: AdminInviteRow) {
  if (!(await ask({ title: "收回這組邀請碼？", body: `${noteTime(i.createdAt)} 產生、還沒用過的這組，收回後立刻不能用。`, yes: "收回", danger: true }))) return;
  try {
    await api("POST", `admin/invites/${i.id}/revoke`);
    await load();
  } catch (e) {
    problem.value = errText(e);
  }
}

const tally = computed(() => ({
  free: invites.value.filter((i) => i.state === "free").length,
  used: invites.value.filter((i) => i.state === "used").length,
  expired: invites.value.filter((i) => i.state === "expired").length,
}));
const STATE: Record<string, string> = { free: "可以用", used: "用掉了", expired: "過期／收回" };
</script>

<template>
  <div>
    <div v-if="problem" class="panel status error">{{ problem }}</div>
    <section class="panel">
      <h2>產生邀請碼</h2>
      <div class="row">
        <label>幾組 <input v-model.number="count" type="number" min="1" max="50" style="width: 90px" /></label>
        <label>幾天內有效 <input v-model.number="days" type="number" min="1" max="90" style="width: 90px" /></label>
        <button class="btn primary" :disabled="busy" @click="make">產生</button>
      </div>
      <template v-if="fresh.length">
        <p class="muted">只會顯示這一次，請現在複製（每組只能註冊一個帳號）：</p>
        <pre class="codes">{{ fresh.join("\n") }}</pre>
        <button class="btn" @click="copyAll">{{ copied ? "複製了" : "全部複製" }}</button>
      </template>
    </section>

    <section class="panel">
      <h2>邀請碼紀錄</h2>
      <p class="muted small">最近 200 組：可以用 {{ tally.free }}・用掉了 {{ tally.used }}・過期或收回 {{ tally.expired }}</p>
      <div class="list">
        <div v-for="i in invites" :key="i.id" class="invite">
          <span :class="i.state">{{ STATE[i.state] }}</span>
          <small class="muted">
            {{ i.usedBy ? `${i.usedBy}・${noteTime(i.usedAt!)}` : `到 ${noteTime(i.expiresAt)}` }}<br />
            {{ noteTime(i.createdAt) }} 由 {{ i.createdBy ?? "伺服器指令" }} 產生
          </small>
          <button v-if="i.state === 'free'" class="btn small" @click="revoke(i)">收回</button>
        </div>
      </div>
    </section>
  </div>
</template>

<style scoped>
.codes { background: #1f2a1c; color: #e8f0e0; padding: 12px; border-radius: 10px; font-size: 16px; letter-spacing: 1px; user-select: all; white-space: pre-wrap; }
.invite { display: flex; align-items: center; gap: 8px; }
.invite > span { white-space: nowrap; font-weight: 700; }
.invite small { flex: 1; text-align: right; min-width: 0; overflow-wrap: anywhere; }
.free { color: var(--green); }
.used { color: var(--muted); }
.expired { color: var(--red); }
</style>
