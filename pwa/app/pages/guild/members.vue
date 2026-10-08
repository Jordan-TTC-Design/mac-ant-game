<script setup lang="ts">
import { GUILD_REJOIN_HOURS, type GuildMemberView, type GuildRole } from "@goblincamp/shared";
import { noteTime } from "~/utils/time";
import { api } from "~/utils/api";
import { GUILD_PRESENCE, GUILD_ROLE } from "~/composables/useGuild";

// 公會成員 (GUILD.md): who is in, how each one is and how much they focused today; the leader and officers invite (by
// friend code) and send people away, the leader sets roles and hands over the lead; anyone may leave.
const ok = await useSignedIn();
const { user, guild, role, busy, message, presence, act } = useGuild();
const code = ref("");

const invite = () =>
  act(async () => {
    await api("POST", "guild/invites", { code: code.value.trim() });
    code.value = "";
  }, "邀請送出了，等對方答應。");
const uninvite = (id: string) => act(() => api("DELETE", `guild/invites/${id}`));
function kick(m: GuildMemberView) {
  if (confirm(`請 ${m.name} 離開公會？`)) void act(() => api("DELETE", `guild/members/${m.id}`));
}
function setRole(m: GuildMemberView, to: GuildRole) {
  if (to === "leader" && !confirm(`把會長交給 ${m.name}？你會變成幹部。`)) return;
  void act(() => api("PUT", `guild/members/${m.id}/role`, { role: to }));
}
async function leave() {
  const last = guild.value?.members.length === 1;
  const q = last ? "你是最後一個人，離開後公會就解散了。確定嗎？" : `離開後要等 ${GUILD_REJOIN_HOURS} 小時才能加入別的公會。確定嗎？`;
  if (!confirm(q)) return;
  await act(() => api("POST", "guild/leave"));
  await navigateTo("/guild");
}
</script>

<template>
  <main v-if="ok" class="page">
    <header class="topbar">
      <NuxtLink to="/guild" class="back">‹</NuxtLink>
      <div style="flex: 1">
        <h1>公會成員</h1>
        <div v-if="guild" class="sub">{{ guild.name }}・{{ guild.members.length }}／{{ guild.rules.members }} 人</div>
      </div>
    </header>
    <p v-if="message" class="note">{{ message }}</p>

    <template v-if="guild">
      <section class="panel">
        <div v-for="m in guild.members" :key="m.id" class="row">
          <span class="face-wrap">
            <img :src="`/sprites/${m.race}/icon.png`" class="pixel face" alt="" />
            <i class="dot" :style="{ background: GUILD_PRESENCE[presence(m)].dot }" />
          </span>
          <span class="grow">
            <b>{{ m.name }}</b> <small class="role" :class="m.role">{{ GUILD_ROLE[m.role] }}</small>
            <br />
            <small>
              {{ GUILD_PRESENCE[presence(m)].text }}<template v-if="presence(m) === 'offline' && m.seenAt">・{{ noteTime(m.seenAt) }}來過</template>
              <template v-if="m.focusToday">・今天專注 {{ m.focusToday }} 輪</template>
            </small>
          </span>
          <span v-if="m.id !== user?.id && role === 'leader'" class="actions">
            <button v-if="m.role === 'member'" class="btn small" :disabled="busy" @click="setRole(m, 'officer')">升幹部</button>
            <button v-if="m.role === 'officer'" class="btn small" :disabled="busy" @click="setRole(m, 'member')">降成員</button>
            <button class="btn small" :disabled="busy" @click="setRole(m, 'leader')">交會長</button>
            <button class="btn small" :disabled="busy" @click="kick(m)">請離開</button>
          </span>
          <span v-else-if="m.id !== user?.id && role === 'officer' && m.role === 'member'" class="actions">
            <button class="btn small" :disabled="busy" @click="kick(m)">請離開</button>
          </span>
        </div>
      </section>

      <section v-if="role !== 'member'" class="panel">
        <h2>邀請</h2>
        <form class="add" @submit.prevent="invite">
          <input v-model="code" class="field" placeholder="對方的好友代碼" autocapitalize="characters" autocomplete="off" />
          <button class="btn primary" :disabled="busy || !code.trim() || guild.members.length >= guild.rules.members">邀請</button>
        </form>
        <p v-if="guild.members.length >= guild.rules.members" class="muted">公會滿了，升級後可以收更多人。</p>
        <div v-for="p in guild.invited" :key="p.id" class="row">
          <img :src="`/sprites/${p.race}/icon.png`" class="pixel face" alt="" />
          <span class="grow"><b>{{ p.name }}</b><br /><small>等對方答應・{{ noteTime(p.at) }}</small></span>
          <button class="btn" :disabled="busy" @click="uninvite(p.id)">收回</button>
        </div>
      </section>

      <button class="btn leave" :disabled="busy" @click="leave">離開公會</button>
    </template>
  </main>
</template>

<style scoped>
.back { color: #fff3c4; font-size: 30px; text-decoration: none; padding: 0 10px 0 0; }
.grow { flex: 1; min-width: 0; }
h2 { margin: 0 0 6px; font-size: 17px; }
.note { color: #fff3c4; margin: 6px 2px; font-weight: 600; }
.muted { color: #666; font-size: 13px; }
.field { border: 2px solid #1f1f1f; border-radius: 10px; padding: 10px 12px; font-size: 16px; background: #fffdf6; min-width: 0; }
.add { display: flex; gap: 8px; margin-bottom: 6px; }
.add .field { flex: 1; }
.row { display: flex; align-items: center; gap: 10px; padding: 8px 0; border-top: 1px solid rgba(0, 0, 0, 0.06); flex-wrap: wrap; }
.row:first-of-type { border-top: 0; }
.row small { color: #666; }
.face-wrap { position: relative; flex: none; }
.face { width: 36px; height: 36px; image-rendering: pixelated; display: block; }
.dot { position: absolute; right: -2px; bottom: -2px; width: 12px; height: 12px; border-radius: 50%; border: 2px solid #fffdf6; }
.role { border-radius: 6px; padding: 0 5px; font-weight: 700; background: #eee; }
.role.leader { background: #e8c547; color: #3a2a00; }
.role.officer { background: #cfe3ff; color: #1f3b6e; }
.actions { display: flex; flex-wrap: wrap; gap: 4px; }
.btn.small { padding: 4px 8px; font-size: 12px; }
.leave { margin-top: 4px; }
</style>
