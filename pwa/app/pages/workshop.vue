<script setup lang="ts">
// The workshop on the phone: make gear (for whoever needs it most, or for someone picked), every piece there is (worn or
// in the store: take it off, give it, hold it), and mending. The same commands as the Mac's workshop.
import type { CampResidentView, GearItem, GearRule, GearSlot } from "@goblincamp/shared/camp";
import { materialName as sharedMaterialName } from "@goblincamp/shared/world";

const ok = await useSignedIn();
const { user } = useAccount();
const camp = useCamp();
const names = ref<ArtNames>({ races: {}, materials: {} });
onMounted(async () => (names.value = await loadArtNames()));
onUnmounted(() => camp.close());
if (ok && user.value) void camp.open(user.value.id);

const view = computed(() => camp.state.saved?.view ?? null);
const breedNames = computed(() => names.value.races[view.value?.race ?? "goblin"]?.breeds ?? {});
const materialName = (id: string) => names.value.materials[id] ?? sharedMaterialName(id);
const home = computed(() => view.value?.residents.filter((r) => r.place === "home") ?? []);
const nameOf = (r: CampResidentView) => r.name || residentNameFromSeed(view.value!.race, r.seed, r.legacySeed);

const tab = ref<"make" | "have" | "mend">("make");
const slotFilter = ref<GearSlot | "all">("all");
const onlyMakeable = ref(false);
const message = ref("");
const problem = ref("");
const busy = ref(false);

const have = (id: string) => view.value?.materials[id] ?? 0;
const makeable = (rule: GearRule) => !gearTier(rule).startsWith("未") && Object.entries(rule.cost).every(([id, n]) => have(id) >= n);
const counts = computed(() => {
  const out: Record<string, { worn: number; store: number }> = {};
  for (const r of home.value) for (const g of Object.values(r.gear ?? {})) (out[g.id] ??= { worn: 0, store: 0 }).worn++;
  for (const g of view.value?.armory ?? []) (out[g.id] ??= { worn: 0, store: 0 }).store++;
  return out;
});
const recipes = computed(() =>
  GEAR.filter((g) => slotFilter.value === "all" || g.slot === slotFilter.value)
    .filter((g) => !onlyMakeable.value || makeable(g))
    .map((g) => ({ g, worth: pieceWorth({ id: g.id, left: g.durability }) }))
    .sort((a, b) => GEAR_SLOTS.indexOf(a.g.slot) - GEAR_SLOTS.indexOf(b.g.slot) || a.worth - b.worth),
);

async function run(command: Record<string, unknown>) {
  busy.value = true;
  problem.value = "";
  message.value = "";
  try {
    message.value = await gearCommand(command);
  } catch (e) {
    problem.value = (e as Error).message;
  } finally {
    busy.value = false;
  }
}

// picking who gets a piece: one being made (craft) or one in the store (equip)
const picking = ref<{ gear: string; title: string; stock?: number } | null>(null);
async function picked(resident: number | null) {
  const p = picking.value!;
  picking.value = null;
  if (p.stock === undefined) await run(resident === null ? { kind: "craft", gear: p.gear } : { kind: "craft", gear: p.gear, to: resident });
  else if (resident !== null) await run({ kind: "equip", resident, stock: p.stock, gear: p.gear });
}

// every piece there is, by slot
interface Piece { item: GearItem; who: CampResidentView | null; stock: number | null }
const pieces = computed(() => {
  const out: Record<string, Piece[]> = {};
  for (const r of home.value) for (const item of Object.values(r.gear ?? {})) (out[gearRule(item.id)?.slot ?? "weapon"] ??= []).push({ item, who: r, stock: null });
  (view.value?.armory ?? []).forEach((item, stock) => (out[gearRule(item.id)?.slot ?? "weapon"] ??= []).push({ item, who: null, stock }));
  for (const list of Object.values(out)) list.sort((a, b) => pieceWorth(b.item) - pieceWorth(a.item));
  return out;
});

// mending: anything under 75%
const jobs = computed(() =>
  Object.values(pieces.value)
    .flat()
    .filter((p) => p.item.left / (gearRule(p.item.id)?.durability ?? 1) < 0.75)
    .sort((a, b) => a.item.left / gearRule(a.item.id)!.durability - b.item.left / gearRule(b.item.id)!.durability),
);
const costText = (cost: Record<string, number>) => Object.entries(cost).map(([id, n]) => `${materialName(id)} ×${n}`).join("、");
const affordable = (cost: Record<string, number>) => Object.entries(cost).every(([id, n]) => have(id) >= n);
</script>

