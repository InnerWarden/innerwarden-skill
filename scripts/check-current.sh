#!/usr/bin/env sh
#
# Is this skill behind the product?
#
# The skill quotes the current Community and Pro versions, and its ClawHub copy
# is published from clawhub/innerwarden-security/. Both go stale the moment a
# release ships or the folder changes and nobody republishes. This checks both
# and changes nothing.
#
#   1. The versions SKILL.md cites against the latest FINAL releases in
#      InnerWarden/innerwarden-releases (guard-v* is Community, v* is Pro;
#      prereleases do not count).
#   2. The newest commit touching clawhub/ against the newest version on
#      ClawHub (needs npx; skipped, not failed, without it).
#
# It reads versions only. Whether every command in the docs still matches the
# new release is a separate check: run the binaries' --help (MAINTAINING.md).
#
# Usage:  sh scripts/check-current.sh
# Exit:   0 current, 1 behind (it says what to update), 2 could not check

cd "$(dirname "$0")/.." || exit 2
command -v python3 >/dev/null 2>&1 || { echo "needs python3" >&2; exit 2; }

python3 - <<'PY'
import json, re, subprocess, sys, urllib.request, datetime

def die(msg, code=2):
    print(msg, file=sys.stderr)
    sys.exit(code)

text = open("SKILL.md", encoding="utf-8").read()
m = re.search(r"Community is (\d+\.\d+\.\d+) and Pro\s+is (\d+\.\d+\.\d+)", text)
if not m:
    die("SKILL.md no longer says 'Community is X and Pro is Y'; update this check with it")
cited_c, cited_p = m.group(1), m.group(2)

try:
    req = urllib.request.Request(
        "https://api.github.com/repos/InnerWarden/innerwarden-releases/releases?per_page=100",
        headers={"Accept": "application/vnd.github+json", "User-Agent": "innerwarden-skill-check"})
    releases = json.load(urllib.request.urlopen(req, timeout=30))
except Exception as e:
    die(f"could not read the release list: {e}")

def ver(s):
    return tuple(int(x) for x in s.split("."))

final = [r["tag_name"] for r in releases if not r.get("prerelease") and not r.get("draft")]
community = sorted((t[len("guard-v"):] for t in final if re.fullmatch(r"guard-v\d+\.\d+\.\d+", t)), key=ver)
pro = sorted((t[1:] for t in final if re.fullmatch(r"v\d+\.\d+\.\d+", t)), key=ver)
if not community or not pro:
    die("the release list has no final guard-v* or v* tag; read it by hand")
latest_c, latest_p = community[-1], pro[-1]

behind = []
print(f"Community: skill cites {cited_c}, latest final {latest_c}")
print(f"Pro:       skill cites {cited_p}, latest final {latest_p}")
if ver(cited_c) < ver(latest_c):
    behind.append(f"Community {latest_c} is out: check every Community command in the skill against its --help, then update the version line in SKILL.md")
if ver(cited_p) < ver(latest_p):
    behind.append(f"Pro {latest_p} is out: check the installer and every innerwarden-ctl / innerwarden-config-sign command against its --help, then update SKILL.md")

try:
    last = subprocess.run(["git", "log", "-1", "--format=%ct", "--", "clawhub/"],
                          capture_output=True, text=True, check=True).stdout.strip()
    folder_changed = int(last) if last else 0
except Exception:
    folder_changed = 0
try:
    out = subprocess.run(["npx", "-y", "clawhub@0.23.3", "inspect", "innerwarden-security", "--json"],
                         capture_output=True, text=True, timeout=120).stdout
    lv = json.loads(out)["latestVersion"]
    published = int(lv["createdAt"]) // 1000
    when = datetime.datetime.fromtimestamp(published, datetime.timezone.utc).strftime("%Y-%m-%d")
    print(f"ClawHub:   innerwarden-security {lv['version']} published {when}")
    if folder_changed > published:
        behind.append("clawhub/ changed after the last ClawHub version went public: republish it "
                      "(or a new version is still in ClawHub's security scan; check again later)")
except Exception as e:
    print(f"ClawHub:   not checked ({e.__class__.__name__}); run: npx clawhub@0.23.3 inspect innerwarden-security")

if behind:
    print()
    for b in behind:
        print(f"  BEHIND  {b}")
    sys.exit(1)
print("\n  current")
PY
