/**
 * Counts attempts per key in fixed windows, in memory. Enough for one server; with several it would move to the database.
 */
export class RateLimiter {
  private hits = new Map<string, { count: number; resetAt: number }>();

  constructor(private readonly now: () => number = Date.now) {}

  /** Records an attempt. Returns 0 if it is allowed, else how many seconds until it will be. */
  hit(key: string, limit: number, windowSeconds: number): number {
    const now = this.now();
    let entry = this.hits.get(key);
    if (!entry || entry.resetAt <= now) {
      entry = { count: 0, resetAt: now + windowSeconds * 1000 };
      this.hits.set(key, entry);
    }
    entry.count++;
    if (this.hits.size > 50_000) this.sweep(now);
    return entry.count > limit ? Math.ceil((entry.resetAt - now) / 1000) : 0;
  }

  private sweep(now: number) {
    for (const [key, entry] of this.hits) if (entry.resetAt <= now) this.hits.delete(key);
  }
}
