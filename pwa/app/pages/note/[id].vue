<script setup lang="ts">
import { NOTE_COLORS } from "@goblincamp/shared";
import { atHour, fridayEvening, noteTime, toLocalInput } from "~/utils/time";

const ok = await useSignedIn();
const route = useRoute();
const id = String(route.params.id);
const notes = useNotes();
const n = computed(() => notes.note(id));
const text = ref(n.value?.text ?? "");
const textarea = ref<HTMLTextAreaElement>();
let typing: ReturnType<typeof setTimeout> | undefined;

onMounted(() => {
  if (route.query.new) textarea.value?.focus();
});
// the words are saved as you type (and sent a second after you stop)
watch(text, (value) => {
  clearTimeout(typing);
  typing = setTimeout(() => {
    typing = undefined;
    notes.change(id, { text: value });
  }, 400);
});
onBeforeUnmount(() => {
  clearTimeout(typing);
  if (n.value && n.value.text !== text.value) notes.change(id, { text: text.value });
  // a new note left empty is not worth keeping
  if (route.query.new && n.value && !text.value.trim() && !n.value.remindAt && !n.value.dueAt) notes.remove(id);
});
// the words changed on another device while this page was open (and nothing typed here is waiting)
watch(
  () => n.value?.text,
  (value) => {
    if (value !== undefined && !typing && value !== text.value) text.value = value;
  },
);

const paperNames: Record<string, string> = { yellow: "黃色", pink: "粉紅", blue: "藍色", green: "綠色", purple: "紫色" };
const mood = computed(() => (n.value ? notes.mood(n.value) : "idle"));

function setRemind(date: Date | null) {
  notes.change(id, { remindAt: date ? date.toISOString() : null, remindFired: false });
}
function setDue(date: Date | null) {
  notes.change(id, { dueAt: date ? date.toISOString() : null });
}
function fromInput(event: Event): Date | null {
  const value = (event.target as HTMLInputElement).value;
  return value ? new Date(value) : null;
}
function del() {
  if (text.value.trim() && !confirm("刪除這張便利貼？（每台裝置上都會刪掉）")) return;
  notes.remove(id);
  navigateTo("/");
}
</script>

<template>
  <main v-if="ok" class="page">
    <header class="topbar">
      <NuxtLink to="/" class="icon-btn">← 便利貼</NuxtLink>
      <span style="flex: 1" />
      <button class="icon-btn" @click="del">刪除</button>
    </header>

    <div v-if="!n" class="panel">這張便利貼不在了（可能在別台刪掉了）。</div>
    <div v-else class="sheet" :class="n.color">
      <div class="who">
        <GoblinSprite :breed="n.breed" :mood="mood" :scale="4" />
        <div>
          <div class="name">{{ n.goblinName || "哥布林" }}</div>
          <div class="hint">住在這張便利貼上</div>
        </div>
      </div>
      <div v-if="mood === 'ringing'" class="ringing">
        <span>提醒時間到了！</span>
        <button class="btn primary" @click="notes.acknowledge(id)">知道了</button>
        <button class="btn" @click="setRemind(new Date(Date.now() + 10 * 60_000))">10 分鐘後</button>
      </div>
      <textarea ref="textarea" v-model="text" class="words" rows="6" placeholder="寫點什麼…" />

      <label class="check"><input type="checkbox" :checked="n.done" @change="notes.change(id, { done: !n.done })" /> 完成了</label>

      <section>
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

      <section>
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
          <button v-for="c in NOTE_COLORS" :key="c" class="swatch" :class="[c, { on: n.color === c }]" :aria-label="paperNames[c]" @click="notes.change(id, { color: c })" />
        </div>
      </section>
    </div>
  </main>
</template>

<style scoped>
.sheet { border-radius: 4px; padding: 18px 16px; border: 2px solid rgba(0, 0, 0, 0.14); box-shadow: 4px 4px 0 rgba(0, 0, 0, 0.28); }
.sheet.yellow, .swatch.yellow { background: var(--paper-yellow); }
.sheet.pink, .swatch.pink { background: var(--paper-pink); }
.sheet.blue, .swatch.blue { background: var(--paper-blue); }
.sheet.green, .swatch.green { background: var(--paper-green); }
.sheet.purple, .swatch.purple { background: var(--paper-purple); }
.who { display: flex; align-items: flex-end; gap: 10px; margin-bottom: 12px; }
.name { font-weight: 700; }
.hint { font-size: 12px; color: #555; }
.ringing { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; background: rgba(255, 255, 255, 0.7); border-radius: 10px; padding: 10px; margin-bottom: 12px; font-weight: 700; color: var(--amber); }
.words { width: 100%; border: 0; background: rgba(255, 255, 255, 0.55); border-radius: 8px; padding: 12px; font-size: 17px; line-height: 1.5; resize: vertical; }
.check { display: flex; align-items: center; gap: 8px; margin: 12px 0 4px; font-weight: 600; }
.check input { width: 20px; height: 20px; }
section { margin-top: 16px; }
h2 { font-size: 14px; margin: 0 0 8px; }
h2 small { font-weight: 600; color: #444; margin-left: 6px; }
.chips { display: flex; flex-wrap: wrap; gap: 8px; }
.chips .btn { min-height: 36px; padding: 6px 12px; background: rgba(255, 255, 255, 0.75); }
.when { margin-top: 8px; width: 100%; border: 1px solid var(--line); border-radius: 8px; padding: 8px 10px; background: rgba(255, 255, 255, 0.75); font-size: 16px; }
.swatch { width: 40px; height: 40px; border-radius: 8px; border: 2px solid rgba(0, 0, 0, 0.25); cursor: pointer; }
.swatch.on { border: 3px solid #1f1f1f; }
</style>
