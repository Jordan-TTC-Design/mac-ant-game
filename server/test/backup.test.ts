import { mkdtemp, readdir, rm, utimes, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { backupName, Backups, isBackupName, lastSlot, MANUAL_MAX, nextSlot, type Dumper } from "../src/backup.ts";

const DAY = 86_400_000;
let dir: string;
let clock: Date;
let fail = false;
/** A dump that writes a little file (or fails, when `fail` is set). */
const fake: Dumper = async (out) => {
  if (fail) throw new Error("pg_dump: connection refused");
  await writeFile(out, "-- dump\n");
  await utimes(out, clock, clock);
};
const backups = () => new Backups(dir, fake, () => clock);

beforeEach(async () => {
  dir = await mkdtemp(join(tmpdir(), "goblin-backups-"));
  clock = new Date("2026-10-01T09:00:00Z"); // 17:00 in Taiwan
  fail = false;
});
afterEach(async () => {
  await rm(dir, { recursive: true, force: true });
});

describe("backup times", () => {
  it("are 01:30 and 13:30 Taiwan time", () => {
    // 17:00 Taiwan: the latest was 13:30 today (05:30 UTC), the next is 01:30 tomorrow (17:30 UTC today)
    expect(lastSlot(clock).toISOString()).toBe("2026-10-01T05:30:00.000Z");
    expect(nextSlot(clock).toISOString()).toBe("2026-10-01T17:30:00.000Z");
    // 00:10 Taiwan (16:10 UTC the day before): the latest was 13:30 the day before
    expect(lastSlot(new Date("2026-09-30T16:10:00Z")).toISOString()).toBe("2026-09-30T05:30:00.000Z");
    // right on the time counts
    expect(lastSlot(new Date("2026-10-01T17:30:00Z")).toISOString()).toBe("2026-10-01T17:30:00.000Z");
  });

  it("names a file by its Taiwan time", () => {
    expect(backupName(new Date("2026-09-30T17:30:00Z"))).toBe("goblin-20261001-013000.sql.gz");
    expect(isBackupName("goblin-20261001-013000.sql.gz")).toBe(true);
    expect(isBackupName("../../etc/passwd")).toBe(false);
  });
});

describe("backups", () => {
  it("makes the auto backup once per time, and makes up a missed one", async () => {
    const b = backups();
    expect((await b.runIfDue())?.kind).toBe("auto"); // none yet: made at once
    expect(await b.runIfDue()).toBeNull(); // (already made for 13:30)
    clock = new Date("2026-10-01T17:31:00Z"); // 01:31 Taiwan
    expect(await b.runIfDue()).not.toBeNull();
    expect((await b.files("auto")).length).toBe(2);
  });

  it("keeps auto backups 7 days, manual ones until deleted", async () => {
    const b = backups();
    await b.make("manual");
    for (let k = 0; k < 20; k++) {
      clock = new Date(clock.getTime() + DAY / 2);
      await b.make("auto");
    }
    const auto = await b.files("auto");
    expect(auto.length).toBe(15); // the ones from the last 7 days (the newest included)
    expect(auto.every((f) => Date.parse(f.at) >= clock.getTime() - 7 * DAY)).toBe(true);
    expect((await b.files("manual")).length).toBe(1);
  });

  it("writes a failure down and leaves no half file", async () => {
    const b = backups();
    fail = true;
    await expect(b.make("auto")).rejects.toThrow("connection refused");
    expect(await b.failures()).toMatchObject([{ kind: "auto", error: "pg_dump: connection refused" }]);
    expect(await readdir(join(dir, "auto"))).toEqual([]);
    expect(b.running).toBeNull();
    // the same time is not tried again every minute
    fail = false;
    await expect(b.runIfDue()).resolves.not.toBeNull(); // (runIfDue had not tried this time yet: make() was called directly)
    expect(await b.runIfDue()).toBeNull();
  });

  it(`refuses a manual backup past ${MANUAL_MAX}, and deletes only its own files`, async () => {
    const b = backups();
    for (let k = 0; k < MANUAL_MAX; k++) {
      clock = new Date(clock.getTime() + 1000);
      await b.make("manual");
    }
    await expect(b.make("manual")).rejects.toMatchObject({ code: "full" });
    expect(b.running).toBeNull();
    const [newest] = await b.files("manual");
    await b.remove("manual", newest!.name);
    expect((await b.files("manual")).length).toBe(MANUAL_MAX - 1);
    await expect(b.remove("manual", "../failures.json")).rejects.toMatchObject({ code: "not_found" });
    await expect(b.remove("other", newest!.name)).rejects.toMatchObject({ code: "not_found" });
  });

  it("makes one backup at a time", async () => {
    let release = () => {};
    const slow = new Backups(dir, (out) => new Promise((resolve) => (release = () => void writeFile(out, "x").then(resolve))), () => clock);
    const first = slow.make("auto");
    await new Promise((r) => setTimeout(r, 10));
    await expect(slow.make("manual")).rejects.toMatchObject({ code: "busy" });
    release();
    await first;
  });
});
