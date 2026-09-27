/// <reference lib="webworker" />
// The phone app's service worker: keeps the app itself for offline use, and shows the reminder pushes.
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

self.addEventListener("push", (event) => {
  let data: ReminderPush | null = null;
  try {
    data = event.data?.json() as ReminderPush;
  } catch {
    // (not ours)
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
  const noteId = (event.notification.data as { noteId?: string } | undefined)?.noteId;
  const url = noteId ? `/note/${noteId}` : "/";
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
