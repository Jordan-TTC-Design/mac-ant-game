<script setup lang="ts">
import { NOTE_COLORS, type NoteFields } from "@goblincamp/shared";
import { atHour, fridayEvening, noteTime, toLocalInput } from "~/utils/time";

const ok = await useSignedIn();
const route = useRoute();
const id = String(route.params.id);
/** `/note/new`: a draft, kept only once 新增 is pressed (leaving without it throws it away). */
const isNew = id === "new";
const notes = useNotes();
const { noun, ensure } = useRace();
void ensure();
const draft = reactive<NoteFields>(notes.draft(route.query.kind === "memo" ? "memo" : "todo"));
const n = computed(() => (isNew ? draft : notes.note(id)));
const text = ref(n.value?.text ?? "");
const textarea = ref<HTMLTextAreaElement>();
let typing: ReturnType<typeof setTimeout> | undefined;
let added = false;

onMounted(() => {
  if (isNew) textarea.value?.focus();
});
// an existing note's words are saved as you type (and sent a second after you stop); a draft's wait for 新增
watch(text, (value) => {
  if (isNew) {
    draft.text = value;
    return;
  }
  clearTimeout(typing);
  typing = setTimeout(() => {
    typing = undefined;
    notes.change(id, { text: value });
  }, 400);
});
onBeforeUnmount(() => {
  clearTimeout(typing);
  if (!isNew && n.value && n.value.text !== text.value) notes.change(id, { text: text.value });
});
// the words changed on another device while this page was open (and nothing typed here is waiting)
watch(
  () => (isNew ? undefined : n.value?.text),
  (value) => {
    if (value !== undefined && !typing && value !== text.value) text.value = value;
  },
);

const hasContent = computed(() => !!(text.value.trim() || draft.remindAt || draft.dueAt));
onBeforeRouteLeave(() => {
  if (isNew && !added && hasContent.value && !confirm("這張便利貼還沒新增，要丟掉嗎？")) return false;
});

/** 新增: keeps the draft (and sends it to the other devices). */
function add() {
  if (!hasContent.value) {
    textarea.value?.focus();
    return;
  }
  notes.create({ ...draft, text: text.value });
  added = true;
  navigateTo("/notes");
}

function apply(fields: Partial<NoteFields>) {
  if (isNew) Object.assign(draft, fields);
  else notes.change(id, fields);
}

const memo = computed(() => n.value?.kind === "memo");
/** Switching kind: a memo has no times (they are cleared) and lives off the desktop; a todo goes on it. */
function setKind(kind: "todo" | "memo") {
  apply(kind === "memo" ? { kind, desk: false, remindAt: null, dueAt: null, remindFired: false } : { kind, desk: true });
}
const lines = computed(() => noteLines(text.value));
const copied = ref<number | null>(null);
async function copyLine(k: number, value: string) {
  if (await copyText(value)) {
    copied.value = k;
    setTimeout(() => (copied.value = null), 1200);
  }
}

const paperNames: Record<string, string> = { yellow: "黃色", pink: "粉紅", blue: "藍色", green: "綠色", purple: "紫色" };
const mood = computed(() => (!isNew && n.value && "id" in n.value ? notes.mood(n.value as Parameters<typeof notes.mood>[0]) : "idle"));

function setRemind(date: Date | null) {
  apply({ remindAt: date ? date.toISOString() : null, remindFired: false });
}
function setDue(date: Date | null) {
  apply({ dueAt: date ? date.toISOString() : null });
}
function fromInput(event: Event): Date | null {
  const value = (event.target as HTMLInputElement).value;
  return value ? new Date(value) : null;
}
function del() {
  if (text.value.trim() && !confirm("刪除這張便利貼？（每台裝置上都會刪掉）")) return;
  notes.remove(id);
  navigateTo("/notes");
}
</script>

