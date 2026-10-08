<script setup lang="ts">
import {
  DEFAULT_BADGE,
  GUILD_NAME_MAX,
  GUILD_REJOIN_HOURS,
  GUILD_BUBBLE_MS,
  GUILD_MOVE_STALE_MS,
  GUILD_SAY_MAX,
  guildDecorKind,
  hallLayout,
  hallPose,
  newDecorUid,
  presenceNow,
  snapDecor,
  WALL_ROWS,
  type GuildDecorLogEntry,
  type GuildMove,
  type GuildDecorPlaced,
  type HallFloor,
  type GuildMemberView,
  type GuildResponse,
  type GuildRole,
} from "@goblincamp/shared";
import { noteTime } from "~/utils/time";
import { ApiError, api } from "~/utils/api";

// 公會 (GUILD.md): founding one or saying yes to an invitation; then the members and who is at their computer, inviting
// (the leader and officers), the leader's badge and roles, and leaving; and the hall, which every member may decorate.
const ok = await useSignedIn();
const { user } = useAccount();
const live = useLive();
const g = computed(() => live.state.guild);
const guild = computed(() => g.value?.guild ?? null);
const me = computed(() => guild.value?.members.find((m) => m.id === user.value?.id) ?? null);
const role = computed<GuildRole | null>(() => me.value?.role ?? null);

const busy = ref(false);
const message = ref("");
const name = ref("");
const badge = ref(DEFAULT_BADGE);
const drawing = ref(false);
const code = ref("");
const now = ref(Date.now());
let clock: ReturnType<typeof setInterval> | undefined;
onMounted(() => {
  void live.loadGuild();
  clock = setInterval(() => (now.value = Date.now()), 30_000);
});
onUnmounted(() => clearInterval(clock));

async function act(work: () => Promise<unknown>, done = "") {
  busy.value = true;
  message.value = "";
  try {
    await work();
    message.value = done;
    await live.loadGuild();
  } catch (e) {
    message.value = e instanceof ApiError ? e.message : String(e);
  } finally {
    busy.value = false;
  }
}
const found = () => act(() => api("POST", "guild", { name: name.value, badge: badge.value }), "公會建立了！");
const join = (id: string) => act(() => api("POST", `guild/join/${id}`), "加入了！");
const decline = (id: string) => act(() => api("DELETE", `guild/join/${id}`));
const invite = () =>
  act(async () => {
    await api("POST", "guild/invites", { code: code.value.trim() });
    code.value = "";
  }, "邀請送出了，等對方答應。");
const uninvite = (id: string) => act(() => api("DELETE", `guild/invites/${id}`));
function openBadge() {
  badge.value = guild.value?.badge ?? DEFAULT_BADGE;
  drawing.value = true;
}
const saveBadge = () =>
  act(async () => {
    await api("PATCH", "guild", { badge: badge.value });
    drawing.value = false;
  }, "徽章換好了。");
function leave() {
  const last = guild.value?.members.length === 1;
  const q = last ? "你是最後一個人，離開後公會就解散了。確定嗎？" : `離開後要等 ${GUILD_REJOIN_HOURS} 小時才能加入別的公會。確定嗎？`;
  if (confirm(q)) void act(() => api("POST", "guild/leave"));
}
function kick(m: GuildMemberView) {
  if (confirm(`請 ${m.name} 離開公會？`)) void act(() => api("DELETE", `guild/members/${m.id}`));
}
function setRole(m: GuildMemberView, to: GuildRole) {
  if (to === "leader" && !confirm(`把會長交給 ${m.name}？你會變成幹部。`)) return;
  void act(() => api("PUT", `guild/members/${m.id}/role`, { role: to }));
}

