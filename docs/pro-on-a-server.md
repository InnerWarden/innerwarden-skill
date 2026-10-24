# Installing InnerWarden Pro on someone's server, and getting them the dashboard

For an agent running on the operator's own machine, reaching a Linux server over
SSH. This is the normal shape: the operator sits at a laptop, the server is
somewhere else, and the dashboard has to end up in the operator's browser
without being exposed to the internet.

Read all of it before running anything. Two steps here are irreversible from the
operator's side if you get them wrong, and one of them can lock their terminal.

InnerWarden Pro is the paid plan. Its software is released under the name
InnerWarden Active Defence, which is what the release pages and some file names
say; it is the same thing. Once it is installed, day-to-day running is in
[`managing-pro.md`](managing-pro.md).

---

## Every command below assumes this

Every `ssh` line in this document is written as `$SSH '...'`, because writing
them as `ssh <user>@<host>` invites dropping the `-i <key>` and failing on any
host that is not in `~/.ssh/config`. Agent shells often do not keep variables
between commands, so either write `ssh -i <key> <user>@<host>` in full in every
command, or start each one with the assignment:

```sh
SSH="ssh -i <key> <user>@<host>"; $SSH 'echo ok'
```

## Before you run a single command, ASK

Do not guess any of these. Ask for each one at the moment you need it, in plain
language, and wait for the answer: operators expect to be walked through this,
not handed a form. But do not begin at all until you have items 1 and 2, because
without them there is nothing to install and nowhere to install it.

Never ask for a password, a private key's contents, or an API key. If a step
needs one, hand the operator the command and let them run it.

1. **The server.** Address or hostname, the SSH user, and the private key path if
   it is not their default. You need to be able to run
   `$SSH 'echo ok'` and see `ok`.
2. **The licence file.** Pro is paid; buying it at
   <https://innerwarden.com/pricing> emails the licence as an attachment named
   `license.txt`, and it can be downloaded again from
   <https://innerwarden.com/account>. Without a licence the same installer puts
   only the free host tier on the machine, which is not what was asked for: stop
   and say so. Ask where the file is **on the operator's machine**. It is JSON
   (older ones are named `license.key`) and contains `customer_id`, `host`,
   `features`, `valid_until` and `signature`. If they paste the JSON into the
   chat instead, write it to a file yourself.
3. **Whether `sudo` needs a password on that server.** This decides whether the
   install can run unattended at all. Check it rather than asking them to guess:

   ```sh
   $SSH 'sudo -n true 2>&1 || echo NEEDS_PASSWORD'
   ```

   If it prints `NEEDS_PASSWORD`, **stop**. You cannot type a sudo password into
   a non-interactive SSH session, and you must not ask the operator to paste
   their password to you. Tell them to log in themselves
   (`ssh -i <key> <user>@<host>`) and run, at the server's prompt:
   `curl -fsSL https://innerwarden.com/install | sudo bash -s -- --license=/tmp/license.key`.
   sudo asks them for the password there. The installer may then open its setup
   wizard in their terminal; they can answer it or skip it, and if the terminal
   stops answering, ENTER then `~` then `.` gets them out.
4. **Whether the machine can reboot today.** On a Debian or Ubuntu server without
   `bpf` in the boot LSM stack, the installer edits the bootloader and prints
   REBOOT REQUIRED. It never reboots by itself, and no kernel control can enforce
   until it does. Say this BEFORE installing, not after. Step 1 tells you whether
   it applies.

---

## 1. Preflight: read the machine before changing it

One command answers most of what you would otherwise have to ask:

```sh
$SSH 'uname -m; uname -r; . /etc/os-release && echo "$PRETTY_NAME"
      grep -o bpf /sys/kernel/security/lsm || echo NO-BPF
      df -h / | awk "NR==2{print \$4\" free\"}"
      sudo -n true 2>/dev/null && echo "SUDO-OK" || echo "SUDO-NEEDS-PASSWORD"
      cat /etc/machine-id 2>/dev/null || echo "no machine-id"'
```

Read every line of the answer before continuing:

- **Architecture must be x86_64 or aarch64.** Anything else, stop and say so.
- **`NO-BPF`** means the installer will edit the bootloader and the machine needs
  a reboot before any kernel control can enforce. Detection and response work
  without it. Tell the operator BEFORE installing and get their agreement, and
  see "Where the reboot goes" below.
