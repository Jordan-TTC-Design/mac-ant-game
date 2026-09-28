<script setup lang="ts">
import { ApiError, api } from "~/utils/api";
import { noteTime } from "~/utils/time";

// 後台: invite codes, who uses the server and how (only admins get past the server's check).
const ok = await useSignedIn();

interface Overview {
  users: { all: number; verified: number; active1: number; active7: number };
  devices: { macs: number; phones: number };
  notes: number;
  camps: Record<string, number>;
  residents: number;
  world: { open: number; heldCells: number; walking: number; fought: number };
  invites: { free: number; used: number; expired: number };
}
interface UserRow {
  id: string;
  email: string;
  name: string;
  createdAt: string;
  verified: boolean;
  deleting: boolean;
  role: "user" | "admin";
  disabled: boolean;
  camp: { race: string; population: number; peak: number; cells: number } | null;
  devices: number;
  lastSeenAt: string | null;
}
interface UserDetail {
  id: string;
  email: string;
  name: string;
  role: "user" | "admin";
  verified: boolean;
  disabled: boolean;
  deletingAt: string | null;
  devices: { id: string; kind: string; name: string; lastSeenAt: string; signedIn: boolean }[];
  camp: { race: string; population: number; peak: number; startedAt: string } | null;
  history: { at: string; action: string; detail: Record<string, unknown> | null }[];
}
interface LogRow { at: string; action: string; admin: string | null; target: string | null; detail: Record<string, unknown> | null }
interface InviteRow { createdAt: string; expiresAt: string; usedAt: string | null; usedBy: string | null; state: "free" | "used" | "expired" }

const overview = ref<Overview | null>(null);
const users = ref<UserRow[]>([]);
const invites = ref<InviteRow[]>([]);
const problem = ref("");
const count = ref(3);
const days = ref(14);
const fresh = ref<string[]>([]);
const copied = ref(false);
const busy = ref(false);

const log = ref<LogRow[]>([]);
async function load() {
  try {
    [overview.value, users.value, invites.value, log.value] = await Promise.all([
      api<Overview>("GET", "admin/overview"),
      api<{ users: UserRow[] }>("GET", "admin/users").then((r) => r.users),
      api<{ invites: InviteRow[] }>("GET", "admin/invites").then((r) => r.invites),
      api<{ log: LogRow[] }>("GET", "admin/log").then((r) => r.log),
    ]);
  } catch (e) {
    problem.value = e instanceof ApiError ? e.message : String(e);
  }
}
onMounted(load);

async function makeInvites() {
  busy.value = true;
  try {
    fresh.value = (await api<{ codes: string[] }>("POST", "admin/invites", { count: count.value, days: days.value })).codes;
    copied.value = false;
    await load();
  } catch (e) {
    problem.value = e instanceof ApiError ? e.message : String(e);
  } finally {
    busy.value = false;
  }
}
async function copyAll() {
  await navigator.clipboard.writeText(fresh.value.join("\n"));
  copied.value = true;
}

// one account opened: its details and what can be done to it
const { user: me } = useAccount();
const open = ref<UserDetail | null>(null);
const acting = ref(false);
async function openUser(id: string) {
  if (open.value?.id === id) return void (open.value = null);
  open.value = await api<UserDetail>("GET", `admin/users/${id}`);
}
async function act(path: string, body?: unknown, ask?: string) {
  if (!open.value || (ask && !confirm(ask))) return;
  acting.value = true;
  try {
    await api("POST", `admin/users/${open.value.id}/${path}`, body);
    const id = open.value.id;
    await load();
    open.value = await api<UserDetail>("GET", `admin/users/${id}`);
  } catch (e) {
    alert(e instanceof ApiError ? e.message : String(e));
  } finally {
    acting.value = false;
  }
}
function remove() {
  if (!open.value) return;
  const typed = prompt(`要刪除 ${open.value.email}？它會立刻被登出，30 天後連同營地一起刪掉（這 30 天內可以復原）。\n請輸入這個帳號的信箱確認：`);
  if (typed) void act("delete", { confirm: typed });
}
const ACTIONS: Record<string, string> = {
  disable: "停用", enable: "恢復", "sign-out": "強制登出", verify: "標記已驗證", role: "改角色", delete: "刪除", restore: "復原", invites: "產生邀請碼",
};

const RACES: Record<string, string> = { goblin: "哥布林", elf: "精靈", undead: "死靈" };
const STATE: Record<string, string> = { free: "可以用", used: "用掉了", expired: "過期" };
</script>

