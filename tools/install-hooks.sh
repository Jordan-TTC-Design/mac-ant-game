#!/bin/bash
# Installs the GoblinCamp hooks for Claude Code:
#   1. copies goblin-notify.sh into ~/.claude/hooks/ (so moving this project does not break the hooks)
#   2. adds a "Notification" and a "Stop" hook to ~/.claude/settings.json (a backup is kept next to it)
# Safe to run again. Undo with:  tools/install-hooks.sh --uninstall
# Optional: pass another folder for the script with  --dir /some/folder
set -e
here="$(cd "$(dirname "$0")" && pwd)"
dir="$HOME/.claude/hooks"
mode="install"
while [ $# -gt 0 ]; do
    case "$1" in
        --uninstall) mode="uninstall" ;;
        --dir) shift; dir="$1" ;;
    esac
    shift
done
settings="$HOME/.claude/settings.json"
target="$dir/goblin-notify.sh"

if [ "$mode" = "install" ]; then
    mkdir -p "$dir"
    cp "$here/goblin-notify.sh" "$target"
    chmod +x "$target"
fi

[ -f "$settings" ] || { mkdir -p "$(dirname "$settings")"; echo '{}' > "$settings"; }
cp "$settings" "$settings.bak-goblincamp"

MODE="$mode" TARGET="$target" SETTINGS="$settings" python3 - <<'PY'
import json, os
path, target, mode = os.environ["SETTINGS"], os.environ["TARGET"], os.environ["MODE"]
data = json.load(open(path))
hooks = data.setdefault("hooks", {})
marker = "goblin-notify.sh"
for event, kind in (("Notification", "permission"), ("Stop", "done")):
    groups = hooks.setdefault(event, [])
    # drop our old entries first (so a moved script does not leave a stale one behind)
    for g in groups:
        g["hooks"] = [h for h in g.get("hooks", []) if marker not in h.get("command", "")]
    groups[:] = [g for g in groups if g.get("hooks")]
    if mode == "install":
        groups.append({"hooks": [{"type": "command", "command": f"{target} {kind}"}]})
    if not groups:
        del hooks[event]
if not hooks:
    del data["hooks"]
json.dump(data, open(path, "w"), indent=2, ensure_ascii=False)
print(("Installed" if mode == "install" else "Removed") + " GoblinCamp hooks in " + path)
PY
[ "$mode" = "install" ] && echo "Script: $target" || true
echo "Backup: $settings.bak-goblincamp   (open /hooks in Claude Code, or restart it, to load the change)"
