import type { Mail, Mailer } from "../mail/mailer.ts";
import type { PushOutcome, PushSender } from "../push/sender.ts";
import type { PushSubscriptionJSON } from "@goblincamp/shared";

const HOUR = 3_600_000;
const ERRORS_KEPT = 10;

/**
 * What 後台's health page shows about the server's own work: pushes and mails sent or not in the last 24 hours, and the
 * last clearing of old records. Kept in memory only: it starts again from nothing when the server restarts.
 */
export class Watch {
  readonly startedAt: Date;
  /** hour (ms / HOUR) → counts in it */
  private hours = new Map<number, Record<string, number>>();
  mailErrors: { at: string; error: string }[] = [];
  maintenance: { at: string; cleared: Record<string, number> } | null = null;

  constructor(private readonly now: () => Date = () => new Date()) {
    this.startedAt = now();
  }

  count(what: string) {
    const hour = Math.floor(this.now().getTime() / HOUR);
    let counts = this.hours.get(hour);
    if (!counts) {
      this.hours.set(hour, (counts = {}));
      for (const h of this.hours.keys()) if (h <= hour - 24) this.hours.delete(h);
    }
    counts[what] = (counts[what] ?? 0) + 1;
  }

  /** How many of `what` in the last 24 hours. */
  last24h(what: string): number {
    const hour = Math.floor(this.now().getTime() / HOUR);
    let n = 0;
    for (const [h, counts] of this.hours) if (h > hour - 24) n += counts[what] ?? 0;
    return n;
  }

  /** The push sender, counting what it does. */
  pushes(inner: PushSender): PushSender {
    const watch = this;
    return {
      get publicKey() {
        return inner.publicKey;
      },
      async send(subscription: PushSubscriptionJSON, payload: object): Promise<PushOutcome> {
        const outcome = await inner.send(subscription, payload);
        if (inner.publicKey) watch.count(`push.${outcome}`); // (no keys: nothing is really tried)
        return outcome;
      },
    };
  }

  /** The mailer, counting what it does and keeping its last errors. */
  mails(inner: Mailer): Mailer {
    return {
      send: async (mail: Mail) => {
        try {
          await inner.send(mail);
          this.count("mail.sent");
        } catch (err) {
          this.count("mail.failed");
          this.mailErrors = [{ at: this.now().toISOString(), error: err instanceof Error ? err.message : String(err) }, ...this.mailErrors].slice(0, ERRORS_KEPT);
          throw err;
        }
      },
    };
  }
}
