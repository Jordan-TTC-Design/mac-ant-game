<script setup lang="ts">
import { guildDecorKind, guildOutfit, OUTFIT_SLOT_NAMES, type GuildDecorKind, type GuildResponse } from "@goblincamp/shared";
import { ApiError, api } from "~/utils/api";

// 公會商人 (GUILD.md §5.3, shared/src/guild-merchant.ts): once a week he comes to the hall for two days with a few of his
// decorations and clothes. A decoration bought with one's own contribution is the whole guild's to put down; clothes are
// one's own. When he is away: when he comes next.
const ok = await useSignedIn();
const { live, g, guild, busy, message } = useGuild();

const merchant = computed(() => guild.value?.merchant ?? null);
const points = computed(() => g.value?.wardrobe?.points ?? 0);
const owned = computed(() => g.value?.wardrobe?.owned ?? []);
const unlocked = computed(() => guild.value?.unlocked ?? []);
const decor = computed(() =>
  (merchant.value?.decor ?? []).map((d) => ({ ...d, k: guildDecorKind(d.kind) })).filter((d): d is { kind: string; price: number; k: GuildDecorKind } => !!d.k),
);
const clothes = computed(() => (merchant.value?.outfits ?? []).map((id) => guildOutfit(id)).filter((o) => !!o));

// (he comes and goes on his own time: the page asks again the moment he arrives or leaves, without being reloaded)
let turn: ReturnType<typeof setTimeout> | undefined;
watch(
  merchant,
  (m) => {
    clearTimeout(turn);
    if (!m) return;
    const next = Date.parse(m.here ? m.until : m.from) - Date.now();
    if (next > 0 && next < 2 ** 31 - 1) turn = setTimeout(() => void live.loadGuild(), next + 1000);
  },
  { immediate: true },
);
onBeforeUnmount(() => clearTimeout(turn));

/** "10/22（四）18:00" in Taiwan. */
function when(iso: string) {
  const d = new Date(iso);
  const day = "日一二三四五六"[new Date(d.getTime() + 8 * 3_600_000).getUTCDay()]; // (Taiwan has no summer time)
  const md = new Intl.DateTimeFormat("zh-TW", { timeZone: "Asia/Taipei", month: "numeric", day: "numeric" }).format(d);
  const hm = new Intl.DateTimeFormat("zh-TW", { timeZone: "Asia/Taipei", hour: "2-digit", minute: "2-digit", hour12: false }).format(d);
  return `${md}（${day}）${hm}`;
}

function thumb(k: GuildDecorKind) {
  const s = Math.min(2, 64 / Math.max(k.w, k.h));
  return { width: `${k.w * s}px`, height: `${k.h * s}px`, backgroundImage: `url(/guild-hall/${k.file})`, backgroundSize: `${k.w * k.frames * s}px ${k.h * s}px` };
}

async function buyDecor(kind: string, name: string) {
  busy.value = true;
  message.value = "";
  try {
    live.state.guild = await api<GuildResponse>("POST", "guild/merchant/buy", { kind });
    message.value = `買下了${name}！整個公會都可以擺了（在「擺裝飾 → 商人限定」）。`;
  } catch (e) {
    message.value = e instanceof ApiError ? e.message : String(e);
  } finally {
    busy.value = false;
  }
}
async function buyOutfit(id: string, name: string) {
  busy.value = true;
  message.value = "";
  try {
    const res = await api<{ wardrobe: GuildResponse["wardrobe"] }>("POST", "guild/outfits/buy", { id });
    if (live.state.guild) live.state.guild = { ...live.state.guild, wardrobe: res.wardrobe };
    message.value = `買了${name}！到「角色 → 衣服 → 商人」穿上。`;
  } catch (e) {
    message.value = e instanceof ApiError ? e.message : String(e);
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <main v-if="ok" class="page">
    <AppHeader title="公會商人" sub="每週來據點兩天，帶來別處買不到的東西" back="/guild" back-label="公會">
      <template #actions><span class="points">貢獻 {{ points.toLocaleString() }}</span></template>
    </AppHeader>
    <p v-if="message" class="note">{{ message }}</p>

    <template v-if="guild && merchant">
      <section v-if="!merchant.here" class="panel away">
        <b>商人這週已經走了，或還沒來。</b>
        <p>下次來：{{ when(merchant.from) }}，待到 {{ when(merchant.until) }}。</p>
        <p class="muted">他來的時候，據點裡會看到他和他的小攤子，點他就能回到這裡。</p>
      </section>

      <template v-else>
        <section class="panel">
          <div class="head">
            <h2>這次帶來的裝飾</h2>
            <small class="muted">待到 {{ when(merchant.until) }}</small>
          </div>
          <p class="muted">用自己的貢獻換，換到的整個公會都能擺。</p>
          <div class="cards">
            <div v-for="d in decor" :key="d.kind" class="card" :class="{ have: unlocked.includes(d.kind) }">
              <div class="pic"><i :style="thumb(d.k)" /></div>
              <b>{{ d.k.name }}</b>
              <small>{{ d.k.category }}・{{ d.k.size }} 點</small>
              <span v-if="unlocked.includes(d.kind)" class="done">公會已經有了</span>
              <button v-else type="button" class="btn primary small" :disabled="busy || points < d.price" @click="buyDecor(d.kind, d.k.name)">用 {{ d.price }} 貢獻換</button>
            </div>
          </div>
        </section>

        <section v-if="clothes.length" class="panel">
          <h2>這次帶來的衣服</h2>
          <p class="muted">只有他來的時候換得到，換到的永遠是你的。</p>
          <div class="cards">
            <div v-for="o in clothes" :key="o!.id" class="card" :class="{ have: owned.includes(o!.id) }">
              <b>{{ o!.name }}</b>
              <small>{{ OUTFIT_SLOT_NAMES[o!.slot] }}</small>
              <span v-if="owned.includes(o!.id)" class="done">已經有了</span>
              <button v-else type="button" class="btn primary small" :disabled="busy || points < o!.price" @click="buyOutfit(o!.id, o!.name)">用 {{ o!.price }} 貢獻換</button>
            </div>
          </div>
        </section>
      </template>

      <p class="muted foot">貢獻是你捐給公會的點數，捐獻照樣算進公會升級。<NuxtLink to="/guild/donate">去捐獻 ›</NuxtLink></p>
    </template>
  </main>
</template>

<style scoped>
.back { color: #fff3c4; font-size: 30px; text-decoration: none; padding: 0 10px 0 0; }
.points { color: #fff3c4; font-weight: 700; white-space: nowrap; }
h2 { margin: 0 0 4px; font-size: 17px; }
.head { display: flex; justify-content: space-between; align-items: baseline; gap: 8px; }
.note { color: #fff3c4; margin: 6px 2px; font-weight: 600; }
.muted { color: #666; font-size: 13px; }
.away p { margin: 6px 0 0; }
.cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(132px, 1fr)); gap: 8px; margin-top: 8px; }
.card { display: grid; justify-items: center; gap: 3px; padding: 8px; border: 2px solid #1f1f1f; border-radius: 10px; background: #fffdf6; text-align: center; }
.card.have { opacity: 0.6; }
.card small { color: #777; }
.pic { display: grid; place-items: center; height: 72px; }
.pic i { display: block; image-rendering: pixelated; background-repeat: no-repeat; }
.done { font-size: 12px; font-weight: 700; color: #4a7a3a; }
.btn.small { padding: 4px 8px; font-size: 12px; }
.foot { margin: 10px 2px; color: #e9dcc0; }
.foot a { color: #fff3c4; }
</style>
