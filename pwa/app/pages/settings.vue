<script setup lang="ts">
import type { SessionInfo } from "@goblincamp/shared";
import { api } from "~/utils/api";
import { disablePush, enablePush, isInstalled, pushState, type PushState } from "~/utils/push";
import { noteTime } from "~/utils/time";
import { measureViewport, type ViewportSizes } from "~/utils/viewport";

const ok = await useSignedIn();
const { user, logout } = useAccount();
const notes = useNotes();
const push = ref<PushState>("off");
const pushBusy = ref(false);
const pushError = ref("");
const sessions = ref<SessionInfo[]>([]);
const copied = ref(false);
const installed = ref(true);

const pushText: Record<PushState, string> = {
  on: "已開啟：提醒時間到，手機會收到通知。",
  off: "還沒開啟。",
  denied: "通知被關掉了：請到手機的設定裡，允許「哥布林營地」發送通知。",
  unsupported: "這個瀏覽器不支援推播。",
  "needs-install": "iPhone 要先把這個網頁「加入主畫面」，從主畫面打開才能收到通知（iOS 16.4 以上）。",
  "no-key": "伺服器還沒設定推播，請跟管理的人說。",
};

// the screen's sizes as the phone reports them (for when something sits in the wrong place: a screenshot of this helps)
const sizes = ref<ViewportSizes | null>(null);
const measure = () => (sizes.value = measureViewport());

const showAllSessions = ref(false);
/** Every other device of this account is signed out (this phone stays). */
async function endOthers() {
  if (!confirm("其他所有裝置（包括 Mac）都會被登出，要再登入才能用。確定嗎？")) return;
  await api("DELETE", "auth/sessions");
  await loadSessions();
}

// the admin page's link shows only for admins (the server says who they are)
const admin = ref(false);
onMounted(async () => {
  api("GET", "admin").then(() => (admin.value = true)).catch(() => {});
  installed.value = isInstalled();
  push.value = await pushState();
  await loadSessions();
});

async function loadSessions() {
  try {
    sessions.value = (await api<{ sessions: SessionInfo[] }>("GET", "auth/sessions")).sessions;
  } catch {
    sessions.value = [];
  }
}

async function togglePush() {
  pushBusy.value = true;
  pushError.value = "";
  try {
    if (push.value === "on") {
      await disablePush();
      push.value = "off";
    } else push.value = await enablePush();
  } catch (e) {
    pushError.value = `開不起來：${e instanceof Error ? e.message : String(e)}`;
  } finally {
    pushBusy.value = false;
  }
}

async function endSession(id: string) {
  await api("DELETE", `auth/sessions/${id}`);
  await loadSessions();
}

async function copyCode() {
  if (!user.value) return;
  await navigator.clipboard.writeText(user.value.friendCode);
  copied.value = true;
  setTimeout(() => (copied.value = false), 1500);
}

async function signOut() {
  if (!confirm("要登出嗎？手機上的便利貼會拿掉（帳號裡的不會刪，下次登入會再同步回來）。")) return;
  if (push.value === "on") await disablePush().catch(() => {});
  await notes.stop();
  await logout();
  await navigateTo("/login");
}
</script>

<template>
  <main v-if="ok" class="page">
    <header class="topbar">
      <NuxtLink to="/" class="icon-btn">← 首頁</NuxtLink>
      <h1>設定</h1>
    </header>

    <section class="panel">
      <h2>帳號</h2>
      <p><strong>{{ user?.displayName }}</strong>（{{ user?.email }}）</p>
      <p>好友代碼：<code>{{ user?.friendCode }}</code> <button class="btn small" @click="copyCode">{{ copied ? "複製了" : "複製" }}</button></p>
      <p v-if="admin"><NuxtLink to="/admin" class="btn">後台（邀請碼、帳號、大世界）</NuxtLink></p>
    </section>

    <section class="panel">
      <h2>提醒通知</h2>
      <p class="muted">{{ pushText[push] }}</p>
      <p class="muted small">開著的話，便利貼的提醒、大世界的出征結果、領地被攻擊、世界魔王被打倒都會通知你。</p>
      <p v-if="pushError" class="status error">{{ pushError }}</p>
      <button v-if="push === 'on' || push === 'off'" class="btn" :class="{ primary: push === 'off' }" :disabled="pushBusy" @click="togglePush">
        {{ push === "on" ? "關閉通知" : "開啟通知" }}
      </button>
      <p v-if="!installed" class="muted small">把這個網頁加入主畫面：Safari 按下方的「分享」→「加入主畫面」；Android 的 Chrome 按右上角選單 →「安裝應用程式」。</p>
    </section>

    <section class="panel">
      <h2>登入中的裝置 <small v-if="sessions.length">{{ sessions.length }} 台</small></h2>
      <div v-for="s in sessions.slice(0, showAllSessions ? sessions.length : 3)" :key="s.id" class="device">
        <div>
          <div class="name">{{ s.device?.name ?? "不明的裝置" }}（{{ s.device?.kind === "pwa" ? "手機" : "Mac" }}）{{ s.current ? "・這台" : "" }}</div>
          <div class="muted small">上次使用：{{ noteTime(s.lastSeenAt) }}</div>
        </div>
        <button v-if="!s.current" class="btn small" @click="endSession(s.id)">登出</button>
      </div>
      <button v-if="sessions.length > 3" class="more" @click="showAllSessions = !showAllSessions">{{ showAllSessions ? "收起" : `還有 ${sessions.length - 3} 台…` }}</button>
      <button v-if="sessions.length > 1" class="btn wide-soft" @click="endOthers">登出其他所有裝置</button>
    </section>

    <button class="btn danger wide" @click="signOut">登出這支手機</button>

    <details class="sizes" @toggle="measure">
      <summary>畫面尺寸（除錯用）</summary>
      <p v-if="sizes" class="muted small">
        主畫面 App：{{ sizes.standalone ? "是" : "否" }}・螢幕 {{ sizes.screen }}・網頁 {{ sizes.inner }}／{{ sizes.client }}・可見 {{ sizes.visual ?? "—" }}・安全區 上 {{ sizes.safeTop }} 下 {{ sizes.safeBottom }}・補 {{ sizes.gap }}
      </p>
    </details>
  </main>
</template>

<style scoped>
.panel { margin-bottom: 14px; }
h2 { font-size: 15px; margin: 0 0 8px; }
.muted { color: var(--muted); }
.small { font-size: 13px; }
.btn.small { min-height: 30px; padding: 4px 10px; font-size: 13px; }
h2 small { font-size: 12px; font-weight: 500; color: var(--muted); margin-left: 4px; }
.more { border: 0; background: none; color: var(--green); font-weight: 700; padding: 8px 0 0; cursor: pointer; }
.wide-soft { width: 100%; margin-top: 10px; }
.device { display: flex; align-items: center; justify-content: space-between; gap: 8px; padding: 8px 0; border-top: 1px solid var(--line); }
.device:first-of-type { border-top: 0; }
.name { font-weight: 600; }
code { background: #f0efe8; padding: 2px 6px; border-radius: 6px; }
.wide { width: 100%; }
.sizes { margin-top: 18px; color: rgba(255, 255, 255, 0.7); font-size: 13px; }
.sizes .muted { color: rgba(255, 255, 255, 0.7); }
</style>
