<script setup lang="ts">
import { api } from "~/utils/api";

const email = ref("");
const status = ref("");
const error = ref(false);
const busy = ref(false);

async function send() {
  if (!email.value.includes("@")) {
    status.value = "信箱看起來不太對。";
    error.value = true;
    return;
  }
  busy.value = true;
  try {
    await api("POST", "auth/forgot-password", { email: email.value.trim() });
    status.value = "如果這個信箱有帳號，重設密碼的信已經寄出（1 小時內有效）。";
    error.value = false;
  } catch (e) {
    status.value = e instanceof Error ? e.message : String(e);
    error.value = true;
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <main class="page">
    <form class="panel" @submit.prevent="send">
      <h1>忘記密碼</h1>
      <p class="muted">填你的信箱，我們會寄一封重設密碼的信。</p>
      <div class="field"><label>信箱</label><input v-model="email" type="email" autocomplete="email" /></div>
      <button class="btn primary" type="submit" :disabled="busy">寄重設密碼的信</button>
      <p class="status" :class="error ? 'error' : 'ok'">{{ status }}</p>
      <NuxtLink to="/login" class="muted">← 回到登入</NuxtLink>
    </form>
  </main>
</template>

<style scoped>
.page { padding-top: calc(env(safe-area-inset-top) + 32px); }
h1 { font-size: 20px; margin-top: 0; }
.muted { color: var(--muted); }
</style>
