// Inside the Mac app's main window (a web view whose user agent says "GoblinCampMac", mac/Sources/GoblinCamp/WebPane.swift):
// the Mac's own sidebar does what the tab bar does, so the page leaves the tab bar out and lays itself out for a wide window.
export const inMacApp = () => typeof navigator !== "undefined" && navigator.userAgent.includes("GoblinCampMac");
