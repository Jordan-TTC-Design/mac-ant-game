<script setup lang="ts">
// Picking who gets a piece of gear: 「自動」 (whoever needs it most) first, then everyone at home, strongest first, with
// what each wears in that slot now. A sheet from the bottom of the screen.
import type { CampResidentView, CampView, GearSlot } from "@goblincamp/shared/camp";

const props = defineProps<{ view: CampView; gear: string; title: string; allowAuto?: boolean; names: Record<string, string> }>();
const emit = defineEmits<{ pick: [resident: number | null]; close: [] }>();

const rule = computed(() => gearRule(props.gear)!);
const slot = computed(() => rule.value.slot as GearSlot);
const auto = computed(() => autoPick(props.view, props.gear));
const nameOf = (r: CampResidentView) => r.name || residentNameFromSeed(props.view.race, r.seed, r.legacySeed);
const filter = ref("");
const everyone = computed(() =>
  props.view.residents
    .filter((r) => r.place === "home")
    .map((r) => ({ r, power: residentPower(props.view.race, r), now: r.gear?.[slot.value] ?? null }))
    .filter(({ r }) => !filter.value || nameOf(r).includes(filter.value) || (props.names[r.breed] ?? r.breed).includes(filter.value))
    .sort((a, b) => b.power - a.power),
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
        <small>{{ auto ? `給最需要的：${nameOf(auto)}（${names[auto.breed] ?? auto.breed}）` : view.autoGear === false ? "放進倉庫（自動分配關著）" : "大家這個位置都有一樣好的了" }}</small>
      </button>
      <input v-model="filter" class="find" placeholder="找名字或品種" />
      <div class="list">
        <button v-for="{ r, power, now } in everyone.slice(0, shown)" :key="r.id" class="who" :disabled="blocked(r)" @click="emit('pick', r.id)">
          <span class="line"><b>{{ nameOf(r) }}</b><small>{{ names[r.breed] ?? r.breed }}</small><span class="grow" /><small>戰力 {{ power }}</small></span>
          <small class="now">
            {{ SLOT_LABELS[slot] }}：{{ now ? `${gearName(now.id)} ${durabilityText(now)}${now.pinned ? " 📌" : ""}` : "空" }}{{ blocked(r) ? "（拿著雙手武器）" : "" }}
          </small>
        </button>
        <button v-if="everyone.length > shown" class="more" @click="shown += 60">再多列一些（還有 {{ everyone.length - shown }} 隻）</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.sheet-back { position: fixed; inset: 0 0 calc(0px - var(--vp-gap, 0px)); z-index: 40; background: rgba(0, 0, 0, 0.45); display: flex; align-items: flex-end; justify-content: center; }
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
.more { border: 0; background: none; color: var(--green); font-weight: 700; padding: 8px; cursor: pointer; }
</style>
