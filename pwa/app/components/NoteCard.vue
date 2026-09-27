<script setup lang="ts">
import { noteTime } from "~/utils/time";

const props = defineProps<{ id: string }>();
const notes = useNotes();
const n = computed(() => notes.note(props.id));
const mood = computed(() => (n.value ? notes.mood(n.value) : "idle"));
</script>

<template>
  <article v-if="n" class="card" :class="[n.color, { done: n.done }]" @click="navigateTo(`/note/${id}`)">
    <div class="tape" />
    <p class="text">{{ n.text || "（空白的便利貼）" }}</p>
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
.done .text { text-decoration: line-through; opacity: 0.55; }
.bottom { display: flex; align-items: flex-end; justify-content: space-between; gap: 8px; }
.times { display: grid; gap: 2px; justify-items: end; font-size: 12px; font-weight: 600; color: #444; }
.late { color: var(--red); }
.done-label { color: var(--green); }
.ack { min-height: 32px; padding: 4px 14px; }
</style>
