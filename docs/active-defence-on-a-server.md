# Installing Active Defence on someone's server, and getting them the dashboard

For an agent running on the operator's own machine, reaching a Linux server over
SSH. This is the normal shape: the operator sits at a laptop, the server is
somewhere else, and the dashboard has to end up in the operator's browser
without being exposed to the internet.

Read all of it before running anything. Two steps here are irreversible from the
operator's side if you get them wrong, and one of them can lock their terminal.

---

## Before you run a single command, ASK

Do not guess any of these. Ask for each one at the moment you need it, in plain
language, and wait for the answer: operators expect to be walked through this,
not handed a form. But do not begin at all until you have items 1 and 2, because
without them there is nothing to install and nowhere to install it.

Never ask for a password, a private key's contents, or an API key. If a step
needs one, hand the operator the command and let them run it.

1. **The server.** Address or hostname, the SSH user, and the private key path if
   it is not their default. You need to be able to run
   `ssh <user>@<host> 'echo ok'` and see `ok`.
2. **The licence file.** Active Defence is licensed; without a licence file this
   install does not happen and you should stop and say so. Ask where the file is
   **on the operator's machine**. It is JSON, usually called `license.key`, and
   it contains `customer_id`, `host`, `features`, `valid_until` and `signature`.
   If they paste the JSON into the chat instead, write it to a file yourself.
3. **Whether `sudo` needs a password on that server.** This decides whether the
   install can run unattended at all. Check it rather than asking them to guess:

   ```sh
   ssh <user>@<host> 'sudo -n true 2>&1 || echo NEEDS_PASSWORD'
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

```sh
ssh <user>@<host> 'uname -m; uname -r; . /etc/os-release && echo "$PRETTY_NAME"'
ssh <user>@<host> 'grep -o bpf /sys/kernel/security/lsm || echo "NO-BPF"'
ssh <user>@<host> 'df -h / | tail -1'
```

Report back to the operator, in plain words:

- **Architecture must be x86_64 or aarch64.** Anything else, stop.
- **`NO-BPF` means the installer will edit the bootloader** and a reboot is
  needed before any kernel control can enforce. Detection and response still
  work without it. Get the operator's agreement before continuing.
- **Under ~2 GB free** is tight: the installer downloads an on-device model of
  about 87 MB plus the binaries.

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
licence to one machine**, matched against that host's `/etc/machine-id`; install
it on a different box and the installer refuses. If `host` is not `*`, say so to
the operator now and confirm this is the intended machine.

Then copy it over and confirm it survived the trip:

```sh
scp -i <key> <local-licence-path> <user>@<host>:/tmp/license.key
ssh <user>@<host> 'head -c 40 /tmp/license.key; echo'
```

That last line is not decoration. A licence downloaded from behind a login
arrives as an HTML page, and you want to see `{"customer_id"` now rather than a
confusing failure in three minutes.

## 3. Install, WITHOUT a terminal

```sh
ssh <user>@<host> 'curl -fsSL https://innerwarden.com/install | sudo bash -s -- --license=/tmp/license.key'
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
ssh <user>@<host> 'for u in innerwarden-sensor innerwarden-watchdog innerwarden-dns-guard; do printf "%-26s %s\n" "$u" "$(systemctl is-active $u 2>&1)"; done'
ssh <user>@<host> 'innerwarden-ctl --version'
```

Expect `active` for all three.

**`innerwarden-agent` reading `inactive` is CORRECT on a paid install** and is
not a failure to report. The watchdog owns the agent's lifecycle and spawns it.
Never run `systemctl start innerwarden-agent` on such a host; you will fight the
supervisor. Say this to the operator, because checking that unit is the obvious
thing to do and it looks like a fault.

Now confirm the licence was accepted:

```sh
ssh <user>@<host> 'sudo innerwarden-ctl arm --check'
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

A fresh install reports, under "Fixing first":

```
- repair dashboard-bind: agent.toml does not declare [dashboard] bind, so
  innerwarden-ctl assumes a default port and cannot reach the dashboard it is
  talking about
```

**This is a warning, not a blocker, and on a default install the dashboard works
anyway.** Verified on a clean Ubuntu 26.04 host: with that line present, the
dashboard still served correctly on its default port. Mention it to the operator
as a known cosmetic gap and carry on. Do not go hunting for a repair command and
do not let it stop you delivering a working dashboard.

## 6. Bring up the dashboard

```sh
ssh <user>@<host> 'sudo innerwarden-ctl dashboard login'
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
ssh <user>@<host> 'sudo innerwarden-ctl dashboard'
```

This prints the bind, the exposure and the tunnel. Four things about it that
will otherwise cost you the demo, all confirmed on a real host:

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
ssh <user>@<host> 'curl -sk -o /dev/null -w "%{http_code}\n" https://127.0.0.1:8787/'
ssh <user>@<host> 'curl -sk -o /dev/null -w "%{http_code}\n" -u admin:<password> https://127.0.0.1:8787/'
```

Expect **401** then **200**. The 401 is the point: the dashboard is fail-closed
and refuses anyone without the login. If the first returns 200, stop and tell the
operator, because the login did not take.

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
