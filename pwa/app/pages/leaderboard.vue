<script setup lang="ts">
import type { RankedEntry } from "@goblincamp/shared/world";
import { ApiError, api } from "~/utils/api";

// 排行榜 (WORLD.md §7): everyone's camp by population, fighting strength and race level; each race has its own board too.
const ok = await useSignedIn();
const { user } = useAccount();
const board = ref<{ all: RankedEntry[]; byRace: Record<string, RankedEntry[]> } | null>(null);
const problem = ref("");
const tab = ref("all");
onMounted(async () => {
  try {
    board.value = await api("GET", "world/leaderboard");
  } catch (e) {
    problem.value = e instanceof ApiError ? e.message : String(e);
  }
});
const RACES: Record<string, string> = { goblin: "哥布林", elf: "精靈", undead: "死靈" };
const rows = computed(() => (tab.value === "all" ? board.value?.all : board.value?.byRace[tab.value]) ?? []);
// someone on the board: ask them to be friends (or go and write to them), as on their cell in the big world
const live = useLive();
const isFriend = (id: string) => !!live.state.friends?.friends.some((f) => f.id === id);
const asked = (id: string) => !!live.state.friends?.outgoing.some((f) => f.id === id);
const asking = ref<string | null>(null);
const told = ref("");
async function addFriend(r: RankedEntry) {
  asking.value = r.player;
  told.value = "";
  try {
    const out = await api<{ status: string }>("POST", "friends/asks", { userId: r.player });
    await live.loadFriends();
    told.value = out.status === "friends" ? `和${r.name}成為好友了！` : `送出好友邀請了，等${r.name}答應。`;
  } catch (e) {
    told.value = e instanceof ApiError ? e.message : String(e);
  } finally {
    asking.value = null;
  }
}
</script>

<template>
  <main v-if="ok" class="page">
    <header class="topbar">
      <NuxtLink to="/world" class="icon-btn">← 大世界</NuxtLink>
      <h1>排行榜</h1>
    </header>
    <div class="tabs">
      <button :class="{ on: tab === 'all' }" @click="tab = 'all'">全部</button>
      <button v-for="(name, id) in RACES" :key="id" :class="{ on: tab === id }" @click="tab = String(id)">{{ name }}</button>
    </div>
    <p v-if="told" class="told">{{ told }}</p>
    <div v-if="!board" class="panel">{{ problem || "讀取中…" }}</div>
    <section v-else class="panel">
      <p v-if="rows.length === 0" class="muted">還沒有人。</p>
      <div v-for="r in rows" :key="r.player" class="row" :class="{ me: r.player === user?.id }">
        <b class="rank">{{ r.rank }}</b>
        <img :src="`/sprites/${r.race}/icon.png`" class="pixel" width="28" height="28" alt="" />
        <div class="who">
          <div class="name">{{ r.name }}</div>
          <small>人口 {{ r.population }}・戰力 {{ r.power }}・等級 {{ r.level }}・領地 {{ r.cells }}</small>
        </div>
        <b class="score">{{ r.score }}</b>
        <template v-if="r.player !== user?.id">
          <NuxtLink v-if="isFriend(r.player)" :to="`/friends/${r.player}`" class="mini">傳訊息</NuxtLink>
          <button v-else class="mini" :disabled="asked(r.player) || asking === r.player" @click="addFriend(r)">{{ asked(r.player) ? "已邀請" : "加好友" }}</button>
        </template>
        <span v-else class="mini-space" />
      </div>
      <p class="muted note">分數 = 人口 × 10 + 戰力 +（種族等級 − 1）× 150</p>
    </section>
  </main>
</template>

<style scoped>
.tabs { display: flex; gap: 6px; margin-bottom: 12px; }
.tabs button { flex: 1; border: 0; border-radius: 9px; padding: 8px 0; background: rgba(255, 255, 255, 0.14); color: #fff; font-weight: 700; cursor: pointer; }
.tabs button.on { background: var(--paper-yellow); color: var(--ink); }
.row { display: flex; align-items: center; gap: 10px; padding: 9px 4px; border-top: 1px solid var(--line); }
.row:first-child { border-top: 0; }
.row.me { background: #fff6c8; border-radius: 8px; }
.rank { width: 24px; text-align: center; font-size: 17px; }
.who { flex: 1; min-width: 0; }
.name { font-weight: 700; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.who small { color: var(--muted); font-size: 12px; }
.score { font-size: 16px; }
.mini {
  flex: none; width: 58px; border: 1px solid rgba(0, 0, 0, 0.18); border-radius: 8px; padding: 5px 0; background: #ececec;
  font-size: 12px; font-weight: 700; text-align: center; text-decoration: none; cursor: pointer; white-space: nowrap;
}
.mini:disabled { opacity: 0.55; cursor: default; }
.mini-space { flex: none; width: 58px; }
.told { background: var(--paper-yellow); border-radius: 10px; padding: 8px 12px; margin: 0 0 12px; font-size: 14px; font-weight: 600; }
.muted { color: var(--muted); }
.note { font-size: 12px; margin-top: 10px; }
</style>
