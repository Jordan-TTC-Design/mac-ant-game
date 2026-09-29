/**
 * The iPhone's home-screen app gives the page a viewport shorter than the screen (by about the status bar's height), so
 * everything fixed to the bottom (the tab bar, the big world's card, the bars under a note or a chat) floats above the
 * bottom edge with a strip of background under it. Measured here: how much shorter the page is than the screen. The
 * elements fixed to the bottom move down by that much (--vp-gap). When iOS gets it right the gap is 0 and nothing moves.
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
