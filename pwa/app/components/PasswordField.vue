<script setup lang="ts">
// A password box with an eye to show what was typed (and hide it again).
const model = defineModel<string>({ default: "" });
defineProps<{ placeholder?: string; autocomplete?: string }>();
const shown = ref(false);
</script>

<template>
  <div class="password">
    <input v-model="model" :type="shown ? 'text' : 'password'" :placeholder="placeholder" :autocomplete="autocomplete" autocapitalize="off" spellcheck="false" />
    <button type="button" class="eye" :aria-label="shown ? '隱藏密碼' : '顯示密碼'" :aria-pressed="shown" @click="shown = !shown">
      <!-- a pixel eye; struck through while the password is hidden -->
      <svg viewBox="0 0 12 8" width="22" height="15" shape-rendering="crispEdges" aria-hidden="true">
        <rect x="3" y="1" width="6" height="1" fill="currentColor" />
        <rect x="1" y="2" width="2" height="1" fill="currentColor" />
        <rect x="9" y="2" width="2" height="1" fill="currentColor" />
        <rect x="0" y="3" width="1" height="2" fill="currentColor" />
        <rect x="11" y="3" width="1" height="2" fill="currentColor" />
        <rect x="1" y="5" width="2" height="1" fill="currentColor" />
        <rect x="9" y="5" width="2" height="1" fill="currentColor" />
        <rect x="3" y="6" width="6" height="1" fill="currentColor" />
        <rect x="5" y="3" width="2" height="2" fill="currentColor" />
        <template v-if="!shown">
          <rect x="1" y="0" width="1" height="1" fill="currentColor" />
          <rect x="2" y="1" width="1" height="1" fill="currentColor" />
          <rect x="4" y="3" width="1" height="1" fill="currentColor" />
          <rect x="7" y="4" width="1" height="1" fill="currentColor" />
          <rect x="9" y="6" width="1" height="1" fill="currentColor" />
          <rect x="10" y="7" width="1" height="1" fill="currentColor" />
        </template>
      </svg>
    </button>
  </div>
</template>

<style scoped>
.password { position: relative; }
.password input { width: 100%; padding-right: 48px; }
.eye {
  position: absolute; right: 4px; top: 50%; transform: translateY(-50%);
  width: 40px; height: 34px; display: grid; place-items: center;
  border: 0; background: transparent; color: #666; cursor: pointer; border-radius: 6px;
}
.eye:hover { background: rgba(0, 0, 0, 0.05); }
.eye[aria-pressed="true"] { color: var(--green); }
</style>
