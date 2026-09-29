<script setup lang="ts">
import { cellBuildingName, cellCenter, GUESTS_MAX, landmarkRule, LANDMARKS, type NearbyLandmark, FOES, HOME_MOVE_DAYS, isCellId, materialName, TERRAIN_NAMES, TERRAIN_YIELD, travelMinutes, type CellView } from "@goblincamp/shared/world";
import { noteTime } from "~/utils/time";
import { ApiError, api } from "~/utils/api";

// 大世界: the real map with the lairs and camps on it. Tapping a cell brings up a card from the bottom (what is there, and
// what can be done: attack, settle, send more, build, recall); an action that sends a party opens the dispatch dialog.
const ok = await useSignedIn();
const world = useWorld();
const { race, noun, ensure } = useRace();
void ensure();
const s = world.state;
const now = ref(Date.now());
let clock: ReturnType<typeof setInterval> | undefined;
const route = useRoute();
onMounted(async () => {
  clock = setInterval(() => (now.value = Date.now()), 1000);
  await world.open();
  // (?cell=…: come from a cell's own page, open the map on it)
  const asked = String(route.query.cell ?? "");
  if (asked && isCellId(asked)) {
    await world.moveTo(cellCenter(asked));
    pick(asked);
  }
});
onUnmounted(() => {
  clearInterval(clock);
  world.close();
});

/** Places to start looking from (the map is the real world; pick somewhere public, not your home). */
const PLACES = [
  { name: "大安森林公園", lat: 25.0302, lng: 121.5357 },
  { name: "台北 101", lat: 25.0336, lng: 121.5647 },
  { name: "新竹公園", lat: 24.8016, lng: 120.9786 },
  { name: "台中公園", lat: 24.1449, lng: 120.6844 },
  { name: "高雄中央公園", lat: 22.6246, lng: 120.3016 },
];
/** Where the phone is (asked only when the person taps 找我附近的地方): the map goes there and suggests the parks and landmarks round it. */
const mapView = ref<{ placesNear: (at: { lat: number; lng: number }) => Promise<{ name: string; lat: number; lng: number; km: number }[]> }>();
const nearby = ref<{ name: string; lat: number; lng: number; km: number }[] | null>(null);
const locating = ref(false);
const locateProblem = ref("");
async function findNearby() {
  if (!navigator.geolocation) {
    locateProblem.value = "這支手機不能定位，從下面的地方挑一個吧。";
    return;
  }
  locating.value = true;
  locateProblem.value = "";
  try {
    const at = await new Promise<{ lat: number; lng: number }>((done, fail) =>
      navigator.geolocation.getCurrentPosition((p) => done({ lat: p.coords.latitude, lng: p.coords.longitude }), fail, { enableHighAccuracy: false, timeout: 10_000, maximumAge: 600_000 }),
    );
    await world.moveTo(at);
    await nextTick();
    nearby.value = (await mapView.value?.placesNear(at)) ?? [];
    if (!nearby.value.length) locateProblem.value = "附近 3 公里內找不到有名字的公園或地標，直接在地圖上點一格也可以。";
  } catch {
    locateProblem.value = "沒辦法知道你在哪（可能沒有允許定位），從下面的地方挑一個吧。";
  } finally {
    locating.value = false;
  }
}
const distance = (km: number) => (km < 1 ? `${Math.round(km * 1000)} 公尺` : `${km.toFixed(1)} 公里`);
// (if the phone already allowed it, look right away)
onMounted(async () => {
  try {
    // (only while there is no camp yet: after that the map starts at the camp)
    if (!world.state.me) await world.refresh();
    if (!world.state.me?.homeCell && (await navigator.permissions?.query({ name: "geolocation" }))?.state === "granted") void findNearby();
  } catch {
    // (no permissions API: wait for the tap)
  }
});
const center = computed(() => s.center ?? s.me?.home ?? PLACES[0]!);
const selected = ref<string | null>(null);
const cell = computed<CellView | null>(() => s.cells.find((c) => c.cell === selected.value) ?? null);
const myId = computed(() => s.cells.find((c) => c.cell === s.me?.homeCell)?.owner?.id ?? null);
const mine = computed(() => !!cell.value?.owner && cell.value.owner.id === myId.value);
const myCell = computed(() => s.me?.cells.find((c) => c.cell === selected.value) ?? null);
const message = ref("");
const busy = ref(false);
const spare = computed(() => Math.max(0, (s.me?.atHome ?? 0) - 2));
function pick(c: string) {
  selected.value = c;
  message.value = "";
}

