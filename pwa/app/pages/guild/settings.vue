<script setup lang="ts">
import { DEFAULT_BADGE, GUILD_NAME_MAX, type GuildDecorLogEntry, type GuildResponse } from "@goblincamp/shared";
import { noteTime } from "~/utils/time";
import { api } from "~/utils/api";

// 公會設定 (GUILD.md): the leader renames the guild and draws its badge; the leader and officers see who changed the hall's
// decorations, and the leader can put them back as they were before a change.
const ok = await useSignedIn();
const { live, guild, role, busy, message, act } = useGuild();
const name = ref("");
const badge = ref(DEFAULT_BADGE);
const log = ref<GuildDecorLogEntry[]>([]);
watch(
  guild,
  (gd) => {
    if (gd && !name.value) {
      name.value = gd.name;
      badge.value = gd.badge;
    }
  },
  { immediate: true },
);
async function loadLog() {
  log.value = (await api<{ entries: GuildDecorLogEntry[] }>("GET", "guild/decor/log")).entries;
}
onMounted(() => void loadLog().catch(() => {}));

const saveName = () => act(() => api("PATCH", "guild", { name: name.value }), "名字改好了。");
const saveBadge = () => act(() => api("PATCH", "guild", { badge: badge.value }), "徽章換好了。");
function restore(entry: GuildDecorLogEntry) {
  if (!confirm(`把裝飾還原成 ${noteTime(entry.at)} ${entry.by} 改動之前的樣子？`)) return;
  void act(async () => {
    live.state.guild = await api<GuildResponse>("POST", "guild/decor/restore", { logId: entry.id });
    await loadLog();
  }, "還原了。");
}
const logLine = (e: GuildDecorLogEntry) =>
  e.restored
    ? "還原了裝飾"
    : [e.added && `放了 ${e.added} 件`, e.moved && `動了 ${e.moved} 件`, e.removed && `收了 ${e.removed} 件`, e.floor && `鋪了 ${e.floor} 格地板`].filter(Boolean).join("、");
</script>

<template>
  <main v-if="ok" class="page">
    <header class="topbar">
      <NuxtLink to="/guild" class="back">‹</NuxtLink>
      <div style="flex: 1">
        <h1>公會設定</h1>
        <div v-if="guild" class="sub">{{ guild.name }}</div>
      </div>
    </header>
    <p v-if="message" class="note">{{ message }}</p>

    <template v-if="guild">
      <p v-if="role === 'member'" class="note">這一頁是會長和幹部用的。</p>

      <section v-if="role === 'leader'" class="panel">
        <h2>公會名字</h2>
        <form class="add" @submit.prevent="saveName">
          <input v-model="name" class="field" :maxlength="GUILD_NAME_MAX" />
          <button class="btn primary" :disabled="busy || name.trim().length < 2 || name.trim() === guild.name">改名</button>
        </form>
      </section>

      <section v-if="role === 'leader'" class="panel">
        <h2>公會徽章</h2>
        <BadgeEditor v-model="badge" />
        <button class="btn primary save" :disabled="busy || badge === guild.badge" @click="saveBadge">儲存徽章</button>
      </section>

      <section v-if="role !== 'member'" class="panel">
        <h2>擺放紀錄</h2>
        <p class="muted">誰在什麼時候動了據點的裝飾和地板（留 7 天）。{{ role === "leader" ? "可以還原到某一次改動之前。" : "" }}</p>
        <p v-if="!log.length" class="muted">還沒有人動過裝飾。</p>
        <div v-for="e in log" :key="e.id" class="row">
          <span class="grow"><b>{{ e.by }}</b> {{ logLine(e) }}<br /><small>{{ noteTime(e.at) }}</small></span>
          <button v-if="role === 'leader'" class="btn small" :disabled="busy" @click="restore(e)">還原到這之前</button>
        </div>
      </section>
    </template>
  </main>
</template>

<style scoped>
.back { color: #fff3c4; font-size: 30px; text-decoration: none; padding: 0 10px 0 0; }
.grow { flex: 1; min-width: 0; }
h2 { margin: 0 0 6px; font-size: 17px; }
.note { color: #fff3c4; margin: 6px 2px; font-weight: 600; }
.muted { color: #666; font-size: 13px; margin: 0 0 6px; }
.field { flex: 1; border: 2px solid #1f1f1f; border-radius: 10px; padding: 10px 12px; font-size: 16px; background: #fffdf6; min-width: 0; }
.add { display: flex; gap: 8px; }
.row { display: flex; align-items: center; gap: 10px; padding: 8px 0; border-top: 1px solid rgba(0, 0, 0, 0.06); }
.row small { color: #666; }
.btn.small { padding: 4px 8px; font-size: 12px; }
.save { margin-top: 10px; }
</style>
