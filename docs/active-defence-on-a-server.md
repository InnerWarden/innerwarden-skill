# Installing Active Defence on someone's server, and getting them the dashboard

For an agent running on the operator's own machine, reaching a Linux server over
SSH. This is the normal shape: the operator sits at a laptop, the server is
somewhere else, and the dashboard has to end up in the operator's browser
without being exposed to the internet.

Read all of it before running anything. Two steps here are irreversible from the
operator's side if you get them wrong, and one of them can lock their terminal.

---

## Before you run a single command, ASK

Do not guess any of these and do not start until you have them. Ask for all of
them in one message so the operator answers once:

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

## 2. Put the licence on the server

```sh
scp -i <key> <local-licence-path> <user>@<host>:/tmp/license.key
ssh <user>@<host> 'head -c 40 /tmp/license.key; echo'
```

The second line is not decoration. A licence that arrived truncated or as HTML
(a download that returned a login page) fails later with a confusing message,
and you want to see JSON now.

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

## 5. Fix the dashboard bind before promising a dashboard

A fresh install can be born reporting `agent.toml does not declare [dashboard]
bind, so innerwarden-ctl assumes a default port and cannot reach the dashboard it
is talking about`. If you skip this, the next step appears to work and the
dashboard is unreachable.

```sh
ssh <user>@<host> 'sudo innerwarden-ctl arm --check | sed -n "/Fixing first/,/^$/p"'
```

Apply whatever repair it names. Re-run `arm --check` afterwards and confirm the
line is gone. Do not tell the operator the dashboard is ready until it is.

## 6. Bring up the dashboard

```sh
ssh <user>@<host> 'sudo innerwarden-ctl dashboard login'
ssh <user>@<host> 'sudo innerwarden-ctl dashboard'
```

`dashboard login` exists because the dashboard is **fail-closed**: without a
login it answers 401. Capture whatever credential or URL it prints and hand it to
the operator; do not paste secrets into a shared channel.

`dashboard` prints the URL and the exact SSH tunnel command.

**`dashboard` exists in both tiers.** On a host that also has the free CLI,
`innerwarden dashboard` is the FREE one on 127.0.0.1:8788. The paid one is
`innerwarden-ctl dashboard` (or `innerwarden host dashboard`). Name the right
binary when you tell the operator what to run, or they will open the wrong
dashboard and report that the paid features are missing.

## 7. Give the operator the tunnel, and say where to run it

The dashboard binds loopback only and is never exposed. The operator reaches it
through an SSH tunnel **from their own machine**:

```sh
ssh -N -L <port>:127.0.0.1:<port> -i <key> <user>@<host>
```

Then they open `http://127.0.0.1:<port>` in their browser.

Say explicitly: **run this on your laptop, in a new terminal, not on the
server.** Operators paste it into the server's own shell and get
`Permission denied (publickey)`, because the server is trying to SSH to itself
with a key it does not have. The terminal stays blank with no prompt while the
tunnel is up; that is what success looks like.

Never suggest opening the port on a firewall or cloud security group instead.
The dashboard publishes decisions, detected agents and modes **with no
authentication of its own beyond that login**, and the tunnel costs one command.

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
