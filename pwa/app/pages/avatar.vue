<script setup lang="ts">
import {
  AVATAR_BROWS,
  AVATAR_EYES,
  AVATAR_FACES,
  AVATAR_HAIR_COLORS,
  AVATAR_LABELS,
  avatarArtRace,
  avatarOptions,
  defaultAvatar,
  GUILD_OUTFITS,
  guildSeason,
  outfitClosed,
  taipeiDay,
  OUTFIT_SLOTS,
  OUTFIT_SLOT_NAMES,
  randomAvatar,
  type GuildOutfit,
  type OutfitSlot,
  type Avatar,
  type AvatarSex,
  type GuildResponse,
} from "@goblincamp/shared";
import { outfitFits, type AvatarManifest } from "~/composables/useAvatarArt";
import { ApiError, api } from "~/utils/api";

// 捏臉 (GUILD.md §2): the guild avatar, of the camp's race. Each part can be picked, or rolled at random (all of them, or
// just one), and the preview plays the avatar's moves.
const ok = await useSignedIn();
const live = useLive();
const art = useAvatarArt();
const g = computed(() => live.state.guild);
const look = ref<Avatar | null>(null);
const busy = ref(false);
const message = ref("");
const preview = ref<HTMLCanvasElement>();
const anim = ref("idle");
let manifest: AvatarManifest | null = null;
/** Bumped once the art is in (it says which clothes each body has pictures of). */
const artReady = ref(0);
/** The last look that was ready (shown while a new one is being put together). */
let shown: ImageBitmap | null = null;
let raf = 0;
let began = performance.now();

watch(
  () => g.value?.avatar,
  (a) => {
    if (a && !look.value) look.value = { ...a };
  },
  { immediate: true },
);
onMounted(async () => {
  void live.loadGuild();
  try {
    manifest = await art.load();
    artReady.value++;
  } catch {
    message.value = "角色的圖還沒準備好。";
  }
  draw();
});
onUnmounted(() => cancelAnimationFrame(raf));

const MOVES: [string, string][] = [
  ["idle", "站著"],
  ["walk", "走路"],
  ["sit", "坐著"],
  ["type", "打字"],
  ["wave", "揮手"],
  ["cheer", "歡呼"],
  ["doze", "打瞌睡"],
];
function play(a: string) {
  anim.value = a;
  began = performance.now();
}

function draw() {
  raf = requestAnimationFrame(draw);
  const c = preview.value;
  const m = manifest;
  if (!c || !m || !look.value) return;
  const scale = 6;
  const pad = 4;
  if (c.width !== (m.frameW + pad * 2) * scale) {
    c.width = (m.frameW + pad * 2) * scale;
    c.height = (m.frameH + pad * 2) * scale;
  }
  const g2 = c.getContext("2d")!;
  g2.imageSmoothingEnabled = false;
  const strip = (shown = art.strip(m, look.value) ?? shown);
  if (!strip) return;
  g2.clearRect(0, 0, c.width, c.height);
  const frame = art.frameOf(m, anim.value, "front", (performance.now() - began) / 1000);
  g2.drawImage(strip, frame * m.frameW, 0, m.frameW, m.frameH, pad * scale, pad * scale, m.frameW * scale, m.frameH * scale);
}

const opts = computed(() => (look.value ? avatarOptions(look.value.race, look.value.sex) : null));
/** One colour per option for the swatches: the art's middle shade. */
function swatch(channel: string, option: string): string | undefined {
  const r = manifest?.recolor[channel]?.options[channel === "skin" ? `${avatarArtRace(look.value!.race)}_${look.value!.sex}_${option}` : option];
  return r?.[Math.min(1, r.length - 1)];
}
type Part = "face" | "eyes" | "brows" | "mouth" | "hair" | "hairColor" | "skin" | "flame";
const parts = computed<{ key: Part; title: string; list: readonly string[]; colour?: string }[]>(() => {
  const o = opts.value;
  if (!o) return [];
  const bone = look.value!.race === "undead" && look.value!.sex === "m";
  const fur = look.value!.race === "beast"; // (the beastfolk's hair is a mane, their skin fur)
  return [
    { key: "hair", title: bone ? "頭部" : fur ? "鬃毛" : "髮型", list: o.hair },
    ...(bone ? [] : [{ key: "hairColor" as Part, title: fur ? "鬃毛色" : "髮色", list: AVATAR_HAIR_COLORS, colour: "hair" }]),
    { key: "skin", title: bone ? "骨色" : fur ? "毛色" : "膚色", list: o.skin, colour: "skin" },
    ...(o.flame.length ? [{ key: "flame" as Part, title: "眼火", list: o.flame, colour: "flame" }] : []),
    { key: "face", title: "臉型", list: AVATAR_FACES },
    { key: "eyes", title: "眼睛", list: AVATAR_EYES },
    ...(bone ? [] : [{ key: "brows" as Part, title: "眉毛", list: AVATAR_BROWS }]),
    { key: "mouth", title: "嘴巴", list: o.mouth },
  ];
});

