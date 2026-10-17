<script setup lang="ts">
// The question useConfirm() is asking, over the page.
const { current } = useConfirm();
const typed = ref("");
const ready = computed(() => !current.value?.typed || typed.value.trim().toLowerCase() === current.value.typed.toLowerCase());
watch(current, () => (typed.value = ""));
function onKey(e: KeyboardEvent) {
  if (e.key === "Escape") current.value?.answer(false);
}
onMounted(() => window.addEventListener("keydown", onKey));
onUnmounted(() => window.removeEventListener("keydown", onKey));
useModal(() => !!current.value);
</script>

<template>
  <div v-if="current" class="veil" @click.self="current.answer(false)">
    <div class="panel dialog" role="dialog" aria-modal="true" :aria-label="current.title">
      <h2>{{ current.title }}</h2>
      <p v-if="current.body" class="body">{{ current.body }}</p>
      <div v-if="current.typed" class="field">
        <label>請輸入「{{ current.typed }}」確認</label>
        <input v-model="typed" autocomplete="off" autocapitalize="off" spellcheck="false" @keydown.enter="ready && current.answer(true)" />
      </div>
      <div class="buttons">
        <button class="btn" @click="current.answer(false)">取消</button>
        <button class="btn" :class="current.danger ? 'danger' : 'primary'" :disabled="!ready" @click="current.answer(true)">{{ current.yes ?? "確定" }}</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.veil { position: fixed; inset: 0; z-index: 50; background: rgba(0, 0, 0, 0.45); display: grid; place-items: center; padding: 16px; }
.dialog { width: 100%; max-width: 420px; }
h2 { font-size: 17px; margin: 0 0 8px; }
.body { white-space: pre-line; margin: 0 0 14px; font-size: 14px; line-height: 1.5; overflow-wrap: anywhere; }
.buttons { display: flex; justify-content: flex-end; gap: 8px; flex-wrap: wrap; }
</style>
