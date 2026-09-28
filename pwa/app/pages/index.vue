<script setup lang="ts">
const ok = await useSignedIn();
const notes = useNotes();
const { user } = useAccount();
// the residents on the notes follow the account's race
const { race, ensure } = useRace();
void ensure();

const syncLine = computed(() => {
  switch (notes.state.status) {
    case "syncing": return "同步中…";
    case "offline": return "離線中：改動先存在手機，連上後會同步";
    case "problem": return `同步出了問題：${notes.state.problem}`;
    case "synced": return "已同步";
    default: return "";
  }
});

// two kinds (待辦 with times, 備忘 kept at hand), and a search over the words
const tab = useState<"todo" | "memo">("notes-tab", () => "todo");
const query = ref("");
const kindOf = (n: { kind?: string }) => (n.kind === "memo" ? "memo" : "todo");
const counts = computed(() => ({
  todo: notes.list.value.filter((n) => kindOf(n) === "todo" && !n.done).length,
  memo: notes.list.value.filter((n) => kindOf(n) === "memo").length,
}));
const shown = computed(() => {
  const q = query.value.trim().toLowerCase();
  return notes.list.value.filter((n) => kindOf(n) === tab.value && (!q || n.text.toLowerCase().includes(q) || n.goblinName.includes(q)));
});

function add() {
  navigateTo(`/note/new?kind=${tab.value}`);
}
</script>

<template>
  <main v-if="ok" class="page">
    <header class="topbar">
      <img :src="`/sprites/${race}/icon.png`" class="pixel" width="36" height="36" alt="" />
      <div style="flex: 1">
        <h1>便利貼</h1>
        <div class="sub">{{ user?.displayName }}・{{ syncLine }}</div>
      </div>
      <NuxtLink to="/camp" class="icon-btn">營地</NuxtLink>
      <NuxtLink to="/settings" class="icon-btn">設定</NuxtLink>
    </header>

    <div class="tabs">
      <button :class="{ on: tab === 'todo' }" @click="tab = 'todo'">待辦 <small v-if="counts.todo">{{ counts.todo }}</small></button>
      <button :class="{ on: tab === 'memo' }" @click="tab = 'memo'">備忘 <small v-if="counts.memo">{{ counts.memo }}</small></button>
    </div>
    <input v-if="notes.list.value.length > 4" v-model="query" class="search" type="search" placeholder="搜尋便利貼…" />

    <p v-if="shown.length === 0" class="empty">
      {{ query ? "找不到。" : tab === "todo" ? "沒有待辦。按右下角的「＋」寫一張，可以設提醒，會同步到你的 Mac。" : "沒有備忘。常用的網址、指令、帳號名稱之類的放這裡：不用設時間，網址點了就開，每一行都能複製。" }}
    </p>
    <NoteCard v-for="n in shown" :id="n.id" :key="n.id" />

    <button class="fab" aria-label="新增便利貼" @click="add">＋</button>
  </main>
</template>

<style scoped>
.icon-btn { text-decoration: none; }
.tabs { display: flex; gap: 6px; margin-bottom: 10px; }
.tabs button { flex: 1; border: 0; border-radius: 10px; padding: 9px 0; background: rgba(255, 255, 255, 0.14); color: #fff; font-weight: 700; font-size: 15px; cursor: pointer; }
.tabs button.on { background: var(--paper-yellow); color: var(--ink); }
.tabs small { font-size: 12px; opacity: 0.7; }
.search { width: 100%; border: 0; border-radius: 10px; padding: 10px 12px; font-size: 16px; margin-bottom: 12px; background: #fffdf6; }
.empty { color: #e8f0e0; text-align: center; margin-top: 40px; line-height: 1.7; }
.fab {
  position: fixed; right: 20px; bottom: calc(env(safe-area-inset-bottom) + 20px); width: 60px; height: 60px; border-radius: 16px;
  background: var(--paper-yellow); border: 3px solid #1f1f1f; font-size: 32px; font-weight: 900; box-shadow: 4px 4px 0 #1f1f1f; cursor: pointer;
}
</style>
