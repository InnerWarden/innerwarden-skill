---
name: innerwarden
description: Install, wire and verify InnerWarden. Two jobs: screening an AI agent's shell commands and tool calls on a machine, and installing the licensed Active Defence host layer on a Linux server (with its dashboard). Use when the user asks to install InnerWarden, protect an agent, install Enterprise or Active Defence on a server with a licence, reach the dashboard, or check whether the guard is actually screening anything.
---

> **Installing on a SERVER, or Enterprise / Active Defence, or a licence, or the
> dashboard?** Stop and read
> [`docs/active-defence-on-a-server.md`](docs/active-defence-on-a-server.md)
> instead, and follow it start to finish. That is a different product from this
> page and the paths diverge at the first command. Anything on this page about
> the host layer is a summary of that document, not a substitute for it.
>
> **If the user handed you an `ssh` command, they mean the server.**

# Installing and verifying InnerWarden

You are setting up a guardrail that sits between an AI agent and the machine it
can act on. What the agent tries is screened first and comes back **allow**,
**review** or **deny**.

Which surface that covers depends on the agent, and it is one or the other, never
both. Claude Code takes a pre-execution hook on its Bash tool calls. Cursor,
Codex, Gemini and OpenClaw have no such hook, so the guard rewrites their MCP
configuration to run through its proxy instead. `innerwarden agents list` names
the mechanism it used for each one, and you should read it rather than assume.

There are two tiers and they are the same command:

| | what it protects | where it runs |
|---|---|---|
| **Community** (free, Apache-2.0) | the agent: its commands and tool calls | Linux, macOS, Windows |
| **Enterprise** (paid, licensed) | the whole host: eBPF sensor, detectors, correlation, autonomous response, and the kernel Execution Gate | Linux today |

Enterprise adds capabilities **under the same `innerwarden` command**. Nothing
the user learns in the free tier is thrown away when they add a licence.

## Read this before you type anything

**Install the free CLI first, always.** It is the front door. The Enterprise
installer expects it and the user's muscle memory is built on it. Do not start
with the host installer even when a licence is in hand.

**`innerwarden setup` is safe for you to run.** It is an arrow-key wizard for
humans, and it prints a summary instead of prompting when stdin is not a
terminal. It will not hang your session. It also will not configure anything in
that mode, so use the explicit commands below rather than relying on it.

**A hook is read at agent startup.** After wiring an agent you MUST tell the user
to restart it. A session that was already open keeps running unscreened, and
this is the single most common reason someone concludes the product "does not
work".

**Start in monitor mode.** `--monitor` records verdicts and blocks nothing. Let
the user see a week of real decisions before anything is refused. A guard that
blocks something legitimate on day one gets uninstalled on day two.

## The sequence

**Be on current versions.** The free CLI is 1.4.1 and the host layer is 0.16.48.
Older installers of the host layer wired an enforcing hook without asking, and
the version you get is whatever `innerwarden.com/install` currently serves, so
check what you actually installed rather than assuming:

```sh
innerwarden --version        # want 1.4.1 or newer
innerwarden-ctl --version    # want 0.16.48 or newer, if the host layer is there
```

### 1. Install the free CLI

```sh
# macOS and Linux
curl -fsSL https://innerwarden.com/free | sh
# Windows, in PowerShell
irm https://innerwarden.com/free.ps1 | iex
```

This picks the signed binary for the machine, checks its sha256 **and** its
Ed25519 signature before it installs anything, and puts it in `~/.local/bin`.
No root at any point, and nothing is fetched or executed at install time beyond
the binary itself.

If `innerwarden` is not found afterwards, `~/.local/bin` is not on PATH:

```sh
export PATH="$HOME/.local/bin:$PATH"   # and add that line to the user's shell rc
```

npm is the other supported channel, carries npm provenance, and is the same
command on every OS. Prefer it when the user already manages their tools with
npm, and be ready for this:

```sh
npm install -g innerwarden
```

**On Linux, expect that to fail with EACCES.** `npm install -g` writes to npm's
prefix; on a distro-packaged Node that prefix is `/usr/local/lib/node_modules`
and it is root-owned, so the first command a new user runs exits non-zero.
Measured on a clean Ubuntu 26.04 machine. That is npm, not the product, and
re-running it changes nothing:

```sh
sudo npm install -g innerwarden
# or give npm a prefix the user owns:
npm config set prefix ~/.npm-global   # then put ~/.npm-global/bin on PATH
```

`.deb`, `.rpm`, Scoop and from-source, with the current version and both
architectures, are at <https://innerwarden.com/docs/installation>. Do not copy a
version-pinned filename into this file: it is stale the next release, which is
the same reason this skill reads verbs from `--help` instead of listing them.

Confirm before continuing:

