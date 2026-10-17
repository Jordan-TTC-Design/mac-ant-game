<script setup lang="ts">
// Picking who gets a piece of gear: 「自動」 (whoever needs it most) first, then everyone who can be handed gear by place
// (主營 first, then the towns and the other held cells), strongest first, with what each wears in that slot now. A sheet
// from the bottom of the screen.
import type { CampResidentView, CampView, GearSlot } from "@goblincamp/shared/camp";

const props = defineProps<{ view: CampView; gear: string; title: string; allowAuto?: boolean; batches?: { label: string; n: number }[]; names: Record<string, string> }>();
const emit = defineEmits<{ pick: [resident: number | null]; batch: [n: number]; close: [] }>();

const rule = computed(() => gearRule(props.gear)!);
const slot = computed(() => rule.value.slot as GearSlot);
const auto = computed(() => autoPick(props.view, props.gear));
const nameOf = (r: CampResidentView) => r.name || residentNameFromSeed(props.view.race, r.seed, r.legacySeed);
const filter = ref("");
/** 主營 first, then the towns, the held cells in the order taken, then those guarding a friend's. */
const placeOrder = (r: CampResidentView) => {
  const label = placeLabel(props.view, r);
  const kind = r.place === "home" ? 0 : label.startsWith("城鎮") ? 1 : label.startsWith("領地") ? 2 : 3;
  return kind * 10_000 + (Number(label.split(" ").at(-1)) || 0);
};
const place = ref<string>("all");
const placesHere = computed(() => {
  const seen = new Map<string, { label: string; n: number; order: number }>();
  for (const r of gearHolders(props.view)) {
    const p = seen.get(r.place) ?? { label: placeLabel(props.view, r), n: 0, order: placeOrder(r) };
    p.n++;
    seen.set(r.place, p);
  }
  return [...seen.entries()].sort((a, b) => a[1].order - b[1].order);
});
const everyone = computed(() =>
  gearHolders(props.view)
    .filter((r) => place.value === "all" || r.place === place.value)
    .map((r) => ({ r, power: residentPower(props.view.race, r), now: r.gear?.[slot.value] ?? null, order: placeOrder(r) }))
    .filter(({ r }) => !filter.value || nameOf(r).includes(filter.value) || (props.names[r.breed] ?? r.breed).includes(filter.value))
    .sort((a, b) => a.order - b.order || b.power - a.power),
);
const shown = ref(40);
const blocked = (r: CampResidentView) => slot.value === "shield" && !!gearRule(r.gear?.weapon?.id ?? "")?.twoHanded;
</script>

<template>
  <div class="sheet-back" @click.self="emit('close')">
    <div class="sheet">
      <header>
        <b>{{ title }}</b>
        <button class="x" @click="emit('close')">✕</button>
      </header>
      <button v-if="allowAuto" class="who auto" @click="emit('pick', null)">
        <b>自動</b>
        <small>{{ auto ? `給最需要的：${nameOf(auto)}（${names[auto.breed] ?? auto.breed}${auto.place === "home" ? "" : `・${placeLabel(view, auto)}`}）` : view.autoGear === false ? "放進倉庫（自動分配關著）" : "大家這個位置都有一樣好的了" }}</small>
      </button>
      <div v-if="batches?.length" class="batches">
        <button v-for="b in batches" :key="b.n" class="btn primary" @click="emit('batch', b.n)">{{ b.label }}</button>
        <small class="muted">一次做好幾件，每件給當時最需要的</small>
      </div>
      <input v-model="filter" class="find" placeholder="找名字或品種（給特定一隻）" />
      <div v-if="placesHere.length > 1" class="places">
        <button :class="{ on: place === 'all' }" @click="place = 'all'">全部</button>
        <button v-for="[id, p] in placesHere" :key="id" :class="{ on: place === id }" @click="place = id">{{ p.label }} <small>{{ p.n }}</small></button>
      </div>
      <div class="list">
        <template v-for="({ r, power, now }, i) in everyone.slice(0, shown)" :key="r.id">
        <h4 v-if="placesHere.length > 1 && (i === 0 || everyone[i - 1]!.r.place !== r.place)">{{ placeLabel(view, r) }}</h4>
        <button class="who" :disabled="blocked(r)" @click="emit('pick', r.id)">
          <span class="line"><b>{{ nameOf(r) }}</b><small>{{ names[r.breed] ?? r.breed }}</small><span class="grow" /><small>戰力 {{ power }}</small></span>
          <small class="now">
            <GearIcon v-if="now" :id="now.id" :size="18" />
            {{ SLOT_LABELS[slot] }}：{{ now ? `${pieceLabel(now)} ${durabilityText(now)}${now.pinned ? " 📌" : ""}` : "空" }}{{ blocked(r) ? "（拿著雙手武器）" : "" }}
          </small>
        </button>
        </template>
        <button v-if="everyone.length > shown" class="more" @click="shown += 60">再多列一些（還有 {{ everyone.length - shown }} 隻）</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.sheet-back { position: fixed; inset: 0; z-index: 40; background: rgba(0, 0, 0, 0.45); display: flex; align-items: flex-end; justify-content: center; }
.sheet { width: 100%; max-width: 560px; max-height: 80vh; display: flex; flex-direction: column; background: var(--paper, #fffdf5); border-radius: 16px 16px 0 0; padding: 12px 14px calc(env(safe-area-inset-bottom) + 12px); }
header { display: flex; align-items: center; gap: 8px; margin-bottom: 8px; }
header b { flex: 1; font-size: 16px; }
.x { border: 0; background: none; font-size: 18px; cursor: pointer; padding: 4px 8px; }
.find { width: 100%; box-sizing: border-box; padding: 8px 10px; border: 1px solid var(--line); border-radius: 10px; margin: 8px 0; font: inherit; }
.list { overflow-y: auto; display: grid; gap: 6px; padding-bottom: 4px; }
.who { display: grid; gap: 2px; text-align: left; border: 1px solid var(--line); background: #fff; border-radius: 10px; padding: 8px 10px; font: inherit; color: inherit; cursor: pointer; }
.who:disabled { opacity: 0.45; cursor: default; }
.who.auto { background: #eef6e6; border-color: var(--green); }
.who small { color: var(--muted); font-size: 12px; }
.line { display: flex; gap: 8px; align-items: baseline; }
.grow { flex: 1; }
.places { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 8px; }
.places button { border: 1px solid var(--line); background: #fff; border-radius: 999px; padding: 4px 10px; font: inherit; font-size: 13px; cursor: pointer; color: inherit; }
.places button.on { background: #333; color: #fff; }
.places small { opacity: 0.7; }
h4 { margin: 6px 2px 0; font-size: 12px; color: var(--muted); }
.batches { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; margin-bottom: 4px; }
.batches small { width: 100%; font-size: 12px; }
.more { border: 0; background: none; color: var(--green); font-weight: 700; padding: 8px; cursor: pointer; }
</style>
