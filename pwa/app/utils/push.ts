import { api } from "~/utils/api";

export type PushState = "on" | "off" | "denied" | "unsupported" | "needs-install" | "no-key";

/** Whether this is the app added to the home screen (iPhone only allows pushes there). */
export function isInstalled(): boolean {
  return window.matchMedia("(display-mode: standalone)").matches || (navigator as Navigator & { standalone?: boolean }).standalone === true;
}

const isIOS = () => /iPhone|iPad|iPod/.test(navigator.userAgent);

export async function pushState(): Promise<PushState> {
  if (!("serviceWorker" in navigator) || !("PushManager" in window) || !("Notification" in window)) return isIOS() && !isInstalled() ? "needs-install" : "unsupported";
  if (Notification.permission === "denied") return "denied";
  const registration = await navigator.serviceWorker.getRegistration();
  return (await registration?.pushManager.getSubscription()) ? "on" : "off";
}

function keyBytes(base64: string): Uint8Array<ArrayBuffer> {
  const padded = (base64 + "=".repeat((4 - (base64.length % 4)) % 4)).replace(/-/g, "+").replace(/_/g, "/");
  const raw = atob(padded);
  const bytes = new Uint8Array(new ArrayBuffer(raw.length));
  for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
  return bytes;
}

/** Asks for permission, subscribes, and tells the server where to push. */
export async function enablePush(): Promise<PushState> {
  const now = await pushState();
  if (now === "unsupported" || now === "needs-install" || now === "denied") return now;
  const { publicKey } = await api<{ publicKey: string | null }>("GET", "push/key");
  if (!publicKey) return "no-key";
  if ((await Notification.requestPermission()) !== "granted") return "denied";
  const registration = await navigator.serviceWorker.ready;
  const subscription = (await registration.pushManager.getSubscription()) ?? (await registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: keyBytes(publicKey) }));
  await api("POST", "push/subscribe", subscription.toJSON());
  return "on";
}

export async function disablePush(): Promise<void> {
  const registration = await navigator.serviceWorker.getRegistration();
  await (await registration?.pushManager.getSubscription())?.unsubscribe();
  await api("DELETE", "push/subscribe");
}
