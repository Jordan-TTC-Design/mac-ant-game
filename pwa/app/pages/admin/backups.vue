<script setup lang="ts">
import type { AdminBackupFile, AdminBackupList } from "@goblincamp/shared";
import { api } from "~/utils/api";
import { bytes, errText } from "~/utils/admin";
import { noteTime } from "~/utils/time";

// 後台 › 備份: twice a day by themselves (kept 7 days), and by hand from here (kept until deleted).
const { ask } = useConfirm();
const backups = ref<AdminBackupList | null>(null);
const problem = ref("");
const note = ref("");
const backingUp = ref(false);

async function load() {
  try {
    backups.value = await api<AdminBackupList>("GET", "admin/backups");
  } catch (e) {
    problem.value = errText(e);
  }
}
onMounted(load);

async function backUpNow() {
  backingUp.value = true;
  note.value = "";
  try {
    const made = await api<AdminBackupFile>("POST", "admin/backups");
    note.value = `備份好了：${made.name}（${bytes(made.size)}）`;
    await load();
  } catch (e) {
    note.value = errText(e);
  } finally {
    backingUp.value = false;
  }
}
async function remove(f: AdminBackupFile) {
  if (!(await ask({ title: `刪除備份 ${f.name}？`, body: "刪掉就找不回來了。", yes: "刪除", danger: true }))) return;
  try {
    await api("DELETE", `admin/backups/${f.kind}/${f.name}`);
    await load();
  } catch (e) {
    problem.value = errText(e);
  }
}
</script>

<template>
  <div>
    <div v-if="problem" class="panel status error">{{ problem }}</div>
    <section v-if="backups" class="panel">
      <h2>資料庫備份</h2>
      <p v-if="!backups.enabled" class="muted">伺服器沒有設定備份資料夾（BACKUP_DIR），目前沒有備份。</p>
      <template v-else>
        <p class="muted small">每天 01:30、13:30 自動備份，保留 {{ backups.keepDays }} 天。下一次：{{ noteTime(backups.next) }}<span v-if="backups.running">・正在備份中…</span></p>
        <div v-if="backups.failures.length" class="fails">
          <b>最近備份失敗</b>
          <p v-for="(f, k) in backups.failures" :key="k" class="small">{{ noteTime(f.at) }}（{{ f.kind === "auto" ? "自動" : "手動" }}）{{ f.error }}</p>
        </div>
        <div class="two">
          <div>
            <h3>自動備份（{{ backups.auto.length }}）</h3>
            <p v-if="!backups.auto.length" class="muted small">還沒有。</p>
            <div class="list">
              <div v-for="f in backups.auto" :key="f.name" class="backup">
                <span>{{ noteTime(f.at) }}<small class="muted">　{{ bytes(f.size) }}</small></span>
                <a class="btn small" :href="`/api/admin/backups/auto/${f.name}`" download>下載</a>
                <button class="btn small" @click="remove(f)">刪除</button>
              </div>
            </div>
          </div>
          <div>
            <h3>手動備份（{{ backups.manual.length }}／{{ backups.manualMax }}）</h3>
            <div class="row">
              <button class="btn primary" :disabled="backingUp || !!backups.running || backups.manual.length >= backups.manualMax" @click="backUpNow">{{ backingUp ? "備份中…" : "立即備份" }}</button>
            </div>
            <p v-if="note" class="small">{{ note }}</p>
            <p v-if="!backups.manual.length" class="muted small">還沒有。手動備份會一直留著，直到你刪掉。</p>
            <div class="list">
              <div v-for="f in backups.manual" :key="f.name" class="backup">
                <span>{{ noteTime(f.at) }}<small class="muted">　{{ bytes(f.size) }}</small></span>
                <a class="btn small" :href="`/api/admin/backups/manual/${f.name}`" download>下載</a>
                <button class="btn small" @click="remove(f)">刪除</button>
              </div>
            </div>
          </div>
        </div>
        <p class="muted small">還原要在伺服器上做（會蓋掉整個資料庫）：<code>make backup-copy file=auto/檔名</code>，再 <code>make restore-db file=backups/檔名</code>。詳見 README。</p>
      </template>
    </section>
    <div v-else-if="!problem" class="panel">讀取中…</div>
  </div>
</template>

<style scoped>
.backup { display: flex; align-items: center; gap: 6px; }
.backup > span { flex: 1; min-width: 0; font-size: 14px; }
.fails { background: #fbd9d6; color: var(--red); border-radius: 10px; padding: 8px 12px; margin: 8px 0; }
.fails p { margin: 4px 0 0; overflow-wrap: anywhere; }
.two { column-gap: 20px; }
</style>
