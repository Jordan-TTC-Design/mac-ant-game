// Opens the phone app's main pages in a headless Chrome (phone-sized), logged in as the preview's demo camp, and checks each
// one: it loads, shows what it should, has no errors in the console, and no line of text cut off in the big world's cell card.
// Saves a picture of each to pwa/screens/ to look at. No packages: Chrome's own DevTools protocol over a WebSocket.
//
//   pwa/scripts/preview.sh --screens     (fills the preview, starts the server and the app, runs this, stops them)
//   node pwa/scripts/screens.mjs         (against a preview already running on :3000)
import { spawn } from "node:child_process";
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const APP = process.env.APP ?? "http://localhost:3000";
const CHROME = process.env.CHROME ?? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const OUT = new URL("../screens/", import.meta.url).pathname;
const PORT = 9333;
mkdirSync(OUT, { recursive: true });

const chrome = spawn(CHROME, [
  "--headless=new",
  `--remote-debugging-port=${PORT}`,
  `--user-data-dir=${mkdtempSync(join(tmpdir(), "gc-screens-"))}`,
  "--window-size=390,844",
  "--no-first-run",
  "--hide-scrollbars",
  "about:blank",
]);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let target;
for (let i = 0; i < 50 && !target; i++) {
  await sleep(200);
  target = await fetch(`http://localhost:${PORT}/json/list`).then((r) => r.json()).then((l) => l.find((t) => t.type === "page")).catch(() => null);
}
if (!target) throw new Error("Chrome did not start");

const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener("open", r, { once: true }));
let seq = 0;
const waiting = new Map();
const problems = [];
let page = "";
ws.addEventListener("message", (e) => {
  const msg = JSON.parse(e.data);
  if (msg.id && waiting.has(msg.id)) {
    waiting.get(msg.id)(msg);
    waiting.delete(msg.id);
  }
  if (msg.method === "Runtime.exceptionThrown") problems.push(`${page}: ${msg.params.exceptionDetails.exception?.description ?? msg.params.exceptionDetails.text}`);
  if (msg.method === "Runtime.consoleAPICalled" && msg.params.type === "error") problems.push(`${page}: console.error ${msg.params.args.map((a) => a.value ?? a.description).join(" ")}`);
  if (msg.method === "Log.entryAdded" && msg.params.entry.level === "error" && !/status of 401/.test(msg.params.entry.text)) problems.push(`${page}: ${msg.params.entry.text} ${msg.params.entry.url ?? ""}`);
});
const send = (method, params = {}) =>
  new Promise((resolve, reject) => {
    const id = ++seq;
    waiting.set(id, (m) => (m.error ? reject(new Error(`${method}: ${m.error.message}`)) : resolve(m.result)));
    ws.send(JSON.stringify({ id, method, params }));
  });
const evaluate = async (expression) => (await send("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true })).result.value;
/** Waits till `expression` is true (or gives up after `ms`). */
async function until(expression, ms = 15000) {
  for (const end = Date.now() + ms; Date.now() < end; await sleep(250)) if (await evaluate(expression)) return true;
  return false;
}
async function shot(name) {
  const { data } = await send("Page.captureScreenshot", { format: "png", captureBeyondViewport: false });
  writeFileSync(join(OUT, `${name}.png`), Buffer.from(data, "base64"));
}
async function visit(name, path, expects) {
  page = name;
  await send("Page.navigate", { url: `${APP}${path}` });
  const shown = await until(`(() => { const t = document.body?.innerText ?? ""; return ${JSON.stringify(expects)}.every((s) => t.includes(s)); })()`);
  if (!shown) problems.push(`${name}: never showed ${expects.filter(Boolean).join("／")}`);
  await sleep(800);
  await shot(name);
}

await send("Page.enable");
await send("Runtime.enable");
await send("Log.enable");
await send("Emulation.setDeviceMetricsOverride", { width: 390, height: 844, deviceScaleFactor: 2, mobile: true });

// log in through the form, as a person would
page = "login";
await send("Page.navigate", { url: `${APP}/login` });
await until(`!!document.querySelector("input[type=password]")`);
await evaluate(`(() => {
  const put = (el, v) => { el.value = v; el.dispatchEvent(new Event("input", { bubbles: true })); };
  put(document.querySelector("input[placeholder='you@example.com']"), "demo@example.com");
  put(document.querySelector("input[type=password]"), "goblin preview");
  document.querySelector("form button[type=submit]").click();
})()`);
if (!(await until(`location.pathname !== "/login"`))) problems.push("login: did not get past the login page");

await visit("world", "/world", ["大世界", "天賦", "敵軍來襲"]);
// the cell card: open the cell being attacked (/world?cell=…), and look for text cut off in the card's lines
const attacked = await evaluate(`fetch("/api/world").then((r) => r.json()).then((w) => w.incoming?.[0]?.to ?? w.cells[0]?.cell)`);
await visit("world-card", `/world?cell=${attacked}`, ["大世界"]);
if (!(await until(`document.querySelectorAll(".grow p").length > 1`))) problems.push("world card: the cell's card did not open");
const clipped = await evaluate(`[...document.querySelectorAll(".grow p")].filter((p) => p.scrollWidth > p.clientWidth + 1).map((p) => p.innerText.slice(0, 40))`);
for (const c of clipped ?? []) problems.push(`world card: text cut off: ${c}`);
await shot("world-card");
if (!(await evaluate(`document.body.innerText.includes("正在路上")`))) problems.push("world card: no ⚔️ line for the party on its way");
await visit("talents", "/talents", ["種族天賦", "掠奪"]);
await visit("workshop", "/workshop", ["工坊", "建議"]);
const cell = await evaluate(`fetch("/api/world").then((r) => r.json()).then((w) => w.cells.find((c) => c.town)?.cell ?? w.cells[0]?.cell)`);
await visit("territory", `/territory/${cell}`, ["住在這裡", "建築"]);
await visit("camp", "/camp", [""]);

ws.close();
chrome.kill();
console.log(`pictures: ${OUT}`);
if (problems.length) {
  console.log(`\n${problems.length} problem(s):`);
  for (const p of problems) console.log(`  ✗ ${p}`);
  process.exit(1);
}
console.log("✓ every page fine");
