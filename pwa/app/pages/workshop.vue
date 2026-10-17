<script setup lang="ts">
// The workshop on the phone: make gear (for whoever needs it most, or for someone picked), every piece there is (worn or
// in the store: take it off, give it, hold it), and mending. The same commands as the Mac's workshop. Residents on a held
// cell or guarding a friend's are in it too, with where they are.
import type { CampResidentView, GearItem, GearRule, GearSlot } from "@goblincamp/shared/camp";
import { ITEMS, materialName as sharedMaterialName, type ItemRule } from "@goblincamp/shared/world";

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
/** Everyone who can be handed gear: at home, on a held cell, guarding a friend's. */
const home = computed(() => (view.value ? gearHolders(view.value) : []));
const whereText = (r: CampResidentView) => (r.place === "home" || !view.value ? "" : `・${placeLabel(view.value, r)}`);
const hasAway = computed(() => !!view.value && Object.keys(view.value.places ?? {}).length > 0);
const nameOf = (r: CampResidentView) => r.name || residentNameFromSeed(view.value!.race, r.seed, r.legacySeed);

const tab = ref<"make" | "items" | "have" | "mend">("make");
const slotFilter = ref<GearSlot | "all">("all");
const onlyMakeable = ref(true);
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
    const said = (message.value = await gearCommand(command));
    setTimeout(() => message.value === said && (message.value = ""), 5000); // (the toast goes by itself)
  } catch (e) {
    problem.value = (e as Error).message;
  } finally {
    busy.value = false;
  }
}

/** How many a piece would upgrade (those the handing out reaches), and how many the materials make. */
const gainOf = (id: string) => (view.value ? upgradeCount(view.value, id) : 0);
const canMake = (cost: Record<string, number>) => (view.value ? affordableCount(view.value, cost) : 0);
/** What would help most now: for each slot, the best piece the materials make, for everyone it would upgrade; and mending. */
const suggestions = computed(() => {
  if (!view.value || view.value.autoGear === false) return [];
  return GEAR_SLOTS.flatMap((slot) => {
    const best = GEAR.filter((g) => g.slot === slot && makeable(g) && gainOf(g.id) > 0).sort((a, b) => pieceWorth({ id: b.id, left: b.durability }) - pieceWorth({ id: a.id, left: a.durability }))[0];
    if (!best) return [];
    const need = gainOf(best.id);
    return [{ slot, gear: best, need, n: Math.min(need, canMake(best.cost), 20) }];
  });
});
const mendable = computed(() => jobs.value.filter((p) => affordable(repairCost(gearRule(p.item.id)!))).length);
/** 製作: straight to whoever needs it most (into the store with the handing out off); `n` of them at once. */
const make = (gear: string, n = 1) => run(n > 1 ? { kind: "craft", gear, count: n } : { kind: "craft", gear });
/** The ⋯ sheet's batches for a piece being made. */
const batchesFor = (gear: string) => {
  const rule = gearRule(gear)!;
  const all = Math.min(view.value?.autoGear === false ? canMake(rule.cost) : gainOf(gear), canMake(rule.cost), 20);
  const out = [3, 5, 10].filter((n) => n < all).map((n) => ({ label: `做 ${n} 件`, n }));
  if (all > 1) out.push({ label: view.value?.autoGear === false ? `做 ${all} 件` : `每隻需要的都有（${all} 件）`, n: all });
  return out;
};
async function batch(n: number) {
  const p = picking.value!;
  picking.value = null;
  await make(p.gear, n);
}

// 現有裝備: one line for each kind, opened to show who has each piece
const opened = ref(new Set<string>());
const toggle = (id: string) => {
  const next = new Set(opened.value);
  if (next.has(id)) next.delete(id);
  else next.add(id);
  opened.value = next;
};
const kindsIn = (list: Piece[]) => {
  const out = new Map<string, Piece[]>();
  for (const p of list) out.set(p.item.id, [...(out.get(p.item.id) ?? []), p]);
  return [...out.entries()];
};

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
    .filter((p) => p.item.left / gearMax(p.item) < 0.75)
    .sort((a, b) => a.item.left / gearMax(a.item) - b.item.left / gearMax(b.item)),
);
// 強化 (ECONOMY.md §1.2): the piece whose next + is shown, and what it takes
const enhancing = ref<string | null>(null);
const pieceKey = (p: { who: CampResidentView | null; stock: number | null; item: GearItem }, slot: GearSlot) => `${p.who?.id ?? "store"}-${p.stock ?? slot}-${p.item.id}`;
const enhanceCommand = (p: { who: CampResidentView | null; stock: number | null }, slot: GearSlot) =>
  p.who ? { kind: "enhance", resident: p.who.id, slot } : { kind: "enhance", stock: p.stock };