<template>
  <main v-if="ok" class="page">
    <header class="topbar">
      <NuxtLink to="/camp" class="icon-btn">← 營地</NuxtLink>
      <div style="flex: 1"><h1>工坊</h1><div class="sub">做好的可以自動給最需要的，或自己挑人</div></div>
      <NuxtLink to="/roster" class="icon-btn">名冊</NuxtLink>
    </header>
    <div v-if="!view" class="panel">{{ camp.state.status === "loading" ? "讀取中…" : "還沒有營地。" }}</div>
    <template v-else>
      <nav class="tabs">
        <button :class="{ on: tab === 'make' }" @click="tab = 'make'">製作</button>
        <button :class="{ on: tab === 'have' }" @click="tab = 'have'">現有裝備</button>
        <button :class="{ on: tab === 'mend' }" @click="tab = 'mend'">修理<small v-if="jobs.length"> {{ jobs.length }}</small></button>
      </nav>
      <div class="panel status">
        <label class="auto">
          <input type="checkbox" :checked="view.autoGear !== false" :disabled="busy" @change="run({ kind: 'auto-gear', on: ($event.target as HTMLInputElement).checked })" />
          自動把倉庫的裝備發給最需要的居民<small>（你手動給的 📌、保留在倉庫的不會動）</small>
        </label>
        <p v-if="message" class="ok">{{ message }}</p>
        <p v-if="problem" class="warn">{{ problem }}</p>
      </div>

      <section v-if="tab === 'make'" class="panel">
        <div class="chips filter">
          <button :class="{ on: slotFilter === 'all' }" @click="slotFilter = 'all'">全部</button>
          <button v-for="s in GEAR_SLOTS" :key="s" :class="{ on: slotFilter === s }" @click="slotFilter = s">{{ SLOT_LABELS[s] }}</button>
        </div>
        <label class="only"><input v-model="onlyMakeable" type="checkbox" /> 只看做得出來的</label>
        <template v-for="({ g }, i) in recipes" :key="g.id">
          <h3 v-if="i === 0 || recipes[i - 1]!.g.slot !== g.slot">{{ SLOT_LABELS[g.slot] }}</h3>
          <article class="recipe" :class="{ dim: gearTier(g) === '未開放' }">
            <div class="grow">
              <div class="title"><b>{{ g.name }}</b><span v-if="gearTier(g)" class="tier" :class="{ closed: gearTier(g) === '未開放' }">{{ gearTier(g) }}</span></div>
              <small class="muted">{{ effectText(g) }}{{ counts[g.id] ? `・穿著 ${counts[g.id]!.worn}・倉庫 ${counts[g.id]!.store}` : "" }}</small>
              <div class="cost">
                <span v-for="[id, n] in Object.entries(g.cost)" :key="id" :class="have(id) >= n ? 'enough' : 'short'">{{ materialName(id) }} {{ have(id) }}/{{ n }}</span>
              </div>
            </div>
            <button class="btn primary" :disabled="busy || !makeable(g)" @click="picking = { gear: g.id, title: `做${g.name}，交給誰？` }">
              {{ gearTier(g) === "未開放" ? "未開放" : "製作…" }}
            </button>
          </article>
        </template>
        <p v-if="recipes.length === 0" class="muted">沒有符合的。</p>
      </section>

      <section v-if="tab === 'have'" class="panel">
        <p class="muted small">📌 是你手動給的（自動分配不會動）；「保留」的留在倉庫，不會自動發出去。</p>
        <template v-for="slot in GEAR_SLOTS" :key="slot">
          <template v-if="pieces[slot]?.length">
            <h3>{{ SLOT_LABELS[slot] }} <small>{{ pieces[slot]!.length }} 件</small></h3>
            <article v-for="p in pieces[slot]" :key="`${p.who?.id ?? 'store'}-${p.stock ?? slot}-${p.item.id}`" class="piece">
              <div class="grow">
                <b>{{ gearName(p.item.id) }}</b> <small>{{ durabilityText(p.item) }}</small>
                <small v-if="p.item.pinned"> 📌</small>
                <div class="muted small">{{ p.who ? `${nameOf(p.who)}（${breedNames[p.who.breed] ?? p.who.breed}）` : p.item.held ? "倉庫・保留" : "倉庫" }}</div>
              </div>
              <template v-if="p.who">
                <button class="btn" :disabled="busy" @click="run({ kind: 'unequip', resident: p.who.id, slot: slot })">收回倉庫</button>
              </template>
              <template v-else>
                <button class="btn primary" :disabled="busy" @click="picking = { gear: p.item.id, title: `把${gearName(p.item.id)}給誰？`, stock: p.stock! }">給…</button>
                <button class="btn" :disabled="busy" @click="run({ kind: 'gear-hold', stock: p.stock, gear: p.item.id, held: !p.item.held })">{{ p.item.held ? "交給自動" : "保留" }}</button>
              </template>
            </article>
          </template>
        </template>
        <p v-if="Object.keys(pieces).length === 0" class="muted">還沒有任何裝備。</p>
      </section>

      <section v-if="tab === 'mend'" class="panel">
        <p class="muted small">耐久低於 75% 的裝備，花三分之一的材料就能修好。</p>
        <article v-for="p in jobs.slice(0, 30)" :key="`${p.who?.id ?? 'store'}-${p.stock ?? ''}-${p.item.id}`" class="piece">
          <div class="grow">
            <b>{{ gearName(p.item.id) }}</b> <small>{{ durabilityText(p.item) }}</small>
            <div class="muted small">{{ p.who ? nameOf(p.who) : "倉庫" }}・{{ costText(repairCost(gearRule(p.item.id)!)) }}</div>
          </div>
          <button class="btn primary" :disabled="busy || !affordable(repairCost(gearRule(p.item.id)!))"
            @click="run(p.who ? { kind: 'repair', resident: p.who.id, slot: gearRule(p.item.id)!.slot } : { kind: 'repair', stock: p.stock })">修理</button>
        </article>
        <p v-if="jobs.length === 0" class="muted">沒有要修的。</p>
      </section>
    </template>
    <ResidentPicker v-if="picking && view" :view="view" :gear="picking.gear" :title="picking.title" :allow-auto="picking.stock === undefined" :names="breedNames" @pick="picked" @close="picking = null" />
  </main>
