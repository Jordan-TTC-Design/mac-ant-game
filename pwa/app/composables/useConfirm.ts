/**
 * A question asked in the page (instead of the browser's confirm()/prompt()): `await ask({...})` is true when the person
 * said yes. With `typed`, they must type that text (an address, say) before yes can be pressed. One at a time; the
 * <ConfirmDialog/> on the page shows it.
 */
export interface ConfirmQuestion {
  title: string;
  body?: string;
  yes?: string;
  danger?: boolean;
  /** What must be typed to say yes (case does not matter). */
  typed?: string;
}

const current = ref<(ConfirmQuestion & { answer: (yes: boolean) => void }) | null>(null);

export function useConfirm() {
  function ask(question: ConfirmQuestion): Promise<boolean> {
    current.value?.answer(false);
    return new Promise((resolve) => {
      current.value = {
        ...question,
        answer: (yes) => {
          current.value = null;
          resolve(yes);
        },
      };
    });
  }
  return { ask, current };
}