const PRESENCE = { focus: { dot: "#e2553f", text: "專注中" }, online: { dot: "#4caf50", text: "在線" }, away: { dot: "#e8c547", text: "離開" }, offline: { dot: "#9a9a9a", text: "離線" } };
const ROLE: Record<GuildRole, string> = { leader: "會長", officer: "幹部", member: "成員" };
const presence = (m: GuildMemberView) => (m.presence === "offline" ? "offline" : presenceNow(m.presence, m.seenAt ? new Date(m.seenAt) : null, new Date(now.value)));
const online = computed(() => guild.value?.members.filter((m) => presence(m) !== "offline").length ?? 0);
// decorating: a copy of the list is changed here and saved in one go (GUILD.md §4.2)
const editing = ref(false);
const draft = ref<GuildDecorPlaced[]>([]);
const draftVersion = ref(0);
const selected = ref<string | null>(null);
const mode = ref<"decor" | "floor" | "wall">("decor");
const brush = ref("oak");
const draftFloor = ref<HallFloor>({ base: "oak", tiles: {} });
const shownDecor = computed(() => (editing.value ? draft.value : (guild.value?.decor ?? [])));
const shownFloor = computed(() => (editing.value ? draftFloor.value : (guild.value?.floor ?? { base: "oak", tiles: {} })));
function startDecor() {
  draft.value = structuredClone(toRaw(guild.value?.decor ?? []));
  draftFloor.value = structuredClone(toRaw(guild.value?.floor ?? { base: "oak", tiles: {} }));
  mode.value = "decor";
  draftVersion.value = guild.value?.decorVersion ?? 0;
  selected.value = null;
  editing.value = true;
  message.value = "";
}
/** Keeps a piece inside the hall, on the wall or on the floor as it belongs, on the art's pixels. */
function place(kind: string, x: number, y: number) {
  const k = guildDecorKind(kind)!;
  const { width, height } = guild.value!.rules;
  const half = k.w / 32;
  const cx = Math.min(width - half, Math.max(half, x));
  const cy = k.wall ? Math.min(WALL_ROWS, Math.max(1 + k.h / 32, y)) : Math.min(height, Math.max(WALL_ROWS + 1 / 16, y));
  return { x: snapDecor(cx), y: snapDecor(cy) };
}
function addDecor(kind: string) {
  const k = guildDecorKind(kind)!;
  const { width } = guild.value!.rules;
  const at = place(kind, width / 2, k.wall ? WALL_ROWS : WALL_ROWS + 3);
  const d: GuildDecorPlaced = { uid: newDecorUid(), kind, ...at };
  draft.value.push(d);
  selected.value = d.uid;
}
function moveDecor(uid: string, x: number, y: number) {
  const d = draft.value.find((p) => p.uid === uid);
  if (!d || (d.locked && role.value === "member")) return;
  Object.assign(d, place(d.kind, x, y));
}
function flipDecor() {
  const d = draft.value.find((p) => p.uid === selected.value);
  if (d) d.flip = !d.flip;
}
function removeDecor() {
  draft.value = draft.value.filter((p) => p.uid !== selected.value);
  selected.value = null;
}
function lockDecor() {
  const d = draft.value.find((p) => p.uid === selected.value);
  if (d) d.locked = !d.locked;
}
/** Lays the brush's floor on one tile (the base style needs no tile of its own). */
function paintTile(x: number, y: number) {
  const key = `${x},${y}`;
  const tiles = draftFloor.value.tiles;
  if (brush.value === draftFloor.value.base) delete tiles[key];
  else tiles[key] = brush.value;
}
function fillFloor() {
  draftFloor.value = { base: brush.value, tiles: {} };
}
const setWall = (id: string) => act(async () => (live.state.guild = await api<GuildResponse>("PUT", "guild/wall", { wall: id })), "牆壁換好了。");
const saveDecor = () =>
  act(async () => {
    try {
      live.state.guild = await api<GuildResponse>("PUT", "guild/decor", { version: draftVersion.value, items: draft.value, floor: draftFloor.value });
      editing.value = false;
    } catch (e) {
      if (e instanceof ApiError && e.status === 409) editing.value = false; // (someone else saved: start again from theirs)
      throw e;
    }
  }, "裝飾存好了。");
