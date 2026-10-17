<script setup lang="ts">
// The head of a page (pwa/UI.md §3): "‹ where you came from", the title and one line under it, and at most two actions
// with words on the right (the `actions` slot). Back goes back in history when there is a page to go back to in this app,
// else to `back` (the part's first page, for a page opened from a link or a notification).
const props = defineProps<{ title: string; sub?: string; back?: string; backLabel?: string }>();
const router = useRouter();
function goBack() {
  // (Vue Router keeps the page before in history.state.back; none: this page was opened directly)
  if (typeof window !== "undefined" && window.history.state?.back) router.back();
  else void navigateTo(props.back ?? "/");
}
</script>

<template>
  <header class="app-header">
    <button v-if="back" type="button" class="back" @click="goBack">‹ {{ backLabel ?? "返回" }}</button>
    <slot name="lead" />
    <div class="titles">
      <h1>{{ title }}</h1>
      <div v-if="sub" class="sub">{{ sub }}</div>
    </div>
    <div v-if="$slots.actions" class="actions"><slot name="actions" /></div>
  </header>
</template>

<style scoped>
.app-header { display: flex; align-items: center; gap: 10px; min-height: 44px; color: #fff; margin-bottom: 12px; }
.titles { flex: 1; min-width: 0; }
h1 { margin: 0; font-size: 20px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.sub { font-size: 12px; opacity: 0.75; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.back {
  flex: none; min-height: 40px; padding: 8px 12px; border: 0; border-radius: 10px; background: rgba(255, 255, 255, 0.14); color: #fff;
  font-weight: 700; font-size: 14px; cursor: pointer; white-space: nowrap;
}
.actions { flex: none; display: flex; gap: 6px; }
.actions :deep(a), .actions :deep(button) {
  display: inline-flex; align-items: center; gap: 4px; min-height: 40px; padding: 8px 12px; border: 0; border-radius: 10px;
  background: rgba(255, 255, 255, 0.14); color: #fff; font-weight: 700; font-size: 14px; text-decoration: none; white-space: nowrap; cursor: pointer;
}
.actions :deep(.primary) { background: var(--green); border: 2px solid #1f1f1f; }
</style>
