<script setup lang="ts">
import { noteTime } from "~/utils/time";

const props = defineProps<{ id: string }>();
const notes = useNotes();
const n = computed(() => notes.note(props.id));
const mood = computed(() => (n.value ? notes.mood(n.value) : "idle"));
const memo = computed(() => n.value?.kind === "memo");
const lines = computed(() => (n.value ? noteLines(n.value.text).slice(0, 6) : []));
const copied = ref<number | null>(null);
async function copy(k: number, text: string) {
  if (await copyText(text)) {
    copied.value = k;
    setTimeout(() => (copied.value = null), 1200);
  }
}
</script>

<template>
  <article v-if="n" class="card" :class="[n.color, { done: n.done }]" @click="navigateTo(`/note/${id}`)">
    <div class="tape" />
    <!-- a memo: its lines, links to tap and a copy button each -->
    <ul v-if="memo && lines.length" class="lines">
      <li v-for="(l, k) in lines" :key="k">
        <a v-if="l.url" :href="l.url" target="_blank" rel="noopener" @click.stop>{{ l.text }}</a>
        <span v-else>{{ l.text }}</span>
        <button class="copy" @click.stop="copy(k, l.url ?? l.text)">{{ copied === k ? "✓" : "複製" }}</button>
      </li>
    </ul>
    <p v-else class="text">{{ n.text || "（空白的便利貼）" }}</p>
    <div class="bottom">
      <GoblinSprite :breed="n.breed" :mood="mood" :scale="3" />
      <div class="times">
        <button v-if="mood === 'ringing'" class="ack btn primary" @click.stop="notes.acknowledge(id)">知道了</button>
        <span v-if="n.done" class="done-label">完成了！</span>
        <template v-else>
          <span v-if="n.dueAt" :class="{ late: mood === 'late' }">截止 {{ noteTime(n.dueAt) }}</span>
          <span v-if="n.remindAt && mood !== 'ringing'">提醒 {{ noteTime(n.remindAt) }}</span>
        </template>
      </div>
    </div>
  </article>
</template>

<style scoped>
.card {
  position: relative; border-radius: 4px; padding: 18px 14px 10px; margin-bottom: 14px; cursor: pointer;
  box-shadow: 3px 3px 0 rgba(0, 0, 0, 0.28); border: 2px solid rgba(0, 0, 0, 0.14);
}
.card.yellow { background: var(--paper-yellow); }
.card.pink { background: var(--paper-pink); }
.card.blue { background: var(--paper-blue); }
.card.green { background: var(--paper-green); }
.card.purple { background: var(--paper-purple); }
.tape { position: absolute; top: -7px; left: 50%; width: 56px; height: 14px; transform: translateX(-50%); background: rgba(255, 255, 255, 0.6); }
.text { margin: 0 0 10px; white-space: pre-wrap; word-break: break-word; font-weight: 500; display: -webkit-box; -webkit-line-clamp: 5; -webkit-box-orient: vertical; overflow: hidden; }
.lines { list-style: none; margin: 0 0 10px; padding: 0; display: grid; gap: 4px; }
.lines li { display: flex; align-items: center; gap: 8px; min-width: 0; }
.lines li > a, .lines li > span { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-weight: 500; }
.lines a { color: #1f4f9a; }
.copy { flex: none; border: 1px solid rgba(0, 0, 0, 0.2); background: rgba(255, 255, 255, 0.7); border-radius: 7px; padding: 2px 8px; font-size: 12px; font-weight: 700; cursor: pointer; }
.done .text { text-decoration: line-through; opacity: 0.55; }
.bottom { display: flex; align-items: flex-end; justify-content: space-between; gap: 8px; }
.times { display: grid; gap: 2px; justify-items: end; font-size: 12px; font-weight: 600; color: #444; }
.late { color: var(--red); }
.done-label { color: var(--green); }
.ack { min-height: 32px; padding: 4px 14px; }
</style>
