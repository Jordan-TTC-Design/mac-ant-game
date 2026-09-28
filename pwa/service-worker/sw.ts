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
        data: { url: world.url },
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
  const data = event.notification.data as { noteId?: string; url?: string } | undefined;
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
