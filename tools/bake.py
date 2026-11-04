#!/usr/bin/env python3
# Bakes your latest in-game settings into the addon. Each game saves, at logout or /reload, the
# export string of every profile and when its settings last changed (ns.bakeMark). This takes
# the one changed last; when that is newer than the last bake (tools/baked-at), it becomes
# DEFAULT_PROFILE, the tests run, and it is committed and pushed. Run by hand (--force: bake the
# newest even if nothing changed) or by the launchd watcher, tools/wolfpack-bake.plist.
import glob, os, re, subprocess, sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WOW = "/Users/severin/Games/World of Warcraft"
ADDON, STAMP = "WolfpackAddon/WolfpackAddon.lua", "tools/baked-at"

def run(*cmd):
    return subprocess.run(cmd, cwd=REPO, capture_output=True, text=True)

def say(msg):
    print(msg)
    run("osascript", "-e", f'display notification "{msg}" with title "Wolfpack bake"')

best = None # (changed at, file time, string, game)
for f in glob.glob(f"{WOW}/*/WTF/Account/*/SavedVariables/WolfpackAddon.lua"):
    m = re.search(r'\["bake"\]\s*=\s*\{([^{}]*)\}', open(f, encoding="utf-8", errors="replace").read())
    at = m and re.search(r'\["at"\]\s*=\s*(\d+)', m.group(1))
    text = m and re.search(r'\["text"\]\s*=\s*"(WPA1:[A-Za-z0-9+/=]+)"', m.group(1))
    if at and text:
        key = (int(at.group(1)), os.path.getmtime(f), text.group(1), f[len(WOW) + 1:].split("/")[0].strip("_"))
        best = max(best, key) if best else key

stamp = os.path.join(REPO, STAMP)
last = int(open(stamp).read().strip() or 0) if os.path.exists(stamp) else 0
if not best or (best[0] <= last and "--force" not in sys.argv):
    print("nothing new to bake")
    sys.exit(0)
at, _, text, game = best

if run("git", "status", "--porcelain", ADDON, STAMP).stdout.strip():
    say(f"Skipped: {ADDON} has unsaved changes")
    sys.exit(1)
if run("git", "pull", "--rebase", "--autostash").returncode:
    say("Skipped: git pull failed")
    sys.exit(1)

path = os.path.join(REPO, ADDON)
src = open(path, encoding="utf-8").read()
new = re.sub(r'^local DEFAULT_PROFILE = "[^"\n]*"$', lambda _: f'local DEFAULT_PROFILE = "{text}"', src, count=1, flags=re.M)
open(path, "w", encoding="utf-8").write(new)
open(stamp, "w").write(f"{at}\n")

for test in ("test/smoke.lua", "test/barstack.lua"):
    t = run("luajit", test)
    if t.returncode:
        run("git", "checkout", "--", ADDON)
        open(stamp, "w").write(f"{last}\n")
        say(f"Not baked: {test} fails with these settings")
        print(t.stdout[-2000:], t.stderr[-2000:])
        sys.exit(1)

run("git", "add", ADDON, STAMP)
if run("git", "commit", "-m", f"chore: bake in-game settings from {game}", "--", ADDON, STAMP).returncode:
    print("nothing changed")
    sys.exit(0)
push = run("git", "push")
say(f"Baked settings from {game}" + ("" if push.returncode == 0 else ": committed, push failed"))
