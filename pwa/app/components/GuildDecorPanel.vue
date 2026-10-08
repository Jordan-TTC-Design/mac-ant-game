<script setup lang="ts">
import {
  GUILD_DECOR,
  GUILD_DECOR_CATEGORIES,
  guildDecorKind,
  guildDecorRoomUsed,
  guildDecorUnlocked,
  HALL_FLOORS,
  HALL_WALLS,
  hallStyleOpen,
  type GuildDecorKind,
  type GuildDecorPlaced,
  type GuildRole,
} from "@goblincamp/shared";

// The catalog while decorating the hall (GUILD.md §4.2–4.3): decorations (the room used, the categories, every piece — the
// ones not unlocked yet greyed, saying what they need — and what can be done to the piece picked in the hall), the floor
// (a style to lay tile by tile, or over all of it) and the wall (the leader and officers).
const props = defineProps<{
  items: GuildDecorPlaced[];
  level: number;
  room: number;
  races: string[];
  role: GuildRole;
  selected: string | null;
  busy: boolean;
  mode: "decor" | "floor" | "wall";
  brush: string;
  wall: string;
}>();
const emit = defineEmits<{
  add: [kind: string];
  flip: [];
  remove: [];
  lock: [];
  save: [];
  cancel: [];
  mode: [mode: "decor" | "floor" | "wall"];
  brush: [id: string];
  fillAll: [];
  wall: [id: string];
}>();
const tile = (file: string) => ({ backgroundImage: `url(/guild-hall/${file})` });

const RACE_NAMES: Record<string, string> = { goblin: "哥布林", elf: "精靈", undead: "死靈" };
const tab = ref<string>(GUILD_DECOR_CATEGORIES[0]);
const used = computed(() => guildDecorRoomUsed(props.items));
const raceSet = computed(() => new Set(props.races));
const kinds = computed(() =>
  GUILD_DECOR.filter((k) => k.category === tab.value)
    .map((k) => ({ k, open: guildDecorUnlocked(k, props.level, raceSet.value) }))
    .sort((a, b) => Number(b.open) - Number(a.open) || a.k.level - b.k.level),
);
const picked = computed(() => props.items.find((d) => d.uid === props.selected) ?? null);
const pickedKind = computed(() => (picked.value ? guildDecorKind(picked.value.kind) : undefined));
const canTouch = computed(() => !!picked.value && (!picked.value.locked || props.role !== "member"));

function thumb(k: GuildDecorKind) {
  const s = Math.min(2, 56 / Math.max(k.w, k.h));
  return {
    width: `${k.w * s}px`,
    height: `${k.h * s}px`,
    backgroundImage: `url(/guild-hall/${k.file})`,
    backgroundSize: `${k.w * k.frames * s}px ${k.h * s}px`,
  };
}
function why(k: GuildDecorKind) {
  if (k.level > props.level) return `Lv ${k.level}`;
  return `要有${RACE_NAMES[k.race ?? ""] ?? ""}`;
}
</script>

