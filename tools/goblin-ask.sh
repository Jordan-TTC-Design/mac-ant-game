#!/bin/sh
# Claude Code hook (popup you can answer):  goblin-ask.sh permission|reply   [older setups point here]
# The work is done by the game itself now ("GoblinCamp --hook"); use the app's menu 連接 Claude Code to set hooks up.
APP="$(cd "$(dirname "$0")/.." && pwd)/GoblinCamp.app/Contents/MacOS/GoblinCamp"
[ -x "$APP" ] || exit 0
exec "$APP" --hook ask "$@"