function set(part: Part, value: string) {
  look.value = { ...look.value!, [part]: value } as Avatar;
}
/** The clothes worn now, kept through a new face or body. */
const worn = (a: Avatar) => Object.fromEntries(OUTFIT_SLOTS.filter((s) => a[s] !== undefined).map((s) => [s, a[s]]));
function setSex(sex: AvatarSex) {
  if (look.value?.sex !== sex) look.value = { ...defaultAvatar(look.value!.race, sex), ...worn(look.value!) };
}
function rollAll() {
  look.value = { ...randomAvatar(look.value!.race, look.value!.sex), ...worn(look.value!) };
}

// the clothes (GUILD.md §2): bought with one's own contribution, worn once owned (saved with the rest of the look)
const wardrobe = computed(() => g.value?.wardrobe ?? { owned: [], points: 0, spent: 0 });
/** The clothes in four groups: the plain ones, a holiday's, a guild level's, the merchant's (2026-10-17). */
type OutfitGroup = "basic" | "season" | "level" | "merchant";
const OUTFIT_GROUPS: { id: OutfitGroup; title: string }[] = [
  { id: "basic", title: "基本" },
  { id: "season", title: "節日限定" },
  { id: "level", title: "公會等級" },
  { id: "merchant", title: "商人" },
];
const groupOf = (o: GuildOutfit): OutfitGroup => (o.season ? "season" : o.level ? "level" : o.merchant ? "merchant" : "basic");
const outfitGroup = ref<OutfitGroup>("basic");
const outfitSlots = computed(() =>
  OUTFIT_SLOTS.map((slot) => ({ slot, title: OUTFIT_SLOT_NAMES[slot], list: GUILD_OUTFITS.filter((o) => o.slot === slot && groupOf(o) === outfitGroup.value) })).filter((s) => s.list.length),
);
/** Where one stands for the limited ones: today, one's guild's level, what the merchant has on him now. */
const shop = computed(() => {
  const guild = g.value?.guild;
  return { today: taipeiDay(new Date()), guildLevel: guild?.level ?? 0, merchant: new Set(guild?.merchant?.here ? guild.merchant.outfits : []) };
});
/** Why a piece one hasn't got can't be had now (null: it can). */
const closed = (o: GuildOutfit) => outfitClosed(o, shop.value);
/** What a limited piece is: its holiday, its level, the merchant's. */
const tag = (o: GuildOutfit) => (o.season ? guildSeason(o.season)?.name ?? "節日" : o.level ? `Lv ${o.level}` : o.merchant ? "商人" : "");
/** Whether this body has a picture of this piece (unknown until the art is in: then it counts as yes). */
function fits(o: GuildOutfit): boolean {
  void artReady.value;
  return !manifest || !look.value || outfitFits(manifest, look.value, o.slot, o.id);
}
function wear(slot: OutfitSlot, id: string | undefined) {
  const next = { ...look.value! } as Avatar;
  if (id === undefined) delete next[slot];
  else next[slot] = id;
  look.value = next;
}
async function buy(o: GuildOutfit) {
  busy.value = true;
  message.value = "";
  try {
    const res = await api<{ wardrobe: GuildResponse["wardrobe"] }>("POST", "guild/outfits/buy", { id: o.id });
    if (live.state.guild) live.state.guild = { ...live.state.guild, wardrobe: res.wardrobe };
    wear(o.slot, o.id);
    message.value = `買了${o.name}！記得按「儲存角色」穿上。`;
  } catch (e) {
    message.value = e instanceof ApiError ? e.message : String(e);
  } finally {
    busy.value = false;
  }
}
function rollOne(part: Part) {
  const a = look.value!;
  const keep = (Object.keys(a) as (keyof Avatar)[]).filter((k) => k !== part);
  look.value = randomAvatar(a.race, a.sex, Math.random, a, keep);
}
async function save() {
  busy.value = true;
  message.value = "";
  try {
    live.state.guild = await api<GuildResponse>("PUT", "guild/avatar", look.value);
    message.value = "存好了！";
  } catch (e) {
    message.value = e instanceof ApiError ? e.message : String(e);
  } finally {
    busy.value = false;
  }
}
const sexNames = computed(() => (look.value?.race === "undead" ? { m: "骨系", f: "魂系" } : { m: "男", f: "女" }));
</script>

