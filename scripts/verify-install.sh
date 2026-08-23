#!/usr/bin/env sh
#
# Prove InnerWarden is actually screening this machine.
#
# "Installed" and "protecting you" are different claims, and the gap between them
# is where an evaluation goes wrong: the binary is on PATH, every command exits 0,
# and nothing is being screened because no agent was ever wired to it.
#
# So this script does not check that files exist. It sends real commands through
# the guard and reads what comes back. Anything it cannot demonstrate, it says it
# cannot demonstrate, and prints the one command that fixes it.
#
# POSIX sh on purpose: it runs on a container, a cloud VM, a Mac laptop and a
# minimal Linux image without assuming bash.
#
# Usage:  ./scripts/verify-install.sh
# Exit:   0 = the guard is screening    1 = installed but not screening
#         2 = not installed             3 = installed but the engine is wrong

pass=0
fail=0
warn=0
ok()   { pass=$((pass+1)); printf '  PASS  %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  FAIL  %s\n' "$1"; [ -n "$2" ] && printf '        %s\n' "$2"; }
note() { warn=$((warn+1)); printf '  NOTE  %s\n' "$1"; [ -n "$2" ] && printf '        %s\n' "$2"; }

echo "== 1. is it installed =="
if ! command -v innerwarden >/dev/null 2>&1; then
  echo "  innerwarden is not on PATH." >&2
  echo "  Install it:  npm install -g innerwarden" >&2
  echo "  Then re-run this script." >&2
  exit 2
fi
ok "innerwarden $(innerwarden --version 2>/dev/null | head -1)"
printf '        at %s\n' "$(command -v innerwarden)"

# Read the decision counter BEFORE probing. The `check` calls below RECORD
# decisions, so a later "decisions exist, therefore traffic is flowing" test
# would be reading this script's own footprints. That is the trap this whole
# file exists to avoid, and the first version of it fell in.
decisions_before=$(innerwarden graph --stats 2>/dev/null \
  | sed -n 's/.*- [0-9]* session(s), \([0-9]*\) command(s).*/\1/p')
[ -n "$decisions_before" ] || decisions_before=0

echo
echo "== 2. does the engine actually judge =="
#
# Two commands, opposite verdicts. One alone proves nothing: a guard that denies
# everything is as useless as one that allows everything, and both would pass a
# single-sided check.
verdict_of() {
  innerwarden check "$1" --json 2>/dev/null \
    | tr -d ' \n' \
    | sed -n 's/.*"recommendation":"\([a-z]*\)".*/\1/p'
}

danger=$(verdict_of 'rm -rf /')
benign=$(verdict_of 'ls -la')

case "$danger" in
  deny) ok "a destructive command is DENIED (rm -rf / -> deny)" ;;
  review) note "a destructive command came back 'review', not 'deny'" \
               "Still screened, but check your suppressions: innerwarden allow --list" ;;
  "")   bad "the guard returned no verdict at all for a destructive command" \
            "The engine is not answering. Try: innerwarden check \"rm -rf /\"" ;;
  *)    bad "a destructive command came back '$danger'" \
            "Expected deny. Something is suppressing it: innerwarden allow --list" ;;
esac

case "$benign" in
  allow) ok "an ordinary command is ALLOWED (ls -la -> allow)" ;;
  "")    bad "no verdict for an ordinary command either; the engine is not answering" ;;
  *)     bad "an ordinary command came back '$benign', not allow" \
             "A guard that denies everything gets switched off within a day." ;;
esac

if [ "$fail" -gt 0 ]; then
  echo
  echo "  The engine is installed but not judging correctly. Nothing below will help"
  echo "  until that is fixed, so this stops here." >&2
  exit 3
fi

echo
echo "== 3. is any agent actually wired to it =="
#
# THE question, and the one an install can pass while failing. Everything above
# works on a machine where no agent has ever been connected, because `check` is
# you asking the engine directly. What matters is whether your agent's commands
# go through the guard on their way to the shell.
#
# Measured by asking which agents are WIRED, not by counting decisions: the
# probes above create decisions, so counting them would be this script reading
# its own footprints.
agents_out=$(innerwarden agents list 2>/dev/null)
wired=$(printf '%s' "$agents_out" | grep -c 'guarded' 2>/dev/null)
unwired=$(printf '%s' "$agents_out" | grep -c 'not guarded' 2>/dev/null)
wired=$((wired - unwired))
[ "$wired" -lt 0 ] && wired=0

