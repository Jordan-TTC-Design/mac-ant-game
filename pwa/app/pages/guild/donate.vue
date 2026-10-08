<script setup lang="ts">
import { donationPoints, GUILD_LEVEL_POINTS, type GuildDonations, type GuildResponse } from "@goblincamp/shared";
import { materialName, MATERIALS } from "@goblincamp/shared/world";
import { noteTime } from "~/utils/time";
import { ApiError, api } from "~/utils/api";

// 捐獻 (GUILD.md §4.1): give camp materials to the guild; each is worth contribution, and enough of it raises the guild's
// level (more members, a bigger hall, more decoration room). The ledger shows who gave how much.
const ok = await useSignedIn();
const { live, guild, busy, message } = useGuild();
const have = ref<Record<string, number>>({});
const give = reactive<Record<string, number>>({});
const ledger = ref<GuildDonations | null>(null);

const known = (id: string) => id in MATERIALS;
const worth = (id: string) => donationPoints(id, known);
async function load() {
  try {
    have.value = (await api<{ materials: Record<string, number> }>("GET", "camp")).materials;
  } catch {
    have.value = {};
  }
  ledger.value = await api<GuildDonations>("GET", "guild/donations").catch(() => null);
}
onMounted(() => void load());

const rows = computed(() =>
  Object.entries(have.value)
    .filter(([id, n]) => n > 0 && worth(id) > 0)
    .sort((a, b) => worth(b[0]) - worth(a[0]) || b[1] - a[1]),
);
const total = computed(() => Object.entries(give).reduce((s, [id, n]) => s + worth(id) * (n || 0), 0));
const progress = computed(() => {
  const g = guild.value;
  if (!g) return 0;
  const from = GUILD_LEVEL_POINTS[g.level - 1] ?? 0;
  const to = GUILD_LEVEL_POINTS[g.level];
  return to === undefined ? 1 : (g.points - from) / (to - from);
});
function setAll(id: string) {
  give[id] = have.value[id] ?? 0;
}
function clamp(id: string) {
  give[id] = Math.max(0, Math.min(have.value[id] ?? 0, Math.floor(Number(give[id]) || 0)));
}
async function donate() {
  const materials = Object.fromEntries(Object.entries(give).filter(([, n]) => n > 0));
  if (!Object.keys(materials).length) return;
  busy.value = true;
  message.value = "";
  try {
    const out = await api<{ message: string; guild: GuildResponse }>("POST", "guild/donate", { materials });
    live.state.guild = out.guild;
    message.value = out.message;
    for (const id of Object.keys(give)) delete give[id];
    await load();
  } catch (e) {
    message.value = e instanceof ApiError ? e.message : String(e);
  } finally {
    busy.value = false;
  }
}
const list = (m: Record<string, number>) => Object.entries(m).map(([id, n]) => `${materialName(id)}×${n}`).join("、");
</script>

<template>
  <main v-if="ok" class="page">
    <header class="topbar">
      <NuxtLink to="/guild" class="back">‹</NuxtLink>
      <div style="flex: 1">
        <h1>捐獻</h1>
        <div class="sub">營地的材料捐給公會，累積貢獻讓公會升級</div>
      </div>
    </header>
    <p v-if="message" class="note">{{ message }}</p>

    <template v-if="guild">
      <section class="panel">
        <div class="lv">
          <b>{{ guild.name }}・Lv {{ guild.level }}</b>
          <small>{{ guild.toNext === null ? "已經是最高級了" : `再 ${guild.toNext.toLocaleString()} 貢獻升 ${guild.level + 1} 級` }}</small>
        </div>
        <div class="bar"><i :style="{ width: `${Math.min(100, progress * 100)}%` }" /></div>
        <small class="muted">累積 {{ guild.points.toLocaleString() }} 貢獻。升級後可以收更多人、據點變大、裝飾點數變多。</small>
      </section>

      <section class="panel">
        <h2>我的營地材料</h2>
        <p v-if="!rows.length" class="muted">營地裡還沒有可以捐的材料。</p>
        <div v-for="[id, n] in rows" :key="id" class="row">
          <i class="gem" :style="{ background: MATERIALS[id]?.color }" />
          <span class="grow"><b>{{ materialName(id) }}</b> <small>有 {{ n }}・每個 {{ worth(id) }} 貢獻</small></span>
          <input v-model.number="give[id]" type="number" min="0" :max="n" class="qty" placeholder="0" @change="clamp(id)" />
          <button type="button" class="btn small" @click="setAll(id)">全部</button>
        </div>
        <div v-if="rows.length" class="send">
          <span class="grow">共 <b>{{ total.toLocaleString() }}</b> 貢獻</span>
          <button class="btn primary" :disabled="busy || !total" @click="donate">捐出</button>
        </div>
      </section>

      <section v-if="ledger" class="panel">
        <h2>公會帳本</h2>
        <div v-for="m in ledger.members" :key="m.id" class="row">
          <span class="grow">{{ m.name }}</span>
          <b>{{ m.points.toLocaleString() }}</b>
        </div>
        <h2 class="later">最近的捐獻</h2>
        <p v-if="!ledger.recent.length" class="muted">還沒有人捐過。</p>
        <div v-for="(r, i) in ledger.recent" :key="i" class="row">
          <span class="grow"><b>{{ r.name }}</b> {{ list(r.materials) }}<br /><small>{{ noteTime(r.at) }}・+{{ r.points }}</small></span>
        </div>
      </section>
    </template>
  </main>
</template>

<style scoped>
.back { color: #fff3c4; font-size: 30px; text-decoration: none; padding: 0 10px 0 0; }
.grow { flex: 1; min-width: 0; }
h2 { margin: 0 0 6px; font-size: 17px; }
h2.later { margin-top: 14px; }
.note { color: #fff3c4; margin: 6px 2px; font-weight: 600; }
.muted { color: #666; font-size: 13px; }
.lv { display: flex; justify-content: space-between; align-items: baseline; gap: 8px; }
.lv small { color: #666; }
.bar { height: 12px; border-radius: 6px; background: #e6dcc6; border: 2px solid #1f1f1f; overflow: hidden; margin: 8px 0 6px; }
.bar i { display: block; height: 100%; background: #e8c547; }
.row { display: flex; align-items: center; gap: 8px; padding: 7px 0; border-top: 1px solid rgba(0, 0, 0, 0.06); }
.row small { color: #777; }
.gem { width: 14px; height: 14px; border-radius: 4px; border: 1px solid rgba(0, 0, 0, 0.4); flex: none; }
.qty { width: 74px; border: 2px solid #1f1f1f; border-radius: 8px; padding: 5px 6px; font-size: 15px; background: #fffdf6; }
.btn.small { padding: 4px 8px; font-size: 12px; }
.send { display: flex; align-items: center; gap: 8px; margin-top: 8px; }
</style>
