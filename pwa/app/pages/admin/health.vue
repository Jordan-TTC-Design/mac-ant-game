<script setup lang="ts">
import type { AdminHealth } from "@goblincamp/shared";
import { api } from "~/utils/api";
import { bytes, errText } from "~/utils/admin";
import { noteTime } from "~/utils/time";

// 後台 › 伺服器: how the server itself is doing (counts of pushes and mails start again when it restarts).
const h = ref<AdminHealth | null>(null);
const problem = ref("");
const loading = ref(false);
async function load() {
  loading.value = true;
  try {
    h.value = await api<AdminHealth>("GET", "admin/health");
    problem.value = "";
  } catch (e) {
    problem.value = errText(e);
  } finally {
    loading.value = false;
  }
}
onMounted(load);

const CLEARED: Record<string, string> = {
  events: "營地事件",
  replays: "戰報重播",
  reports: "戰報",
  rewards: "戰利品紀錄",
  sessions: "登入",
  links: "信件連結",
  invites: "邀請碼",
  accounts: "帳號",
  claude: "Claude 問題",
  active: "每日紀錄",
};
const uptime = computed(() => {
  if (!h.value) return "";
  const ms = Date.now() - Date.parse(h.value.startedAt);
  const d = Math.floor(ms / 86_400_000);
  const hours = Math.floor((ms % 86_400_000) / 3_600_000);
  return d ? `${d} 天 ${hours} 小時` : `${hours} 小時 ${Math.floor((ms % 3_600_000) / 60_000)} 分`;
});
</script>

<template>
  <div>
    <div v-if="problem" class="panel status error">{{ problem }}</div>
    <template v-if="h">
      <section class="panel">
        <div class="head">
          <h2>伺服器</h2>
          <button class="btn small" :disabled="loading" @click="load">重新整理</button>
        </div>
        <div class="stats">
          <div><b>{{ uptime }}</b><small>已經跑了</small></div>
          <div><b>{{ h.live.users }}</b><small>現在連線的帳號（{{ h.live.sockets }} 條連線）</small></div>
          <div><b>{{ bytes(h.database.bytes) }}</b><small>資料庫大小</small></div>
        </div>
        <p class="small muted">API 版本 {{ h.apiVersion }}・{{ h.commit ? `程式 ${h.commit.slice(0, 8)}` : "沒有記錄程式版本" }}・Node {{ h.node }}・{{ noteTime(h.startedAt) }} 啟動</p>
      </section>

      <div class="two">
        <section class="panel">
          <h2>推播（最近 24 小時）</h2>
          <p v-if="!h.push.configured" class="status error">沒有設定 VAPID 金鑰，手機收不到推播。</p>
          <template v-else>
            <p class="small">送出 <b>{{ h.push.sent }}</b>・失敗 <b :class="{ bad: h.push.failed }">{{ h.push.failed }}</b>・手機已取消訂閱 {{ h.push.gone }}</p>
            <p class="small muted">「已取消訂閱」是對方關掉通知或刪掉 App，伺服器會自動忘記那支手機。</p>
          </template>
        </section>
        <section class="panel">
          <h2>寄信（最近 24 小時）</h2>
          <p class="small">寄出 <b>{{ h.mail.sent }}</b>・失敗 <b :class="{ bad: h.mail.failed }">{{ h.mail.failed }}</b></p>
          <template v-if="h.mail.lastErrors.length">
            <h3>最近寄不出去</h3>
            <p v-for="(e, k) in h.mail.lastErrors" :key="k" class="small err">{{ noteTime(e.at) }}　{{ e.error }}</p>
          </template>
        </section>
      </div>

      <div class="two">
        <section class="panel">
          <h2>定期清除舊資料</h2>
          <p v-if="!h.maintenance" class="small muted">這次啟動後還沒跑過（啟動一分鐘後第一次，之後每 6 小時）。</p>
          <template v-else>
            <p class="small">上次 {{ noteTime(h.maintenance.at) }}</p>
            <p class="small muted">
              <template v-for="(n, k) in h.maintenance.cleared" :key="k"><span v-if="n">{{ CLEARED[k] ?? k }} {{ n }}　</span></template>
              <span v-if="!Object.values(h.maintenance.cleared).some(Boolean)">沒有需要清的。</span>
            </p>
          </template>
        </section>
        <section class="panel">
          <h2>備份</h2>
          <p v-if="!h.backups.enabled" class="status error">沒有設定備份資料夾（BACKUP_DIR）。</p>
          <template v-else>
            <p class="small">上次自動備份：{{ h.backups.lastAuto ? noteTime(h.backups.lastAuto) : "還沒有" }}・下一次 {{ h.backups.next ? noteTime(h.backups.next) : "—" }}</p>
            <p v-if="h.backups.failures" class="small bad">最近 24 小時失敗 {{ h.backups.failures }} 次</p>
            <NuxtLink to="/admin/backups" class="small">看備份 ›</NuxtLink>
          </template>
        </section>
      </div>

      <section class="panel">
        <h2>最大的資料表</h2>
        <table>
          <thead><tr><th>表</th><th>大小</th><th>大約幾筆</th></tr></thead>
          <tbody>
            <tr v-for="t in h.database.tables" :key="t.name"><td><code>{{ t.name }}</code></td><td>{{ bytes(t.bytes) }}</td><td>{{ t.rows.toLocaleString() }}</td></tr>
          </tbody>
        </table>
      </section>
    </template>
    <div v-else-if="!problem" class="panel">讀取中…</div>
  </div>
</template>

<style scoped>
.head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }
.head h2 { margin: 0; }
.stats { grid-template-columns: repeat(3, 1fr) !important; }
.stats b { font-size: 18px !important; }
.bad, .err { color: var(--red); }
.err { overflow-wrap: anywhere; }
td code { font-size: 13px; }
</style>
