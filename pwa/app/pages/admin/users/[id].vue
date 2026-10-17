<script setup lang="ts">
import type { AdminUserDetail } from "@goblincamp/shared";
import { raceLevel } from "@goblincamp/shared/world";
import { api } from "~/utils/api";
import { ACTIONS, RACES, errText } from "~/utils/admin";
import { noteTime } from "~/utils/time";

// 後台 › 帳號 › one account: everything about it, and what can be done to it (each asked first, in the page).
const route = useRoute();
const id = computed(() => String(route.params.id));
const { user: me } = useAccount();
const { ask } = useConfirm();
const u = ref<AdminUserDetail | null>(null);
const problem = ref("");
const note = ref("");
const acting = ref(false);

async function load() {
  try {
    u.value = await api<AdminUserDetail>("GET", `admin/users/${id.value}`);
  } catch (e) {
    problem.value = errText(e);
  }
}
onMounted(load);
watch(id, load);
const isMe = computed(() => u.value?.id === me.value?.id);

/** Does `path` to this account, after asking `question` (if any); says how it went. */
async function act(path: string, body?: unknown, question?: Parameters<typeof ask>[0], done?: string) {
  if (!u.value || (question && !(await ask(question)))) return;
  acting.value = true;
  problem.value = "";
  note.value = "";
  try {
    const out = await api<{ ok: true; warning?: string }>("POST", `admin/users/${u.value.id}/${path}`, body);
    note.value = out?.warning ?? done ?? "好了。";
    await load();
  } catch (e) {
    problem.value = errText(e);
  } finally {
    acting.value = false;
  }
}

const disable = () => act("disable", undefined, { title: `停用 ${u.value!.email}？`, body: "它會立刻從所有裝置登出，也不能再登入，直到恢復。", yes: "停用", danger: true }, "停用了。");
const signOut = () => act("sign-out", undefined, { title: `把 ${u.value!.email} 所有裝置都登出？`, yes: "登出" }, "所有裝置都登出了。");
const sendReset = () =>
  act("send-reset", undefined, { title: `寄設定新密碼的信給 ${u.value!.email}？`, body: "他點信裡的連結自己設定密碼（24 小時內有效），設好會從所有裝置登出一次。", yes: "寄出" }, "信寄出了。");
const makeAdmin = () => act("role", { role: "admin" }, { title: `把 ${u.value!.email} 設成管理員？`, body: "它可以進後台、管理所有帳號、發公告。", yes: "設為管理員" });
const dropAdmin = () => act("role", { role: "user" }, { title: `取消 ${u.value!.email} 的管理員？`, yes: "取消管理員" });
const remove = () =>
  act("delete", { confirm: u.value!.email }, { title: `刪除 ${u.value!.email}？`, body: "它會立刻被登出，30 天後連同營地一起刪掉（這 30 天內可以復原）。", yes: "刪除", danger: true, typed: u.value!.email }, "已申請刪除，30 天內可以復原。");

// renaming and a new address: small forms, opened one at a time
const editing = ref<"" | "name" | "email">("");
const draft = ref("");
function edit(what: "name" | "email") {
  editing.value = what;
  draft.value = what === "name" ? u.value!.name : u.value!.email;
}
async function save() {
  const what = editing.value;
  const value = draft.value.trim();
  if (!what || !value) return;
  if (what === "email" && !(await ask({ title: `把信箱改成 ${value}？`, body: "會變成未驗證，並寄一封確認信到新信箱。他之後要用新信箱登入。", yes: "改信箱" }))) return;
  await act(what, what === "name" ? { displayName: value } : { email: value }, undefined, what === "name" ? "名字改好了。" : "信箱改好了，確認信已寄出。");
  if (!problem.value) editing.value = "";
}

const GUILD_ROLES: Record<string, string> = { leader: "會長", officer: "幹部", member: "成員" };
</script>