async function doIt(work: () => Promise<string | null>, done: string) {
  busy.value = true;
  message.value = "";
  const problem = await work();
  busy.value = false;
  message.value = problem ?? done;
}
/** A name for the cell picked, for the questions below: the nearest suggested place, or its ground. */
const placeName = computed(() => {
  const c = cell.value;
  if (!c) return "";
  const near = nearby.value?.find((p) => Math.hypot((p.lat - c.lat) * 110_574, (p.lng - c.lng) * 100_000) < 250);
  return near?.name ?? TERRAIN_NAMES[c.terrain];
});
/** The camp's place is asked twice, in the card itself (the Mac's window shows no browser dialogs): tap, then 確定. */
const asking = ref<"open" | "move" | null>(null);
watch(selected, () => (asking.value = null));
const openHere = () => {
  asking.value = null;
  void doIt(() => world.openWorld(selected.value!), "大世界開啟了！營地就在這一格。");
};
// someone else's cell: ask them to be friends (or go and write to them)
const live = useLive();
const isFriend = computed(() => !!cell.value?.owner && !!live.state.friends?.friends.some((f) => f.id === cell.value!.owner!.id));
const askedFriend = computed(() => !!cell.value?.owner && !!live.state.friends?.outgoing.some((f) => f.id === cell.value!.owner!.id));
const addFriend = () =>
  doIt(async () => {
    try {
      const out = await api<{ status: string }>("POST", "friends/asks", { userId: cell.value!.owner!.id });
      await live.loadFriends();
      return out.status === "friends" ? "成為好友了！" : `送出好友邀請了，等${cell.value?.owner?.name}答應。`;
    } catch (e) {
      return e instanceof Error ? e.message : String(e);
    }
  }, "");
const isHome = computed(() => !!cell.value && cell.value.cell === s.me?.homeCell);
/** When the camp may move again, as words (null: it may now). */
const moveWait = computed(() => {
  const at = s.me?.homeMoveAt ? Date.parse(s.me.homeMoveAt) : 0;
  if (at <= now.value) return null;
  const h = Math.ceil((at - now.value) / 3_600_000);
  return h >= 24 ? `${Math.ceil(h / 24)} 天後` : `${h} 小時後`;
});
const canMoveHere = computed(() => !!s.me?.homeCell && !!cell.value && !isHome.value && !cell.value.boss && (!cell.value.owner || mine.value));
const moveHere = () => {
  asking.value = null;
  void doIt(() => world.moveHome(selected.value!), "營地搬過來了！");
};
const openAgain = () => doIt(() => world.openWorld(), "重新開啟了大世界。");
const nest = () => doIt(() => world.nest(selected.value!), "開始蓋繁殖巢了（2 小時）。");
const town = () => doIt(() => world.town(selected.value!), "蓋了城鎮！");
const recall = () => {
  if (!confirm("所有居民都走回營地，這一格就不是你的了。")) return;
  void doIt(() => world.recall(selected.value!), "都回營地了。");
};

// the dispatch dialog
const dispatch = ref<"attack" | "settle" | "move" | "guard" | null>(null);
async function sent(party: number[], settle: boolean, from: string, supplies: Record<string, number>) {
  const to = selected.value!;
  const guard = dispatch.value === "guard";
  dispatch.value = null;
  await doIt(() => world.send(to, party, settle, from, supplies, guard), `出發了！${party.length} 隻上路。`);
}
/** My residents guarding the cell picked (a friend's). */
const myGuests = computed(() => s.me?.guarding.find((g) => g.cell === selected.value)?.count ?? 0);
const unguard = () => doIt(() => world.unguard(selected.value!), "幫守的居民回家了。");

/** My parties on the road, from where they set out (the camp's cell for "home") to where they are going. */
const parties = computed(() =>
  (s.me?.walking ?? []).flatMap((w) => {
    const from = w.from === "home" ? s.me?.homeCell : w.from;
    if (!from) return [];
    return [{ id: w.id, from: cellCenter(from), to: cellCenter(w.to), setOutAt: w.setOutAt, arriveAt: w.arriveAt, race: race.value }];
  }),
);
const goHome = () => s.me?.home && world.moveTo(s.me.home);

