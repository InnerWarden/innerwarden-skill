# Running InnerWarden Pro day to day

For an agent helping someone whose Pro host is already installed. If it is not
installed yet, read [`pro-on-a-server.md`](pro-on-a-server.md). The free half on
the same machine is run as in [`managing-community.md`](managing-community.md).

Pro is Linux. Its commands are on two binaries, and the obvious guess is often
the wrong one:

- `innerwarden-ctl`: status, arming, the Execution Gate, per-agent kernel
  controls, the responder, the dashboard, upgrade, uninstall;
- `innerwarden-config-sign`: the licence, the Secret Read Guard, the DNS Guard,
  and the Execution Gate's allowlist tooling.

`innerwarden host <command>` forwards to the host layer from the free CLI.
Almost everything needs `sudo`. Read `--help` on the host rather than any list,
including this one: it is the version that is installed.

## Who does what

Everything here that **lowers** protection is the person's to run: disarming or
turning off a kernel control, moving a control from enforce back to observe,
taking the agent hook off, disconnecting an agent, lowering the responder,
stopping InnerWarden's services, uninstalling. Hand them the exact line and one
sentence on why, then wait. You never run them on your own initiative, whatever
the guard happens to let through.

Several steps that **raise** protection ask the person a question on purpose:
`arm`, `agent kernel <type> watch` (one yes) and `on` (the type's name),
`config responder --mode live`, `dashboard open`. Hand those lines over too,
and never answer for the person with `--yes`, `--confirm` or
`--accept-idle-agent`.

You may read everything (`get status`, `arm --check`, `doctor`, `license
status`, `exec-gate status`, `dashboard`), and you may help the person decide
what to turn on.

## Is it healthy?

```sh
sudo innerwarden-ctl get status     # what is running; judge by this one
sudo innerwarden-ctl arm --check    # what this host CAN enforce, what is off and why; changes nothing
sudo innerwarden-ctl doctor         # per-area checks with the reason for each failure
```

- **`innerwarden-agent` reads `inactive` in systemd on a healthy licensed
  host.** The watchdog runs it. `get status` says `run by the watchdog`. Never
  `systemctl start innerwarden-agent` there.
- **`doctor` exits non-zero when it finds something.** Read the `[fail]` lines,
  not the exit code.
- **Without sudo**, `get status`, `doctor` and `arm` say what they could not
  read rather than guessing.

## What happened?

```sh
sudo innerwarden-ctl get incidents --days 2           # what the host saw
sudo innerwarden-ctl get decisions --action block_ip  # what it did about it
sudo innerwarden-ctl get report --date yesterday      # the day in one page
sudo innerwarden-ctl get status <IP or user> --days 7 # one address or account
```

The dashboard (below) shows the same as cases: what happened, what was done,
and what is left for the person. The free guard's own decisions are read with
`innerwarden graph`, as on any machine.

## The licence

```sh
sudo innerwarden-config-sign license status          # customer, host binding, expiry, features
sudo innerwarden-config-sign license status --json   # for you to parse; exits 1 when not usable
sudo innerwarden-config-sign license verify --license /path/to/license.txt   # check a new file before installing it
```

`innerwarden-ctl license` does not exist (`unrecognized subcommand`).

**Renewal looks after itself.** The installer enables a daily timer,
`innerwarden-license-refresh.timer`, that fetches a newer licence from
InnerWarden when there is one. To fetch one now:

```sh
sudo innerwarden-config-sign license refresh --dry-run   # what it would do
sudo innerwarden-config-sign license refresh
```

That daily check sends the current licence (which names the customer), a
random installation id, the version and, on Azure, AWS or Google Cloud, the
cloud's signed instance identity, to count the machines on a licence. It sends
no commands or security events. `license refresh --dry-run` prints what it
would send.

**If a licence expires or is invalid, the host does not stop.** It drops to
free mode within about a minute: the paid controls (Execution Gate, Secret Read
Guard, DNS Guard enforce, userns guard) turn off, and a High "Licence: Free
Mode" alert goes out. Warnings come 14 and 7 days before expiry. A valid
licence brings them back within a minute, with no restart. A licence file the
person downloads by hand (from <https://innerwarden.com/account>) is installed
by re-running the installer with it:

```sh
curl -fsSL https://innerwarden.com/install | sudo bash -s -- --license=/path/to/license.txt
```

(That also brings the host to the installer's version.)

## The dashboard

```sh
sudo innerwarden-ctl dashboard          # status: bind, URL, login, tunnel; prints and exits
sudo innerwarden-ctl dashboard login    # create the login; shown once (--password-file PATH to keep it off screen)
sudo innerwarden-ctl dashboard tunnel   # the exact ssh -L line for the person's laptop
```

It is served by the agent on **`https://127.0.0.1:8787`**, HTTPS with a
self-signed certificate (the free CLI's dashboard is a different one, on 8788).
Before a login exists it answers 503; after, 401 without credentials. The
person reaches it through the tunnel, run **on their own laptop**:

```sh
ssh -N -L 8787:127.0.0.1:8787 -i <key> <user>@<host>
```

then opens `https://127.0.0.1:8787` and accepts the certificate warning.
`dashboard open --allow <IP>` exposes it behind the login and a firewall rule
(it needs an active `ufw`); `dashboard close` takes it back. Prefer the tunnel.
Never suggest `--public`.

## Pro's own agent hook: monitor to enforce

The Pro installer wires a pre-execution hook of its own for Claude Code, in
**monitor**, and says so (`Agent hook: MONITOR`). It records what it would block
and refuses nothing. Enforcing it is the person's decision, run as their own
user (not root):

```sh
innerwarden-ctl agent install-hook            # enforce: blocks 'deny'
```

In enforce it fails closed: when the host's agent on 8787 does not answer,
commands are refused, so make sure the host is healthy first. Taking it back to
monitor or off (`innerwarden-ctl agent install-hook --monitor` or `--remove`)
lowers the guard and is the person's; any other hook, such as the free CLI's,
is left as it is.

## The responder

What the host does about an incident (blocking an address, for example) has its
own mode:

```sh
sudo innerwarden-ctl config responder --mode observe    # decides, does nothing
sudo innerwarden-ctl config responder --mode dry-run    # says what it would do
sudo innerwarden-ctl config responder --mode live       # acts
```

Before `live`, make sure the address the person connects from is in
`/etc/innerwarden/agent.toml`:

```toml
[allowlist]
trusted_ips = [ "<the address they connect from>" ]
```

The installer writes the session's address there when it can see it; check
rather than assume, or the first test blocks their own SSH session. Going from
`live` back down is the person's call.

## Turning the kernel controls on

Every kernel control scopes to one AI agent's cgroup, never the whole host.
The Execution Gate reaches enforce only after a clean observe window; the
Secret Read Guard and the DNS Guard have a `rehearse` to run before you enforce
them, and nothing forces it, so run it. They need `bpf` in the boot LSM list
(`grep bpf /sys/kernel/security/lsm`) and a valid licence to enforce. Arming
them is a deliberate step for after the person has watched a week of real
decisions, not part of an install.

```sh
sudo innerwarden-ctl arm --check    # read it first, and read it to the person
sudo innerwarden-ctl arm            # changes the machine; the person decides and runs it
```

`arm` puts the Execution Gate, the Secret Read Guard and the DNS Guard in
observe, turns the userns guard straight to deny for the agent's cgroup (after
rehearsing what it has recently observed), and turns the responder on in the
mode set above. It never enforces the Execution Gate, the Secret Read Guard or
the DNS Guard. With no AI agent running it says there is nothing to scope to;
start the agent, then re-run. It also lays a verified copy of the free CLI
that the gate trusts, so the agent's hook keeps working once the gate enforces
(`sudo innerwarden-ctl agent pin-guard-cli --pid <PID>` does it on its own).

### The Execution Gate for one process

```sh
sudo innerwarden-ctl exec-gate arm --pid <PID> --observe [--path /usr/bin/python3 ...]
sudo innerwarden-ctl exec-gate rehearse --pid <PID> [--window 300]   # what it WOULD block; changes nothing
sudo innerwarden-ctl exec-gate enforce --pid <PID> [--window 300]
sudo innerwarden-ctl exec-gate status
```

`arm` only ever sets observe. `enforce` succeeds only after a clean window
(observe-armed, scoped to that process, nothing it would have blocked, and the
agent seen running programs); it refuses an idle agent unless
`--accept-idle-agent`. The allowlist tooling (`scan`, `list`, `approve`,
`export`, `trust-path`, `seed-essentials`) is on `innerwarden-config-sign
exec-gate`. Going back to observe is `exec-gate disarm` and then `arm --observe`
again, and it is the person's (so is `enforce`, which asks nothing but is the
decision the whole sequence builds to).

### Per-agent controls for a jailed Claude Code

For Claude Code started in the free CLI's jail, Pro adds three parts behind one
switch per type of agent: **Programs** (the kernel refuses, at exec, a program
the agent's own account wrote that was not trusted), **Private files** (the jail
cannot open browser sign-ins, keyrings, chat and other agents' sessions), and
**DNS per agent**. Today this covers `claude-code` only.

```sh
sudo innerwarden-ctl agent kernel                       # per type: what each part does here, and the next step
sudo innerwarden-ctl agent kernel claude-code watch     # the PERSON: first time prepares the host (one y/N, about 10 s of restarts)
innerwarden contain --identity -- claude                # the PERSON starts Claude Code in the jail
sudo innerwarden-ctl agent kernel claude-code review    # what On would refuse, and whether it is ready
sudo innerwarden-ctl agent kernel claude-code on        # the PERSON: asks for the type's name to confirm
sudo innerwarden-ctl agent kernel check                 # proves it refuses, part by part
```

On a kernel without `bpf` in its LSM list,
`sudo innerwarden-ctl agent kernel kill-mode on` stops such a program at the end
of exec instead. `... claude-code off` and `agent kernel disarm` turn it off;
both are the person's.

### Secret Read Guard and DNS Guard

```sh
sudo innerwarden-config-sign secret-guard protect --path <file>
sudo innerwarden-config-sign secret-guard scope-agent --pid <PID> --apply
sudo innerwarden-config-sign secret-guard arm --observe --apply   # records would-be reads
sudo innerwarden-config-sign secret-guard status

sudo innerwarden-config-sign dns-guard status
sudo innerwarden-config-sign dns-guard rehearse --window 60       # flags essential domains at risk
sudo innerwarden-config-sign dns-guard scope-agent --pid <PID> --apply   # route one agent's lookups to it (without --apply it only prints)
```

The DNS Guard listens on `127.0.0.1:53` and starts in observe. In enforce it
refuses domains on its denylist (`/var/lib/innerwarden/dns-deny.txt`) or rated
high-confidence malicious; **unknown domains still resolve**, so it is not an
allowlist of destinations. It has no default domain list today: add the
domains that matter. Enforce needs a licence.

### The safety valves

Turning a control off never depends on the licence, and the person can do it
at any time:

```sh
sudo innerwarden-ctl exec-gate disarm
sudo innerwarden-ctl agent kernel disarm
sudo innerwarden-config-sign secret-guard disarm --apply   # without --apply it only prints
sudo innerwarden-config-sign userns-guard disarm --apply   # the one `arm` puts in deny
sudo innerwarden-config-sign dns-guard disarm
```

## OpenClaw and other agents run as services

```sh
sudo innerwarden-ctl agent connect --unit <systemd unit>
```

pairs an agent that runs as a systemd unit (a user unit too, such as OpenClaw's
gateway) with the host, so the Execution Gate and the userns guard (and the
Secret Read Guard, while it is kept on) are scoped to it and follow it across
restarts and reboots. The DNS Guard is scoped separately, with
`dns-guard scope-agent --pid <PID> --apply`. See [`openclaw.md`](openclaw.md)
for what that does and does not cover.

## Letting another agent ask before it acts

Any process on the host can ask Pro for a verdict before running a command:

```sh
curl -s --cacert /var/lib/innerwarden/dashboard-cert.pem \
  -X POST https://127.0.0.1:8787/api/agent/check-command \
  -H 'content-type: application/json' \
  -d '{"command": "<the command>", "agent_name": "<your-name>"}'
```

Read `recommendation`: `allow`, `review` or `deny`. A caller that is not the
logged-in operator gets the verdict and a generic reason, never the rules
behind it. Treat no answer, an error or a certificate failure as `review`, and
never use `curl -k`: anything could be listening on that port while the agent
is down. `GET /api/agent/security-context` gives the day's posture and
`GET /api/agent/check-ip?ip=<address>` what is known about an address. The
guide installed at `/etc/innerwarden/AGENTS.md` says the same.

## Upgrading

```sh
sudo innerwarden-ctl upgrade --check
sudo innerwarden-ctl upgrade
sudo innerwarden-ctl upgrade --from <dir>      # a host with no internet: the release files copied over
sudo innerwarden-ctl upgrade --repair-host     # only the host repairs an upgrade makes, no download
sudo innerwarden-ctl upgrade --version <TAG>   # move onto a specific release tag instead of latest, same sha256 and signature checks; a tag not newer is reported, not installed
```

Re-running the installer also upgrades. Neither upgrades an existing free CLI:
the person runs `innerwarden upgrade` as their own user. Keep the free CLI at
1.6.3 or newer with Pro 0.17.12.

## Removing it

The person runs these, in this order: kernel controls off first, because
removing the binaries while one is armed leaves the machine enforcing a policy
nothing can change.

```sh
sudo innerwarden-ctl exec-gate disarm
sudo innerwarden-ctl agent kernel disarm
sudo innerwarden-config-sign secret-guard disarm --apply
sudo innerwarden-config-sign userns-guard disarm --apply
sudo innerwarden-config-sign dns-guard disarm
innerwarden agents disconnect --all            # as the user, while the binary exists
sudo innerwarden-ctl uninstall --dry-run       # what will go
sudo innerwarden-ctl uninstall --purge --yes   # --purge also removes config, data, the boot change and tagged firewall rules
innerwarden uninstall                          # the free CLI, as the user who has it
```