<template>
  <main v-if="ok" class="page">
    <header class="topbar">
      <NuxtLink to="/settings" class="icon-btn">← 設定</NuxtLink>
      <h1>後台</h1>
    </header>
    <div v-if="problem" class="panel status error">{{ problem }}</div>

    <template v-if="overview">
      <section class="panel grid">
        <div><b>{{ overview.users.all }}</b><small>帳號（{{ overview.users.verified }} 已驗證）</small></div>
        <div><b>{{ overview.users.active1 }}</b><small>今天有用</small></div>
        <div><b>{{ overview.users.active7 }}</b><small>這週有用</small></div>
        <div><b>{{ overview.devices.macs }}</b><small>Mac</small></div>
        <div><b>{{ overview.devices.phones }}</b><small>手機</small></div>
        <div><b>{{ overview.notes }}</b><small>便利貼</small></div>
        <div><b>{{ overview.residents }}</b><small>活著的居民</small></div>
        <div><b>{{ overview.world.open }}</b><small>開了大世界</small></div>
        <div><b>{{ overview.world.heldCells }}</b><small>被佔的格子</small></div>
        <div><b>{{ overview.world.walking }}</b><small>路上的隊伍</small></div>
        <div><b>{{ overview.world.fought }}</b><small>打過的仗</small></div>
        <div><b>{{ overview.invites.free }}</b><small>可用的邀請碼</small></div>
        <p class="races">營地：<span v-for="(n, race) in overview.camps" :key="race">{{ RACES[race] ?? race }} {{ n }}　</span></p>
      </section>

      <section class="panel">
        <h2>產生邀請碼</h2>
        <div class="row">
          <label>幾組 <input v-model.number="count" type="number" min="1" max="50" /></label>
          <label>幾天內有效 <input v-model.number="days" type="number" min="1" max="90" /></label>
          <button class="btn primary" :disabled="busy" @click="makeInvites">產生</button>
        </div>
        <template v-if="fresh.length">
          <p class="muted">只會顯示這一次，請現在複製（每組只能註冊一個帳號）：</p>
          <pre class="codes">{{ fresh.join("\n") }}</pre>
          <button class="btn" @click="copyAll">{{ copied ? "複製了" : "全部複製" }}</button>
        </template>
      </section>

      <section class="panel">
        <h2>帳號（{{ users.length }}）</h2>
        <div v-for="u in users" :key="u.id" class="user" :class="{ open: open?.id === u.id }">
          <button class="who" @click="openUser(u.id)">
            <b>{{ u.name }}</b> <small>{{ u.email }}</small>
            <span v-if="u.role === 'admin'" class="tag gold">管理員</span><span v-if="!u.verified" class="tag">未驗證</span><span v-if="u.disabled" class="tag red">停用中</span><span v-if="u.deleting" class="tag red">刪除中</span>
            <br />
            <small class="muted">
              {{ u.camp ? `${RACES[u.camp.race] ?? u.camp.race} ${u.camp.population} 隻${u.camp.cells ? `・領地 ${u.camp.cells} 格` : ""}` : "還沒有營地" }}・{{ u.lastSeenAt ? `上次 ${noteTime(u.lastSeenAt)}` : "沒登入過" }}
            </small>
          </button>
          <div v-if="open?.id === u.id" class="detail">
            <p class="muted">註冊 {{ noteTime(u.createdAt) }}{{ open.camp ? `・營地最多時 ${open.camp.peak} 隻` : "" }}</p>
            <h3>裝置</h3>
            <p v-if="!open.devices.length" class="muted">沒有。</p>
            <p v-for="d in open.devices" :key="d.id" class="dev">{{ d.name }}（{{ d.kind === "pwa" ? "手機" : "Mac" }}）<small class="muted">{{ d.signedIn ? "登入中" : "已登出" }}・{{ noteTime(d.lastSeenAt) }}</small></p>
            <div class="ops">
              <button v-if="!open.disabled" class="btn" :disabled="acting || open.id === me?.id" @click="act('disable', undefined, `停用 ${open.email}？它會立刻被登出，也不能再登入，直到恢復。`)">停用</button>
              <button v-else class="btn" :disabled="acting" @click="act('enable')">恢復</button>
              <button class="btn" :disabled="acting || open.id === me?.id" @click="act('sign-out', undefined, `把 ${open.email} 所有裝置都登出？`)">強制登出</button>
              <button v-if="!open.verified" class="btn" :disabled="acting" @click="act('verify')">標記已驗證</button>
              <button v-if="open.role === 'user'" class="btn" :disabled="acting" @click="act('role', { role: 'admin' }, `把 ${open.email} 設成管理員？它可以進後台、管理所有帳號。`)">設為管理員</button>
              <button v-else class="btn" :disabled="acting || open.id === me?.id" @click="act('role', { role: 'user' })">取消管理員</button>
              <button v-if="!open.deletingAt" class="btn danger" :disabled="acting || open.id === me?.id" @click="remove">刪除</button>
              <button v-else class="btn" :disabled="acting" @click="act('restore')">復原（{{ noteTime(open.deletingAt) }} 申請刪除）</button>
            </div>
            <template v-if="open.history.length">
              <h3>管理紀錄</h3>
              <p v-for="(h, k) in open.history" :key="k" class="muted small">{{ noteTime(h.at) }}　{{ ACTIONS[h.action] ?? h.action }}{{ h.detail?.role ? `（${h.detail.role === "admin" ? "管理員" : "一般"}）` : "" }}</p>
            </template>
          </div>
        </div>
      </section>

      <section class="panel">
        <h2>管理紀錄</h2>
        <p v-if="!log.length" class="muted">還沒有。</p>
        <p v-for="(l, k) in log.slice(0, 30)" :key="k" class="small">
          <span class="muted">{{ noteTime(l.at) }}</span>　{{ l.admin ?? "伺服器指令" }} {{ ACTIONS[l.action] ?? l.action }}{{ l.target ? ` ${l.target}` : "" }}{{ l.detail && "count" in l.detail ? ` ${l.detail.count} 組` : "" }}
        </p>
      </section>

      <section class="panel">
        <h2>邀請碼紀錄</h2>
        <p class="muted">可以用 {{ overview.invites.free }}・用掉了 {{ overview.invites.used }}・過期 {{ overview.invites.expired }}</p>
        <div v-for="(i, k) in invites" :key="k" class="invite">
          <span :class="i.state">{{ STATE[i.state] }}</span>
          <small class="muted">{{ i.usedBy ? `${i.usedBy}・${noteTime(i.usedAt!)}` : `到 ${noteTime(i.expiresAt)}` }}</small>
        </div>
      </section>
    </template>
    <div v-else-if="!problem" class="panel">讀取中…</div>
  </main>
