<script setup lang="ts">
import { MESSAGE_MAX } from "@goblincamp/shared";
import { noteTime } from "~/utils/time";
import { ApiError, api } from "~/utils/api";

// A conversation with one friend: newest at the bottom, a line to write in (200 characters at most).
const ok = await useSignedIn();
const route = useRoute();
const id = String(route.params.id);
const live = useLive();
const chat = computed(() => (live.state.chat?.friend.id === id ? live.state.chat : null));
const text = ref("");
const sending = ref(false);
const problem = ref("");
const list = ref<HTMLElement>();

// the line to write in sits on the tab bar, and the newest message just above both (measured: their heights vary by phone)
const form = ref<HTMLElement>();
const tabHeight = ref(62);
const formHeight = ref(64);
let sizes: ResizeObserver | undefined;
onMounted(() => {
  void live.openChat(id);
  sizes = new ResizeObserver(() => {
    tabHeight.value = document.querySelector<HTMLElement>(".tabbar")?.offsetHeight ?? 0;
    formHeight.value = form.value?.offsetHeight ?? 64;
  });
  const bar = document.querySelector<HTMLElement>(".tabbar");
  if (bar) sizes.observe(bar);
  if (form.value) sizes.observe(form.value);
});
onUnmounted(() => {
  live.closeChat();
  sizes?.disconnect();
});
// keep the newest in sight
watch(
  () => chat.value?.messages.length,
  async () => {
    await nextTick();
    const page = document.getElementById("scroller"); // (the page scrolls in there, not the document: see app.vue)
    page?.scrollTo({ top: page.scrollHeight });
  },
);

async function send() {
  const t = text.value.trim();
  if (!t || sending.value) return;
  sending.value = true;
  problem.value = "";
  try {
    await live.send(id, t);
    text.value = "";
  } catch (e) {
    problem.value = e instanceof ApiError ? e.message : String(e);
  } finally {
    sending.value = false;
  }
}
async function unfriend() {
  if (!confirm(`不再和 ${chat.value?.friend.name} 當好友？（對話會留著，但不能再傳訊息）`)) return;
  await api("DELETE", `friends/${id}`);
  await navigateTo("/friends");
}
async function block() {
  if (!confirm(`封鎖 ${chat.value?.friend.name}？對方不會知道，之後也加不了你、傳不了訊息。`)) return;
  await api("POST", `friends/${id}/block`, {});
  await navigateTo("/friends");
}
/** A time between messages more than 10 minutes apart. */
const showTime = (k: number) => {
  const m = chat.value?.messages;
  if (!m) return false;
  return k === 0 || Date.parse(m[k]!.at) - Date.parse(m[k - 1]!.at) > 10 * 60_000;
};
</script>

<template>
  <main v-if="ok" class="page chat-page" :style="{ paddingBottom: `${tabHeight + formHeight + 12}px` }">
    <header class="topbar">
      <NuxtLink to="/friends" class="icon-btn">← 好友</NuxtLink>
      <img v-if="chat" :src="`/sprites/${chat.friend.race}/icon.png`" class="pixel face" alt="" />
      <h1 class="grow">{{ chat?.friend.name ?? "" }}</h1>
      <details class="more">
        <summary class="icon-btn">⋯</summary>
        <div class="menu">
          <button @click="unfriend">不當好友</button>
          <button @click="block">封鎖</button>
        </div>
      </details>
    </header>

    <div v-if="!chat" class="panel">讀取中…</div>
    <div v-else ref="list" class="messages">
      <p v-if="!chat.messages.length" class="empty">還沒有訊息，打個招呼吧！</p>
      <template v-for="(m, k) in chat.messages" :key="m.id">
        <p v-if="showTime(k)" class="time">{{ noteTime(m.at) }}</p>
        <div class="bubble" :class="{ mine: m.mine }">
          {{ m.text }}
          <small v-if="m.mine && k === chat.messages.length - 1">{{ m.read ? "已讀" : "送出了" }}</small>
        </div>
      </template>
    </div>

    <form ref="form" class="write" :style="{ bottom: `${tabHeight}px` }" @submit.prevent="send">
      <p v-if="problem" class="problem">{{ problem }}</p>
      <div class="line">
        <input v-model="text" :maxlength="MESSAGE_MAX" placeholder="寫點什麼…" enterkeyhint="send" />
        <button class="btn primary" :disabled="sending || !text.trim()">傳送</button>
      </div>
      <small v-if="text.length > MESSAGE_MAX - 40" class="count">{{ text.length }}/{{ MESSAGE_MAX }}</small>
    </form>
  </main>
</template>

<style scoped>
.face { width: 30px; height: 30px; image-rendering: pixelated; }
.grow { flex: 1; font-size: 18px; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.more { position: relative; }
.more summary { list-style: none; cursor: pointer; }
.more summary::-webkit-details-marker { display: none; }
.menu { position: absolute; right: 0; top: 44px; z-index: 5; background: #fffdf6; border: 2px solid #1f1f1f; border-radius: 10px; display: grid; min-width: 120px; overflow: hidden; }
.menu button { border: 0; background: none; padding: 11px 14px; text-align: left; font-size: 15px; cursor: pointer; }
.menu button + button { border-top: 1px solid #eee; color: #c0392b; }
.messages { display: flex; flex-direction: column; gap: 6px; }
.empty { color: #d8e4d0; text-align: center; margin-top: 30px; }
.time { align-self: center; color: #c9d6c0; font-size: 11px; margin: 8px 0 2px; }
.bubble {
  align-self: flex-start; max-width: 78%; background: #fffdf6; color: var(--ink); border-radius: 14px 14px 14px 4px; padding: 8px 12px;
  font-size: 15px; line-height: 1.45; white-space: pre-wrap; word-break: break-word; box-shadow: 2px 2px 0 rgba(0, 0, 0, 0.25);
}
.bubble.mine { align-self: flex-end; background: var(--paper-yellow); border-radius: 14px 14px 4px 14px; }
.bubble small { display: block; text-align: right; font-size: 10px; color: #777; margin-top: 2px; }
.write {
  position: fixed; left: 0; right: 0; z-index: 15; padding: 8px 12px;
  background: rgba(24, 38, 22, 0.96);
}
.line { display: flex; gap: 8px; max-width: 560px; margin: 0 auto; }
.line input { flex: 1; min-width: 0; border: 0; border-radius: 20px; padding: 10px 14px; font-size: 16px; background: #fffdf6; }
.count { display: block; text-align: right; color: #c9d6c0; max-width: 560px; margin: 2px auto 0; }
.problem { color: #ffd1c7; margin: 0 auto 6px; max-width: 560px; font-size: 13px; }
</style>