<template>
  <section class="panel decor">
    <div class="head">
      <b>擺裝飾</b>
      <span class="room" :class="{ over: used > room }">裝飾點數 {{ used }}／{{ room }}</span>
    </div>

    <div class="modes">
      <button type="button" class="tab" :class="{ on: mode === 'decor' }" @click="emit('mode', 'decor')">🪑 裝飾</button>
      <button type="button" class="tab" :class="{ on: mode === 'floor' }" @click="emit('mode', 'floor')">🟫 地板</button>
      <button v-if="role !== 'member'" type="button" class="tab" :class="{ on: mode === 'wall' }" @click="emit('mode', 'wall')">🧱 牆壁</button>
    </div>

    <template v-if="mode === 'floor'">
      <p class="hint">選一種地板，在據點裡點一下或拖過去，一格一格鋪；或整片換掉。</p>
      <div class="styles">
        <button
          v-for="f in HALL_FLOORS"
          :key="f.id"
          type="button"
          class="style"
          :class="{ on: brush === f.id, shut: !hallStyleOpen(f, raceSet) }"
          :disabled="!hallStyleOpen(f, raceSet)"
          @click="emit('brush', f.id)"
        >
          <span class="swatch pixel" :style="tile(`floors/${f.id}.png`)" />
          <small>{{ f.name }}</small>
          <small v-if="!hallStyleOpen(f, raceSet)" class="pts">要有{{ RACE_NAMES[f.race ?? ""] }}</small>
        </button>
      </div>
      <button type="button" class="btn small" @click="emit('fillAll')">整片換成這種</button>
    </template>

    <template v-else-if="mode === 'wall'">
      <p class="hint">整個據點的牆一起換，馬上生效。</p>
      <div class="styles">
        <button
          v-for="w in HALL_WALLS"
          :key="w.id"
          type="button"
          class="style"
          :class="{ on: wall === w.id, shut: !hallStyleOpen(w, raceSet) }"
          :disabled="!hallStyleOpen(w, raceSet) || busy"
          @click="emit('wall', w.id)"
        >
          <span class="swatch tall pixel" :style="tile(`walls/${w.id}.png`)" />
          <small>{{ w.name }}</small>
          <small v-if="!hallStyleOpen(w, raceSet)" class="pts">要有{{ RACE_NAMES[w.race ?? ""] }}</small>
        </button>
      </div>
    </template>

    <template v-else>
    <div v-if="picked && pickedKind" class="picked">
      <span class="grow">{{ pickedKind.name }}<template v-if="picked.locked">・🔒 鎖住了</template></span>
      <button type="button" class="btn small" :disabled="!canTouch" @click="emit('flip')">↔︎ 翻面</button>
      <button type="button" class="btn small" :disabled="!canTouch" @click="emit('remove')">收掉</button>
      <button v-if="role !== 'member'" type="button" class="btn small" @click="emit('lock')">{{ picked.locked ? "解鎖" : "🔒 鎖定" }}</button>
    </div>
    <p v-else class="hint">點下面的裝飾放進據點，在據點裡拖著移動；點一下已經放的可以翻面、收掉。</p>

    <div class="tabs">
      <button v-for="c in GUILD_DECOR_CATEGORIES" :key="c" type="button" class="tab" :class="{ on: tab === c }" @click="tab = c">{{ c }}</button>
    </div>
    <div class="grid">
      <button
        v-for="{ k, open } in kinds"
        :key="k.id"
        type="button"
        class="item"
        :class="{ shut: !open }"
        :disabled="!open || busy"
        :title="`${k.name}（${k.size} 點）`"
        @click="emit('add', k.id)"
      >
        <span class="thumb pixel" :style="thumb(k)" />
        <small>{{ k.name }}</small>
        <small class="pts">{{ open ? `${k.size} 點` : why(k) }}</small>
      </button>
    </div>
    </template>

    <div class="actions">
      <button type="button" class="btn primary" :disabled="busy || used > room" @click="emit('save')">儲存</button>
      <button type="button" class="btn" :disabled="busy" @click="emit('cancel')">取消</button>
    </div>
  </section>
</template>

<style scoped>
.decor { display: grid; gap: 8px; }
.head { display: flex; justify-content: space-between; align-items: center; }
.room { font-size: 13px; color: #555; font-weight: 700; }
.room.over { color: #c0392b; }
.picked { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; background: #fff3c4; border-radius: 10px; padding: 6px 8px; }
.grow { flex: 1; min-width: 0; font-weight: 700; }
.hint { margin: 0; color: #666; font-size: 13px; }
.tabs { display: flex; gap: 4px; overflow-x: auto; padding-bottom: 2px; }
.tab { flex: none; border: 2px solid #1f1f1f; border-radius: 999px; background: #fffdf6; padding: 3px 10px; font-size: 12px; color: inherit; }
.tab.on { background: #e8c547; }
.grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(78px, 1fr)); gap: 6px; max-height: 300px; overflow-y: auto; }
.item { display: grid; justify-items: center; align-content: end; gap: 2px; min-height: 96px; border: 2px solid #1f1f1f; border-radius: 10px; background: #f3ead6; padding: 6px 4px; color: inherit; }
.item.shut { opacity: 0.45; }
.thumb { display: block; background-repeat: no-repeat; image-rendering: pixelated; }
.item small { font-size: 11px; line-height: 1.2; text-align: center; }
.pts { color: #777; }
.actions { display: flex; gap: 8px; position: sticky; bottom: 0; margin: 0 -20px -20px; padding: 10px 20px calc(env(safe-area-inset-bottom) + 12px); background: var(--card); border-top: 1px solid var(--line); border-radius: 0 0 14px 14px; z-index: 1; } /* (stays at the bottom of the sheet, so saving is never scrolled away) */
.modes { display: flex; gap: 6px; }
.styles { display: grid; grid-template-columns: repeat(auto-fill, minmax(76px, 1fr)); gap: 6px; }
.style { display: grid; justify-items: center; gap: 3px; border: 2px solid #1f1f1f; border-radius: 10px; background: #f3ead6; padding: 6px 4px; color: inherit; }
.style.on { background: #e8c547; }
.style.shut { opacity: 0.45; }
.style small { font-size: 11px; text-align: center; }
.swatch { width: 48px; height: 48px; background-size: 24px 24px; image-rendering: pixelated; border: 1px solid rgba(0, 0, 0, 0.3); }
.swatch.tall { width: 48px; height: 48px; background-size: 24px 48px; }
.btn.small { padding: 4px 8px; font-size: 12px; }
</style>
