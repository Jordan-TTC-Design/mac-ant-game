import type { ChatMessage, ChatResponse, ClaudeResponse, FriendsResponse, PomodoroAction, PomodoroResponse, PomodoroState, ServerEvent } from "@goblincamp/shared";
import { pomodoroAt, pomodoroSegments } from "@goblincamp/shared";
import { ApiError, api } from "~/utils/api";

/**
 * What changes while the app is open besides the notes and the camp: friends and their messages, the pomodoro shared
 * with the Mac, and Claude's questions from the Mac. Fetched once after signing in, again when the server says so over
 * the WebSocket (useNotes passes its events on) and when the app comes back into sight; the tabs' red dots come from here.
 */
const state = reactive<{
  friends: FriendsResponse | null;
  pomodoro: PomodoroState | null;
  /** The pomodoro has been asked for at least once (until then, "none" is not known yet). */
  pomodoroLoaded: boolean;
  /** The server's clock minus this phone's (so a phone with a wrong clock still counts right). */
  clockOffset: number;
  claude: ClaudeResponse | null;
  /** The chat open now (its friend's id), and its messages. */
  chatWith: string | null;
  chat: ChatResponse | null;
}>({ friends: null, pomodoro: null, pomodoroLoaded: false, clockOffset: 0, claude: null, chatWith: null, chat: null });
let started = false;

async function quietly<T>(work: () => Promise<T>): Promise<T | null> {
  try {
    return await work();
  } catch (e) {
    if (e instanceof ApiError && e.offline) return null;
    console.warn(e);
    return null;
  }
}

const loadFriends = async () => {
  const out = await quietly(() => api<FriendsResponse>("GET", "friends"));
  if (out) state.friends = out;
};
const loadPomodoro = async () => {
  const out = await quietly(() => api<PomodoroResponse>("GET", "pomodoro"));
  if (out) setPomodoro(out);
};
const loadClaude = async () => {
  const out = await quietly(() => api<ClaudeResponse>("GET", "claude"));
  if (out) state.claude = out;
};
const loadChat = async () => {
  if (!state.chatWith) return;
  const id = state.chatWith;
  const out = await quietly(() => api<ChatResponse>("GET", `friends/${id}/messages`));
  if (out && state.chatWith === id) state.chat = out;
};
function setPomodoro(out: PomodoroResponse) {
  state.pomodoro = out.state;
  state.pomodoroLoaded = true;
  state.clockOffset = out.serverTime - Date.now();
}

function onEvent(e: Event) {
  const event = (e as CustomEvent<ServerEvent>).detail;
  if (event.type === "friends.changed") {
    void loadFriends();
    if (!event.from || event.from === state.chatWith) void loadChat();
  }
  if (event.type === "pomodoro.changed" && event.version !== state.pomodoro?.version) void loadPomodoro();
  if (event.type === "claude.changed") void loadClaude();
}
function onVisible() {
  if (document.visibilityState !== "visible") return;
  void loadFriends();
  void loadPomodoro();
  void loadClaude();
  void loadChat();
}

export function useLive() {
  function start() {
    if (started) return;
    started = true;
    window.addEventListener("gc:server-event", onEvent);
    document.addEventListener("visibilitychange", onVisible);
    onVisible();
  }

  /** The pomodoro as it is at `now` (ms, this phone's clock): the part, time left, and so on. */
  function pomodoroNow(now: number) {
    const moved = pomodoroAt(state.pomodoro, now + state.clockOffset).state;
    if (!moved) return null;
    const segments = pomodoroSegments(moved.plan);
    const part = segments[moved.index]!;
    const left = moved.endsAt !== null ? moved.endsAt - (now + state.clockOffset) : (moved.pausedLeft ?? 0);
    return { state: moved, part, segments, left: Math.max(0, left), paused: moved.endsAt === null };
  }

  async function pomodoro(action: PomodoroAction) {
    const out = await api<PomodoroResponse>("POST", "pomodoro", action);
    setPomodoro(out);
  }

  async function openChat(id: string) {
    state.chatWith = id;
    state.chat = state.chat?.friend.id === id ? state.chat : null;
    await loadChat();
    void loadFriends(); // (its unread count is 0 now)
  }
  function closeChat() {
    state.chatWith = null;
  }
  async function send(id: string, text: string) {
    const msg = await api<ChatMessage>("POST", `friends/${id}/messages`, { text });
    // (the server's own "friends.changed" may have reloaded the chat with this message in it already)
    if (state.chat?.friend.id === id && !state.chat.messages.some((m) => m.id === msg.id)) state.chat.messages.push(msg);
    void loadFriends();
  }

  async function answerClaude(id: string, action: "allow" | "deny" | "reply" | "dismiss", text?: string) {
    await api("POST", `claude/${id}/answer`, { action, ...(text ? { text } : {}) });
    await loadClaude();
  }

  /** The red dots on the tabs: unread messages and asks on 好友, Claude's questions on 首頁. */
  const badges = computed<Record<string, number>>(() => ({
    "/friends": (state.friends?.friends.reduce((n, x) => n + x.unread, 0) ?? 0) + (state.friends?.incoming.length ?? 0),
    "/": state.claude?.waiting.length ?? 0,
  }));

  return {
    state,
    badges,
    start,
    refresh: onVisible,
    loadFriends,
    loadClaude,
    pomodoroNow,
    pomodoro,
    openChat,
    closeChat,
    send,
    answerClaude,
  };
}