<template>
  <div>
    <p><NuxtLink to="/admin/users" class="icon-btn">← 帳號列表</NuxtLink></p>
    <div v-if="problem" class="panel status error">{{ problem }}</div>
    <template v-if="u">
      <section class="panel">
        <h2>
          {{ u.name }}
          <span v-if="u.role === 'admin'" class="tag gold">管理員</span><span v-if="!u.verified" class="tag">未驗證</span><span v-if="u.disabled" class="tag red">停用中</span><span v-if="u.deletingAt" class="tag red">刪除中</span>
        </h2>
        <p class="small">{{ u.email }}<span class="muted">　好友代碼 {{ u.friendCode }}</span></p>
        <p class="small muted">註冊 {{ noteTime(u.createdAt) }}{{ u.verifiedAt ? `・${noteTime(u.verifiedAt)} 驗證` : "" }}{{ u.deletingAt ? `・${noteTime(u.deletingAt)} 申請刪除` : "" }}</p>

        <div v-if="editing" class="edit">
          <div class="field">
            <label>{{ editing === "name" ? "新名字（最多 20 字）" : "新信箱" }}</label>
            <input v-model="draft" :type="editing === 'email' ? 'email' : 'text'" autocomplete="off" autocapitalize="off" spellcheck="false" @keydown.enter="save" />
          </div>
          <div class="ops">
            <button class="btn" @click="editing = ''">取消</button>
            <button class="btn primary" :disabled="acting || !draft.trim()" @click="save">儲存</button>
          </div>
        </div>

        <div class="ops">
          <button class="btn" :disabled="acting" @click="edit('name')">改名</button>
          <button class="btn" :disabled="acting" @click="edit('email')">改信箱</button>
          <button v-if="!u.disabled" class="btn" :disabled="acting || isMe" @click="disable">停用</button>
          <button v-else class="btn" :disabled="acting" @click="act('enable', undefined, undefined, '恢復了。')">恢復</button>
          <button class="btn" :disabled="acting || isMe" @click="signOut">強制登出</button>
          <button class="btn" :disabled="acting || u.disabled" @click="sendReset">寄重設密碼信</button>
          <button v-if="!u.verified" class="btn" :disabled="acting" @click="act('verify', undefined, undefined, '標記為已驗證。')">標記已驗證</button>
          <button v-if="u.role === 'user'" class="btn" :disabled="acting" @click="makeAdmin">設為管理員</button>
          <button v-else class="btn" :disabled="acting || isMe" @click="dropAdmin">取消管理員</button>
          <button v-if="!u.deletingAt" class="btn danger" :disabled="acting || isMe" @click="remove">刪除</button>
          <button v-else class="btn" :disabled="acting" @click="act('restore', undefined, undefined, '復原了。')">復原</button>
        </div>
        <p v-if="note" class="status ok">{{ note }}</p>
      </section>

      <div class="two">
        <section class="panel">
          <h2>遊戲</h2>
          <p class="small">
            <b>營地</b>：{{ u.camp ? `${RACES[u.camp.race] ?? u.camp.race}，現在 ${u.camp.population} 隻、最多時 ${u.camp.peak} 隻，${noteTime(u.camp.startedAt)} 開始` : "還沒有" }}
          </p>
          <p class="small">
            <b>大世界</b>：{{ u.world ? `種族 Lv${raceLevel(u.world.xp)}（${u.world.xp} 經驗）・領地 ${u.world.cells} 格・路上 ${u.world.walking} 隊` : "還沒開" }}
          </p>
          <p class="small"><b>公會</b>：{{ u.guild ? `${u.guild.name}（Lv${u.guild.level}，${GUILD_ROLES[u.guild.role]}）` : "沒有" }}</p>
          <p class="small"><b>好友</b> {{ u.friends }}・<b>封鎖了</b> {{ u.blocked }}・<b>便利貼</b> {{ u.notes }}・<b>回報</b> {{ u.feedback }}</p>
          <template v-if="u.events.length">
            <h3>營地最近的事件</h3>
            <p v-for="(e, k) in u.events.slice(0, 10)" :key="k" class="small muted">{{ noteTime(e.at) }}　{{ e.kind }}</p>
          </template>
        </section>

        <section class="panel">
          <h2>裝置（{{ u.devices.length }}）</h2>
          <p v-if="!u.devices.length" class="muted">沒有。</p>
          <div class="list">
            <p v-for="d in u.devices" :key="d.id" class="small">
              {{ d.name }}（{{ d.kind === "pwa" ? "手機" : "Mac" }}）
              <span v-if="d.signedIn" class="tag green">登入中</span><span v-else class="tag">已登出</span><span v-if="d.push" class="tag">收推播</span>
              <br /><small class="muted">上次 {{ noteTime(d.lastSeenAt) }}</small>
            </p>
          </div>
        </section>
      </div>

      <section class="panel">
        <h2>管理紀錄</h2>
        <p v-if="!u.history.length" class="muted">沒有。</p>
        <p v-for="(h, k) in u.history" :key="k" class="small">
          <span class="muted">{{ noteTime(h.at) }}</span>　{{ h.admin ?? "伺服器指令" }} {{ ACTIONS[h.action] ?? h.action }}
          <span v-if="h.detail?.from" class="muted">{{ h.detail.from }} → {{ h.detail.to }}</span>
          <span v-if="h.detail?.role" class="muted">（{{ h.detail.role === "admin" ? "管理員" : "一般" }}）</span>
        </p>
        <NuxtLink v-if="u.history.length >= 20" :to="`/admin/log?target=${u.id}`" class="small">看全部 ›</NuxtLink>
      </section>
    </template>
    <div v-else-if="!problem" class="panel">讀取中…</div>
  </div>
</template>

<style scoped>
h2 { overflow-wrap: anywhere; }
.edit { margin: 10px 0; padding: 10px; background: #faf7ec; border-radius: 10px; }
.edit .field { margin-bottom: 6px; }
.edit .ops { margin-top: 0; justify-content: flex-end; }
</style>
