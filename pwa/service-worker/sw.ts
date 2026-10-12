/// <reference lib="webworker" />
// The phone app's service worker: keeps the app itself for offline use, and shows the pushes (reminders, big-world news).
import { clientsClaim } from "workbox-core";
import { cleanupOutdatedCaches, createHandlerBoundToURL, precacheAndRoute } from "workbox-precaching";
import { NavigationRoute, registerRoute } from "workbox-routing";

declare let self: ServiceWorkerGlobalScope;

precacheAndRoute(self.__WB_MANIFEST);
cleanupOutdatedCaches();
// every page of the app is the same index.html (a single-page app); the API is never cached
try {
  registerRoute(new NavigationRoute(createHandlerBoundToURL("/index.html"), { denylist: [/^\/api\//] }));
} catch {
  // (in development there is no index.html in the cache)
}
// the pictures: fetched once, then kept (not listed in the precache: see nuxt.config.ts)
registerRoute(
  ({ request, url }) => request.destination === "image" && url.origin === self.location.origin,
  async ({ request }) => {
    const cache = await caches.open("pictures-v1");
    const kept = await cache.match(request);
    if (kept) return kept;
    const response = await fetch(request);
    if (response.ok) void cache.put(request, response.clone());
    return response;
  },
);
self.skipWaiting();
clientsClaim();

interface ReminderPush {
  type: "reminder";
  noteId: string;
  title: string;
  body: string;
}

/** News with a page (tapping opens `url`): the big world, a message or friend ask, a pomodoro part, a question from Claude. */
interface WorldPush {
  type: "world" | "social" | "claude";
  /** Claude's question: the notification gets 允許這一次 / 拒絕 (where the phone shows buttons on notifications). */
  ask?: { id: string; kind: string };
  title: string;
  body: string;
  url: string;
  tag: string;
}

self.addEventListener("push", (event) => {
  let data: ReminderPush | WorldPush | null = null;
  try {
    data = event.data?.json() as ReminderPush | WorldPush;
  } catch {
    // (not ours)
  }
  // news with a page to open: the big world, friends and messages, the pomodoro, Claude's questions
  if (data?.type === "world" || data?.type === "social" || data?.type === "claude") {
    const world = data;
    event.waitUntil(
      self.registration.showNotification(world.title, {
        body: world.body,
        tag: world.tag,
        icon: "/icons/icon-192.png",
        badge: "/icons/icon-192.png",
        data: { url: world.url, ask: world.ask },
        ...(world.ask?.kind === "permission"
          ? { actions: [{ action: "allow", title: "允許這一次" }, { action: "deny", title: "拒絕" }], requireInteraction: true }
          : {}),
      }),
    );
    return;
  }
  if (!data || data.type !== "reminder") return;
  event.waitUntil(
    self.registration.showNotification(data.title, {
      body: data.body,
      tag: data.noteId, // a second push for the same note replaces the first
      icon: "/icons/icon-192.png",
      badge: "/icons/icon-192.png",
      data: { noteId: data.noteId },
    }),
  );
});

// tapping the notification opens that note (in the app if it is open already)
self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const data = event.notification.data as { noteId?: string; url?: string; ask?: { id: string } } | undefined;
  // a button on Claude's question: answer it right here (the session cookie goes along), no need to open the app
  if (data?.ask && (event.action === "allow" || event.action === "deny")) {
    const action = event.action;
    event.waitUntil(
      fetch(`/api/claude/${encodeURIComponent(data.ask.id)}/answer`, {
        method: "POST",
        credentials: "include",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ action }),
      })
        .then((res) =>
          self.registration.showNotification(res.ok ? (action === "allow" ? "已允許" : "已拒絕") : "沒送到", {
            body: res.ok ? "已經告訴電腦上的 Claude 了。" : "這個問題可能已經回答過、或電腦已經不等了。",
            tag: `claude-${data.ask!.id}`,
            icon: "/icons/icon-192.png",
          }),
        )
        .catch(() => undefined),
    );
    return;
  }
  const url = data?.url ?? (data?.noteId ? `/note/${data.noteId}` : "/");
  event.waitUntil(
    (async () => {
      const windows = await self.clients.matchAll({ type: "window", includeUncontrolled: true });
      for (const client of windows) {
        if ("focus" in client) {
          await client.focus();
          if ("navigate" in client) await (client as WindowClient).navigate(url);
          return;
        }
      }
      await self.clients.openWindow(url);
    })(),
  );
});