<template>
  <main v-if="ok" class="page">
    <AppHeader title="我的角色" sub="在公會據點裡代表你" back="/guild" back-label="公會" />

    <template v-if="look">
      <section class="panel stage">
        <canvas ref="preview" class="pixel" aria-label="角色預覽" />
        <div class="moves">
          <button v-for="[a, label] in MOVES" :key="a" type="button" class="btn small" :class="{ primary: anim === a }" @click="play(a)">{{ label }}</button>
        </div>
      </section>

      <div class="bar">
        <div class="sex">
          <button v-for="s in (['m', 'f'] as const)" :key="s" type="button" class="btn" :class="{ primary: look.sex === s }" @click="setSex(s)">{{ sexNames[s] }}</button>
        </div>
        <button type="button" class="btn" @click="rollAll">🎲 全部隨機</button>
      </div>

      <section v-for="p in parts" :key="p.key" class="panel part">
        <div class="part-head">
          <h2>{{ p.title }}</h2>
          <button type="button" class="btn small" :aria-label="`隨機${p.title}`" @click="rollOne(p.key)">🎲</button>
        </div>
        <div class="choices">
          <button
            v-for="v in p.list"
            :key="v"
            type="button"
            class="choice"
            :class="{ on: look[p.key] === v, colour: !!p.colour }"
            :title="AVATAR_LABELS[v] ?? v"
            @click="set(p.key, v)"
          >
            <i v-if="p.colour" class="dot" :style="{ background: swatch(p.colour, v) }" />
            <span>{{ AVATAR_LABELS[v] ?? v }}</span>
          </button>
        </div>
      </section>

      <section class="panel part">
        <div class="part-head">
          <h2>衣服</h2>
          <span class="points">貢獻 {{ wardrobe.points }}</span>
        </div>
        <p class="dim">捐東西給公會會累積自己的貢獻，可以拿來換衣服；換到的永遠是你的。節日限定的要在節日期間換，公會等級的要公會升到那一級，商人的要等公會商人帶來。</p>
        <div class="groups">
          <button v-for="gr in OUTFIT_GROUPS" :key="gr.id" type="button" class="tab" :class="{ on: outfitGroup === gr.id }" @click="outfitGroup = gr.id">{{ gr.title }}</button>
        </div>
        <div v-for="s in outfitSlots" :key="s.slot" class="slot">
          <h3>{{ s.title }}</h3>
          <div class="choices">
            <button v-if="outfitGroup === 'basic'" type="button" class="choice" :class="{ on: look[s.slot] === undefined }" @click="wear(s.slot, undefined)">
              <span>{{ s.slot === "hat" ? "不戴" : "原本的" }}</span>
            </button>
            <template v-for="o in s.list" :key="o.id">
              <button
                v-if="wardrobe.owned.includes(o.id)"
                type="button"
                class="choice"
                :class="{ on: look[s.slot] === o.id, shut: !fits(o) }"
                :disabled="!fits(o)"
                :title="fits(o) ? o.name : '這個身形穿不了'"
                @click="wear(s.slot, o.id)"
              >
                <span>{{ o.name }}</span>
                <small v-if="!fits(o)">這個身形穿不了</small>
              </button>
              <button
                v-else
                type="button"
                class="choice locked"
                :class="{ shut: !fits(o) || !!closed(o) || wardrobe.points < o.price }"
                :disabled="busy || !fits(o) || !!closed(o)"
                :title="!fits(o) ? '這個身形穿不了' : closed(o) ?? `用 ${o.price} 貢獻換${o.name}`"
                @click="buy(o)"
              >
                <span>{{ o.name }}</span>
                <small>{{ !fits(o) ? "這個身形穿不了" : closed(o) ? `${tag(o)}・還換不到` : `🔒 ${o.price}${tag(o) ? `・${tag(o)}` : ""}` }}</small>
              </button>
            </template>
          </div>
        </div>
      </section>

      <p v-if="message" class="note">{{ message }}</p>
      <button class="btn primary save" :disabled="busy" @click="save">儲存角色</button>
    </template>
  </main>
</template>

<style scoped>
.back { color: #fff3c4; font-size: 30px; text-decoration: none; padding: 0 10px 0 0; }
.stage { display: grid; justify-items: center; gap: 10px; background: #e9dcc0; }
.stage canvas { width: min(70vw, 240px); image-rendering: pixelated; }
.moves { display: flex; flex-wrap: wrap; justify-content: center; gap: 4px; }
.bar { display: flex; justify-content: space-between; gap: 8px; margin: 10px 0; }
.sex { display: flex; gap: 6px; }
.part-head { display: flex; align-items: center; justify-content: space-between; }
h2 { margin: 0 0 6px; font-size: 16px; }
.choices { display: flex; flex-wrap: wrap; gap: 6px; }
.choice { display: inline-flex; align-items: center; gap: 5px; border: 2px solid #1f1f1f; border-radius: 10px; background: #fffdf6; padding: 5px 9px; font-size: 13px; color: inherit; }
.choice.on { background: #e8c547; }
.dot { width: 14px; height: 14px; border-radius: 50%; border: 1px solid rgba(0, 0, 0, 0.4); }
.btn.small { padding: 4px 8px; font-size: 12px; }
.note { color: #fff3c4; margin: 6px 2px; font-weight: 600; }
.save { width: 100%; margin: 6px 0 20px; }
.points { font-weight: 700; font-size: 14px; }
.dim { margin: 0 0 8px; color: #666; font-size: 12px; }
.slot h3 { margin: 8px 0 4px; font-size: 13px; }
.groups { display: flex; flex-wrap: wrap; gap: 6px; margin: 6px 0 2px; }
.groups .tab { padding: 5px 10px; border: 2px solid #1f1f1f; border-radius: 999px; background: #fffdf6; font-size: 13px; font-weight: 700; }
.groups .tab.on { background: #e8c547; }
.choice.shut { opacity: 0.45; }
.choice.locked { background: #efe6d2; }
.choice small { font-size: 11px; color: #777; }
</style>
