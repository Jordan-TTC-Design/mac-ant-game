<script setup lang="ts">
import {
  AVATAR_BROWS,
  AVATAR_EYES,
  AVATAR_FACES,
  AVATAR_HAIR_COLORS,
  AVATAR_LABELS,
  avatarOptions,
  defaultAvatar,
  randomAvatar,
  type Avatar,
  type AvatarSex,
  type GuildResponse,
} from "@goblincamp/shared";
import type { AvatarManifest } from "~/composables/useAvatarArt";
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
  } catch {
    message.value = "分身的圖還沒準備好。";
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
  const r = manifest?.recolor[channel]?.options[channel === "skin" ? `${look.value!.race}_${look.value!.sex}_${option}` : option];
  return r?.[Math.min(1, r.length - 1)];
}
type Part = "face" | "eyes" | "brows" | "mouth" | "hair" | "hairColor" | "skin" | "flame";
const parts = computed<{ key: Part; title: string; list: readonly string[]; colour?: string }[]>(() => {
  const o = opts.value;
  if (!o) return [];
  const bone = look.value!.race === "undead" && look.value!.sex === "m";
  return [
    { key: "hair", title: bone ? "頭部" : "髮型", list: o.hair },
    ...(bone ? [] : [{ key: "hairColor" as Part, title: "髮色", list: AVATAR_HAIR_COLORS, colour: "hair" }]),
    { key: "skin", title: bone ? "骨色" : "膚色", list: o.skin, colour: "skin" },
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
function setSex(sex: AvatarSex) {
  if (look.value?.sex !== sex) look.value = defaultAvatar(look.value!.race, sex);
}
function rollAll() {
  look.value = randomAvatar(look.value!.race, look.value!.sex);
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
    <header class="topbar">
      <NuxtLink to="/guild" class="back">‹</NuxtLink>
      <div style="flex: 1">
        <h1>我的分身</h1>
        <div class="sub">在公會據點裡代表你</div>
      </div>
    </header>

    <template v-if="look">
      <section class="panel stage">
        <canvas ref="preview" class="pixel" aria-label="分身預覽" />
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

      <p v-if="message" class="note">{{ message }}</p>
      <button class="btn primary save" :disabled="busy" @click="save">儲存分身</button>
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
</style>
