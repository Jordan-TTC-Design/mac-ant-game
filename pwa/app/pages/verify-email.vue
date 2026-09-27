<script setup lang="ts">
import { api } from "~/utils/api";

// The link in the confirmation mail lands here.
const token = String(useRoute().query.token ?? "");
const state = ref<"working" | "ok" | "failed">("working");
const message = ref("");
onMounted(async () => {
  try {
    const r = await api<{ message: string }>("POST", "auth/verify-email", { token });
    message.value = r.message;
    state.value = "ok";
  } catch (e) {
    message.value = e instanceof Error ? e.message : String(e);
    state.value = "failed";
  }
});
</script>

<template>
  <main class="page">
    <div class="panel center">
      <img src="/sprites/icon.png" class="pixel" width="64" height="64" alt="" />
      <h1>{{ state === "working" ? "確認中…" : state === "ok" ? "信箱確認好了！" : "確認失敗" }}</h1>
      <p :class="state === 'failed' ? 'error' : ''">{{ message }}</p>
      <p v-if="state === 'ok'" class="muted">現在可以在 Mac 的哥布林營地或這裡登入了。</p>
      <NuxtLink v-if="state !== 'working'" to="/login" class="btn primary">去登入</NuxtLink>
    </div>
  </main>
</template>

<style scoped>
.page { padding-top: calc(env(safe-area-inset-top) + 48px); }
.center { text-align: center; display: grid; justify-items: center; gap: 6px; }
.btn { text-decoration: none; }
.error { color: var(--red); font-weight: 600; }
.muted { color: var(--muted); }
</style>
