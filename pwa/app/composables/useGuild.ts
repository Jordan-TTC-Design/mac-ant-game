import { presenceNow, type GuildMemberView, type GuildRole } from "@goblincamp/shared";
import { ApiError } from "~/utils/api";

/**
 * What the guild's pages share (GUILD.md): the guild as last fetched, this account's place in it, how each member is now
 * (a Mac that went quiet since the fetch counts as gone), and doing one thing at a time with a line saying how it went.
 */
export const GUILD_PRESENCE = {
  focus: { dot: "#e2553f", text: "專注中" },
  online: { dot: "#4caf50", text: "在線" },
  away: { dot: "#e8c547", text: "離開" },
  offline: { dot: "#9a9a9a", text: "離線" },
} as const;
export const GUILD_ROLE: Record<GuildRole, string> = { leader: "會長", officer: "幹部", member: "成員" };

export function useGuild() {
  const { user } = useAccount();
  const live = useLive();
  const g = computed(() => live.state.guild);
  const guild = computed(() => g.value?.guild ?? null);
  const me = computed(() => guild.value?.members.find((m) => m.id === user.value?.id) ?? null);
  const role = computed<GuildRole | null>(() => me.value?.role ?? null);
  const busy = ref(false);
  const message = ref("");
  const now = ref(Date.now());
  let clock: ReturnType<typeof setInterval> | undefined;
  onMounted(() => {
    void live.loadGuild();
    clock = setInterval(() => (now.value = Date.now()), 30_000);
  });
  onUnmounted(() => clearInterval(clock));

  const presence = (m: GuildMemberView) => (m.presence === "offline" ? "offline" : presenceNow(m.presence, m.seenAt ? new Date(m.seenAt) : null, new Date(now.value)));
  const online = computed(() => guild.value?.members.filter((m) => presence(m) !== "offline").length ?? 0);
  /** The members with how they are now. */
  const inHall = computed(() => guild.value?.members.map((m) => ({ ...m, presence: presence(m) })) ?? []);

  async function act(work: () => Promise<unknown>, done = "") {
    busy.value = true;
    message.value = "";
    try {
      await work();
      message.value = done;
      await live.loadGuild();
    } catch (e) {
      message.value = e instanceof ApiError ? e.message : String(e);
    } finally {
      busy.value = false;
    }
  }

  return { user, live, g, guild, me, role, busy, message, presence, online, inHall, act };
}