async function goToBoss(b: { cell: string; lat: number; lng: number }) {
  await world.moveTo({ lat: b.lat, lng: b.lng });
  pick(b.cell);
}
const hoursLeft = (iso: string) => {
  const m = Math.max(0, Math.round((Date.parse(iso) - now.value) / 60_000));
  return m >= 60 ? `${Math.floor(m / 60)} 小時 ${m % 60} 分` : `${m} 分鐘`;
};
const minutesTo = computed(() => (s.me?.homeCell && selected.value ? travelMinutes(s.me.homeCell, selected.value) : null));
const lootText = (loot: Record<string, number>) => Object.entries(loot).sort((a, b) => b[1] - a[1]).slice(0, 4).map(([id, n]) => `${materialName(id)} ${n}`).join("、");
const costList = (cost: Record<string, number>) => Object.entries(cost).map(([id, n]) => `${materialName(id)} ${n}`).join("、");
const left = (iso: string) => {
  const sec = Math.max(0, Math.round((Date.parse(iso) - now.value) / 1000));
  return sec === 0 ? "到了，結算中…" : `${Math.floor(sec / 60)} 分 ${String(sec % 60).padStart(2, "0")} 秒後到`;
};
const cellName = (id: string) => {
  if (id === "home") return "營地";
  const c = s.cells.find((x) => x.cell === id);
  return c ? (c.owner ? `${c.owner.name}的領地` : c.lair ? c.lair.name : TERRAIN_NAMES[c.terrain]) : "遠方";
};
const title = computed(() => {
  const c = cell.value;
  if (!c) return "";
  if (c.owner) return mine.value ? (c.cell === s.me?.homeCell ? "你的營地" : "你的領地") : `${c.owner.name}的領地`;
  if (c.boss) return `世界魔王・${c.boss.name}`;
  if (c.lair) return c.lair.name;
  return TERRAIN_NAMES[c.terrain];
});
const canAct = computed(() => !!s.me?.open && spare.value > 0);

// 附近地標: the landmarks around where the map is looking (3 km), the nearest first; tapping one goes there
const landmarkList = ref<NearbyLandmark[] | null>(null);
const landmarkKind = ref("");
const landmarkBusy = ref(false);
const landmarkProblem = ref("");
async function findLandmarks() {
  landmarkBusy.value = true;
  landmarkProblem.value = "";
  try {
    const at = center.value;
    landmarkList.value = (await api<{ landmarks: NearbyLandmark[] }>("GET", `world/landmarks?lat=${at.lat.toFixed(6)}&lng=${at.lng.toFixed(6)}`)).landmarks;
  } catch (e) {
    landmarkProblem.value = e instanceof ApiError ? e.message : String(e);
  } finally {
    landmarkBusy.value = false;
  }
}
const shownLandmarks = computed(() => (landmarkList.value ?? []).filter((l) => !landmarkKind.value || l.kind === landmarkKind.value));
async function goToLandmark(l: NearbyLandmark) {
  landmarkList.value = null;
  await world.moveTo({ lat: l.lat, lng: l.lng });
  pick(l.cell);
}
</script>