const costText = (cost: Record<string, number>) => Object.entries(cost).map(([id, n]) => `${materialName(id)} ×${n}`).join("、");
const affordable = (cost: Record<string, number>) => Object.entries(cost).every(([id, n]) => have(id) >= n);
/** A 道具's recipe is open once its quest is done (the server keeps which: view.questsDone). */
const itemOpen = (i: ItemRule) => !i.unlock || (view.value?.questsDone ?? []).includes(i.unlock);
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
        <button :class="{ on: tab === 'items' }" @click="tab = 'items'">道具</button>
        <button :class="{ on: tab === 'have' }" @click="tab = 'have'">現有裝備</button>
        <button :class="{ on: tab === 'mend' }" @click="tab = 'mend'">修理<small v-if="jobs.length"> {{ jobs.length }}</small></button>
      </nav>
      <div class="panel status">
        <label class="auto">
          <input type="checkbox" :checked="view.autoGear !== false" :disabled="busy" @change="run({ kind: 'auto-gear', on: ($event.target as HTMLInputElement).checked })" />
          自動把倉庫的裝備發給最需要的居民<small>（你手動給的 📌、保留在倉庫的不會動）</small>
        </label>
        <label v-if="hasAway" class="auto far">
          <input type="checkbox" :checked="!!view.autoGearFar" :disabled="busy || view.autoGear === false" @change="run({ kind: 'auto-gear-far', on: ($event.target as HTMLInputElement).checked })" />
          也包含領地<small>（營地和城鎮一定會發）</small>
        </label>
      </div>
      <!-- what just happened: kept in sight whatever is scrolled -->
      <p v-if="message || problem" class="toast" :class="{ bad: problem }" @click="message = problem = ''">{{ problem || message }}</p>

      <section v-if="tab === 'make' && (suggestions.length || mendable)" class="panel suggest">
        <h3>建議</h3>
        <div v-for="x in suggestions" :key="x.slot" class="suggest-line">
          <GearIcon :id="x.gear.id" :size="26" />
          <span class="grow">{{ SLOT_LABELS[x.slot] }}：{{ x.need }} 隻可以換成<b>{{ x.gear.name }}</b><small class="muted">（{{ effectText(x.gear) }}）</small></span>
          <button class="btn primary" :disabled="busy" @click="make(x.gear.id, x.n)">{{ x.n > 1 ? `做 ×${x.n}` : "做 1 件" }}</button>
        </div>
        <div v-if="mendable" class="suggest-line">
          <span class="grow">修理：{{ mendable }} 件快壞了，材料夠修</span>
          <button class="btn" :disabled="busy" @click="run({ kind: 'repair-all' })">全部修理</button>
        </div>
      </section>

      <section v-if="tab === 'make'" class="panel">
        <div class="chips filter">
          <button :class="{ on: slotFilter === 'all' }" @click="slotFilter = 'all'">全部</button>
          <button v-for="s in GEAR_SLOTS" :key="s" :class="{ on: slotFilter === s }" @click="slotFilter = s">{{ SLOT_LABELS[s] }}</button>
        </div>
        <label class="only"><input v-model="onlyMakeable" type="checkbox" /> 只看做得出來的</label>
        <template v-for="({ g }, i) in recipes" :key="g.id">
          <h3 v-if="i === 0 || recipes[i - 1]!.g.slot !== g.slot">{{ SLOT_LABELS[g.slot] }}</h3>
          <article class="recipe" :class="{ dim: gearTier(g) === '未開放' }">
            <GearIcon :id="g.id" :size="34" />
            <div class="grow">
              <div class="title"><b>{{ g.name }}</b><span v-if="gearTier(g)" class="tier" :class="{ closed: gearTier(g) === '未開放' }">{{ gearTier(g) }}</span></div>
              <small class="muted">{{ effectText(g) }}{{ counts[g.id] ? `・穿著 ${counts[g.id]!.worn}・倉庫 ${counts[g.id]!.store}` : "" }}{{ gainOf(g.id) ? `・能讓 ${gainOf(g.id)} 隻變強` : "" }}</small>
              <div class="cost">
                <span v-for="[id, n] in Object.entries(g.cost)" :key="id" :class="have(id) >= n ? 'enough' : 'short'">{{ materialName(id) }} {{ have(id) }}/{{ n }}</span>
              </div>
            </div>
            <div class="make-ops">
              <button class="btn primary" :disabled="busy || !makeable(g) || (view.autoGear !== false && !gainOf(g.id))" @click="make(g.id)">
                {{ gearTier(g) === "未開放" ? "未開放" : !makeable(g) ? "材料不足" : view.autoGear !== false && !gainOf(g.id) ? "都有了" : "製作" }}
              </button>
              <button class="btn more" :disabled="busy || !makeable(g)" aria-label="做好幾件，或挑一隻給牠" @click="picking = { gear: g.id, title: `做${g.name}：做幾件，或交給誰？` }">⋯</button>
            </div>
          </article>
        </template>
        <p v-if="recipes.length === 0" class="muted">沒有符合的。</p>
      </section>

      <section v-if="tab === 'items'" class="panel">
        <p class="muted small">道具放在倉庫，出征時和加成食物一樣帶著用（每 5 隻 1 個）。有些要先完成任務才會解鎖。</p>
        <article v-for="i in ITEMS" :key="i.id" class="recipe" :class="{ dim: !itemOpen(i) }">
          <div class="grow">
            <div class="title"><b>{{ i.name }}</b><span v-if="!itemOpen(i)" class="tier closed">任務解鎖</span></div>
            <small class="muted">{{ i.what }}・倉庫有 {{ have(i.id) }}</small>
            <div class="cost">
              <span v-for="[id, n] in Object.entries(i.cost)" :key="id" :class="have(id) >= n ? 'enough' : 'short'">{{ materialName(id) }} {{ have(id) }}/{{ n }}</span>
            </div>
          </div>
          <button class="btn primary" :disabled="busy || !itemOpen(i) || !affordable(i.cost)" @click="run({ kind: 'craft', gear: i.id })">
            {{ itemOpen(i) ? "製作" : "未解鎖" }}
          </button>
        </article>
      </section>

      <section v-if="tab === 'have'" class="panel">
        <p class="muted small">📌 是你手動給的（自動分配不會動）；「保留」的留在倉庫，不會自動發出去。<template v-if="view.canRefine">★ 是改造過的精良裝備（強 30%）；「★ 改造」要花做這件的全部材料。</template></p>
        <template v-for="slot in GEAR_SLOTS" :key="slot">
          <template v-if="pieces[slot]?.length">
            <h3>{{ SLOT_LABELS[slot] }} <small>{{ pieces[slot]!.length }} 件</small></h3>
            <template v-for="[id, list] in kindsIn(pieces[slot]!)" :key="id">
            <button class="kind" @click="toggle(id)">
              <GearIcon :id="id" />
              <span class="grow"><b>{{ gearName(id) }}</b> ×{{ list.length }} <small class="muted">穿著 {{ list.filter((p) => p.who).length }}・倉庫 {{ list.filter((p) => !p.who).length }}</small></span>
              <small class="muted">{{ opened.has(id) ? "收起 ▴" : "看是誰 ▾" }}</small>
            </button>
            <template v-if="opened.has(id)">
            <article v-for="p in list" :key="`${p.who?.id ?? 'store'}-${p.stock ?? slot}-${p.item.id}`" class="piece sub">
              <GearIcon :id="p.item.id" />
              <div class="grow">
                <b>{{ pieceLabel(p.item) }}</b> <small>{{ durabilityText(p.item) }}</small>
                <small v-if="p.item.pinned"> 📌</small>
                <div class="muted small">{{ p.who ? `${nameOf(p.who)}（${breedNames[p.who.breed] ?? p.who.breed}${whereText(p.who)}）` : p.item.held ? "倉庫・保留" : "倉庫" }}</div>
              </div>
              <button v-if="view.canRefine && !p.item.refined" class="btn" :disabled="busy || !affordable(gearRule(p.item.id)!.cost)" :title="`改造成 ★ 精良（${costText(gearRule(p.item.id)!.cost)}）`"
                @click="run(p.who ? { kind: 'refine', resident: p.who.id, slot } : { kind: 'refine', stock: p.stock })">★ 改造</button>
              <button class="btn" :class="{ on: enhancing === pieceKey(p, slot) }" :disabled="busy || (p.item.plus ?? 0) >= ENHANCE_MAX"
                @click="enhancing = enhancing === pieceKey(p, slot) ? null : pieceKey(p, slot)">{{ (p.item.plus ?? 0) >= ENHANCE_MAX ? `+${ENHANCE_MAX}` : "強化" }}</button>
              <div v-if="enhancing === pieceKey(p, slot) && enhanceCost(p.item)" class="enhance">
                <div class="small"><b>+{{ p.item.plus ?? 0 }} → +{{ (p.item.plus ?? 0) + 1 }}</b>：能力 +6%、耐久 +10%（不會失敗，順便修好）</div>
                <div class="cost">
                  <span v-for="[id, n] in Object.entries(enhanceCost(p.item)!)" :key="id" :class="have(id) >= n ? 'enough' : 'short'">{{ materialName(id) }} {{ have(id) }}/{{ n }}</span>
                </div>
                <button class="btn primary" :disabled="busy || !affordable(enhanceCost(p.item)!)" @click="run(enhanceCommand(p, slot))">強化到 +{{ (p.item.plus ?? 0) + 1 }}</button>
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
          </template>
        </template>
        <p v-if="Object.keys(pieces).length === 0" class="muted">還沒有任何裝備。</p>
      </section>

      <section v-if="tab === 'mend'" class="panel">
        <p class="muted small">耐久低於 75% 的裝備，花三分之一的材料就能修好。</p>
        <button v-if="jobs.length" class="btn primary all" :disabled="busy || !mendable" @click="run({ kind: 'repair-all' })">
          {{ mendable === jobs.length ? `全部修理（${jobs.length} 件）` : `修材料夠的（${mendable}/${jobs.length} 件）` }}
        </button>
        <article v-for="p in jobs.slice(0, 30)" :key="`${p.who?.id ?? 'store'}-${p.stock ?? ''}-${p.item.id}`" class="piece">
          <GearIcon :id="p.item.id" />
          <div class="grow">
            <b>{{ pieceLabel(p.item) }}</b> <small>{{ durabilityText(p.item) }}</small>
            <div class="muted small">{{ p.who ? nameOf(p.who) + whereText(p.who) : "倉庫" }}・{{ costText(repairCost(gearRule(p.item.id)!)) }}</div>
          </div>
          <button class="btn primary" :disabled="busy || !affordable(repairCost(gearRule(p.item.id)!))"
            @click="run(p.who ? { kind: 'repair', resident: p.who.id, slot: gearRule(p.item.id)!.slot } : { kind: 'repair', stock: p.stock })">修理</button>
        </article>
        <p v-if="jobs.length === 0" class="muted">沒有要修的。</p>
      </section>
    </template>
    <ResidentPicker
      v-if="picking && view"
      :view="view"
      :gear="picking.gear"
      :title="picking.title"
      :allow-auto="false"
      :batches="picking.stock === undefined ? batchesFor(picking.gear) : []"
      :names="breedNames"
      @pick="picked"
      @batch="batch"
      @close="picking = null"
    />
  </main>