</template>

<style scoped>
section { margin-top: 14px; }
h2 { font-size: 16px; margin: 0 0 10px; }
.grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; text-align: center; }
.grid b { display: block; font-size: 22px; }
.grid small { font-size: 11px; color: var(--muted); }
.races { grid-column: 1 / -1; margin: 4px 0 0; font-size: 13px; }
.row { display: flex; flex-wrap: wrap; gap: 10px; align-items: flex-end; }
.row label { display: grid; gap: 4px; font-size: 12px; color: var(--muted); }
.row input { width: 90px; border: 1px solid var(--line); border-radius: 8px; padding: 8px; font-size: 16px; }
.codes { background: #1f2a1c; color: #e8f0e0; padding: 12px; border-radius: 10px; font-size: 16px; letter-spacing: 1px; user-select: all; white-space: pre-wrap; }
.user, .invite { padding: 8px 0; border-top: 1px solid var(--line); }
.user .who { display: block; width: 100%; text-align: left; border: 0; background: none; padding: 0; font: inherit; color: inherit; cursor: pointer; }
.user.open { background: #faf7ec; border-radius: 10px; padding: 8px; }
.detail { margin-top: 8px; }
.detail h3 { font-size: 13px; margin: 10px 0 4px; }
.dev { margin: 3px 0; font-size: 14px; }
.ops { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 10px; }
.ops .btn { font-size: 13px; min-height: 36px; padding: 6px 10px; }
.tag.gold { background: #fff0b8; color: #8a6a00; }
.small { font-size: 13px; margin: 4px 0; }
.user:first-of-type, .invite:first-of-type { border-top: 0; }
.who small { color: var(--muted); word-break: break-all; }
.tag { margin-left: 6px; font-size: 11px; background: #eee; border-radius: 6px; padding: 1px 6px; }
.tag.red { background: #fbd9d6; color: var(--red); }
.muted { color: var(--muted); }
.invite { display: flex; justify-content: space-between; gap: 8px; }
.invite > span { white-space: nowrap; }
.invite small { text-align: right; min-width: 0; overflow-wrap: anywhere; }
.free { color: var(--green); font-weight: 700; }
.used { color: var(--muted); font-weight: 700; }
.expired { color: var(--red); font-weight: 700; }
</style>
