/** A memo's lines, each with the web address in it (if any), for tapping and copying. */
export function noteLines(text: string): { text: string; url: string | null }[] {
  return text
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => ({ text: line, url: line.match(/https?:\/\/[^\s]+/)?.[0] ?? null }));
}

/** Copies to the clipboard; true when it worked. */
export async function copyText(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    return false;
  }
}