<template>
  <main v-if="ok" class="page" :class="{ 'with-sheet': !!cell }">
    <header class="topbar">
      <NuxtLink to="/camp" class="icon-btn">← 營地</NuxtLink>
      <div style="flex: 1">
        <h1>大世界</h1>
        <div v-if="s.me" class="sub">{{ noun }} Lv{{ s.me.level }}（{{ s.me.xp }}/{{ s.me.nextLevelXp }}）・{{ s.me.cells.length }} 格・在家 {{ s.me.atHome }}<template v-if="s.me.upkeep?.paying">・<span :class="{ hungry: s.me.upkeep.rations < s.me.upkeep.perYield }">乾糧 {{ s.me.upkeep.rations }}（每 3 小時吃 {{ s.me.upkeep.perYield }}）</span></template></div>
      </div>
      <NuxtLink to="/leaderboard" class="icon-btn">排行</NuxtLink>
    </header>

    <div v-if="!s.me" class="panel">{{ s.problem || "讀取中…" }}</div>
    <template v-else>
      <section v-if="!s.me.homeCell && !s.me.canOpen" class="panel intro">
        <h2>還不能開啟大世界</h2>
        <p>營地要曾經有過 <b>{{ s.me.unlockPeak }}</b> 隻（第三階段）才能開啟；現在最多時是 {{ s.me.peak }} 隻。</p>
        <p class="muted">先看看附近有什麼：拖動地圖，點格子看看。</p>
      </section>
      <section v-else-if="!s.me.homeCell" class="panel intro">
        <h2>先選營地的位置</h2>
        <p>地圖是真實世界：點一格，把你的營地放在那裡——整個營地都在那一格，不用派人。之後再從營地出發去打怪、佔地。<b>請選公園、地標這類公開的地方，不要選自己家。</b></p>
      </section>
      <section v-else-if="!s.me.open" class="panel intro">
        <h2>龜縮中</h2>
        <p>上一場打輸了，營地和領地現在都不會被打，但也不能出征。準備好了就重新開啟。</p>
        <button class="btn primary" :disabled="busy" @click="openAgain">重新開啟大世界</button>
      </section>

      <button v-if="s.me.bosses?.length" class="boss-banner" @click="goToBoss(s.me.bosses[0]!)">
        <b>世界魔王：{{ s.me.bosses[0]!.name }}（{{ s.me.bosses[0]!.km }} 公里外）</b>
        <span>剩 {{ Math.round((100 * s.me.bosses[0]!.hp) / s.me.bosses[0]!.maxHp) }}% 血・{{ hoursLeft(s.me.bosses[0]!.endsAt) }}後離開・點一下去看看</span>
      </button>

      <div v-if="!s.me.homeCell" class="places">
        <button class="chip here" :disabled="locating" @click="findNearby">{{ locating ? "找附近的地方中…" : "📍 找我附近的地方" }}</button>
        <template v-if="nearby?.length">
          <button v-for="p in nearby" :key="p.name" class="chip" @click="world.moveTo(p)">{{ p.name }}<small>{{ distance(p.km) }}</small></button>
        </template>
        <template v-else>
          <button v-for="p in PLACES" :key="p.name" class="chip" @click="world.moveTo(p)">{{ p.name }}</button>
        </template>
        <p v-if="locateProblem" class="places-note">{{ locateProblem }}</p>
        <p v-else-if="nearby?.length" class="places-note">挑一個公園或地標當營地吧——地圖是真的，別選你家。</p>
      </div>

      <div class="map-tools">
        <button class="chip" :disabled="landmarkBusy" @click="landmarkList ? (landmarkList = null) : findLandmarks()">
          {{ landmarkBusy ? "找地標中…" : landmarkList ? "收起地標" : "🏛️ 附近地標" }}
        </button>
      </div>
      <section v-if="landmarkList" class="panel landmarks">
        <div class="kinds">
          <button :class="{ on: !landmarkKind }" @click="landmarkKind = ''">全部 {{ landmarkList.length }}</button>
          <button v-for="k in LANDMARKS.filter((k) => landmarkList!.some((l) => l.kind === k.kind))" :key="k.kind" :class="{ on: landmarkKind === k.kind }" @click="landmarkKind = k.kind">
            {{ k.icon }} {{ k.name }}
          </button>
        </div>
        <p v-if="!shownLandmarks.length" class="muted small">地圖中心 3 公里內沒有地標，拖到別的地方再找一次。</p>
        <button v-for="l in shownLandmarks" :key="l.cell" class="landmark-row" @click="goToLandmark(l)">
          <span class="icon">{{ landmarkRule(l.kind)?.icon }}</span>
          <span class="grow"><b>{{ l.name }}</b><small>{{ landmarkRule(l.kind)?.name }}・{{ landmarkRule(l.kind)?.blurb }}</small></span>
          <span class="side">
            <small>{{ distance(l.km) }}</small>
            <small :class="l.owner ? (l.owner.id === myId ? 'mine' : 'taken') : 'free'">{{ l.owner ? (l.owner.id === myId ? "你的" : `${l.owner.name}的`) : "沒人佔" }}</small>
          </span>
        </button>
      </section>
      <p v-if="landmarkProblem" class="status error">{{ landmarkProblem }}</p>

      <WorldMap
        ref="mapView"
        :cells="s.cells"
        :center="center"
        :mine="myId"
        :selected="selected"
        :walking-to="s.me.walking.map((w) => w.to)"
        :parties="parties"
        :home="s.me.homeCell ? race : null"
        @select="pick"
        @pan="world.moveTo"
        @home="goHome"
      />
      <p class="legend">真實世界的地圖（OpenStreetMap）。格子裡是那裡最強的怪物與等級，大馬路邊有強盜與強獸人；黃框是你的，紅框是別人的。點一格看看。</p>

      <section v-if="s.me.walking.length" class="panel">
        <h2>在路上</h2>
        <p v-for="w in s.me.walking" :key="w.id" class="line">
          {{ w.party }} 隻 → {{ cellName(w.to) }}{{ w.kind === "move" ? "（搬家）" : w.kind === "guard" ? "（幫守）" : "" }}<br />
          <small>{{ left(w.arriveAt) }}</small>
        </p>
      </section>

      <section v-if="s.me.happenings?.length" class="panel">
        <h2>最近的事</h2>
        <p v-for="(h, k) in s.me.happenings.slice(0, 5)" :key="k" class="line">
          <template v-if="h.lairBack">
            <span :class="h.lairBack.held ? 'won' : 'lost'">{{ h.lairBack.held ? "守住了" : "被搶回去了" }}</span>
            {{ h.lairBack.name }}（{{ h.lairBack.level }} 級）回來搶領地{{ h.lairBack.fallen ? `，倒下 ${h.lairBack.fallen} 隻` : "" }}{{ h.lairBack.held && Object.keys(h.lairBack.loot).length ? `，撿到 ${lootText(h.lairBack.loot)}` : "" }}
          </template>
          <template v-else-if="h.bossReward">
            <span class="won">世界魔王{{ h.bossReward.name }}倒下了</span>：出了 {{ Math.round(h.bossReward.share * 100) }}% 的力，分到 {{ lootText(h.bossReward.loot) }}，經驗 +{{ h.bossReward.xp }}
          </template>
          <template v-else-if="h.yields">領地送來了 {{ lootText(h.yields) }}</template>
          <br /><small>{{ noteTime(h.at) }}</small>
        </p>
      </section>

      <section v-if="s.me.recent.length" class="panel">
        <h2>戰報</h2>
        <NuxtLink v-for="r in s.me.recent.slice(0, 5)" :key="r.id" :to="`/expedition/${r.id}`" class="report">
          <span :class="wentWell(r) ? 'won' : 'lost'">{{ outcomeText(r) }}</span>
          <span class="grow">{{ r.outcome?.against }}</span>
          <small>{{ noteTime(r.arriveAt) }}</small>
        </NuxtLink>
      </section>
    </template>

    <!-- the card of the cell picked -->
    <aside v-if="cell && s.me" class="sheet">
      <button class="x" aria-label="關閉" @click="selected = null">✕</button>
      <div class="head">
        <span class="badge">
          <FoeIcon v-if="cell.boss" :id="cell.boss.kind" :size="48" />
          <img v-else-if="cell.owner" :src="`/sprites/${cell.owner.race}/icon.png`" class="pixel face" alt="" />
          <FoeIcon v-else-if="cell.lair" :id="cell.lair.kind === 'enemy_town' ? 'enemy_town' : leaderOf(cell.lair.foes)" :size="48" />
          <span v-else class="ground" :class="cell.terrain" />
        </span>
        <div class="grow">
          <h2>{{ title }}<small v-if="cell.lair"> {{ cell.lair.level }} 級</small></h2>
          <p v-if="cell.lair?.boss" class="boss-tag">👑 初期魔王：比一般巢穴強很多，會掉做中等裝備的材料。打輸了傷會留著，可以找朋友接著打。</p>
          <p class="muted">{{ TERRAIN_NAMES[cell.terrain] }}{{ minutesTo !== null && !mine ? `・從營地走約 ${minutesTo} 分鐘` : "" }}</p>
          <p v-if="cell.landmark" class="landmark">{{ landmarkRule(cell.landmark.kind)?.icon }} {{ cell.landmark.name }}（{{ landmarkRule(cell.landmark.kind)?.name }}）<small>{{ landmarkRule(cell.landmark.kind)?.blurb }}</small></p>
        </div>
      </div>

      <!-- what is there -->
      <div v-if="cell.lair" class="foes">
        <span v-for="(n, id) in cell.lair.foes" :key="id" class="foe"><FoeIcon :id="String(id)" :size="32" /><small>{{ FOES[String(id)]?.name ?? id }} ×{{ n }}</small></span>
        <span class="power"><small>戰力</small><b>{{ cell.lair.power }}</b></span>
      </div>
      <p v-if="cell.lair && cell.lairWounds" class="wounds">
        受傷中：剩 {{ cell.lairWounds.standing }}/{{ cell.lairWounds.total }} 隻、{{ Math.round(cell.lairWounds.hpShare * 100) }}% 血，{{ noteTime(cell.lairWounds.healedAt) }}恢復——趁現在派第二波！
      </p>
      <template v-else-if="cell.boss">
        <div class="hpbar"><i :style="{ width: `${(100 * cell.boss.hp) / cell.boss.maxHp}%` }" /></div>
        <p class="muted">{{ cell.boss.hp }} / {{ cell.boss.maxHp }} 血・{{ hoursLeft(cell.boss.endsAt) }}後離開。牠的傷會留著，大家一起打。</p>
      </template>
      <template v-else-if="mine">
        <p v-if="isHome">營地就在這裡：在家的 <b>{{ cell.garrison }}</b> 隻都住這、守這，營地本身就會生居民{{ cell.town ? "・城鎮" : "" }}</p>
        <p v-else>住了 <b>{{ cell.garrison }}</b> 隻・{{ { none: "還沒有繁殖巢（不會自己生居民）", building: "繁殖巢蓋到一半", ready: "有繁殖巢，會自己生居民" }[cell.nest] }}{{ cell.town ? "・城鎮" : "" }}</p>
        <p v-if="cell.guests" class="small">🤝 好友幫守 {{ cell.guests }} 隻</p>
        <p v-if="cell.building" class="small">🏗️ {{ cellBuildingName(cell.building.kind, race) }} {{ cell.building.level }} 級{{ cell.building.busy ? "（蓋到一半）" : "" }}</p>
        <p class="muted small">每 3 小時產出：{{ (TERRAIN_YIELD[cell.terrain] ?? []).map((y) => materialName(y.id)).join("、") }}{{ myCell ? `・下次 ${noteTime(myCell.nextYieldAt)}` : "" }}</p>
      </template>
      <p v-else-if="cell.owner" class="muted">住了 {{ cell.garrison }} 隻{{ cell.guests ? `・好友幫守 ${cell.guests} 隻` : "" }}{{ cell.building ? `・${cellBuildingName(cell.building.kind, cell.owner.race)} ${cell.building.level} 級` : "" }}</p>
      <p v-else-if="cell.lairBackAt" class="muted">巢穴清掉了，{{ noteTime(cell.lairBackAt) }} 會回來。現在可以直接住。</p>
      <p v-else class="muted">什麼都沒有，可以直接住。</p>

      <!-- what can be done -->
      <div class="actions">
        <template v-if="!s.me.homeCell">
          <template v-if="s.me.canOpen && !cell.owner && !cell.boss">
            <p v-if="cell.lair" class="muted small wide">營地放下來，這裡的{{ cell.lair.name }}就會被趕走。</p>
            <div v-if="asking === 'open'" class="ask wide">
              <p>把營地放在「<b>{{ placeName }}</b>」這一格？整個營地都在這裡（在家的 {{ s.me.atHome }} 隻都住這、守這），之後 {{ HOME_MOVE_DAYS }} 天可以搬一次。</p>
              <button class="btn primary" :disabled="busy" @click="openHere">確定</button>
              <button class="btn" @click="asking = null">再想想</button>
            </div>
            <button v-else class="btn primary wide" :disabled="busy" @click="asking = 'open'">把營地放在這裡</button>
          </template>
        </template>
        <template v-else-if="mine">
          <NuxtLink v-if="!isHome" :to="`/territory/${cell.cell}`" class="btn primary">進去看看</NuxtLink>
          <NuxtLink v-else to="/camp" class="btn primary">看營地</NuxtLink>
          <button v-if="!isHome" class="btn" :disabled="!canAct" @click="dispatch = 'move'">派人駐守</button>
          <button v-if="!isHome && cell.nest === 'none'" class="btn" :disabled="busy" @click="nest">蓋繁殖巢</button>
          <button v-if="!cell.town && (myCell?.region ?? 0) >= s.me.rules.townMinCells" class="btn" :disabled="busy" @click="town">蓋城鎮</button>
          <button v-if="!isHome" class="btn" :disabled="busy" @click="recall">撤回</button>
          <button v-if="canMoveHere && asking !== 'move'" class="btn" :disabled="busy || !!moveWait" @click="asking = 'move'">搬營地到這裡</button>
        </template>
        <template v-else>
          <button v-if="cell.owner && isFriend" class="btn primary" :disabled="!canAct || (cell.guests ?? 0) >= GUESTS_MAX" @click="dispatch = 'guard'">派兵幫守</button>
          <button v-if="myGuests" class="btn" :disabled="busy" @click="unguard">叫幫守的 {{ myGuests }} 隻回來</button>
          <button v-if="(cell.boss || cell.lair || cell.owner) && !myGuests" class="btn" :class="{ primary: !(cell.owner && isFriend) }" :disabled="!canAct" @click="dispatch = 'attack'">{{ cell.boss ? "攻擊魔王" : "攻擊" }}</button>
          <button v-else class="btn primary" :disabled="!canAct" @click="dispatch = 'settle'">派人佔領</button>
          <NuxtLink v-if="cell.owner && isFriend" :to="`/friends/${cell.owner.id}`" class="btn">傳訊息</NuxtLink>
          <button v-else-if="cell.owner" class="btn" :disabled="busy || askedFriend" @click="addFriend">{{ askedFriend ? "等對方答應好友" : "加好友" }}</button>
          <button v-if="canMoveHere && asking !== 'move'" class="btn" :disabled="busy || !!moveWait" @click="asking = 'move'">搬營地到這裡</button>
        </template>
      </div>
      <div v-if="asking === 'move'" class="ask">
        <p>把營地搬到「<b>{{ placeName }}</b>」？{{ HOME_MOVE_DAYS }} 天只能搬一次。{{ cell.lair ? `這裡的${cell.lair.name}會被趕走。` : "" }}原本那一格就不是你的了（住在那的會跟著回營地）。</p>
        <button class="btn primary" :disabled="busy" @click="moveHere">確定搬過來</button>
        <button class="btn" @click="asking = null">再想想</button>
      </div>
      <p v-if="canMoveHere && moveWait" class="muted small">營地 {{ HOME_MOVE_DAYS }} 天只能搬一次，{{ moveWait }}可以再搬。</p>
      <p v-if="mine && !isHome && cell.nest === 'none'" class="muted small">佔領只是派人去住，那一格不會自己長人。蓋繁殖巢（{{ costList(s.me.rules.nestCost) }}，{{ s.me.rules.nestHours }} 小時蓋好）之後，這一格每 {{ s.me.rules.nestBirthMinutes }} 分鐘生一隻，不用一直從營地派人補。</p>
      <p v-if="message" class="status">{{ message }}</p>
    </aside>

    <DispatchDialog v-if="dispatch && cell && s.me" :target="cell" :kind="dispatch" :me="s.me" :race="race" @close="dispatch = null" @sent="sent" />
  </main>