<template>
  <main v-if="ok" class="page">
    <header class="topbar">
      <NuxtLink to="/notes" class="icon-btn">{{ isNew ? "取消" : "← 便利貼" }}</NuxtLink>
      <h1 class="title">{{ isNew ? "新的便利貼" : "" }}</h1>
      <button v-if="!isNew" class="icon-btn" @click="del">刪除</button>
    </header>

    <div v-if="!n" class="panel">這張便利貼不在了（可能在別台刪掉了）。</div>
    <div v-else class="sheet" :class="n.color">
      <div class="who">
        <GoblinSprite :breed="n.breed" :mood="mood" :scale="4" />
        <div>
          <div class="name">{{ n.goblinName || noun }}</div>
          <div class="hint">{{ isNew ? `新增後會住在這張便利貼上` : "住在這張便利貼上" }}</div>
        </div>
      </div>
      <div v-if="mood === 'ringing'" class="ringing">
        <span>提醒時間到了！</span>
        <button class="btn primary" @click="notes.acknowledge(id)">知道了</button>
        <button class="btn" @click="setRemind(new Date(Date.now() + 10 * 60_000))">10 分鐘後</button>
      </div>
      <div class="kinds">
        <button :class="{ on: !memo }" @click="setKind('todo')">待辦<small>可以設提醒</small></button>
        <button :class="{ on: memo }" @click="setKind('memo')">備忘<small>常用的網址、指令…</small></button>
      </div>
      <textarea ref="textarea" v-model="text" class="words" rows="6" :placeholder="memo ? '一行一樣：網址、指令、帳號名稱…（密碼不要寫在這裡）' : '寫點什麼…'" />

      <!-- a memo: each line to copy, links to open -->
      <ul v-if="memo && lines.length" class="lines">
        <li v-for="(l, k) in lines" :key="k">
          <a v-if="l.url" :href="l.url" target="_blank" rel="noopener">{{ l.text }}</a>
          <span v-else>{{ l.text }}</span>
          <button class="copy" @click="copyLine(k, l.url ?? l.text)">{{ copied === k ? "✓ 複製了" : "複製" }}</button>
        </li>
      </ul>

      <label v-if="!isNew && !memo" class="check"><input type="checkbox" :checked="n.done" @change="apply({ done: !n.done })" /> 完成了</label>

      <section v-if="!memo">
        <h2>提醒時間 <small v-if="n.remindAt">{{ noteTime(n.remindAt) }}</small></h2>
        <div class="chips">
          <button class="btn" @click="setRemind(new Date(Date.now() + 30 * 60_000))">30 分鐘後</button>
          <button class="btn" @click="setRemind(new Date(Date.now() + 60 * 60_000))">1 小時後</button>
          <button class="btn" @click="setRemind(atHour(17))">今天 17:00</button>
          <button class="btn" @click="setRemind(atHour(9, 1))">明天 9:00</button>
          <button v-if="n.remindAt" class="btn" @click="setRemind(null)">取消</button>
        </div>
        <input type="datetime-local" class="when" :value="toLocalInput(n.remindAt)" @change="setRemind(fromInput($event))" />
      </section>

      <section v-if="!memo">
        <h2>目標時間 <small v-if="n.dueAt">{{ noteTime(n.dueAt) }}</small></h2>
        <div class="chips">
          <button class="btn" @click="setDue(atHour(18))">今天下班前</button>
          <button class="btn" @click="setDue(atHour(18, 1))">明天下班前</button>
          <button class="btn" @click="setDue(fridayEvening())">這週五</button>
          <button v-if="n.dueAt" class="btn" @click="setDue(null)">取消</button>
        </div>
        <input type="datetime-local" class="when" :value="toLocalInput(n.dueAt)" @change="setDue(fromInput($event))" />
      </section>

      <section>
        <h2>紙的顏色</h2>
        <div class="chips">
          <button v-for="c in NOTE_COLORS" :key="c" class="swatch" :class="[c, { on: n.color === c }]" :aria-label="paperNames[c]" @click="apply({ color: c })" />
        </div>
      </section>
    </div>

    <div v-if="n" class="actions">
      <button v-if="isNew" class="btn primary big" :disabled="!hasContent" @click="add">新增便利貼</button>
      <button v-else class="btn primary big" @click="navigateTo('/notes')">完成</button>
    </div>
  </main>
</template>