const log = ref<GuildDecorLogEntry[] | null>(null);
async function openLog() {
  log.value = log.value ? null : ((await api<{ entries: GuildDecorLogEntry[] }>("GET", "guild/decor/log")).entries);
}
function restore(entry: GuildDecorLogEntry) {
  if (!confirm(`把裝飾還原成 ${noteTime(entry.at)} ${entry.by} 改動之前的樣子？`)) return;
  void act(async () => {
    live.state.guild = await api<GuildResponse>("POST", "guild/decor/restore", { logId: entry.id });
    log.value = null;
  }, "還原了。");
}
const logLine = (e: GuildDecorLogEntry) =>
  e.restored
    ? "還原了裝飾"
    : [e.added && `放了 ${e.added} 件`, e.moved && `動了 ${e.moved} 件`, e.removed && `收了 ${e.removed} 件`, e.floor && `鋪了 ${e.floor} 格地板`].filter(Boolean).join("、");

// walking one's own avatar and talking (GUILD.md §3.1)
const layout = computed(() => (guild.value ? hallLayout(guild.value.level) : null));
const control = useHallControl(layout, () => {
  // (where this one's avatar is wandering right now, so taking it over does not make it jump)
  const L = layout.value;
  if (!L || !guild.value || !user.value) return null;
  const order = [...inHall.value].sort((a, b) => a.joinedAt.localeCompare(b.joinedAt)).map((m, seat) => ({ id: m.id, presence: m.presence, seat }));
  const mine = order.find((m) => m.id === user.value!.id);
  const present = order.filter((m) => m.presence !== "offline");
  const at = mine && hallPose(L, mine, present, Date.now());
  return at ? { x: at.x, y: at.y } : { x: L.width / 2, y: L.aisles.at(-1)! };
});
const tick = ref(Date.now());
let ticker: ReturnType<typeof setInterval> | undefined;
onMounted(() => {
  ticker = setInterval(() => (tick.value = Date.now()), 1000);
  void live.loadGuildChat();
});
onUnmounted(() => clearInterval(ticker));
const hand = computed(() => {
  const out: Record<string, GuildMove & { since?: number }> = {};
  for (const [id, mv] of Object.entries(live.state.guildMoves)) if (tick.value - mv.heard < GUILD_MOVE_STALE_MS) out[id] = { ...mv, since: mv.heard };
  if (control.pose.value && user.value) out[user.value.id] = control.pose.value;
  return out;
});
const bubbles = computed(() => {
  const out: Record<string, { text: string; until: number }> = {};
  for (const line of live.state.guildChat) {
    const until = Date.parse(line.at) + GUILD_BUBBLE_MS;
    if (until > tick.value) out[line.userId] = { text: line.text, until };
  }
  return out;
});
const sayBox = ref<HTMLInputElement>();
const saying = ref("");
async function say() {
  const text = saying.value.trim();
  if (!text) return;
  saying.value = "";
  try {
    const line = await api<import("@goblincamp/shared").GuildChatLine>("POST", "guild/say", { text });
    if (!live.state.guildChat.some((l) => l.id === line.id)) live.state.guildChat = [...live.state.guildChat, line].slice(-50);
  } catch (e) {
    message.value = e instanceof ApiError ? e.message : String(e);
  }
}
function talk() {
  sayBox.value?.focus();
}
// Enter to talk, Esc to stop typing (on the Mac)
function keys(e: KeyboardEvent) {
  const inBox = e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement;
  if (e.key === "Enter" && !inBox && guild.value && !editing.value) {
    e.preventDefault();
    talk();
  } else if (e.key === "Escape" && e.target === sayBox.value) sayBox.value?.blur();
}
onMounted(() => window.addEventListener("keydown", keys));
onUnmounted(() => window.removeEventListener("keydown", keys));
const recentChat = computed(() => live.state.guildChat.slice(-6));

