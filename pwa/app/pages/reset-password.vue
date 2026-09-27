<script setup lang="ts">
import { api } from "~/utils/api";

// The link in the reset mail lands here.
const token = String(useRoute().query.token ?? "");
const password = ref("");
const again = ref("");
const status = ref("");
const error = ref(false);
const done = ref(false);
const busy = ref(false);

async function save() {
  if (password.value.length < 10) return ((status.value = "密碼至少要 10 個字。"), (error.value = true));
  if (password.value !== again.value) return ((status.value = "兩次輸入的密碼不一樣。"), (error.value = true));
  busy.value = true;
  try {
    const r = await api<{ message: string }>("POST", "auth/reset-password", { token, password: password.value });
    status.value = r.message;
    error.value = false;
    done.value = true;
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
    <form class="panel" @submit.prevent="save">
      <h1>設定新密碼</h1>
      <template v-if="!done">
        <p class="muted">設定之後，所有裝置都會登出，需要用新密碼重新登入。</p>
        <div class="field"><label>新密碼</label><PasswordField v-model="password" autocomplete="new-password" placeholder="至少 10 個字" /></div>
        <div class="field"><label>再輸入一次</label><PasswordField v-model="again" autocomplete="new-password" /></div>
        <button class="btn primary" type="submit" :disabled="busy">設定</button>
      </template>
      <p class="status" :class="error ? 'error' : 'ok'">{{ status }}</p>
      <NuxtLink to="/login" class="btn" :class="{ primary: done }">去登入</NuxtLink>
    </form>
  </main>
</template>

<style scoped>
.page { padding-top: calc(env(safe-area-inset-top) + 32px); }
h1 { font-size: 20px; margin-top: 0; }
.muted { color: var(--muted); }
.btn { text-decoration: none; }
</style>
