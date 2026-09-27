<script setup lang="ts">
const ok = await useSignedIn();
const notes = useNotes();
const { user } = useAccount();

const syncLine = computed(() => {
  switch (notes.state.status) {
    case "syncing": return "同步中…";
    case "offline": return "離線中：改動先存在手機，連上後會同步";
    case "problem": return `同步出了問題：${notes.state.problem}`;
    case "synced": return "已同步";
    default: return "";
  }
});

function add() {
  navigateTo(`/note/${notes.create()}?new=1`);
}
</script>

<template>
  <main v-if="ok" class="page">
    <header class="topbar">
      <img src="/sprites/icon.png" class="pixel" width="36" height="36" alt="" />
      <div style="flex: 1">
        <h1>便利貼</h1>
        <div class="sub">{{ user?.displayName }}・{{ syncLine }}</div>
      </div>
      <NuxtLink to="/settings" class="icon-btn">設定</NuxtLink>
    </header>

    <p v-if="notes.list.value.length === 0" class="empty">還沒有便利貼。按右下角的「＋」寫一張，會同步到你的 Mac。</p>
    <NoteCard v-for="n in notes.list.value" :id="n.id" :key="n.id" />

    <button class="fab" aria-label="新增便利貼" @click="add">＋</button>
  </main>
</template>

<style scoped>
.icon-btn { text-decoration: none; }
.empty { color: #e8f0e0; text-align: center; margin-top: 40px; line-height: 1.7; }
.fab {
  position: fixed; right: 20px; bottom: calc(env(safe-area-inset-bottom) + 20px); width: 60px; height: 60px; border-radius: 16px;
  background: var(--paper-yellow); border: 3px solid #1f1f1f; font-size: 32px; font-weight: 900; box-shadow: 4px 4px 0 #1f1f1f; cursor: pointer;
}
</style>