/** The members with how they are now (a Mac that went quiet since the last fetch counts as gone). */
const inHall = computed(() => guild.value?.members.map((m) => ({ ...m, presence: presence(m) })) ?? []);
</script>

<template>
  <main v-if="ok" class="page">
    <header class="topbar">
      <div style="flex: 1">
        <h1>公會</h1>
        <div class="sub">大家一起在據點裡，看得到誰在電腦前</div>
      </div>
    </header>

    <p v-if="message" class="note">{{ message }}</p>

    <template v-if="g && !guild">
      <section v-if="g.invites.length" class="panel">
        <h2>公會邀請</h2>
        <div v-for="i in g.invites" :key="i.guildId" class="row">
          <GuildBadge :badge="i.badge" :size="40" />
          <span class="grow"><b>{{ i.name }}</b><br /><small>{{ i.members }} 人・{{ i.by }} 邀請・{{ noteTime(i.at) }}</small></span>
          <button class="btn primary" :disabled="busy || !!g.waitUntil" @click="join(i.guildId)">加入</button>
          <button class="btn" :disabled="busy" @click="decline(i.guildId)">不要</button>
        </div>
      </section>

      <section class="panel">
        <h2>建立公會</h2>
        <p v-if="g.waitUntil" class="muted">剛離開公會，{{ noteTime(g.waitUntil) }}後才能加入或建立新的。</p>
        <form class="stack" @submit.prevent="found">
          <input v-model="name" class="field" :maxlength="GUILD_NAME_MAX" placeholder="公會名字（2～16 個字）" autocomplete="off" />
          <div class="badge-line">
            <GuildBadge :badge="badge" :size="56" />
            <button type="button" class="btn" @click="drawing = !drawing">{{ drawing ? "收起" : "畫徽章" }}</button>
          </div>
          <BadgeEditor v-if="drawing" v-model="badge" />
          <button class="btn primary" :disabled="busy || name.trim().length < 2 || !!g.waitUntil">建立（你會是會長）</button>
        </form>
        <p class="hint">加入公會要靠邀請：請會長或幹部用你的好友代碼邀請你。</p>
      </section>
      <NuxtLink to="/avatar" class="wide-link">🧑‍🎨 先捏一個分身 ›</NuxtLink>
    </template>

    <template v-if="guild">
      <section class="panel head">
        <GuildBadge :badge="guild.badge" :size="64" />
        <div class="grow">
          <b class="gname">{{ guild.name }}</b>
          <small>Lv {{ guild.level }}・{{ guild.members.length }}／{{ guild.rules.members }} 人・{{ online }} 人在線</small>
        </div>
        <button v-if="role === 'leader' && !drawing" class="btn" @click="openBadge">改徽章</button>
      </section>

      <GuildHall
        :level="guild.level"
        :members="inHall"
        :me="user?.id"
        :decor="shownDecor"
        :floor="shownFloor"
        :wall="guild.wall"
        :editing="editing"
        :painting="editing && mode === 'floor'"
        :selected="selected"
        :hand="hand"
        :bubbles="bubbles"
        class="hall"
        @select="selected = $event"
        @move="moveDecor"
        @paint="paintTile"
        @walk-to="control.walkTo"
      />
      <template v-if="!editing">
        <GuildPad class="phone-only" @pad="control.press" @a="control.pressA" @b="control.pressB" @talk="talk" />
        <p class="hint desk-only">點地板走過去・方向鍵／WASD 走路・空白鍵坐下／喝水／揮手・Q 歡呼・Enter 說話</p>
        <section class="panel chat">
          <div v-for="line in recentChat" :key="line.id" class="line">
            <b>{{ line.name }}</b>：{{ line.text }} <small>{{ noteTime(line.at) }}</small>
          </div>
          <p v-if="!recentChat.length" class="muted">還沒有人說話，打個招呼吧。</p>
          <form class="say" @submit.prevent="say">
            <input ref="sayBox" v-model="saying" class="field" :maxlength="GUILD_SAY_MAX" placeholder="說點什麼…（Enter 送出）" enterkeyhint="send" />
            <button class="btn primary" :disabled="!saying.trim()">說</button>
          </form>
        </section>
      </template>
      <GuildDecorPanel
        v-if="editing && role"
        :items="draft"
        :level="guild.level"
        :room="guild.rules.room"
        :races="guild.races"
        :role="role"
        :selected="selected"
        :busy="busy"
        :mode="mode"
        :brush="brush"
        :wall="guild.wall"
        @mode="mode = $event"
        @brush="brush = $event"
        @fill-all="fillFloor"
        @wall="setWall"
        @add="addDecor"
        @flip="flipDecor"
        @remove="removeDecor"
        @lock="lockDecor"
        @save="saveDecor"
        @cancel="editing = false"
      />
      <div v-else class="links">
        <button type="button" class="wide-link" @click="startDecor">🪑 擺裝飾</button>
        <NuxtLink to="/avatar" class="wide-link">🧑‍🎨 我的分身{{ g?.avatarChosen ? "" : "（還沒捏過）" }}</NuxtLink>
      </div>
      <button v-if="!editing" type="button" class="log-link" @click="openLog">{{ log ? "收起擺放紀錄" : "📜 擺放紀錄" }}</button>
      <section v-if="log && !editing" class="panel">
        <h2>擺放紀錄</h2>
        <p v-if="!log.length" class="muted">還沒有人動過裝飾。</p>
        <div v-for="e in log" :key="e.id" class="row">
          <span class="grow"><b>{{ e.by }}</b> {{ logLine(e) }}<br /><small>{{ noteTime(e.at) }}</small></span>
          <button v-if="role === 'leader'" class="btn small" :disabled="busy" @click="restore(e)">還原到這之前</button>
        </div>
      </section>

      <section v-if="drawing" class="panel">
        <BadgeEditor v-model="badge" />
        <div class="tools">
          <button class="btn primary" :disabled="busy" @click="saveBadge">儲存徽章</button>
          <button class="btn" @click="drawing = false">取消</button>
        </div>
      </section>

      <section class="panel">
        <h2>成員</h2>
        <div v-for="m in guild.members" :key="m.id" class="row">
          <span class="face-wrap">
            <img :src="`/sprites/${m.race}/icon.png`" class="pixel face" alt="" />
            <i class="dot" :style="{ background: PRESENCE[presence(m)].dot }" />
          </span>
          <span class="grow">
            <b>{{ m.name }}</b> <small class="role" :class="m.role">{{ ROLE[m.role] }}</small>
            <br />
            <small>
              {{ PRESENCE[presence(m)].text }}<template v-if="presence(m) === 'offline' && m.seenAt">・{{ noteTime(m.seenAt) }}來過</template>
              <template v-if="m.focusToday">・今天專注 {{ m.focusToday }} 輪</template>
            </small>
          </span>
          <span v-if="m.id !== user?.id && role === 'leader'" class="actions">
            <button v-if="m.role === 'member'" class="btn small" :disabled="busy" @click="setRole(m, 'officer')">升幹部</button>
            <button v-if="m.role === 'officer'" class="btn small" :disabled="busy" @click="setRole(m, 'member')">降成員</button>
            <button class="btn small" :disabled="busy" @click="setRole(m, 'leader')">交會長</button>
            <button class="btn small" :disabled="busy" @click="kick(m)">請離開</button>
          </span>
          <span v-else-if="m.id !== user?.id && role === 'officer' && m.role === 'member'" class="actions">
            <button class="btn small" :disabled="busy" @click="kick(m)">請離開</button>
          </span>
        </div>
      </section>

      <section v-if="role !== 'member'" class="panel">
        <h2>邀請</h2>
        <form class="add" @submit.prevent="invite">
          <input v-model="code" class="field" placeholder="對方的好友代碼" autocapitalize="characters" autocomplete="off" />
          <button class="btn primary" :disabled="busy || !code.trim() || guild.members.length >= guild.rules.members">邀請</button>
        </form>
        <p v-if="guild.members.length >= guild.rules.members" class="muted">公會滿了，升級後可以收更多人。</p>
        <div v-for="p in guild.invited" :key="p.id" class="row">
          <img :src="`/sprites/${p.race}/icon.png`" class="pixel face" alt="" />
          <span class="grow"><b>{{ p.name }}</b><br /><small>等對方答應・{{ noteTime(p.at) }}</small></span>
          <button class="btn" :disabled="busy" @click="uninvite(p.id)">收回</button>
        </div>
      </section>

      <button class="btn leave" :disabled="busy" @click="leave">離開公會</button>
    </template>
  </main>
