#!/bin/bash
# Claude Code hook -> GoblinCamp popup you can answer.   usage: goblin-ask.sh permission|reply
#   permission  (PermissionRequest hook): the goblin asks "allow?"; the answer goes back to Claude Code.
#   reply       (Stop hook): the goblin says Claude is done and offers a text box; what you type goes back to Claude as its next instruction.
# If GoblinCamp is not running, is silent (focus mode), or you do not answer in time, this prints nothing and
# Claude Code carries on as if the hook did not exist (its own prompt appears / it stops normally).
kind="${1:-reply}"
pgrep -x GoblinCamp >/dev/null || exit 0
input="$(cat)"
KIND="$kind" INPUT="$input" TERM_PROGRAM="$TERM_PROGRAM" python3 - <<'PY'
import json, os, re, subprocess, sys, time, uuid, urllib.parse

kind = os.environ["KIND"]
try:
    data = json.loads(os.environ.get("INPUT") or "{}")
except Exception:
    data = {}

APPS = {"Apple_Terminal": "com.apple.Terminal", "iTerm.app": "com.googlecode.iterm2", "vscode": "com.microsoft.VSCode",
        "WarpTerminal": "dev.warp.Warp-Stable", "ghostty": "com.mitchellh.ghostty", "WezTerm": "com.github.wez.wezterm"}
app = APPS.get(os.environ.get("TERM_PROGRAM", ""), "")
project = os.path.basename((data.get("cwd") or "").rstrip("/"))

def squash(text, limit=90):
    text = re.sub(r"\s+", " ", str(text)).strip()
    return text if len(text) <= limit else text[: limit - 1] + "…"

summary = ""
if kind == "permission":
    tool, tin = data.get("tool_name", ""), data.get("tool_input") or {}
    if tool == "Bash":
        summary = "執行：" + squash(tin.get("command", ""))
    elif tool in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
        summary = "修改：" + os.path.basename(tin.get("file_path") or tin.get("notebook_path") or "")
    elif tool == "Read":
        summary = "讀取：" + os.path.basename(tin.get("file_path") or "")
    elif tool in ("WebFetch", "WebSearch"):
        summary = "上網：" + squash(tin.get("url") or tin.get("query") or "")
    else:
        summary = squash(tool)

ident = str(uuid.uuid4())
support = os.path.expanduser("~/Library/Application Support/GoblinCamp/replies")
os.makedirs(support, exist_ok=True)
ack, answer = os.path.join(support, ident + ".ack"), os.path.join(support, ident + ".json")
max_wait = 60

query = urllib.parse.urlencode({"kind": "permission" if kind == "permission" else "reply", "id": ident, "project": project,
                                "app": app, "text": summary, "wait": max_wait}, quote_via=urllib.parse.quote)
subprocess.run(["open", "-g", "goblincamp://ask?" + query], check=False)

# 1. the game must confirm it got the question quickly, otherwise do not hold Claude Code up
deadline = time.time() + 4
while time.time() < deadline and not os.path.exists(ack):
    time.sleep(0.1)
if not os.path.exists(ack):
    sys.exit(0)
# 2. wait for the answer
deadline = time.time() + max_wait
while time.time() < deadline and not os.path.exists(answer):
    time.sleep(0.2)
try:
    reply = json.load(open(answer))
except Exception:
    reply = {}
for f in (ack, answer):
    try:
        os.remove(f)
    except OSError:
        pass

action = reply.get("action", "none")
if kind == "permission":
    if action == "allow":
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": {"behavior": "allow"}}}))
    elif action == "deny":
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "PermissionRequest",
                                                 "decision": {"behavior": "deny", "message": "使用者在哥布林泡泡上拒絕了這個操作"}}}, ensure_ascii=False))
elif action == "reply" and reply.get("text"):
    print(json.dumps({"decision": "block", "reason": "使用者從哥布林泡泡回覆：" + reply["text"]}, ensure_ascii=False))
PY
exit 0