- **`SUDO-NEEDS-PASSWORD`**: stop. You cannot type a sudo password into a
  non-interactive SSH session, `-t` is forbidden here (step 3), and you must
  never ask the operator to give you their password. Hand them the login and
  the command from item 3 above, to run at the server's own prompt.
- **Under ~2 GB free** is tight: the installer downloads an on-device model of
  about 87 MB plus the binaries.
- **The machine-id** matters only if the licence is host-bound. Keep it; step 2
  compares against it.

### Where the reboot goes

If preflight said `NO-BPF`, the sequence is: install (step 3) → verify services
and licence (step 4) → tell the operator a reboot is required and why → they
reboot → **re-run step 4** → dashboard (step 6). Do not arm anything before the
reboot and do not describe kernel enforcement as available until after it. The
installer never reboots by itself and neither should you.

## 2. Get the licence, and check it before you trust it

Ask the operator for the licence now if you do not already have it. It comes in
one of three shapes and all three are normal:

- **a file on their machine**, usually `license.txt` from the purchase email;
- **JSON pasted into the chat**, in which case write it to a file yourself;
- **a download link**, in which case fetch it first: `curl -fsSL <url> -o /tmp/license.key`.
  The installer takes a local file only.

A valid licence is JSON with exactly these fields:

```json
{
  "customer_id": "...",
  "host": "*",
  "features": ["all"],
  "valid_from": "2026-08-24T16:37:00Z",
  "valid_until": "2026-11-22T16:37:00Z",
  "signature": "<128 hex characters>"
}
```

Check it BEFORE installing. A bad licence fails deep inside the installer with a
message that sends people looking in the wrong place:

Write this to a file and run it; do not try to inline it with `python3 -c`,
because the quoting fights the shell and the f-strings need names rather than
nested subscripts:

```sh
cat > /tmp/lic-check.py <<'PY'
import json, sys, datetime
d = json.load(open(sys.argv[1]))
for k in ("customer_id", "host", "features", "valid_until", "signature"):
    assert k in d, f"missing field: {k}"
assert len(d["signature"]) == 128, "signature is not 128 hex chars - file may be truncated"
left = (datetime.datetime.fromisoformat(d["valid_until"].replace("Z", "+00:00"))
        - datetime.datetime.now(datetime.timezone.utc)).days
assert left > 0, f"licence EXPIRED {abs(left)} days ago"
cid, hst = d["customer_id"], d["host"]
print(f"ok: {cid}, host {hst}, {left} days left")
PY
python3 /tmp/lic-check.py /tmp/license.key
```

Expected: `ok: <customer>, host *, <N> days left`. Anything else, stop and read
the message to the operator: a truncated signature and an expired licence are
both things only they can fix, and both fail confusingly later.

`"host": "*"` is a site licence and runs anywhere. **Any other value binds the
licence to one machine**, and it is compared against that host's
`/etc/machine-id`. You read the machine-id in preflight, so compare them
yourself now rather than discovering the mismatch when the installer refuses:

```sh
# only when host is not "*"
$SSH 'cat /etc/machine-id'      # must equal the licence's "host" value
```

If they differ, stop: the operator has been given a licence for a different
machine and only they can resolve it. (`innerwarden-config-sign machine-id`
prints the id to send to whoever issued it, once the host is installed.)

Then copy it over, lock it down, and confirm it survived the trip:

```sh
scp -i <key> <local-licence-path> <user>@<host>:/tmp/license.key
$SSH 'chmod 600 /tmp/license.key; head -c 40 /tmp/license.key; echo'
```

`chmod 600` because `/tmp` is world-readable and a licence is a credential. The
`head` is not decoration: a licence downloaded from behind a login arrives as an
HTML page, and you want to see `{"customer_id"` now rather than a confusing
failure in three minutes.

The check above runs on your own machine, so a server without `python3` is no
obstacle. Never skip it.

Delete the scratch files once step 4 confirms the licence was accepted, on your
machine and on the server:

```sh
rm -f /tmp/lic-check.py /tmp/license.key
$SSH 'rm -f /tmp/license.key'
```

The installer copies the licence to `/etc/innerwarden/license.key`, so the one in
`/tmp` is a leftover with no further use.

## 3. Install, WITHOUT a terminal

```sh
$SSH 'curl -fsSL https://innerwarden.com/install | sudo bash -s -- --license=/tmp/license.key'
```

Two things about this command are load-bearing.

**The `=` is required.** `--license /tmp/license.key` with a space is rejected on
purpose, so a mistyped flag cannot quietly leave the host on the free tier.