</template>

<style scoped>
section { margin-top: 12px; }
h3 { font-size: 13px; margin: 16px 0 6px; color: var(--muted); }
h3 small { font-weight: 400; }
.tabs { display: flex; gap: 6px; margin-top: 12px; }
.tabs button { flex: 1; border: 1px solid var(--line); background: #faf8f0; border-radius: 10px; padding: 9px 0; font: inherit; font-weight: 700; cursor: pointer; color: inherit; }
.tabs button.on { background: var(--green); color: #fff; border-color: var(--green); }
.status { margin-top: 10px; padding-top: 10px; padding-bottom: 10px; }
.auto { display: block; font-size: 14px; }
.auto small { color: var(--muted); }
.only { display: block; margin: 8px 0 0; font-size: 14px; }
.filter { display: flex; flex-wrap: wrap; gap: 6px; }
.filter button { border: 1px solid var(--line); background: #fff; border-radius: 999px; padding: 4px 10px; font: inherit; font-size: 13px; cursor: pointer; color: inherit; }
.filter button.on { background: #333; color: #fff; }
.recipe, .piece { display: flex; gap: 10px; align-items: center; border-top: 1px solid var(--line); padding: 9px 0; }
.recipe.dim { opacity: 0.55; }
.grow { flex: 1; min-width: 0; }
.title { display: flex; gap: 6px; align-items: baseline; }
.tier { font-size: 11px; background: #e8e2cc; border-radius: 6px; padding: 1px 6px; }
.tier.closed { background: #ddd; color: #666; }
.cost { display: flex; flex-wrap: wrap; gap: 4px 10px; font-size: 12px; margin-top: 3px; }
.enough { color: var(--green); }
.short { color: var(--red); }
.muted { color: var(--muted); }
.small { font-size: 12px; }
.ok { color: var(--green); font-weight: 600; margin: 8px 2px 0; }
.warn { color: #b3412c; margin: 8px 2px 0; }
.piece .btn { white-space: nowrap; }
</style>