</template>

<style scoped>
.toast { position: fixed; left: 50%; bottom: calc(env(safe-area-inset-bottom) + 76px); transform: translateX(-50%); z-index: 30; max-width: min(520px, calc(100vw - 32px)); margin: 0; padding: 10px 14px; border-radius: 12px; background: #2f6b2a; color: #fff; font-weight: 600; box-shadow: 0 4px 14px rgba(0, 0, 0, 0.25); cursor: pointer; }
.toast.bad { background: #b3412c; }
.suggest h3 { margin-top: 0; }
.suggest-line { display: flex; align-items: center; gap: 8px; padding: 6px 0; border-top: 1px solid var(--line); }
.suggest-line:first-of-type { border-top: 0; }
.make-ops { display: flex; gap: 4px; }
.btn.more { padding-left: 10px; padding-right: 10px; }
.kind { display: flex; align-items: center; gap: 10px; width: 100%; text-align: left; border: 0; border-top: 1px solid var(--line); background: none; padding: 9px 0; font: inherit; color: inherit; cursor: pointer; }
.piece.sub { padding-left: 24px; }
.btn.all { margin: 4px 0 8px; }
section { margin-top: 12px; }
h3 { font-size: 13px; margin: 16px 0 6px; color: var(--muted); }
h3 small { font-weight: 400; }
.tabs { display: flex; gap: 6px; margin-top: 12px; }
.tabs button { flex: 1; border: 1px solid var(--line); background: #faf8f0; border-radius: 10px; padding: 9px 0; font: inherit; font-weight: 700; cursor: pointer; color: inherit; }
.tabs button.on { background: var(--green); color: #fff; border-color: var(--green); }
.status { margin-top: 10px; padding-top: 10px; padding-bottom: 10px; }
.auto { display: block; font-size: 14px; }
.auto small { color: var(--muted); }
.auto.far { margin: 6px 0 0 22px; }
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
.enhance { flex-basis: 100%; display: flex; flex-direction: column; gap: 4px; padding: 6px 0 0 40px; }
.enhance .btn { align-self: flex-start; }
.cost { display: flex; flex-wrap: wrap; gap: 4px 10px; font-size: 12px; margin-top: 3px; }
.enough { color: var(--green); }
.short { color: var(--red); }
.muted { color: var(--muted); }
.small { font-size: 12px; }
.ok { color: var(--green); font-weight: 600; margin: 8px 2px 0; }
.warn { color: #b3412c; margin: 8px 2px 0; }
.piece .btn { white-space: nowrap; }
.piece { flex-wrap: wrap; }
</style>
