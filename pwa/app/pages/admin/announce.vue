<script setup lang="ts">
import {
  ANNOUNCE_BODY_MAX,
  ANNOUNCE_TITLE_MAX,
  type AdminAnnouncement,
  type AdminAnnouncementList,
  type AnnounceAudience,
  type AnnounceAudienceCount,
} from "@goblincamp/shared";
import { api } from "~/utils/api";
import { errText } from "~/utils/admin";
import { noteTime } from "~/utils/time";

// 後台 › 公告: a banner on everyone's phone home page, maybe pushed to their phones too.
const { ask } = useConfirm();
const list = ref<AdminAnnouncement[]>([]);
const problem = ref("");
const note = ref("");
const busy = ref(false);
const title = ref("");
const body = ref("");
const url = ref("");
const audience = ref<AnnounceAudience>("all");
const hours = ref<number | "">("");
const push = ref(false);

async function load() {
  try {
    list.value = (await api<AdminAnnouncementList>("GET", "admin/announcements")).announcements;
  } catch (e) {
    problem.value = errText(e);
  }
}
onMounted(load);

async function send() {
  problem.value = "";
  note.value = "";
  const who = await api<AnnounceAudienceCount>("GET", `admin/announcements/audience?audience=${audience.value}`).catch(() => null);
  const whom = audience.value === "admins" ? "管理員" : "所有人";
  const lines = [`${whom}（${who?.users ?? "?"} 個帳號）打開手機首頁會看到。`];
  if (push.value) lines.push(`也會推播到 ${who?.phones ?? "?"} 支手機（一分鐘只能推一次）。`);
  if (!(await ask({ title: `發出公告「${title.value.trim()}」？`, body: lines.join("\n"), yes: push.value ? "發出並推播" : "發出" }))) return;
  busy.value = true;
  try {
    await api("POST", "admin/announcements", {
      title: title.value,
      body: body.value,
      url: url.value.trim() || null,
      audience: audience.value,
      endsAt: hours.value ? new Date(Date.now() + Number(hours.value) * 3_600_000).toISOString() : null,
      push: push.value,
    });
    note.value = push.value ? "公告發出了，推播在背景送出中。" : "公告發出了。";
    title.value = body.value = url.value = "";
    push.value = false;
    await load();
  } catch (e) {
    problem.value = errText(e);
  } finally {
    busy.value = false;
  }
}

async function takeDown(a: AdminAnnouncement) {
  if (!(await ask({ title: `下架「${a.title}」？`, body: "大家的首頁上會馬上消失。", yes: "下架", danger: true }))) return;
  try {
    await api("DELETE", `admin/announcements/${a.id}`);
    await load();
  } catch (e) {
    problem.value = errText(e);
  }
}
</script>

<template>
  <div class="two">
    <section class="panel">
      <h2>發公告</h2>
      <div class="field">
        <label>標題（最多 {{ ANNOUNCE_TITLE_MAX }} 字）</label>
        <input v-model="title" :maxlength="ANNOUNCE_TITLE_MAX" placeholder="例如：週六晚上 10 點維護一小時" />
      </div>
      <div class="field">
        <label>內容（可以空著，最多 {{ ANNOUNCE_BODY_MAX }} 字）</label>
        <textarea v-model="body" rows="4" :maxlength="ANNOUNCE_BODY_MAX" />
      </div>
      <div class="field">
        <label>點了打開哪一頁（可以空著，例如 /guild、/feedback）</label>
        <input v-model="url" placeholder="/" autocapitalize="off" spellcheck="false" />
      </div>
      <div class="row">
        <label>給誰
          <select v-model="audience">
            <option value="all">所有人</option>
            <option value="admins">只給管理員（先試看看）</option>
          </select>
        </label>
        <label>顯示幾小時（空著＝直到下架）
          <input v-model.number="hours" type="number" min="1" max="2160" style="width: 120px" />
        </label>
      </div>
      <label class="check"><input v-model="push" type="checkbox" /> 同時推播到手機</label>
      <div class="ops">
        <button class="btn primary" :disabled="busy || !title.trim()" @click="send">{{ busy ? "發送中…" : "發出" }}</button>
      </div>
      <p v-if="problem" class="status error">{{ problem }}</p>
      <p v-if="note" class="status ok">{{ note }}</p>
    </section>

    <section class="panel">
      <h2>發過的公告</h2>
      <p v-if="!list.length" class="muted">還沒有。</p>
      <div class="list">
        <div v-for="a in list" :key="a.id" class="item" :class="{ over: a.over }">
          <div class="grow">
            <b>{{ a.title }}</b>
            <span v-if="a.over" class="tag">已結束</span><span v-else class="tag green">顯示中</span><span v-if="a.audience === 'admins'" class="tag gold">只給管理員</span>
            <p v-if="a.body" class="small text">{{ a.body }}</p>
            <p class="small muted">
              {{ noteTime(a.at) }} {{ a.by ?? "" }}{{ a.endsAt && !a.over ? `・到 ${noteTime(a.endsAt)}` : "" }}{{ a.url ? `・打開 ${a.url}` : "" }}{{ a.pushed !== null ? `・推播 ${a.pushed} 支手機` : "" }}
            </p>
          </div>
          <button v-if="!a.over" class="btn small" @click="takeDown(a)">下架</button>
        </div>
      </div>
    </section>
  </div>
</template>

<style scoped>
.check { display: flex; align-items: center; gap: 8px; margin: 12px 0 4px; font-size: 14px; }
.check input { width: 18px; height: 18px; }
.row select { min-width: 160px; }
.item { display: flex; gap: 8px; align-items: flex-start; }
.item .grow { flex: 1; min-width: 0; }
.item.over { opacity: 0.6; }
.text { white-space: pre-line; overflow-wrap: anywhere; }
</style>
