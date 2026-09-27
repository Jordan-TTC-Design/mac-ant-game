import webpush from "web-push";
import type { PushSubscriptionJSON } from "@goblincamp/shared";

export type PushOutcome = "sent" | "gone" | "failed";

/** Delivers a push to one phone. */
export interface PushSender {
  readonly publicKey: string | null;
  send(subscription: PushSubscriptionJSON, payload: object): Promise<PushOutcome>;
}

/** The real one (Web Push with VAPID keys; `pnpm --filter @goblincamp/server vapid` makes a pair). */
export class WebPushSender implements PushSender {
  constructor(
    readonly publicKey: string,
    privateKey: string,
    subject: string,
  ) {
    webpush.setVapidDetails(subject, publicKey, privateKey);
  }

  async send(subscription: PushSubscriptionJSON, payload: object): Promise<PushOutcome> {
    try {
      await webpush.sendNotification(subscription as webpush.PushSubscription, JSON.stringify(payload), { TTL: 3600, urgency: "high" });
      return "sent";
    } catch (err) {
      const status = (err as { statusCode?: number }).statusCode;
      if (status === 404 || status === 410) return "gone"; // the phone unsubscribed or the app was removed
      console.error("push failed:", status ?? err);
      return "failed";
    }
  }
}

/** No keys set: pushes are skipped (the phone just does not get them). */
export class NoPushSender implements PushSender {
  readonly publicKey = null;
  async send(): Promise<PushOutcome> {
    return "failed";
  }
}

/** Keeps what would have been sent, for tests. */
export class MemoryPushSender implements PushSender {
  readonly publicKey = "test-public-key";
  readonly sent: { endpoint: string; payload: Record<string, unknown> }[] = [];
  /** Endpoints that answer "gone". */
  readonly gone = new Set<string>();
  async send(subscription: PushSubscriptionJSON, payload: object): Promise<PushOutcome> {
    if (this.gone.has(subscription.endpoint)) return "gone";
    this.sent.push({ endpoint: subscription.endpoint, payload: payload as Record<string, unknown> });
    return "sent";
  }
}
