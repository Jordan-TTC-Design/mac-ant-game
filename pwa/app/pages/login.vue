<script setup lang="ts">
import { ApiError, api } from "~/utils/api";

const route = useRoute();
const { user, refresh, login } = useAccount();
const tab = ref<"login" | "register">("login");
const email = ref("");
const password = ref("");
const passwordAgain = ref("");
const displayName = ref("");
const inviteCode = ref(String(route.query.invite ?? ""));
const status = ref(route.query.expired ? "登入已經過期，請重新登入。" : "");
const error = ref(!!route.query.expired);
const busy = ref(false);
const sentTo = ref("");

if (route.query.invite) tab.value = "register";
if (user.value === undefined) await refresh();
if (user.value) await navigateTo("/");

function say(text: string, isError = false) {
  status.value = text;
  error.value = isError;
}

async function run(working: string, body: () => Promise<void>) {
  busy.value = true;
  say(working);
  try {
    await body();
  } catch (e) {
    if (e instanceof ApiError && e.code === "email_not_verified") {
      sentTo.value = email.value;
      say("這個信箱還沒確認。", true);
    } else say(e instanceof Error ? e.message : String(e), true);
  } finally {
    busy.value = false;
  }
}

function submit() {
  const mail = email.value.trim();
  if (!mail.includes("@")) return say("信箱看起來不太對。", true);
  if (tab.value === "login") {
    if (!password.value) return say("請填密碼。", true);
    return run("登入中…", async () => {
      await login(mail, password.value);
      await navigateTo("/");
    });
  }
  if (password.value.length < 10) return say("密碼至少要 10 個字。", true);
  if (password.value !== passwordAgain.value) return say("兩次輸入的密碼不一樣。", true);
  if (!displayName.value.trim()) return say("請填暱稱。", true);
  if (!inviteCode.value.trim()) return say("請填邀請碼。", true);
  return run("註冊中…", async () => {
    await api("POST", "auth/register", { email: mail, password: password.value, displayName: displayName.value.trim(), inviteCode: inviteCode.value.trim() });
    sentTo.value = mail;
    password.value = "";
    passwordAgain.value = "";
    say("");
  });
}

function resend() {
  run("寄送中…", async () => {
    await api("POST", "auth/resend-verification", { email: sentTo.value });
    say("又寄了一封，請看最新的那封。");
  });
}
</script>

<template>
  <main class="page">
    <div class="panel">
      <div class="head">
        <img src="/sprites/icon.png" class="pixel" width="48" height="48" alt="" />
        <div>
          <h1>哥布林營地帳號</h1>
          <p class="muted">登入後，便利貼會在你的 Mac 和手機之間同步</p>
        </div>
      </div>

      <template v-if="sentTo">
        <h2>確認信寄到 {{ sentTo }} 了</h2>
        <p class="muted">點信裡的連結確認信箱，然後回來登入。找不到的話看看垃圾信件匣。</p>
        <div class="row">
          <button class="btn" :disabled="busy" @click="resend">重寄確認信</button>
          <button class="btn primary" @click="(sentTo = '', (tab = 'login'), say(''))">回到登入</button>
        </div>
      </template>
      <form v-else @submit.prevent="submit">
        <div class="tabs">
          <button type="button" class="btn" :class="{ primary: tab === 'login' }" @click="(tab = 'login'), say('')">登入</button>
          <button type="button" class="btn" :class="{ primary: tab === 'register' }" @click="(tab = 'register'), say('')">註冊</button>
        </div>
        <div class="field"><label>信箱</label><input v-model="email" type="email" autocomplete="email" placeholder="you@example.com" /></div>
        <div class="field">
          <label>密碼</label>
          <PasswordField v-model="password" :autocomplete="tab === 'login' ? 'current-password' : 'new-password'" placeholder="至少 10 個字" />
        </div>
        <template v-if="tab === 'register'">
          <div class="field"><label>再輸入一次密碼</label><PasswordField v-model="passwordAgain" autocomplete="new-password" placeholder="和上面一樣" /></div>
          <div class="field"><label>暱稱</label><input v-model="displayName" maxlength="20" placeholder="使者上會顯示這個名字" /></div>
          <div class="field"><label>邀請碼</label><input v-model="inviteCode" autocapitalize="characters" placeholder="GOBLIN-XXXX-XXXX" /></div>
        </template>
        <div class="row between">
          <NuxtLink v-if="tab === 'login'" to="/forgot-password" class="muted small">忘記密碼？</NuxtLink>
          <span v-else />
          <button class="btn primary" type="submit" :disabled="busy">{{ tab === "login" ? "登入" : "註冊" }}</button>
        </div>
      </form>
      <p class="status" :class="error ? 'error' : 'ok'">{{ status }}</p>
      <hr />
      <p class="muted small">{{ tab === "register" && !sentTo ? "需要邀請碼才能註冊；跟給你這個 App 的人要一組。" : "Mac 上的哥布林營地用同一個帳號登入，便利貼就會同步。" }}</p>
    </div>
  </main>
</template>

<style scoped>
.page { padding-top: calc(env(safe-area-inset-top) + 32px); }
.head { display: flex; gap: 12px; align-items: center; margin-bottom: 18px; }
h1 { font-size: 20px; margin: 0; }
h2 { font-size: 16px; }
.muted { color: var(--muted); margin: 4px 0; }
.small { font-size: 13px; }
.tabs { display: flex; justify-content: center; gap: 8px; margin-bottom: 18px; }
.row { display: flex; gap: 8px; align-items: center; }
.between { justify-content: space-between; }
hr { border: 0; border-top: 1px solid var(--line); margin: 14px 0 10px; }
</style>
