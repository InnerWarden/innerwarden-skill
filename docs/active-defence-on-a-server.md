# Installing Active Defence on someone's server, and getting them the dashboard

For an agent running on the operator's own machine, reaching a Linux server over
SSH. This is the normal shape: the operator sits at a laptop, the server is
somewhere else, and the dashboard has to end up in the operator's browser
without being exposed to the internet.

Read all of it before running anything. Two steps here are irreversible from the
operator's side if you get them wrong, and one of them can lock their terminal.

---

## Every command below assumes this

Set it once, from what the operator gives you in item 1, and use `$SSH`
throughout. Every `ssh` line in this document is written that way, because
writing them as `ssh <user>@<host>` invites dropping the `-i <key>` and failing
on any host that is not in `~/.ssh/config`.

```sh
SSH="ssh -i <key> <user>@<host>"
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
2. **The licence file.** Active Defence is licensed; without a licence file this
   install does not happen and you should stop and say so. Ask where the file is
   **on the operator's machine**. It is JSON, usually called `license.key`, and
   it contains `customer_id`, `host`, `features`, `valid_until` and `signature`.
   If they paste the JSON into the chat instead, write it to a file yourself.
3. **Whether `sudo` needs a password on that server.** This decides whether the
   install can run unattended at all. Check it rather than asking them to guess:

   ```sh
   $SSH 'sudo -n true 2>&1 || echo NEEDS_PASSWORD'
   ```

   If it prints `NEEDS_PASSWORD`, **stop**. You cannot type a sudo password into
   a non-interactive SSH session, and you must not ask the operator to paste
   their password to you. Tell them to run the install command themselves in
   their own terminal, or to add a NOPASSWD rule for the install, and hand them
   the exact command from step 3 below.
4. **Whether the machine can reboot today.** On a Debian or Ubuntu server without
   `bpf` in the boot LSM stack, the installer edits the bootloader and prints
   REBOOT REQUIRED. It never reboots by itself, and no kernel control can enforce
   until it does. Say this BEFORE installing, not after. Step 2 tells you whether
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
  never ask the operator to give you their password. Hand them the command from
  step 3 to run in their own terminal, or ask them to add a NOPASSWD rule.
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

- **a file on their machine**, usually `license.key`;
- **JSON pasted into the chat**, in which case write it to a file yourself;
- **a download link**, in which case fetch it: `curl -fsSL <url> -o /tmp/license.key`.

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
machine and only they can resolve it.

Then copy it over, lock it down, and confirm it survived the trip:

```sh
scp -i <key> <local-licence-path> <user>@<host>:/tmp/license.key
$SSH 'chmod 600 /tmp/license.key; head -c 40 /tmp/license.key; echo'
```

`chmod 600` because `/tmp` is world-readable and a licence is a credential. The
`head` is not decoration: a licence downloaded from behind a login arrives as an
HTML page, and you want to see `{"customer_id"` now rather than a confusing
failure in three minutes.

**If `python3` is missing** (common on minimal cloud images), do the validation
on your own machine before the `scp` instead. Never skip it.

Delete both scratch files once step 4 confirms the licence was accepted:

```sh
$SSH 'rm -f /tmp/license.key /tmp/lic-check.py'
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
finishes and then tries to launch its interactive setup wizard. With a terminal
present it runs that wizard through `sudo`, and modern sudo ships
`Defaults use_pty`, so the wizard renders on a pty that `sudo` created while the
operator types into a different one. Arrow keys print as `^[[B`, ENTER does
nothing, and **Ctrl+C does not work**: the session is wedged and the only way out
is the SSH escape (`ENTER ~ .`) or killing the process from a second connection.

Without a terminal the installer detects there is no usable tty, **skips the
wizard**, and says so. That is the outcome you want. The wizard is the optional
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

Look for a line reading `licence   present, N feature(s) granted`. **There is no
`innerwarden-ctl license status` subcommand**; `arm --check` is where licence
state is reported. `arm --check` surveys only and changes nothing, which also
makes it the best thing to show an operator who wants to see what the paid tier
knows about their host.

Read its "Fixing first" section back to the operator. On a fresh install it
usually reports that `agent.toml` does not declare a dashboard bind, which is
step 5.

## 5. Read `arm --check`, but do not get stuck on it

A fresh install reports, under "Fixing first", **exactly this and only this**:

```
- repair dashboard-bind: agent.toml does not declare [dashboard] bind, so
  innerwarden-ctl assumes a default port and cannot reach the dashboard it is
  talking about
```

**That specific line is a cosmetic warning, not a blocker.** Verified on a clean
Ubuntu 26.04 host: with it present, the dashboard still served correctly and
answered 401/200 as designed. Mention it to the operator as a known gap and
carry on. Do not go hunting for a repair command for it.

**Anything else under "Fixing first" is NOT covered by that exemption.** Match
the text: if the line is about `dashboard-bind`, proceed; if it is about
anything else, stop, read it to the operator, and do not continue until you both
understand it. "The doc said warnings are fine" is not a reason to walk past a
message you have not read.

## 6. Bring up the dashboard

```sh
$SSH 'sudo innerwarden-ctl dashboard login'
```

It prints a username and a generated password, **once**:

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
- **The tunnel line it prints contains `root@YOUR_SERVER`.** That is a
  placeholder AND the wrong user for most hosts. Never pass it through verbatim;
  substitute the real user, host and key yourself.

Prove it serves before you say it is ready:

```sh
$SSH 'curl -sk -o /dev/null -w "%{http_code}\n" https://127.0.0.1:8787/'
$SSH 'curl -sk -o /dev/null -w "%{http_code}\n" -u admin:<password> https://127.0.0.1:8787/'
```

Expect **401** then **200**. The 401 is the point: the dashboard is fail-closed
and refuses anyone without the login. If the first returns 200, stop and tell the
operator, because the login did not take.

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

chk "licence accepted" \
    "$(sudo innerwarden-ctl arm --check 2>/dev/null | grep -qiE 'licence +present|license +present' && echo yes || echo no)" \
    "yes"

chk "dashboard refuses without login" \
    "$(curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1:8787/)" "401"

echo
[ "$fail" -eq 0 ] && echo "  ALL CHECKS PASSED" || echo "  FAILED - do not report success"
exit "$fail"
EOF
```

The 401 is a real check, not a formality: it proves the dashboard is up AND that
it is fail-closed. A 200 there means the login did not take and the dashboard is
open to anyone who reaches the port. A `000` means you used `http://` instead of
`https://`, or nothing is listening.

Add the authenticated check once you have the password from step 6:

```sh
$SSH 'curl -sk -o /dev/null -w "%{http_code}\n" -u admin:<password> https://127.0.0.1:8787/'
```

Expect **200**.

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

## 8. Do not arm the kernel controls during an evaluation

`innerwarden-ctl arm --check` surveys and is safe to show. `innerwarden-ctl arm`
changes the machine.

Arming is deliberate, agent-scoped, and belongs after the operator has watched a
week of real decisions. A host-wide execution-gate arm has bricked a machine at
boot; `arm` refuses that shape rather than offering it, and you should not go
looking for a way around the refusal. If the operator asks for it anyway, point
them at `innerwarden-ctl arm --check` first and let it explain what this host can
and cannot enforce, and why.

Safety valve, any time, and it never requires a licence:

```sh
sudo innerwarden-config-sign exec-gate disarm --apply
```

---

## Removing it

An evaluation has an end date, so know this before it starts. Order matters:
disarming comes first, because removing the binaries while a kernel control is
armed leaves the machine enforcing a policy nothing can change.

```sh
sudo innerwarden-config-sign exec-gate disarm --apply   # first, always
innerwarden agents disconnect --all                     # while the binary exists
sudo innerwarden-ctl uninstall --purge --yes
sudo npm uninstall -g innerwarden
rm -rf ~/.config/innerwarden
sudo rm -rf /etc/innerwarden /var/lib/innerwarden /var/log/innerwarden
sudo systemctl daemon-reload
hash -r
```

## What to tell the operator when you are done

- Which services are running, and that `innerwarden-agent` reading `inactive` is
  the correct production pattern rather than a fault.
- That the licence was accepted, quoting the `feature(s) granted` line.
- The dashboard URL, the tunnel command, and that the tunnel runs on THEIR
  machine.
- That nothing is being blocked: the host stack installs in observe-only, and
  DNS Guard was started in observe with `/etc/resolv.conf` untouched.
- That arming the kernel controls is a separate, deliberate decision they have
  not yet made.

## Known rough edges, so they do not surprise you

- **The interactive installer wizard wedges the terminal under `sudo`.** Covered
  in step 3. Never allocate a tty for the install.
- **The AI provider is asked for twice.** The free CLI stores its second-opinion
  model in `~/.config/innerwarden/llm.toml`; the paid agent has its own `[ai]`
  block in `/etc/innerwarden/agent.toml`. Neither mentions the other. The paid
  side does not need it: the installer provisions an on-device model
  (`[ai.warden] enabled = true`, `provider = "local_warden"`) and leaves the
  external `[ai]` disabled. Tell the operator the external provider is an
  optional upgrade, not a missing step.
- **`innerwarden-ctl license status` does not exist.** Use `arm --check`.
