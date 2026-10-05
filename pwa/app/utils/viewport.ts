/**
 * The screen's sizes as the phone reports them, for 設定 →「畫面尺寸（除錯用）」: when something sits in the wrong place on an
 * iPhone, a screenshot of these says why. `gap`: how much shorter than the screen the home-screen app makes the page.
 * (Moving the bottom bars down by it did not work: iOS does not draw the page there at all. See nuxt.config.ts.)
 */
export interface ViewportSizes {
  standalone: boolean;
  screen: number;
  inner: number;
  client: number;
  visual: number | null;
  safeTop: number;
  safeBottom: number;
  gap: number;
}

export const isStandalone = () => matchMedia("(display-mode: standalone)").matches || (navigator as { standalone?: boolean }).standalone === true;

function safeArea(side: "top" | "bottom"): number {
  const probe = document.createElement("div");
  probe.style.cssText = `position:fixed;visibility:hidden;padding-${side}:env(safe-area-inset-${side})`;
  document.body.appendChild(probe);
  const px = parseFloat(getComputedStyle(probe)[side === "top" ? "paddingTop" : "paddingBottom"]) || 0;
  probe.remove();
  return px;
}

export function measureViewport(): ViewportSizes {
  const standalone = isStandalone();
  // (on iOS the screen's width and height do not swap when the phone is turned)
  const portrait = matchMedia("(orientation: portrait)").matches;
  const screenHeight = portrait ? Math.max(screen.width, screen.height) : Math.min(screen.width, screen.height);
  const inner = window.innerHeight;
  const raw = Math.round(screenHeight - inner);
  // only in the home-screen app (in Safari its own bars take the difference), and a gap the size of a status bar at most
  const gap = standalone && raw > 0 && raw <= 100 ? raw : 0;
  return {
    standalone,
    screen: screenHeight,
    inner,
    client: document.documentElement.clientHeight,
    visual: window.visualViewport ? Math.round(window.visualViewport.height) : null,
    safeTop: safeArea("top"),
    safeBottom: safeArea("bottom"),
    gap,
  };
}
