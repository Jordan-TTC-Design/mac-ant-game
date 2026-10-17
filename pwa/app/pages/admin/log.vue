<script setup lang="ts">
import type { AdminLogPage, AdminLogRow } from "@goblincamp/shared";
import { api } from "~/utils/api";
import { ACTIONS, errText, logDetail } from "~/utils/admin";
import { noteTime } from "~/utils/time";

// 後台 › 管理紀錄: what admins did, newest first; one kind of action, or what was done to one account (?target=).
const route = useRoute();
const action = ref(String(route.query.action ?? ""));
const target = computed(() => (route.query.target ? String(route.query.target) : ""));
const rows = ref<AdminLogRow[]>([]);
const next = ref<string | null>(null);
const loading = ref(false);
const problem = ref("");

async function load(more = false) {
  loading.value = true;
  problem.value = "";
  const params = new URLSearchParams();
  if (action.value) params.set("action", action.value);
  if (target.value) params.set("target", target.value);
  if (more && next.value) params.set("cursor", next.value);
  try {
    const page = await api<AdminLogPage>("GET", `admin/log?${params}`);
    rows.value = more ? [...rows.value, ...page.log] : page.log;
    next.value = page.next;
  } catch (e) {
    problem.value = errText(e);
  } finally {
    loading.value = false;
  }
}
onMounted(() => load());
watch([action, target], () => load());
</script>

<template>
  <section class="panel">
    <div class="head">
      <h2>管理紀錄</h2>
      <select v-model="action" aria-label="只看哪一種">
        <option value="">全部</option>
        <option v-for="(label, key) in ACTIONS" :key="key" :value="key">{{ label }}</option>
      </select>
    </div>
    <p v-if="target" class="small">只看對 <b>{{ rows[0]?.target ?? "這個帳號" }}</b> 做的事　<NuxtLink to="/admin/log">看全部</NuxtLink></p>
    <div v-if="problem" class="status error">{{ problem }}</div>
    <p v-if="!rows.length && !loading" class="muted">沒有。</p>
    <div class="list">
      <p v-for="l in rows" :key="l.id" class="small">
        <span class="muted">{{ noteTime(l.at) }}</span>　{{ l.admin ?? "伺服器指令" }} <b>{{ ACTIONS[l.action] ?? l.action }}</b>
        <NuxtLink v-if="l.targetId" :to="`/admin/users/${l.targetId}`">{{ logDetail(l) }}</NuxtLink>
        <template v-else>{{ logDetail(l) }}</template>
      </p>
    </div>
    <button v-if="next" class="btn more" :disabled="loading" @click="load(true)">{{ loading ? "讀取中…" : "再載入" }}</button>
  </section>
</template>

<style scoped>
.head { display: flex; justify-content: space-between; align-items: center; gap: 8px; margin-bottom: 8px; }
.head h2 { margin: 0; }
.head select { border: 1px solid var(--line); border-radius: 8px; padding: 6px 8px; background: #fff; max-width: 50%; }
.list p { overflow-wrap: anywhere; }
.list a { color: inherit; }
</style>