**Never add `-t` to that ssh.** This is the one that bites. The installer
finishes and then may launch its interactive setup wizard. Run through `sudo`
on a host whose sudo has `Defaults use_pty`, that wizard can render on a pty
`sudo` created while the operator types into a different one: arrow keys print
as `^[[B`, ENTER does nothing, and **Ctrl+C does not work**. The session is
wedged and the only way out is the SSH escape (`ENTER ~ .`) or killing the
process from a second connection. Recent installers skip the wizard by
themselves when they can see this coming, but not in every shape of
`curl | sudo bash` with a terminal attached, so do not give them one.

Without a terminal the installer prints
`No usable TTY (headless/piped install) - skipping interactive setup.` and
`Run 'sudo innerwarden-ctl setup' later ...`. That is the outcome you want. The wizard is the optional
last step; everything that matters is already configured by the time it would
have run, and step 6 does the same job with explicit commands.

If the operator ever reports a frozen terminal after an install, that is this
bug. Tell them: press ENTER, then `~`, then `.`

## 4. Verify the install rather than assuming it

The installer prints a success banner. Confirm the machine agrees:

```sh
$SSH 'for u in innerwarden-sensor innerwarden-watchdog innerwarden-dns-guard; do printf "%-26s %s\n" "$u" "$(systemctl is-active $u 2>&1)"; done'
$SSH 'innerwarden-ctl --version'
```

Expect `active` for all three.

**`innerwarden-agent` reading `inactive` is CORRECT on a paid install** and is
not a failure to report. The watchdog owns the agent's lifecycle and spawns it.
Never run `systemctl start innerwarden-agent` on such a host; you will fight the
supervisor. Say this to the operator, because checking that unit is the obvious
thing to do and it looks like a fault.

Now confirm the licence was accepted:

```sh
$SSH 'sudo innerwarden-ctl arm --check'
```

Look for a line reading `licence   present, N feature(s) granted`. `arm --check`
surveys only and changes nothing, which also makes it the best thing to show an
operator who wants to see what the paid tier knows about their host.

For the licence on its own, in detail, the verb is on the **other** binary:

```sh
$SSH 'sudo innerwarden-config-sign license status'
$SSH 'sudo innerwarden-config-sign license status --json'   # for you to parse
```

It reports the customer, whether the host binding matches this machine's
machine-id, the expiry, each feature as ok or FAIL, and an overall verdict. It
reports an expired or wrong-host licence in words rather than failing silently,
and exits 1 whenever the licence is not usable, so a script can test it.

**`innerwarden-ctl license` does NOT exist** and answers `error: unrecognized
subcommand 'license'`. The licence verbs live on `innerwarden-config-sign`.
Two binaries, and the obvious guess is the wrong one.

Read `arm --check`'s "Fixing first" section back to the operator. On a fresh install it
usually reports that `agent.toml` does not declare a dashboard bind, which is
step 5.

## 5. Read `arm --check`, but do not get stuck on it

A fresh install usually reports, under "Fixing first", this line:

```
- repair dashboard-bind: agent.toml does not declare [dashboard] bind, so
  innerwarden-ctl assumes a default port and cannot reach the dashboard it is
  talking about
```

**That specific line has been a cosmetic warning, not a blocker:** on a clean
Ubuntu 26.04 host with it present, the dashboard still served correctly and
answered 401/200 as designed. Mention it to the operator as a known gap and
carry on, once step 6b passes. Do not go hunting for a repair command for it.

**Anything else under "Fixing first" is NOT covered by that exemption.** Match
the text: if the line is about `dashboard-bind`, proceed; if it is about
anything else, stop, read it to the operator, and do not continue until you both
understand it. "The doc said warnings are fine" is not a reason to walk past a
message you have not read.

## 6. Bring up the dashboard

Until a login exists the dashboard answers **503** to everyone, by design.
Create it:

```sh
$SSH 'sudo innerwarden-ctl dashboard login'
```

(Or, so the password never crosses your session, the operator runs it with
`--password-file PATH`: it writes the new password to a new file readable only
by root, which must not exist yet; they read it, keep it safe, and delete the
file.) Otherwise it prints a username and a generated password, **once**:

```
[ok] dashboard login created. SAVE THIS, it is shown once:
       username: admin
       password: <generated>
```

Give those to the operator directly and tell them it is shown once. Do not paste
them into a shared or logged channel. It also restarts the watchdog to apply the
change, which is expected.

