<script setup lang="ts">
// Everyone at home, strongest first; tap one to see and change what it wears, slot by slot (from the store, or take it
// off). What is put on here is pinned (📌): the handing out leaves it be.
import type { CampResidentView, GearSlot } from "@goblincamp/shared/camp";

const ok = await useSignedIn();
const { user } = useAccount();
const camp = useCamp();
const names = ref<ArtNames>({ races: {}, materials: {} });
onMounted(async () => (names.value = await loadArtNames()));
onUnmounted(() => camp.close());
if (ok && user.value) void camp.open(user.value.id);

const view = computed(() => camp.state.saved?.view ?? null);
const race = computed(() => view.value?.race ?? "goblin");
const art = computed(() => names.value.races[race.value]);
const breedName = (b: string) => art.value?.breeds[b] ?? b;
const nameOf = (r: CampResidentView) => r.name || residentNameFromSeed(race.value, r.seed, r.legacySeed);

const filter = ref("");
const sort = ref<"power" | "gear" | "id">("power");
const rows = computed(() =>
  (view.value?.residents ?? [])
    .filter((r) => r.place === "home")
    .map((r) => ({ r, power: residentPower(race.value, r), pieces: Object.keys(r.gear ?? {}).length }))
    .filter(({ r }) => !filter.value || nameOf(r).includes(filter.value) || breedName(r.breed).includes(filter.value))
    .sort((a, b) => (sort.value === "power" ? b.power - a.power : sort.value === "gear" ? a.pieces - b.pieces || b.power - a.power : a.r.id - b.r.id)),
);
const shown = ref(60);
const open = ref<number | null>(null);
const busy = ref(false);
const message = ref("");
const problem = ref("");

/** The store's pieces that fit `slot`, best first, with their place in the store. */
const fits = (slot: GearSlot) =>
  (view.value?.armory ?? [])
    .map((item, stock) => ({ item, stock }))
    .filter(({ item }) => gearRule(item.id)?.slot === slot)
    .sort((a, b) => pieceWorth(b.item) - pieceWorth(a.item));

async function change(r: CampResidentView, slot: GearSlot, value: string) {
  busy.value = true;
  problem.value = "";
  message.value = "";
  try {
    if (value === "off") message.value = await gearCommand({ kind: "unequip", resident: r.id, slot });
    else {
      const stock = Number(value);
      message.value = await gearCommand({ kind: "equip", resident: r.id, stock, gear: view.value!.armory[stock]!.id });
    }
  } catch (e) {
    problem.value = (e as Error).message;
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <main v-if="ok" class="page">
    <header class="topbar">
      <NuxtLink to="/camp" class="icon-btn">← 營地</NuxtLink>
      <div style="flex: 1"><h1>名冊</h1><div class="sub">點一隻可以換裝備</div></div>
      <NuxtLink to="/workshop" class="icon-btn">工坊</NuxtLink>
    </header>
    <div v-if="!view" class="panel">{{ camp.state.status === "loading" ? "讀取中…" : "還沒有營地。" }}</div>
    <template v-else>
      <div class="tools">
        <input v-model="filter" class="find" placeholder="找名字或品種" />
        <select v-model="sort">
          <option value="power">戰力高的先</option>
          <option value="gear">裝備少的先</option>
          <option value="id">照編號</option>
        </select>
      </div>
      <p v-if="message" class="ok">{{ message }}</p>
      <p v-if="problem" class="warn">{{ problem }}</p>
      <p class="muted small">在家 {{ rows.length }} 隻・倉庫 {{ view.armory.length }} 件・{{ view.autoGear === false ? "自動分配關著" : "自動分配開著" }}</p>
      <ul class="list">
        <li v-for="{ r, power, pieces } in rows.slice(0, shown)" :key="r.id" :class="{ open: open === r.id }">
          <button class="row" @click="open = open === r.id ? null : r.id">
            <span class="icon pixel" :style="{ backgroundImage: `url(/sprites/${race}/${art?.sheets[r.breed] ?? 'worker'}.png)` }" />
            <span class="grow"><b>{{ nameOf(r) }}</b> <small>{{ breedName(r.breed) }}・#{{ r.id }}</small></span>
            <small>裝備 {{ pieces }}/7</small>
            <b class="power">{{ power }}</b>
          </button>
          <div v-if="open === r.id" class="slots">
            <label v-for="slot in GEAR_SLOTS" :key="slot" class="slot">
              <span class="label">{{ SLOT_LABELS[slot] }}</span>
              <select :disabled="busy" :value="'now'" @change="change(r, slot, ($event.target as HTMLSelectElement).value)">
                <option value="now">{{ r.gear?.[slot] ? `${gearName(r.gear[slot]!.id)} ${durabilityText(r.gear[slot]!)}${r.gear[slot]!.pinned ? " 📌" : ""}` : "（空）" }}</option>
                <option v-if="r.gear?.[slot]" value="off">脫下，收回倉庫</option>
                <option v-for="{ item, stock } in fits(slot)" :key="stock" :value="String(stock)">
                  換上 {{ gearName(item.id) }} {{ durabilityText(item) }}{{ item.held ? "（保留的）" : "" }}
                </option>
              </select>
            </label>
            <p v-if="view.armory.length === 0" class="muted small">倉庫是空的；到工坊做裝備時可以直接選給牠。</p>
          </div>
        </li>
      </ul>
      <button v-if="rows.length > shown" class="more" @click="shown += 100">再多列一些（還有 {{ rows.length - shown }} 隻）</button>
    </template>
  </main>
</template>

<style scoped>
.tools { display: flex; gap: 8px; margin-top: 12px; }
.find { flex: 1; min-width: 0; padding: 8px 10px; border: 1px solid var(--line); border-radius: 10px; font: inherit; }
select { padding: 7px 8px; border: 1px solid var(--line); border-radius: 10px; font: inherit; background: #fff; max-width: 100%; }
.list { list-style: none; margin: 8px 0 0; padding: 0; display: grid; gap: 6px; }
.row { width: 100%; display: flex; align-items: center; gap: 10px; border: 1px solid var(--line); background: #fffdf5; border-radius: 10px; padding: 6px 10px; font: inherit; color: inherit; text-align: left; cursor: pointer; }
.open .row { border-color: var(--green); }
.row small { color: var(--muted); font-size: 12px; white-space: nowrap; }
.grow { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.power { min-width: 2.2em; text-align: right; }
.icon { flex: none; width: 32px; height: 32px; background-size: 128px 96px; background-position: 0 0; }
.slots { display: grid; gap: 6px; margin-top: 4px; padding: 10px; background: #fffdf5; border-radius: 10px; }
.slot { display: flex; align-items: center; gap: 8px; }
.slot .label { width: 3em; flex: none; font-size: 13px; color: var(--muted); }
.slot select { flex: 1; min-width: 0; }
.muted { color: var(--muted); }
.small { font-size: 12px; }
.ok { color: var(--green); font-weight: 600; margin: 8px 2px 0; }
.warn { color: #b3412c; margin: 8px 2px 0; }
.more { border: 0; background: none; color: var(--green); font-weight: 700; padding: 10px 0; cursor: pointer; }
</style>
