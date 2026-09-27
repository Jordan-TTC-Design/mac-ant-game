<script setup lang="ts">
import type { SessionInfo } from "@goblincamp/shared";
import { api } from "~/utils/api";
import { disablePush, enablePush, isInstalled, pushState, type PushState } from "~/utils/push";
import { noteTime } from "~/utils/time";

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

onMounted(async () => {
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
      <NuxtLink to="/" class="icon-btn">← 便利貼</NuxtLink>
      <h1>設定</h1>
    </header>

    <section class="panel">
      <h2>帳號</h2>
      <p><strong>{{ user?.displayName }}</strong>（{{ user?.email }}）</p>
      <p>好友代碼：<code>{{ user?.friendCode }}</code> <button class="btn small" @click="copyCode">{{ copied ? "複製了" : "複製" }}</button></p>
    </section>

    <section class="panel">
      <h2>提醒通知</h2>
      <p class="muted">{{ pushText[push] }}</p>
      <p v-if="pushError" class="status error">{{ pushError }}</p>
      <button v-if="push === 'on' || push === 'off'" class="btn" :class="{ primary: push === 'off' }" :disabled="pushBusy" @click="togglePush">
        {{ push === "on" ? "關閉通知" : "開啟通知" }}
      </button>
      <p v-if="!installed" class="muted small">把這個網頁加入主畫面：Safari 按下方的「分享」→「加入主畫面」；Android 的 Chrome 按右上角選單 →「安裝應用程式」。</p>
    </section>

    <section class="panel">
      <h2>登入中的裝置</h2>
      <div v-for="s in sessions" :key="s.id" class="device">
        <div>
          <div class="name">{{ s.device?.name ?? "不明的裝置" }}（{{ s.device?.kind === "pwa" ? "手機" : "Mac" }}）{{ s.current ? "・這台" : "" }}</div>
          <div class="muted small">上次使用：{{ noteTime(s.lastSeenAt) }}</div>
        </div>
        <button v-if="!s.current" class="btn small" @click="endSession(s.id)">登出</button>
      </div>
    </section>

    <button class="btn danger wide" @click="signOut">登出這支手機</button>
  </main>
</template>

<style scoped>
.panel { margin-bottom: 14px; }
h2 { font-size: 15px; margin: 0 0 8px; }
.muted { color: var(--muted); }
.small { font-size: 13px; }
.btn.small { min-height: 30px; padding: 4px 10px; font-size: 13px; }
.device { display: flex; align-items: center; justify-content: space-between; gap: 8px; padding: 8px 0; border-top: 1px solid var(--line); }
.device:first-of-type { border-top: 0; }
.name { font-weight: 600; }
code { background: #f0efe8; padding: 2px 6px; border-radius: 6px; }
.wide { width: 100%; }
</style>