```sh
$SSH 'sudo innerwarden-ctl dashboard'
```

**This is a status command. It prints and exits; it does not serve anything and
it will not hang your session.** The dashboard itself is served by the installed
stack and is already listening before you run this, so it survives your SSH
connection closing. Do NOT background it, do not wrap it in `nohup` or
`systemd-run`, and do not leave an SSH session open "to keep it alive". (The
FREE CLI's `innerwarden dashboard` is the opposite: that one IS a foreground
server and does not return. Two different commands, one word apart.)

It prints the bind, the exposure and the tunnel. Four things about it that will
otherwise cost you the demo, all confirmed on a real host:

- **It is HTTPS, not HTTP.** `http://` gets you a connection failure that looks
  like nothing is listening. The certificate is self-signed, so a browser shows
  a warning the operator must click through, and `curl` needs `-k`.
- **The paid dashboard is port 8787.** The FREE CLI's dashboard is 8788. They are
  different servers on the same machine and the installer puts the free CLI there
  too, so both can be up at once.
- **`dashboard` exists in both tiers.** `innerwarden dashboard` is the FREE one;
  the paid one is `innerwarden-ctl dashboard` (or `innerwarden host dashboard`).
  Name the right binary or the operator opens the wrong dashboard and reports the
  paid features missing.
- **Check the tunnel line it prints before passing it on.** Recent versions
  print the sudo user and a reachable address, or `<address-you-ssh-to>` when
  they cannot tell. Make sure it names the user, host and key the operator
  really uses (`sudo innerwarden-ctl dashboard tunnel` prints just that line).

Prove it serves before you say it is ready:

```sh
$SSH 'curl -sk -o /dev/null -w "%{http_code}\n" https://127.0.0.1:8787/'
```

Expect **401**. The 401 is the point: the dashboard is fail-closed and refuses
anyone without the login. A **503** means no login exists yet (go back one
step). If it returns 200, stop and tell the operator, because the login did not
take. The logged-in half (a 200 with the password) is the operator's to see,
through the tunnel in step 7: do not put the password on a command line, where
it lands in the server's process list and in your transcript.

## 6b. One command that either passes or does not

The agent path has `verify-install.sh` and exits 0 or it does not. The server
path needs the same bar, because "read the output back to them" is exactly the
softer standard that lets a broken install be reported as done. Run this and
require `ALL CHECKS PASSED`:

```sh
$SSH 'bash -s' <<'EOF'
fail=0
chk() { printf "  %-34s %s\n" "$1" "$2"; [ "$2" = "$3" ] || { echo "        expected: $3"; fail=1; }; }

for u in innerwarden-sensor innerwarden-watchdog innerwarden-dns-guard; do
  chk "$u" "$(systemctl is-active $u 2>&1)" "active"
done
# innerwarden-agent is deliberately NOT checked: the watchdog owns its
# lifecycle and the unit reads 'inactive' on a correct paid install.

chk "licence present" \
    "$(sudo innerwarden-ctl arm --check 2>/dev/null | grep -qiE 'licence +present|license +present' && echo yes || echo no)" \
    "yes"
# Present is not usable: an expired or wrong-host licence keeps the host in
# free mode. `license status` exits 1 in exactly that case.
chk "licence usable" \
    "$(sudo innerwarden-config-sign license status >/dev/null 2>&1 && echo yes || echo no)" \
    "yes"

chk "dashboard refuses without login" \
    "$(curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1:8787/)" "401"

echo
[ "$fail" -eq 0 ] && echo "  ALL CHECKS PASSED" || echo "  FAILED - do not report success"
exit "$fail"
EOF
```

The 401 is a real check, not a formality: it proves the dashboard is up AND that
it is fail-closed. A 503 means no login was created yet. A 200 means the login
did not take and the dashboard is open to anyone who reaches the port. A `000`
means you used `http://` instead of `https://`, or nothing is listening.

The logged-in check is the operator opening the dashboard through the tunnel
in step 7 and signing in.

## 7. Give the operator the tunnel, and say where to run it

The dashboard binds loopback only. The operator reaches it through an SSH tunnel
**from their own machine**, with the real user and key filled in:

```sh
ssh -N -L 8787:127.0.0.1:8787 -i <key> <user>@<host>
```

Then they open **`https://127.0.0.1:8787`** and accept the self-signed
certificate warning, and log in with the username and password from step 6.

