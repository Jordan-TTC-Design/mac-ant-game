/**
 * Database backups (server/DESIGN.md §17): pg_dump, gzipped, into BACKUP_DIR (a volume of its own in the compose files).
 *
 * - auto: twice a day, at 01:30 and 13:30 Taiwan time, kept for 7 days. A time missed (the server was down or being
 *   deployed) is made up as soon as the server is up again;
 * - manual: from the admin page, kept until an admin deletes them, at most 20.
 *
 * The files are what `make dump-db` makes (plain SQL with --clean --if-exists), gzipped: `make restore-db file=….sql.gz`
 * puts one back. A failed backup is written down (failures.json) so the admin page can say so.
 */
import { spawn } from "node:child_process";
import { createWriteStream } from "node:fs";
import { mkdir, readFile, readdir, rename, rm, stat, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { pipeline } from "node:stream/promises";
import { createGzip } from "node:zlib";

export type BackupKind = "auto" | "manual";
export const BACKUP_KINDS: BackupKind[] = ["auto", "manual"];

export interface BackupFile {
  kind: BackupKind;
  name: string;
  size: number;
  /** When it was finished (ISO). */
  at: string;
}
export interface BackupFailure {
  at: string;
  kind: BackupKind;
  error: string;
}

const DAY = 86_400_000;
export const KEEP_AUTO_DAYS = 7;
export const MANUAL_MAX = 20;
/** Taiwan time is UTC+8 all year (no summer time). */
const TAIWAN = 8 * 3_600_000;
/** 01:30 and 13:30 Taiwan time, as minutes after midnight UTC (17:30 the day before, and 05:30). */
const SLOTS_UTC = [5 * 60 + 30, 17 * 60 + 30];
const NAME = /^goblin-\d{8}-\d{6}\.sql\.gz$/;
const FAILURES_KEPT = 20;

/** The latest auto backup time at or before `now`. */
export function lastSlot(now: Date): Date {
  const midnight = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  const times = [midnight - DAY, midnight].flatMap((d) => SLOTS_UTC.map((m) => d + m * 60_000));
  return new Date(Math.max(...times.filter((t) => t <= now.getTime())));
}

/** The next auto backup time after `now`. */
export function nextSlot(now: Date): Date {
  const midnight = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  const times = [midnight, midnight + DAY].flatMap((d) => SLOTS_UTC.map((m) => d + m * 60_000));
  return new Date(Math.min(...times.filter((t) => t > now.getTime())));
}

/** goblin-20260930-013000.sql.gz: when it was made, in Taiwan time (so the files read right on the server too). */
export function backupName(at: Date): string {
  const t = new Date(at.getTime() + TAIWAN).toISOString(); // 2026-09-30T01:30:00.000Z, read as Taiwan time
  return `goblin-${t.slice(0, 10).replaceAll("-", "")}-${t.slice(11, 19).replaceAll(":", "")}.sql.gz`;
}

export const isBackupName = (name: string) => NAME.test(name);

/** Writes the database, gzipped, to `out`. */
export type Dumper = (out: string) => Promise<void>;

/** pg_dump of the database at `databaseUrl` (the password goes in the environment, not on the command line). */
export function pgDump(databaseUrl: string): Dumper {
  const url = new URL(databaseUrl);
  const env = {
    ...process.env,
    PGHOST: url.hostname,
    PGPORT: url.port || "5432",
    PGUSER: decodeURIComponent(url.username),
    PGPASSWORD: decodeURIComponent(url.password),
    PGDATABASE: decodeURIComponent(url.pathname.slice(1)),
  };
  return async (out) => {
    const child = spawn("pg_dump", ["--clean", "--if-exists"], { env, stdio: ["ignore", "pipe", "pipe"] });
    let errors = "";
    child.stderr.on("data", (d: Buffer) => (errors = (errors + d.toString()).slice(-2000)));
    const exited = new Promise<number>((resolve, reject) => {
      child.on("error", reject); // (pg_dump is not installed)
      child.on("close", (code) => resolve(code ?? -1));
    });
    await Promise.all([pipeline(child.stdout, createGzip(), createWriteStream(out)), exited]);
    const code = await exited;
    if (code !== 0) throw new Error(errors.trim() || `pg_dump exited with ${code}`);
  };
}

export class BackupError extends Error {
  constructor(
    readonly code: "busy" | "full" | "not_found",
    message: string,
  ) {
    super(message);
  }
}

/** The backup folder: making, listing, pruning and deleting backups. One backup at a time. */
export class Backups {
  /** What is being made now. */
  running: BackupKind | null = null;

  constructor(
    readonly dir: string,
    private readonly dump: Dumper,
    private readonly now: () => Date = () => new Date(),
  ) {}

  private folder(kind: BackupKind) {
    return join(this.dir, kind);
  }

  /** The file of a backup, or null when the name is not one of ours (nothing outside the folder can be reached). */
  file(kind: string, name: string): string | null {
    if (!BACKUP_KINDS.includes(kind as BackupKind) || !isBackupName(name)) return null;
    return join(this.folder(kind as BackupKind), name);
  }

  async files(kind: BackupKind): Promise<BackupFile[]> {
    await mkdir(this.folder(kind), { recursive: true });
    const names = (await readdir(this.folder(kind))).filter(isBackupName);
    const out = await Promise.all(
      names.map(async (name) => {
        const s = await stat(join(this.folder(kind), name));
        return { kind, name, size: s.size, at: s.mtime.toISOString() };
      }),
    );
    return out.sort((a, b) => b.at.localeCompare(a.at));
  }

  async failures(): Promise<BackupFailure[]> {
    try {
      return JSON.parse(await readFile(join(this.dir, "failures.json"), "utf8")) as BackupFailure[];
    } catch {
      return [];
    }
  }

  private async fail(kind: BackupKind, error: string) {
    const list = [{ at: this.now().toISOString(), kind, error }, ...(await this.failures())].slice(0, FAILURES_KEPT);
    await writeFile(join(this.dir, "failures.json"), JSON.stringify(list, null, 1));
  }

  /** Makes a backup now. A manual one is refused while another is being made, or when there are MANUAL_MAX already. */
  async make(kind: BackupKind): Promise<BackupFile> {
    if (this.running) throw new BackupError("busy", "正在備份中，請等一下再試。");
    this.running = kind;
    const name = backupName(this.now());
    const out = join(this.folder(kind), name);
    const partial = `${out}.partial`;
    try {
      if (kind === "manual" && (await this.files("manual")).length >= MANUAL_MAX) {
        throw new BackupError("full", `手動備份最多 ${MANUAL_MAX} 份，請先刪掉舊的。`);
      }
    } catch (err) {
      this.running = null;
      throw err;
    }
    try {
      await mkdir(this.folder(kind), { recursive: true });
      await this.dump(partial);
      await rename(partial, out);
      if (kind === "auto") await this.prune();
      const s = await stat(out);
      return { kind, name, size: s.size, at: s.mtime.toISOString() };
    } catch (err) {
      await rm(partial, { force: true });
      await this.fail(kind, err instanceof Error ? err.message : String(err)).catch(() => {});
      throw err;
    } finally {
      this.running = null;
    }
  }

  /** Auto backups older than KEEP_AUTO_DAYS go (only after a new one was made, so there is always one left). */
  async prune(): Promise<string[]> {
    const before = this.now().getTime() - KEEP_AUTO_DAYS * DAY;
    const old = (await this.files("auto")).filter((f) => Date.parse(f.at) < before);
    for (const f of old) await rm(join(this.folder("auto"), f.name), { force: true });
    return old.map((f) => f.name);
  }

  async remove(kind: string, name: string) {
    const file = this.file(kind, name);
    if (!file || !(await stat(file).catch(() => null))) throw new BackupError("not_found", "沒有這份備份。");
    await rm(file);
  }

  /** Leftovers of a backup cut off half-way (the server stopped while writing). */
  async clearPartials() {
    for (const kind of BACKUP_KINDS) {
      await mkdir(this.folder(kind), { recursive: true });
      for (const name of await readdir(this.folder(kind))) if (name.endsWith(".partial")) await rm(join(this.folder(kind), name), { force: true });
    }
  }

  /** Makes the auto backup when one is due: none made since the latest backup time. Each time is tried once. */
  private tried = 0;
  async runIfDue(): Promise<BackupFile | null> {
    const slot = lastSlot(this.now()).getTime();
    if (this.tried === slot || this.running) return null;
    const newest = (await this.files("auto"))[0];
    if (newest && Date.parse(newest.at) >= slot) return null;
    this.tried = slot;
    return this.make("auto");
  }
}

/** Looks every minute whether an auto backup is due (the first look a minute after the start); returns a function that stops it. */
export function startBackups(backups: Backups, everyMs = 60_000): () => void {
  const run = async () => {
    try {
      const made = await backups.runIfDue();
      if (made) console.log(`backup made: ${made.kind}/${made.name} (${made.size} bytes)`);
    } catch (err) {
      console.error("backup:", err);
    }
  };
  void backups.clearPartials().catch((err) => console.error("backup:", err));
  const first = setTimeout(run, 60_000);
  const timer = setInterval(run, everyMs);
  return () => {
    clearTimeout(first);
    clearInterval(timer);
  };
}
