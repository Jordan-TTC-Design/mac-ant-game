<script setup lang="ts">
import "~/assets/admin.css";

// 後台: the frame around its pages (pages/admin/*); the server lets only admins through.
const ok = await useSignedIn();
const route = useRoute();
const PAGES = [
  { to: "/admin", name: "總覽" },
  { to: "/admin/users", name: "帳號" },
  { to: "/admin/announce", name: "公告" },
  { to: "/admin/invites", name: "邀請碼" },
  { to: "/admin/health", name: "伺服器" },
  { to: "/admin/backups", name: "備份" },
  { to: "/admin/log", name: "管理紀錄" },
];
const here = (to: string) => (to === "/admin" ? route.path === "/admin" : route.path.startsWith(to));
</script>

<template>
  <main v-if="ok" class="page admin">
    <header class="topbar">
      <NuxtLink to="/settings" class="icon-btn">← 設定</NuxtLink>
      <h1>後台</h1>
    </header>
    <nav class="nav">
      <NuxtLink v-for="p in PAGES" :key="p.to" :to="p.to" :class="{ here: here(p.to) }">{{ p.name }}</NuxtLink>
    </nav>
    <div class="body">
      <NuxtPage />
    </div>
    <ConfirmDialog />
  </main>
</template>