</template>

<style scoped>
section { margin-top: 14px; }
h2 { font-size: 16px; margin: 0 0 8px; }
p { margin: 6px 0; line-height: 1.55; }
.muted { color: var(--muted); font-size: 14px; }
.small { font-size: 12px; }
.intro { margin: 0 0 12px; }
.places { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 10px; }
.places .chip small { margin-left: 5px; opacity: 0.7; font-size: 11px; }
.places .chip.here { background: #f3d36b; color: #1f1f1f; font-weight: 700; }
.places-note { flex-basis: 100%; margin: 2px 2px 0; font-size: 12px; color: #d8e4d0; }
.chip { border: 0; border-radius: 999px; padding: 7px 12px; background: rgba(255, 255, 255, 0.16); color: #fff; font-weight: 600; font-size: 13px; cursor: pointer; }
.legend { color: #dfe9d8; font-size: 11px; line-height: 1.6; margin: 6px 2px 0; }
.line small { color: var(--muted); }
.report { display: flex; align-items: baseline; gap: 8px; padding: 8px 0; border-top: 1px solid var(--line); text-decoration: none; }
.report:first-of-type { border-top: 0; }
.grow { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.report small { color: var(--muted); white-space: nowrap; }
.won { color: var(--green); font-weight: 700; white-space: nowrap; }
.lost { color: var(--red); font-weight: 700; white-space: nowrap; }
.boss-banner { display: grid; gap: 2px; width: 100%; text-align: left; border: 3px solid #1f1f1f; border-radius: 12px; padding: 10px 12px; margin-bottom: 10px; background: #ffd9d4; box-shadow: 3px 3px 0 #1f1f1f; cursor: pointer; }
.boss-banner b { color: #b0261a; }
.boss-banner span { font-size: 13px; color: #6b2a22; }
.page.with-sheet { padding-bottom: 300px; }

/* the cell's card, up from the bottom */
.sheet {
  position: fixed; left: 0; right: 0; bottom: 0; z-index: 40; margin: 0 auto; max-width: 560px;
  background: var(--card); border-radius: 18px 18px 0 0; border: 3px solid #1f1f1f; border-bottom: 0;
  padding: 14px 16px calc(env(safe-area-inset-bottom) + 14px); box-shadow: 0 -4px 0 rgba(0, 0, 0, 0.25); animation: rise 0.18s ease-out;
}
@keyframes rise { from { transform: translateY(40px); opacity: 0; } }
.sheet .x { position: absolute; top: 10px; right: 10px; border: 0; background: #eee; border-radius: 50%; width: 30px; height: 30px; cursor: pointer; }
.head { display: flex; align-items: center; gap: 12px; padding-right: 34px; }
.head h2 { margin: 0; font-size: 18px; }
.head h2 small { font-size: 13px; color: var(--muted); font-weight: 600; }
.head p { margin: 2px 0 0; font-size: 13px; }
.badge { flex: none; width: 56px; height: 56px; border-radius: 12px; background: #f1eee2; display: grid; place-items: center; }
.face { width: 44px; height: 44px; }
.ground { width: 36px; height: 36px; border-radius: 8px; border: 2px solid rgba(0, 0, 0, 0.2); }
.ground.forest { background: #3f7d3a; }
.ground.park { background: #79b957; }
.ground.water { background: #4a8ec2; }
.ground.urban { background: #a89b88; }
.ground.open { background: #cdbf8a; }
.ground.road { background: #f1e6c6; }
.foes { display: flex; flex-wrap: wrap; align-items: flex-end; gap: 10px; margin: 10px 0 4px; }
.foe { display: grid; justify-items: center; gap: 2px; }
.foe small { font-size: 11px; color: var(--muted); }
.power { margin-left: auto; display: grid; justify-items: end; }
.power small { font-size: 11px; color: var(--muted); }
.power b { font-size: 20px; }
.hpbar { height: 12px; background: #e3ddd0; border-radius: 6px; overflow: hidden; margin: 10px 0 4px; }
.hpbar i { display: block; height: 100%; background: #e0402f; }
.actions { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 12px; }
.actions .btn { flex: 1 1 auto; min-height: 44px; }
.actions .wide { flex-basis: 100%; }
.wounds { margin: 6px 0 0; font-size: 13px; font-weight: 700; color: #b3412c; }
.ask { background: #f6efd4; border: 2px solid #1f1f1f; border-radius: 12px; padding: 10px 12px; margin-top: 8px; display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
.ask p { flex-basis: 100%; margin: 0; font-size: 14px; line-height: 1.5; }
.row { display: flex; align-items: center; gap: 8px; width: 100%; font-weight: 600; }
.row input { flex: 1; min-width: 0; }
.landmark { margin: 4px 0 0; font-size: 13px; font-weight: 700; color: #7a5a00; }
.landmark small { display: block; font-weight: 500; color: var(--muted); }
.hungry { color: #ffb3a6; font-weight: 700; }
.map-tools { display: flex; gap: 6px; margin: 0 0 8px; }
.landmarks { margin-bottom: 10px; padding: 12px; max-height: 50vh; overflow-y: auto; }
.landmarks .kinds { display: flex; gap: 6px; overflow-x: auto; padding-bottom: 6px; }
.landmarks .kinds button { flex: none; border: 0; border-radius: 999px; padding: 5px 10px; background: #f0efe8; font-weight: 700; font-size: 12px; cursor: pointer; }
.landmarks .kinds button.on { background: var(--green); color: #fff; }
.landmark-row { display: flex; align-items: center; gap: 10px; width: 100%; padding: 8px 2px; border: 0; border-top: 1px solid var(--line); background: none; font: inherit; color: inherit; text-align: left; cursor: pointer; }
.landmark-row .icon { font-size: 22px; }
.landmark-row .grow { flex: 1; min-width: 0; display: grid; }
.landmark-row .grow small { color: var(--muted); font-size: 11px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.landmark-row .side { display: grid; justify-items: end; font-size: 11px; white-space: nowrap; }
.landmark-row .free { color: var(--green); font-weight: 700; }
.landmark-row .mine { color: #8a6a00; font-weight: 700; }
.landmark-row .taken { color: #b3412c; }
.boss-tag { margin: 4px 0 0; font-size: 12px; font-weight: 700; color: #8a5a00; }
</style>
