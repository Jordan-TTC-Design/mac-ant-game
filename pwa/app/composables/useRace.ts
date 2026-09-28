import { api } from "~/utils/api";

const KEY = "gc-race";
const NOUNS: Record<string, string> = { goblin: "哥布林", elf: "精靈", undead: "死靈" };
let asked = false;
// (a plain ref, not useState: it is also set from inside useCamp's fetch, outside any component)
const race = ref<string>(saved());

function saved(): string {
  try {
    return (typeof localStorage === "undefined" ? null : localStorage.getItem(KEY)) ?? "goblin";
  } catch {
    return "goblin";
  }
}

/**
 * The account's race (from its camp), for the residents on the notes: their sprites and names follow it, as on the Mac.
 * Kept on the phone; asked from the server once a visit (useCamp keeps it up to date too). Goblin until known.
 */
export function useRace() {
  function set(value: string) {
    if (!NOUNS[value]) return;
    race.value = value;
    try {
      localStorage.setItem(KEY, value);
    } catch {
      // (private mode: kept for this visit only)
    }
  }
  /** Asks the server once (quietly: no camp yet or offline keeps what is known). */
  async function ensure() {
    if (asked) return;
    asked = true;
    try {
      set((await api<{ race: string }>("GET", "camp")).race);
    } catch {
      asked = false;
    }
  }
  /** Signing out: the next account may be another race. */
  function forget() {
    race.value = "goblin";
    asked = false;
    try {
      localStorage.removeItem(KEY);
    } catch {
      // (nothing kept)
    }
  }
  const noun = computed(() => NOUNS[race.value] ?? "哥布林");
  return { race, noun, set, ensure, forget };
}