<style scoped>
.title { font-size: 17px; text-align: center; }
.sheet { border-radius: 4px; padding: 18px 16px; border: 2px solid rgba(0, 0, 0, 0.14); box-shadow: 4px 4px 0 rgba(0, 0, 0, 0.28); min-width: 0; }
.sheet.yellow, .swatch.yellow { background: var(--paper-yellow); }
.sheet.pink, .swatch.pink { background: var(--paper-pink); }
.sheet.blue, .swatch.blue { background: var(--paper-blue); }
.sheet.green, .swatch.green { background: var(--paper-green); }
.sheet.purple, .swatch.purple { background: var(--paper-purple); }
.who { display: flex; align-items: flex-end; gap: 10px; margin-bottom: 12px; }
.name { font-weight: 700; }
.hint { font-size: 12px; color: #555; }
.ringing { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; background: rgba(255, 255, 255, 0.7); border-radius: 10px; padding: 10px; margin-bottom: 12px; font-weight: 700; color: var(--amber); }
.kinds { display: flex; gap: 8px; margin-bottom: 10px; }
.kinds button { flex: 1; display: grid; gap: 1px; border: 2px solid rgba(0, 0, 0, 0.15); border-radius: 10px; padding: 7px 8px; background: rgba(255, 255, 255, 0.5); font-weight: 700; cursor: pointer; }
.kinds button small { font-weight: 500; font-size: 11px; color: #555; }
.kinds button.on { border-color: #1f1f1f; background: rgba(255, 255, 255, 0.9); }
.lines { list-style: none; margin: 10px 0 0; padding: 0; display: grid; gap: 6px; }
.lines li { display: flex; align-items: center; gap: 8px; min-width: 0; background: rgba(255, 255, 255, 0.55); border-radius: 8px; padding: 6px 8px; }
.lines li > a, .lines li > span { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.lines a { color: #1f4f9a; font-weight: 600; }
.copy { flex: none; border: 1px solid rgba(0, 0, 0, 0.2); background: #fff; border-radius: 7px; padding: 4px 10px; font-size: 13px; font-weight: 700; cursor: pointer; }
.words { display: block; width: 100%; max-width: 100%; border: 0; background: rgba(255, 255, 255, 0.55); border-radius: 8px; padding: 12px; font-size: 17px; line-height: 1.5; resize: vertical; -webkit-appearance: none; appearance: none; }
.check { display: flex; align-items: center; gap: 8px; margin: 12px 0 4px; font-weight: 600; }
.check input { width: 20px; height: 20px; }
section { margin-top: 16px; }
h2 { font-size: 14px; margin: 0 0 8px; }
h2 small { font-weight: 600; color: #444; margin-left: 6px; }
.chips { display: flex; flex-wrap: wrap; gap: 8px; }
.chips .btn { min-height: 36px; padding: 6px 12px; background: rgba(255, 255, 255, 0.75); white-space: nowrap; }
/* iPhone Safari draws date inputs at their own width (wider than the sheet) unless told not to */
.when {
  display: block; margin-top: 8px; width: 100%; max-width: 100%; min-width: 0; min-height: 44px; box-sizing: border-box;
  -webkit-appearance: none; appearance: none; border: 1px solid var(--line); border-radius: 8px; padding: 8px 10px;
  background: rgba(255, 255, 255, 0.75); font-size: 16px; line-height: 1.4; text-align: left; color: var(--ink);
}
.when::-webkit-date-and-time-value { text-align: left; }
.swatch { width: 40px; height: 40px; border-radius: 8px; border: 2px solid rgba(0, 0, 0, 0.25); cursor: pointer; }
.swatch.on { border: 3px solid #1f1f1f; }
.actions {
  position: fixed; left: 0; right: 0; bottom: calc(0px - var(--vp-gap, 0px)); z-index: 10; padding: 12px 16px calc(env(safe-area-inset-bottom) + 12px);
  background: linear-gradient(rgba(34, 55, 31, 0), var(--bg-deep) 40%); display: flex; justify-content: center;
}
.big { width: 100%; max-width: 528px; min-height: 52px; font-size: 17px; border: 3px solid #1f1f1f; box-shadow: 3px 3px 0 #1f1f1f; }
.big:disabled { background: #9aa596; }
</style>
