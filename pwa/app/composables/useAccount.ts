import type { LoginResult, PublicUser } from "@goblincamp/shared";
import { ApiError, api } from "~/utils/api";

/** This phone's own id, made once and kept (the server knows the device by it). */
function deviceId(): string {
  let id = localStorage.getItem("gc-device-id");
  if (!id) {
    id = crypto.randomUUID();
    localStorage.setItem("gc-device-id", id);
  }
  return id;
}

function deviceName(): string {
  const ua = navigator.userAgent;
  if (/iPhone/.test(ua)) return "iPhone";
  if (/iPad/.test(ua)) return "iPad";
  if (/Android/.test(ua)) return "Android 手機";
  return "瀏覽器";
}

/** Who is signed in (null: nobody; undefined: not asked yet). The session itself is an HttpOnly cookie. */
export function useAccount() {
  const user = useState<PublicUser | null | undefined>("user", () => undefined);

  /** Asks the server who this is. Offline: keeps what was known, so the notes still show. */
  async function refresh(): Promise<PublicUser | null> {
    try {
      const me = await api<{ user: PublicUser }>("GET", "auth/me");
      user.value = me.user;
      localStorage.setItem("gc-user", JSON.stringify(me.user));
    } catch (e) {
      if (e instanceof ApiError && e.offline) {
        const saved = localStorage.getItem("gc-user");
        user.value = saved ? (JSON.parse(saved) as PublicUser) : null;
      } else {
        user.value = null;
        localStorage.removeItem("gc-user");
      }
    }
    return user.value ?? null;
  }

  async function login(email: string, password: string) {
    const result = await api<LoginResult>("POST", "auth/login", { email, password, device: { id: deviceId(), kind: "pwa", name: deviceName() } });
    user.value = result.user;
    localStorage.setItem("gc-user", JSON.stringify(result.user));
    return result.user;
  }

  async function logout() {
    try {
      await api("POST", "auth/logout");
    } catch {
      // (signed out here anyway)
    }
    user.value = null;
    localStorage.removeItem("gc-user");
    useRace().forget();
  }

  return { user, refresh, login, logout };
}
