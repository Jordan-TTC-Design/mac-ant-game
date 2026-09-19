#!/bin/bash
# Installs the GoblinCamp hooks for Claude Code:
#   1. copies goblin-notify.sh and goblin-ask.sh into ~/.claude/hooks/ (so moving this project does not break the hooks)
#   2. adds hooks to ~/.claude/settings.json (a backup is kept next to it):
#        PermissionRequest -> a goblin asks "allow?" and you answer on the bubble (falls back to Claude Code's own prompt)
#        Stop              -> a goblin says Claude is done and you can type a reply on the bubble
#        Notification      -> (idle_prompt, elicitation_dialog only) a plain popup
# Safe to run again. Undo with:  tools/install-hooks.sh --uninstall
# Options:  --simple  only plain popups (no answering): Notification and Stop hooks, as in earlier versions
#           --dir /some/folder  put the scripts somewhere else
set -e
here="$(cd "$(dirname "$0")" && pwd)"
dir="$HOME/.claude/hooks"
mode="install"
style="interactive"
while [ $# -gt 0 ]; do
    case "$1" in
        --uninstall) mode="uninstall" ;;
        --simple) style="simple" ;;
        --dir) shift; dir="$1" ;;
    esac
    shift
done
settings="$HOME/.claude/settings.json"
target="$dir/goblin-notify.sh"

if [ "$mode" = "install" ]; then
    mkdir -p "$dir"
    cp "$here/goblin-notify.sh" "$target"
    cp "$here/goblin-ask.sh" "$dir/goblin-ask.sh"
    chmod +x "$target" "$dir/goblin-ask.sh"
fi

[ -f "$settings" ] || { mkdir -p "$(dirname "$settings")"; echo '{}' > "$settings"; }
cp "$settings" "$settings.bak-goblincamp"

MODE="$mode" STYLE="$style" DIR="$dir" SETTINGS="$settings" python3 - <<'PY'
import json, os
path, folder, mode, style = os.environ["SETTINGS"], os.environ["DIR"], os.environ["MODE"], os.environ["STYLE"]
notify, ask = os.path.join(folder, "goblin-notify.sh"), os.path.join(folder, "goblin-ask.sh")
data = json.load(open(path))
hooks = data.setdefault("hooks", {})
markers = ("goblin-notify.sh", "goblin-ask.sh")
if style == "simple":
    plan = [("Notification", None, f"{notify} permission", None), ("Stop", None, f"{notify} done", None)]
else:
    plan = [("PermissionRequest", None, f"{ask} permission", 70), ("Stop", None, f"{ask} reply", 70),
            ("Notification", "idle_prompt|elicitation_dialog", f"{notify} permission", None)]
# drop our old entries first (a moved script or another style must not leave a stale one behind)
for event in ("Notification", "Stop", "PermissionRequest"):
    groups = hooks.get(event, [])
    for g in groups:
        g["hooks"] = [h for h in g.get("hooks", []) if not any(m in h.get("command", "") for m in markers)]
    groups[:] = [g for g in groups if g.get("hooks")]
    if not groups:
        hooks.pop(event, None)
if mode == "install":
    for event, matcher, command, timeout in plan:
        hook = {"type": "command", "command": command}
        if timeout:
            hook["timeout"] = timeout
        group = {"hooks": [hook]}
        if matcher:
            group["matcher"] = matcher
        hooks.setdefault(event, []).append(group)
if not hooks:
    del data["hooks"]
json.dump(data, open(path, "w"), indent=2, ensure_ascii=False)
print(("Installed (" + style + ")" if mode == "install" else "Removed") + " GoblinCamp hooks in " + path)
PY
[ "$mode" = "install" ] && echo "Scripts: $dir" || true
echo "Backup: $settings.bak-goblincamp   (open /hooks in Claude Code, or restart it, to load the change)"
