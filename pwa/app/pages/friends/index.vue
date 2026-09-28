<script setup lang="ts">
import { noteTime } from "~/utils/time";
import { ApiError, api } from "~/utils/api";

// 好友: my friend code to give out, adding someone by theirs, asks waiting for a yes, and the friends with their last message.
const ok = await useSignedIn();
const live = useLive();
const f = computed(() => live.state.friends);
const code = ref("");
const busy = ref(false);
const message = ref("");
const copied = ref(false);

onMounted(() => void live.loadFriends());

async function ask() {
  const c = code.value.trim();
  if (!c) return;
  busy.value = true;
  message.value = "";
  try {
    const out = await api<{ status: string }>("POST", "friends/asks", { code: c });
    message.value = out.status === "friends" ? "成為好友了！" : "送出了，等對方答應。";
    code.value = "";
    await live.loadFriends();
  } catch (e) {
    message.value = e instanceof ApiError ? e.message : String(e);
  } finally {
    busy.value = false;
  }
}
async function accept(id: string) {
  await api("POST", `friends/${id}/accept`, {});
  await live.loadFriends();
}
async function drop(id: string, question: string) {
  if (question && !confirm(question)) return;
  await api("DELETE", `friends/${id}`);
  await live.loadFriends();
}
async function share() {
  const text = `來哥布林營地當好友！我的好友代碼：${f.value?.code}`;
  if (navigator.share) {
    try {
      await navigator.share({ text });
      return;
    } catch {
      // (closed: copy instead)
    }
  }
  if (await copyText(f.value?.code ?? "")) {
    copied.value = true;
    setTimeout(() => (copied.value = false), 1500);
  }
}
</script>

<template>
  <main v-if="ok" class="page">
    <header class="topbar">
      <div style="flex: 1">
        <h1>好友</h1>
        <div class="sub">傳訊息、一起打大世界</div>
      </div>
    </header>

    <section class="panel mine">
      <div class="grow">
        <small>我的好友代碼</small>
        <b class="code">{{ f?.code ?? "…" }}</b>
      </div>
      <button class="btn" @click="share">{{ copied ? "✓ 複製了" : "分享" }}</button>
    </section>

    <form class="add" @submit.prevent="ask">
      <input v-model="code" placeholder="對方的代碼，如 GOB-7K2QXM" autocapitalize="characters" autocomplete="off" />
      <button class="btn primary" :disabled="busy || !code.trim()">加好友</button>
    </form>
    <p v-if="message" class="note">{{ message }}</p>
    <p class="hint">在大世界的地圖上點別人的領地，也可以直接加好友。</p>

    <section v-if="f?.incoming.length" class="panel">
      <h2>想加你好友</h2>
      <div v-for="p in f.incoming" :key="p.id" class="row">
        <img :src="`/sprites/${p.race}/icon.png`" class="pixel face" alt="" />
        <span class="grow"><b>{{ p.name }}</b><br /><small>{{ noteTime(p.at) }}</small></span>
        <button class="btn primary" @click="accept(p.id)">答應</button>
        <button class="btn" @click="drop(p.id, '')">不要</button>
      </div>
    </section>

    <section class="panel list">
      <h2>好友 <small v-if="f">{{ f.friends.length }}</small></h2>
      <p v-if="f && !f.friends.length" class="muted">還沒有好友。把上面的代碼傳給同事，或輸入他們的。</p>
      <NuxtLink v-for="p in f?.friends ?? []" :key="p.id" :to="`/friends/${p.id}`" class="row friend">
        <img :src="`/sprites/${p.race}/icon.png`" class="pixel face" alt="" />
        <span class="grow">
          <b>{{ p.name }}</b>
          <small class="last">{{ p.last ? `${p.last.mine ? "你：" : ""}${p.last.text}` : "還沒聊過，打個招呼吧" }}</small>
        </span>
        <span class="side">
          <small v-if="p.last">{{ noteTime(p.last.at) }}</small>
          <i v-if="p.unread" class="unread">{{ p.unread }}</i>
        </span>
      </NuxtLink>
    </section>

    <section v-if="f?.outgoing.length" class="panel">
      <h2>等對方答應</h2>
      <div v-for="p in f.outgoing" :key="p.id" class="row">
        <img :src="`/sprites/${p.race}/icon.png`" class="pixel face" alt="" />
        <span class="grow"><b>{{ p.name }}</b></span>
        <button class="btn" @click="drop(p.id, '取消這個邀請？')">取消</button>
      </div>
    </section>
  </main>
</template>

<style scoped>
.mine { display: flex; align-items: center; gap: 10px; }
.mine small { display: block; color: #666; font-size: 12px; }
.code { font-size: 22px; letter-spacing: 1px; font-family: ui-monospace, Menlo, monospace; }
.grow { flex: 1; min-width: 0; }
.add { display: flex; gap: 8px; margin: 12px 0 4px; }
.add input { flex: 1; min-width: 0; border: 0; border-radius: 10px; padding: 10px 12px; font-size: 16px; background: #fffdf6; }
.note { color: #fff3c4; margin: 6px 2px; font-weight: 600; }
.hint { color: #c9d6c0; font-size: 12px; margin: 4px 2px 12px; }
h2 { margin: 0 0 6px; font-size: 17px; }
h2 small { color: #888; font-weight: 600; }
.row { display: flex; align-items: center; gap: 10px; padding: 8px 0; border-top: 1px solid rgba(0, 0, 0, 0.06); color: inherit; text-decoration: none; }
.row:first-of-type { border-top: 0; }
.face { width: 36px; height: 36px; image-rendering: pixelated; flex: none; }
.friend .last { display: block; color: #666; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.side { display: grid; justify-items: end; gap: 3px; color: #888; }
.unread { min-width: 20px; height: 20px; border-radius: 10px; background: #e2553f; color: #fff; font-style: normal; font-weight: 800; font-size: 12px; line-height: 20px; text-align: center; padding: 0 5px; }
.muted { color: #666; }
</style>
