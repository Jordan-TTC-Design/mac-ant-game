<script setup lang="ts">
import { DEFAULT_BADGE, GUILD_NAME_MAX, merchantVisit } from "@goblincamp/shared";
import { api } from "~/utils/api";
import { GUILD_PRESENCE, GUILD_ROLE } from "~/composables/useGuild";
import { noteTime } from "~/utils/time";

// 公會 (pwa/UI.md §4.4): without a guild, the invitations and founding one; in one, a page of cards — its level, who is on,
// the merchant — and the way into the hall (full screen, /guild/hall) and everything else. In the Mac app or a wide window
// the hall is the page itself, as before.
const ok = await useSignedIn();
const { live, g, guild, role, busy, message, inHall, online, act } = useGuild();
const name = ref("");
const badge = ref(DEFAULT_BADGE);
const drawing = ref(false);

const found = () => act(() => api("POST", "guild", { name: name.value, badge: badge.value }), "公會建立了！");
const join = (id: string) => act(() => api("POST", `guild/join/${id}`), "加入了！");
const decline = (id: string) => act(() => api("DELETE", `guild/join/${id}`));

onMounted(() => {
  if (inMacApp() || window.innerWidth >= 1000) {
    watchEffect(() => {
      if (guild.value) void navigateTo("/guild/hall", { replace: true });
    });
  }
});

const minute = ref(Date.now());
const timer = setInterval(() => (minute.value = Date.now()), 60_000);
onBeforeUnmount(() => clearInterval(timer));
const merchant = computed(() => (guild.value ? merchantVisit(guild.value.id, new Date(minute.value)) : null));
const here = computed(() => inHall.value.filter((m) => m.presence !== "offline"));
const share = computed(() => {
  const gv = guild.value;
  if (!gv || gv.toNext === null) return 1;
  return gv.points / Math.max(1, gv.points + gv.toNext);
});
void live;
</script>

<template>
  <main v-if="ok" class="page">
    <PalsHead :sub="guild ? `${guild.name}・Lv ${guild.level}` : '大家一起在據點裡，看得到誰在電腦前'" />
    <p v-if="message" class="note">{{ message }}</p>

    <template v-if="g && !guild">
      <section v-if="g.invites.length" class="panel">
        <h2>公會邀請</h2>
        <div v-for="i in g.invites" :key="i.guildId" class="row">
          <GuildBadge :badge="i.badge" :size="40" />
          <span class="grow"><b>{{ i.name }}</b><br /><small>{{ i.members }} 人・{{ i.by }} 邀請・{{ noteTime(i.at) }}</small></span>
          <button class="btn primary" :disabled="busy || !!g.waitUntil" @click="join(i.guildId)">加入</button>
          <button class="btn" :disabled="busy" @click="decline(i.guildId)">不要</button>
        </div>
      </section>

      <section class="panel">
        <h2>建立公會</h2>
        <p v-if="g.waitUntil" class="muted">剛離開公會，{{ noteTime(g.waitUntil) }}後才能加入或建立新的。</p>
        <form class="stack" @submit.prevent="found">
          <input v-model="name" class="field" :maxlength="GUILD_NAME_MAX" placeholder="公會名字（2～16 個字）" autocomplete="off" />
          <div class="badge-line">
            <GuildBadge :badge="badge" :size="56" />
            <button type="button" class="btn" @click="drawing = !drawing">{{ drawing ? "收起" : "畫徽章" }}</button>
          </div>
          <BadgeEditor v-if="drawing" v-model="badge" />
          <button class="btn primary" :disabled="busy || name.trim().length < 2 || !!g.waitUntil">建立（你會是會長）</button>
        </form>
        <p class="hint">加入公會要靠邀請：請會長或幹部用你的好友代碼邀請你。</p>
      </section>
      <NuxtLink to="/avatar" class="big wide">🧑‍🎨 先捏一個角色 ›</NuxtLink>
    </template>

    <template v-if="guild">
      <section class="panel head">
        <div class="top">
          <GuildBadge :badge="guild.badge" :size="56" />
          <div class="grow">
            <b class="gname">{{ guild.name }}</b>
            <small>Lv {{ guild.level }}・{{ guild.members.length }}／{{ guild.rules.members }} 人・{{ online }} 人在線</small>
          </div>
        </div>
        <div class="bar"><span :style="{ width: `${Math.round(share * 100)}%` }" /></div>
        <div class="bar-line">
          <small>{{ guild.toNext === null ? "已經是最高級" : `升 ${guild.level + 1} 級還要 ${guild.toNext.toLocaleString()} 貢獻` }}</small>
          <small>我的貢獻 {{ g?.wardrobe.points ?? 0 }}</small>
        </div>
        <div v-if="here.length" class="who">
          <span v-for="m in here.slice(0, 5)" :key="m.id"><i class="dot" :style="{ background: GUILD_PRESENCE[m.presence].dot }" /><b>{{ m.name }}</b><small>{{ m.role !== "member" ? `（${GUILD_ROLE[m.role]}）` : "" }}{{ GUILD_PRESENCE[m.presence].text }}</small></span>
        </div>
      </section>

      <NuxtLink to="/guild/hall" class="enter">
        <span class="i">🏰</span><span class="grow">進入公會大廳</span><span>›</span>
      </NuxtLink>

      <div class="grid">
        <NuxtLink to="/guild/donate" class="big"><span class="i">🎁</span>捐獻</NuxtLink>
        <NuxtLink to="/guild/merchant" class="big"><span class="i">🛒</span>公會商人<em v-if="merchant?.here">來了</em></NuxtLink>
        <NuxtLink to="/guild/members" class="big"><span class="i">👥</span>成員</NuxtLink>
        <NuxtLink to="/avatar" class="big"><span class="i">🧑‍🎨</span>我的角色<em v-if="!g?.avatarChosen">還沒捏</em></NuxtLink>
        <NuxtLink v-if="role !== 'member'" to="/guild/settings" class="big"><span class="i">⚙️</span>公會設定</NuxtLink>
      </div>
      <p v-if="merchant && !merchant.here" class="hint">公會商人下次 {{ noteTime(new Date(merchant.from).toISOString()) }} 來。</p>
    </template>
  </main>