```sh
innerwarden --version
```

### 2. Wire the agent

```sh
innerwarden agents list                        # what is on this machine
innerwarden agents connect --all --monitor     # wire everything, record only
```

Then tell the user, in these words: **restart your agent now, or it is still
running unscreened.**

`connect` picks ONE mechanism per agent and prints which. To put the guard in
front of an MCP server it did not wire, including servers Claude Code runs,
substitute the server's own command in that agent's MCP config:

```sh
innerwarden proxy --mode advisory -- <server command>   # monitor week
innerwarden proxy --mode guard    -- <server command>   # once they enforce
```

**If `connect` says an agent "does not exist yet" or "has no local MCP servers
to guard", it cannot be auto-wired and running the command again changes
nothing. Stop looping.** That machine reaches a wired state by adding the MCP
server the user actually runs and reconnecting, by wrapping one with `proxy`
above, or by running the agent under `innerwarden contain -- <command>`.

For an agent on another machine, in a container, or in CI, the local hook does
not apply. Read `docs/protecting-a-remote-agent.md` in this repository.

Set up alerts now, while you are here. It takes two commands and the second one
is not optional:

```sh
innerwarden notify --telegram-token <T> --telegram-chat <C>   # or --slack-webhook <URL>
innerwarden notify --test
```

### 3. Add the Enterprise host layer, if there is a licence

Linux only. The user will have been issued a `license.key` file.

> **Installing on a REMOTE server, or asked for the Active Defence dashboard?**
> Read [`docs/active-defence-on-a-server.md`](docs/active-defence-on-a-server.md)
> instead of this section and follow it exactly. It covers what to ask the user
> for before you start, the sudo-password case you cannot solve from a script,
> the dashboard and its SSH tunnel, and the one mistake that locks the user's
> terminal so hard that Ctrl+C does not work.

```sh
curl -fsSL https://innerwarden.com/install | sudo bash -s -- --license=/path/to/license.key
```

The `=` matters. `--license /path` with a space is **rejected**, deliberately, so
a mistyped flag can never quietly leave the host on the free tier.

**Never give that command a terminal it did not need.** When it finishes it tries
to launch an interactive setup wizard through `sudo`, and modern sudo ships
`Defaults use_pty`: the wizard renders on a pty `sudo` created while the user
types into a different one. Arrow keys print as `^[[B`, ENTER does nothing, and
**Ctrl+C does not work**. Run it over `ssh` WITHOUT `-t`, or with stdin closed
(`< /dev/null`), and the installer detects there is no usable tty and skips the
wizard, which is the outcome you want. Everything that matters is configured
before the wizard would run.

If a user reports a frozen terminal after installing: press ENTER, then `~`,
then `.` (the SSH escape). Then finish with `sudo innerwarden-ctl setup` run
directly in their own shell, where sudo inherits the existing pty.

The value must be a **local file path**. The installer's own `--help` says it
accepts an `https://` URL; it does not, it tests `-f` on the value and exits 1.
If the licence arrived as a link, fetch it first:

```sh
curl -fsSL <url> -o /tmp/license.key
```

The HOST LAYER comes up in observe-only: it watches the machine, explains what
it sees, and blocks nothing until the user decides otherwise.

**Check which mode the agent hook ended up in.** The installer wires its own
pre-execution hook beside the one from step 2. From 0.16.48 it asks for monitor,
so it records and refuses nothing, and the installer prints the mode it left
behind. Read that line back to the user.

Installers older than 0.16.48 wired an ENFORCING hook here regardless of what
step 2 chose, and that hook exits 2 on every command whenever the InnerWarden
agent is not answering. If the user is on an older host, or you are unsure:

```sh
grep -c agent_command_guard ~/.claude/settings.json   # is one wired at all
grep -c "exit 2" ~/.config/innerwarden/agent_command_guard.sh   # 0 means monitor
```

Non-zero on the second command means it BLOCKS. For a monitor-first pilot, take
it back off until the user opts into enforcement:

```sh
innerwarden-ctl agent install-hook --remove   # leaves the step 2 hook alone
```

**On Debian and Ubuntu without `bpf` in the LSM stack, the installer edits the
bootloader.** It writes `/etc/default/grub.d/99-innerwarden-lsm.cfg`, runs
`update-grub`, preserves the existing stack, and prints REBOOT REQUIRED. It
never reboots. Say this to the user BEFORE you run the installer, not after: it
is a change to how their machine boots. No kernel control can enforce until they
reboot.

### 4. Prove it, do not assume it

```sh
./scripts/verify-install.sh
```

Run it from this repository. It does not check that files exist. It sends real
commands through the guard and reads the verdicts, then reports what it could
**not** demonstrate and the exact command that fixes each one.

