#!/bin/sh
# The lead install command in every document here must be one that works on a
# machine straight out of the box.
#
# WHY THIS FILE EXISTS. Every document in this repository used to open with
#
#   npm install -g innerwarden
#
# and `npm install -g` writes to npm's global prefix. On any distro-packaged Node
# that prefix is /usr/local/lib/node_modules and it is owned by root, so the
# command exits EACCES before InnerWarden is involved at all. Measured on a clean
# Ubuntu 26.04 host: the first command a new user ran failed. The docs had even
# described the failure further down the page, and one of them asserted the
# opposite in the lead sentence ("needs no sudo or root"). Being right in a
# footnote does not help someone who stopped reading at the first code block.
#
# So the rule this file enforces is about ORDER, not about banning npm. npm is a
# supported channel and carries provenance. It just must not be the first thing
# offered on a page, because the first thing offered is the only thing most
# readers run.
#
# FAILS ON REVERT: move `npm install -g innerwarden` above the shell installer in
# any file below, or drop the EACCES warning, and this exits 1.

set -eu
cd "$(dirname "$0")/../.."

fail=0
bad() { printf '  FAIL  %s\n' "$1" >&2; fail=1; }
ok()  { printf '  ok    %s\n' "$1"; }

# First line matching a pattern, or empty if absent. Deliberately not `grep -m1`:
# BusyBox grep does not take -m, and this script is meant to run wherever the
# product does.
first_line() {
  grep -n -- "$2" "$1" 2>/dev/null | head -1 | cut -d: -f1
}

echo "== the install command offered first must not need root =="

for f in SKILL.md README.md AGENTS.md; do
  [ -f "$f" ] || { bad "$f is missing"; continue; }

  curl_at=$(first_line "$f" 'innerwarden\.com/free')
  npm_at=$(first_line "$f" 'npm install -g innerwarden')

  if [ -z "$npm_at" ]; then
    # No npm at all is fine: nothing can lead with the failing command.
    [ -n "$curl_at" ] || bad "$f offers no install command at all"
    [ -n "$curl_at" ] && ok "$f leads with the shell installer (npm not mentioned)"
    continue
  fi

  if [ -z "$curl_at" ]; then
    bad "$f offers 'npm install -g' (line $npm_at) and never mentions innerwarden.com/free.
        On Linux that is the only command it gives, and it fails with EACCES."
    continue
  fi

  if [ "$curl_at" -lt "$npm_at" ]; then
    ok "$f leads with the shell installer (line $curl_at, before npm at $npm_at)"
  else
    bad "$f leads with 'npm install -g innerwarden' (line $npm_at), before the
        shell installer (line $curl_at). npm's prefix is root-owned on a
        distro-packaged Node, so that is a first command that exits EACCES."
  fi

  # Offering npm is fine. Offering it without saying it needs root on Linux is
  # what sent a real user into an error, so the warning has to travel with it.
  if grep -q 'EACCES' "$f"; then
    ok "$f warns about EACCES where it mentions npm"
  else
    bad "$f mentions 'npm install -g' but never the word EACCES.
        A reader hits the error with no idea it is expected or how to pass it."
  fi
done

echo "== the verify script's own remediation must be runnable =="

v=scripts/verify-install.sh
if [ ! -f "$v" ]; then
  bad "$v is missing"
else
  # It tells the user how to install when nothing is found. That instruction is
  # read at the exact moment someone has nothing working, which is the worst
  # possible moment to hand out a command that fails.
  if grep -q 'Install it:.*npm install -g' "$v"; then
    bad "$v tells an uninstalled user to run 'npm install -g', which exits EACCES on Linux"
  else
    ok "$v does not send an uninstalled user to a command that needs root"
  fi

  if grep -q 'Install it:.*innerwarden\.com/free' "$v"; then
    ok "$v points at the shell installer"
  else
    bad "$v does not offer the shell installer as the way to install"
  fi
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "install-lead-works-without-root: PASS"
else
  echo "install-lead-works-without-root: FAILED" >&2
fi
exit "$fail"