</template>

<style scoped>
.grow { flex: 1; min-width: 0; }
.note { color: #fff3c4; margin: 6px 2px; font-weight: 600; }
.hint { color: #c9d6c0; font-size: 12px; margin: 8px 2px; }
.muted { color: #666; font-size: 13px; }
.stack { display: grid; gap: 10px; }
.badge-line { display: flex; align-items: center; gap: 12px; }
.row { display: flex; align-items: center; gap: 10px; padding: 8px 0; border-top: 1px solid rgba(0, 0, 0, 0.06); flex-wrap: wrap; }
.row:first-of-type { border-top: 0; }
.row small { color: #666; }
.head { display: grid; gap: 8px; }
.head .top { display: flex; align-items: center; gap: 12px; }
.gname { font-size: 18px; display: block; }
.head small { color: #666; font-size: 13px; }
.bar { height: 10px; border-radius: 5px; background: rgba(0, 0, 0, 0.1); overflow: hidden; }
.bar span { display: block; height: 100%; background: var(--green); }
.bar-line { display: flex; justify-content: space-between; gap: 8px; }
.who { display: grid; gap: 4px; padding-top: 4px; }
.who span { display: flex; align-items: center; gap: 6px; font-size: 14px; }
.who .dot { width: 8px; height: 8px; border-radius: 4px; }
.enter {
  display: flex; align-items: center; gap: 12px; margin: 12px 0; padding: 16px; border-radius: 16px; background: var(--green); color: #fff;
  border: 3px solid #1f1f1f; box-shadow: 3px 3px 0 rgba(0, 0, 0, 0.35); font-weight: 900; font-size: 17px; text-decoration: none;
}
.enter .i { font-size: 26px; }
.grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 8px; }
.big {
  position: relative; display: grid; justify-items: center; gap: 4px; padding: 14px 4px; min-height: 76px; border-radius: 14px;
  border: 2px solid #1f1f1f; background: var(--card); color: var(--ink); font-weight: 800; font-size: 14px; text-decoration: none; text-align: center;
}
.big .i { font-size: 24px; }
.big em { position: absolute; top: 6px; right: 6px; font-style: normal; font-size: 10px; padding: 1px 6px; border-radius: 8px; background: #e2553f; color: #fff; }
.big.wide { display: block; margin-top: 12px; padding: 14px; min-height: 0; }
</style>
