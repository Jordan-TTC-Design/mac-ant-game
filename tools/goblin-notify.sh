#!/bin/bash
# Claude Code hook -> GoblinCamp popup.   usage: goblin-notify.sh permission|done
# Claude Code passes a JSON description of the event on stdin; from it we only take the project folder name.
# Does nothing when GoblinCamp is not running, so it never starts the game by itself.
kind="${1:-done}"
pgrep -x GoblinCamp >/dev/null || exit 0
project="$(python3 -c '
import sys, json, os, urllib.parse
try:
    d = json.load(sys.stdin)
    print(urllib.parse.quote(os.path.basename(d.get("cwd", "").rstrip("/")))[:80])
except Exception:
    pass
' 2>/dev/null)"
# which app Claude runs in, so a click on the popup can bring it back to the front
case "$TERM_PROGRAM" in
    Apple_Terminal) app="com.apple.Terminal" ;;
    iTerm.app) app="com.googlecode.iterm2" ;;
    vscode) app="com.microsoft.VSCode" ;;
    WarpTerminal) app="dev.warp.Warp-Stable" ;;
    ghostty) app="com.mitchellh.ghostty" ;;
    WezTerm) app="com.github.wez.wezterm" ;;
    *) app="" ;;
esac
open -g "goblincamp://notify?kind=${kind}&project=${project}&app=${app}"
exit 0