Say explicitly: **run this on your laptop, in a new terminal, not on the
server.** Operators paste it into the server's own shell and get
`Permission denied (publickey)`, because the server is then trying to SSH to
itself with a key it does not have. This happens often enough to be worth
saying before they do it. The terminal stays blank with no prompt while the
tunnel is up; that is what success looks like, not a hang.

`innerwarden-ctl dashboard open` exposes it on the network behind the password
and a firewall rule. Do not reach for it during an evaluation: the tunnel costs
one command and exposes nothing.

## 8. Do not arm the kernel controls while INSTALLING

> If the person's job is to EVALUATE the product rather than receive it, they do
> need to prove these controls, and there is a safe sequence for that in
> [`evaluating-a-pilot.md`](evaluating-a-pilot.md). The invariants below hold
> either way: agent-scoped, never host-wide, never a blind flip.


`innerwarden-ctl arm --check` surveys and is safe to show. `innerwarden-ctl arm`
changes the machine.

Arming is deliberate, agent-scoped, and belongs after the operator has watched a
week of real decisions. A host-wide execution-gate arm has bricked a machine at
boot; `arm` refuses that shape rather than offering it, and you should not go
looking for a way around the refusal. If the operator asks for it anyway, point
them at `innerwarden-ctl arm --check` first and let it explain what this host can
and cannot enforce, and why.

Safety valves, for the person to run, any time; none of them needs a licence:

```sh
sudo innerwarden-ctl exec-gate disarm                      # the process-scoped Execution Gate
sudo innerwarden-ctl agent kernel disarm                   # every per-agent kernel control
sudo innerwarden-config-sign secret-guard disarm --apply   # Secret Read Guard
sudo innerwarden-config-sign userns-guard disarm --apply   # userns guard (arm puts it in deny)
sudo innerwarden-config-sign dns-guard disarm              # DNS Guard
```

---

## Removing it

An evaluation has an end date, so know this before it starts. Order matters:
disarming comes first, because removing the binaries while a kernel control is
armed leaves the machine enforcing a policy nothing can change.

Removal lowers the guard, so the operator runs these (over the same SSH, or in
their own terminal on the server); give them the list:

```sh
sudo innerwarden-ctl exec-gate disarm                # first, always
sudo innerwarden-ctl agent kernel disarm
sudo innerwarden-config-sign secret-guard disarm --apply
sudo innerwarden-config-sign userns-guard disarm --apply
sudo innerwarden-config-sign dns-guard disarm
innerwarden agents disconnect --all                  # as the user, while the binary exists
sudo innerwarden-ctl uninstall --purge --yes         # --dry-run first shows what goes
innerwarden uninstall                                # the free CLI, as the user who has it
rm -rf ~/.config/innerwarden
sudo systemctl daemon-reload
hash -r
```

`--purge` also removes the boot change, the units' drop-ins, the audit rules,
the group and the firewall rules InnerWarden tagged. Without `--purge`, config
and data stay in `/etc/innerwarden` and `/var/lib/innerwarden`.

## What to tell the operator when you are done

- Which services are running, and that `innerwarden-agent` reading `inactive` is
  the correct production pattern rather than a fault.
- That the licence was accepted, quoting the `feature(s) granted` line.
- The dashboard URL, the tunnel command, and that the tunnel runs on THEIR
  machine.
- That nothing is being blocked: the host stack installs observing, the DNS
  Guard starts in observe (listening on `127.0.0.1:53`), and the agent hook the
  installer added is in monitor.
- That arming the kernel controls is a separate, deliberate decision they have
  not yet made.

## Known rough edges, so they do not surprise you

- **The interactive installer wizard can wedge the terminal under `sudo`.**
  Covered in step 3. Never allocate a tty for the install.
- **The AI provider is asked for twice.** The free CLI stores its second-opinion
  model in `~/.config/innerwarden/llm.toml`; the paid agent has its own `[ai]`
  block in `/etc/innerwarden/agent.toml`. Neither mentions the other. The paid
  side does not need it: the installer provisions an on-device model
  (`[ai.warden] enabled = true`, `provider = "local_warden"`) and leaves the
  external `[ai]` disabled. Tell the operator the external provider is an
  optional upgrade, not a missing step.
- **The licence verbs are on `innerwarden-config-sign`, not `innerwarden-ctl`.**
  `innerwarden-ctl license` answers `unrecognized subcommand`;
  `innerwarden-config-sign license status` is the one that reports customer,
  host binding, expiry and per-feature state. See step 4.