Exit codes: `0` screening confirmed, `1` installed but nothing is reaching it,
`2` not installed, `3` installed but the engine is judging wrongly.

Do not tell the user the install succeeded until this exits 0. "It installed
without errors" and "it is protecting you" are different claims, and the gap
between them is where an evaluation goes wrong.

## After it is working

Read the command surface from the tool itself rather than from any list,
including this one. Lists in documentation drift from what ships:

```sh
innerwarden --help              # every verb, from the binary that is installed
innerwarden <verb> --help       # one verb in detail
innerwarden host --help         # the Enterprise host layer, same command
```

The ones worth showing a new user, in this order:

```sh
innerwarden status                       # is it on, and is it screening anything
innerwarden check "rm -rf /"             # ask for a verdict directly
innerwarden graph                        # what has been screened, and how it ended
innerwarden notify                       # Telegram, Slack, Discord, webhook
innerwarden allow "<glob>"               # stop it asking about a trusted command
innerwarden enforce                      # denials become real, THEN restart the agents
```

`innerwarden dashboard` is not in that list because it is a **foreground
server**, not a one-shot command: it does not return. Background it or give it a
terminal the user owns, then open <http://127.0.0.1:8788>. On the cloud VM or
container that `docs/platforms.md` calls the normal deployment, reach it with
`ssh -L 8788:127.0.0.1:8788 <host>`. Never expose it: it publishes decisions,
detected agents and modes with no auth. Note that `innerwarden status` probes
8787 for a dashboard and will report it as not running whatever the dashboard is
doing; confirm with `curl -s http://127.0.0.1:8788/api/meta` instead.

## Things that will cost you an hour if you skip them

- **Every mode change needs a restart, not just the first wiring.** `connect`,
  `dry-run` and `enforce` all print "Restart guarded agents so they reload their
  hook or MCP configuration". Read that line back to the user each time,
  especially for `enforce`, which is the moment the pilot has been building to.
  `innerwarden agents list` reads the config file on disk, so it shows the new
  mode instantly and is NOT evidence the running session picked it up.
- **Counting screening decisions does not prove traffic is flowing.** Running
  `innerwarden check` yourself records decisions. The verify script reads that
  counter *before* it probes, for exactly this reason.
- **On a hardened Enterprise host the agent unit reads `inactive` while running.**
  The watchdog owns its lifecycle. Never `systemctl start innerwarden-agent`
  there; you will fight the supervisor.
- **The kernel Execution Gate needs `bpf` in the boot LSM stack.** Without it the
  gate loads and enforces nothing. Detection and response are unaffected. Check
  with `grep bpf /sys/kernel/security/lsm`.
- **Do not arm the Execution Gate during an evaluation.** It is agent-scoped and
  deliberate, and it is the last step, not the first.

## Removing it

A pilot has an end date, so know this before it starts.

```sh
innerwarden agents disconnect --all   # FIRST, and not optional
# restart every agent that was connected
npm uninstall -g innerwarden          # or: sudo apt remove innerwarden / sudo dnf remove innerwarden
rm -rf ~/.config/innerwarden          # local state and the decision log
```

The first line is not optional because a full `innerwarden uninstall` unwires
Claude Code only. Every other agent was wired by rewriting its MCP config to
call the guard binary by absolute path, so removing the binary without
disconnecting leaves those servers pointing at a path that no longer exists, and
the command that would have fixed it went with the binary.

For the Enterprise host layer: `innerwarden-ctl uninstall` (add `--purge` to drop
config and data too).

## What to tell the user when you are done

Report what you did and what you proved, then get out of the way. The product is
built to be tested, so let them test it rather than reading claims from you.

Say:

- which tier is installed and on which machine;
- that their agent is wired **and that they must restart it**;
- that it is in **monitor** mode: it records verdicts and blocks nothing yet;
- that `./scripts/verify-install.sh` exited 0, which means commands really are
  reaching the guard, not merely that files were copied.

Then give them the two things to do next, in this order:

```sh
innerwarden check "<something you would never want an agent to run>"
innerwarden graph            # after a day of normal work: their traffic, judged
```

That second one is the evaluation. Their own commands, with verdicts and
reasons. If the verdicts match what they would have decided, `innerwarden
enforce` makes the denials real. If one does not, `innerwarden allow "<glob>"`
teaches it.

Do not characterise the product's limits for them, and do not promise coverage.
Point them at `docs/what-it-does.md` for the human-facing description and let
the tool answer for itself.

Facts they need BEFORE they start are a different thing, and you SHOULD state
those plainly: which platforms the Enterprise layer runs on, that the kernel
Execution Gate needs `bpf` in the boot LSM stack, and that a licence file
selects the paid tier. Those are prerequisites, not caveats, and finding them
out on day three wastes their time. `docs/platforms.md` has them.
