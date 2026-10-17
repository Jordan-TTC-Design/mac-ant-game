<script setup lang="ts">
import type { AdminUserPage, AdminUserRow, AdminUserSort, AdminUserStatus } from "@goblincamp/shared";
import { api } from "~/utils/api";
import { RACES, errText } from "~/utils/admin";
import { noteTime } from "~/utils/time";

// 後台 › 帳號: find one by address, name or friend code; only the stopped, admins…; newest or lately seen first.
// What is searched stays in the address, so coming back from an account keeps it.
const route = useRoute();
const router = useRouter();
const q = ref(String(route.query.q ?? ""));
const status = ref<AdminUserStatus>((route.query.status as AdminUserStatus) ?? "all");
const sort = ref<AdminUserSort>(route.query.sort === "lastSeen" ? "lastSeen" : "created");
const rows = ref<AdminUserRow[]>([]);
const total = ref(0);
const next = ref<string | null>(null);
const loading = ref(false);
const problem = ref("");

const STATUSES: [AdminUserStatus, string][] = [
  ["all", "全部"],
  ["admin", "管理員"],
  ["unverified", "未驗證"],
  ["disabled", "停用中"],
  ["deleting", "刪除中"],
];

let asked = 0;
async function load(more = false) {
  const mine = ++asked;
  loading.value = true;
  problem.value = "";
  const params = new URLSearchParams({ status: status.value, sort: sort.value });
  if (q.value.trim()) params.set("q", q.value.trim());
  if (more && next.value) params.set("cursor", next.value);
  try {
    const page = await api<AdminUserPage>("GET", `admin/users?${params}`);
    if (mine !== asked) return; // (an older search answering late)
    rows.value = more ? [...rows.value, ...page.users] : page.users;
    total.value = page.total;
    next.value = page.next;
  } catch (e) {
    problem.value = errText(e);
  } finally {
    if (mine === asked) loading.value = false;
  }
}
let typing: ReturnType<typeof setTimeout> | undefined;
watch(q, () => {
  clearTimeout(typing);
  typing = setTimeout(() => void load(), 300);
});
watch([status, sort], () => void load());
watch([q, status, sort], () => {
  const query: Record<string, string> = {};
  if (q.value.trim()) query.q = q.value.trim();
  if (status.value !== "all") query.status = status.value;
  if (sort.value !== "created") query.sort = sort.value;
  void router.replace({ query });
});
onMounted(() => load());

const campLine = (u: AdminUserRow) =>
  u.camp ? `${RACES[u.camp.race] ?? u.camp.race} ${u.camp.population} 隻${u.camp.cells ? `・領地 ${u.camp.cells} 格` : ""}` : "還沒有營地";
const open = (u: AdminUserRow) => router.push(`/admin/users/${u.id}`);
</script>

<template>
  <div>
    <section class="panel">
      <div class="field">
        <input v-model="q" type="search" placeholder="搜尋信箱、名字或好友代碼" autocomplete="off" autocapitalize="off" spellcheck="false" />
      </div>
      <div class="filters">
        <div class="chips">
          <button v-for="[key, label] in STATUSES" :key="key" :class="{ on: status === key }" @click="status = key">{{ label }}</button>
        </div>
        <select v-model="sort" aria-label="排序">
          <option value="created">新註冊的在前</option>
          <option value="lastSeen">最近用過的在前</option>
        </select>
      </div>
    </section>

    <section class="panel">
      <h2>帳號（{{ total }}）</h2>
      <div v-if="problem" class="status error">{{ problem }}</div>
      <p v-if="!rows.length && !loading" class="muted">沒有符合的帳號。</p>

      <!-- a computer: a table -->
      <table v-if="rows.length" class="wide-only">
        <thead>
          <tr><th>名字</th><th>信箱</th><th>營地</th><th>裝置</th><th>上次</th><th>註冊</th></tr>
        </thead>
        <tbody>
          <tr v-for="u in rows" :key="u.id" class="link" @click="open(u)">
            <td>
              <NuxtLink :to="`/admin/users/${u.id}`" @click.stop><b>{{ u.name }}</b></NuxtLink>
              <span v-if="u.role === 'admin'" class="tag gold">管理員</span><span v-if="!u.verified" class="tag">未驗證</span><span v-if="u.disabled" class="tag red">停用</span><span v-if="u.deleting" class="tag red">刪除中</span>
            </td>
            <td class="email">{{ u.email }}<br /><small class="muted">{{ u.friendCode }}</small></td>
            <td>{{ campLine(u) }}</td>
            <td>{{ u.devices }}</td>
            <td>{{ u.lastSeenAt ? noteTime(u.lastSeenAt) : "—" }}</td>
            <td>{{ noteTime(u.createdAt) }}</td>
          </tr>
        </tbody>
      </table>

      <!-- a phone: cards -->
      <div class="list narrow-only">
        <NuxtLink v-for="u in rows" :key="u.id" :to="`/admin/users/${u.id}`" class="who">
          <b>{{ u.name }}</b> <small class="muted">{{ u.email }}</small>
          <span v-if="u.role === 'admin'" class="tag gold">管理員</span><span v-if="!u.verified" class="tag">未驗證</span><span v-if="u.disabled" class="tag red">停用</span><span v-if="u.deleting" class="tag red">刪除中</span>
          <br />
          <small class="muted">{{ campLine(u) }}・{{ u.lastSeenAt ? `上次 ${noteTime(u.lastSeenAt)}` : "沒登入過" }}</small>
        </NuxtLink>
      </div>

      <button v-if="next" class="btn more" :disabled="loading" @click="load(true)">{{ loading ? "讀取中…" : `再載入（還有 ${total - rows.length}）` }}</button>
      <p v-else-if="loading" class="muted small">讀取中…</p>
    </section>
  </div>
</template>

<style scoped>
.filters { display: flex; flex-wrap: wrap; gap: 10px; justify-content: space-between; align-items: center; }
.filters select { border: 1px solid var(--line); border-radius: 8px; padding: 6px 8px; background: #fff; }
.field { margin-bottom: 10px; }
.who { display: block; text-decoration: none; color: inherit; word-break: break-all; }
.email { word-break: break-all; }
td a { color: inherit; text-decoration: none; }
</style>