</template>

<style scoped>
.grow { flex: 1; min-width: 0; }
h2 { margin: 0 0 6px; font-size: 17px; }
.note { color: #fff3c4; margin: 6px 2px; font-weight: 600; }
.hint { color: #c9d6c0; font-size: 12px; margin: 8px 2px; }
.muted { color: #666; font-size: 13px; }
.stack { display: grid; gap: 10px; }
.field { border: 2px solid #1f1f1f; border-radius: 10px; padding: 10px 12px; font-size: 16px; background: #fffdf6; min-width: 0; }
.badge-line { display: flex; align-items: center; gap: 12px; }
.add { display: flex; gap: 8px; margin-bottom: 6px; }
.add .field { flex: 1; }
.head { display: flex; align-items: center; gap: 12px; }
.gname { font-size: 20px; display: block; }
.head small { color: #666; }
.row { display: flex; align-items: center; gap: 10px; padding: 8px 0; border-top: 1px solid rgba(0, 0, 0, 0.06); flex-wrap: wrap; }
.row:first-of-type { border-top: 0; }
.row small { color: #666; }
.face-wrap { position: relative; flex: none; }
.face { width: 36px; height: 36px; image-rendering: pixelated; display: block; }
.dot { position: absolute; right: -2px; bottom: -2px; width: 12px; height: 12px; border-radius: 50%; border: 2px solid #fffdf6; }
.role { border-radius: 6px; padding: 0 5px; font-weight: 700; background: #eee; }
.role.leader { background: #e8c547; color: #3a2a00; }
.role.officer { background: #cfe3ff; color: #1f3b6e; }
.actions { display: flex; flex-wrap: wrap; gap: 4px; }
.btn.small { padding: 4px 8px; font-size: 12px; }
.tools { display: flex; gap: 8px; margin-top: 10px; }
.leave { margin-top: 4px; }
.hall { margin: 0 0 12px; }
</style>

<style scoped>
.wide-link { display: block; margin: 0 0 12px; padding: 12px; border-radius: 12px; background: rgba(255, 255, 255, 0.12); color: #fff; text-decoration: none; font-weight: 700; text-align: center; border: 0; font-size: 15px; width: 100%; }
.links { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.chat { display: grid; gap: 4px; }
.chat .line { font-size: 14px; line-height: 1.4; word-break: break-word; }
.chat .line small { color: #999; font-size: 11px; }
.say { display: flex; gap: 6px; margin-top: 4px; }
.say .field { flex: 1; }
.phone-only { display: none; }
@media (hover: none) and (pointer: coarse) {
  .phone-only { display: flex; }
  .desk-only { display: none; }
}
.log-link { display: block; margin: -4px auto 12px; background: none; border: 0; color: #c9d6c0; font-size: 13px; }
</style>