if [ "$wired" -gt 0 ]; then
  ok "$wired agent(s) wired to the guard"
  printf '%s' "$agents_out" | grep 'guarded' | grep -v 'not guarded' | sed 's/^ */        /'
elif [ "$unwired" -gt 0 ]; then
  bad "$unwired agent(s) found on this machine and NONE of them are wired" \
      "The guard is installed and judging correctly, and your agent is not
        sending it anything. This is the state an evaluation mistakes for
        'it does not work'.
          innerwarden agents connect --all --monitor
        Then RESTART the agent. The hook is read at agent startup, so a session
        that was already open stays unscreened."
  printf '%s' "$agents_out" | grep 'not guarded' | sed 's/^ */        /'
else
  bad "no AI agents were found on this machine at all" \
      "Start the agent you want to protect, then re-run this script.
        If it is a cloud or headless agent, see docs/protecting-a-remote-agent.md:
        it connects over HTTP instead of a local hook."
fi

# Real traffic is what existed BEFORE this script ran.
if [ "${decisions_before:-0}" -gt 0 ]; then
  ok "$decisions_before command(s) had already been screened before this check ran"
else
  note "no commands had been screened before this check ran" \
       "Expected on a fresh install. Once an agent is wired and restarted, run
        something through it and this line becomes the proof that it is live."
fi

echo
echo "== 4. the host layer (Enterprise, Linux only) =="
#
# Absent is not a failure. The free guardrail is a complete product and most
# evaluations start there; this section reports what is present rather than
# grading a machine for not having bought anything.
if command -v innerwarden-ctl >/dev/null 2>&1; then
  ok "Enterprise host layer present: $(innerwarden-ctl --version 2>/dev/null | head -1)"
  # `systemctl is-active` PRINTS the state and RETURNS non-zero for anything that
  # is not running, so `$(... || echo missing)` captures both and prints two
  # answers on one line. Test the output, not the exit code.
  for svc in innerwarden-sensor innerwarden-agent innerwarden-watchdog; do
    state=$(systemctl is-active "$svc" 2>/dev/null)
    [ -n "$state" ] || state="not-installed"
    printf '        %-24s %s\n' "$svc" "$state"
  done
  # An inactive agent is NOT necessarily a fault. On a hardened host the watchdog
  # owns the agent's lifecycle and starts it; the unit reads inactive while the
  # process is running and supervised. Do not "fix" this with systemctl start.
  if [ "$(systemctl is-active innerwarden-watchdog 2>/dev/null)" = "active" ] \
     && [ "$(systemctl is-active innerwarden-agent 2>/dev/null)" != "active" ]; then
    note "the agent unit is inactive while the watchdog is running" \
         "That is the supervised arrangement, not a failure: the watchdog starts
        and restarts the agent. Do NOT run 'systemctl start innerwarden-agent'."
  fi
  if [ "$(id -u)" = 0 ] && [ -r /sys/kernel/security/lsm ]; then
    if grep -q bpf /sys/kernel/security/lsm 2>/dev/null; then
      ok "bpf is in this kernel's LSM stack, so the Execution Gate CAN enforce"
    else
      note "bpf is NOT in this kernel's LSM stack" \
           "Detection and response work. The kernel Execution Gate cannot enforce
        until 'lsm=...,bpf' is on the boot cmdline and the host reboots."
    fi
  else
    note "kernel LSM stack not read (needs root)" \
         "Re-run with sudo to have this checked."
  fi
else
  note "Enterprise host layer is not installed on this machine" \
       "That is fine: the free guardrail above is a complete product.
        To add it (Linux, needs the licence you were issued):
          curl -fsSL https://innerwarden.com/install | sudo bash -s -- --license=/path/to/license.key"
fi

echo
echo "== verdict =="
if [ "$fail" -gt 0 ]; then
  echo "  NOT protecting this machine yet: $pass checks passed, $fail failed."
  echo "  Each FAIL above names the command that fixes it."
  exit 1
fi
echo "  Screening confirmed: $pass checks passed${warn:+, $warn note(s)}."
echo "  Commands from a wired agent are being judged before they run."
