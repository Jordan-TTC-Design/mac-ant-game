/** 今天 15:30、明天 09:00、10/3 18:00 (like the notes on the Mac). */
export function noteTime(iso: string, now = new Date()): string {
  const d = new Date(iso);
  const hm = `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
  const day = (offset: number) => {
    const x = new Date(now);
    x.setDate(x.getDate() + offset);
    return x.toDateString();
  };
  if (d.toDateString() === day(0)) return `今天 ${hm}`;
  if (d.toDateString() === day(1)) return `明天 ${hm}`;
  if (d.toDateString() === day(-1)) return `昨天 ${hm}`;
  return `${d.getMonth() + 1}/${d.getDate()} ${hm}`;
}

/** `hour` o'clock `days` days from today. */
export function atHour(hour: number, days = 0): Date {
  const d = new Date();
  d.setDate(d.getDate() + days);
  d.setHours(hour, 0, 0, 0);
  return d;
}

/** 18:00 on the coming Friday. */
export function fridayEvening(): Date {
  const now = new Date();
  let days = (5 - now.getDay() + 7) % 7;
  if (days === 0 && now >= atHour(18)) days = 7;
  return atHour(18, days);
}

/** For <input type="datetime-local">: local time without a zone, and back. */
export function toLocalInput(iso: string | null): string {
  if (!iso) return "";
  const d = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}
export function fromLocalInput(value: string): string | null {
  return value ? new Date(value).toISOString() : null;
}
