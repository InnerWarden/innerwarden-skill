---
name: innerwarden
description: Install, wire and verify InnerWarden, the runtime guardrail that screens an AI agent's shell commands and tool calls before they run. Use when the user asks to install InnerWarden, protect an agent, add the Enterprise host layer with a licence, or check whether the guard is actually screening anything.
---

# Installing and verifying InnerWarden

You are setting up a guardrail that sits between an AI agent and the machine it
can act on. Every shell command and MCP tool call the agent tries is screened
first and comes back **allow**, **review** or **deny**.

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

### 1. Install the free CLI

```sh
npm install -g innerwarden
```

No sudo, no postinstall script, prebuilt and signed. If npm is not available:

```sh
# Debian / Ubuntu
sudo apt install ./innerwarden_<version>_amd64.deb
# Fedora / RHEL / Rocky
sudo dnf install ./innerwarden-<version>-1.x86_64.rpm
```

Both are attached to the release at
<https://github.com/InnerWarden/innerwarden-releases/releases>.

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

For an agent on another machine, in a container, or in CI, the local hook does
not apply. Read `docs/protecting-a-remote-agent.md` in this repository.

### 3. Add the Enterprise host layer, if there is a licence

Linux only. The user will have been issued a `license.key` file.

```sh
curl -fsSL https://innerwarden.com/install | sudo bash -s -- --license=/path/to/license.key
```

The `=` matters. `--license /path` with a space is **rejected**, deliberately, so
a mistyped flag can never quietly leave the host on the free tier. The flag also
accepts an `https://` URL.

It comes up in observe-only mode. It watches, explains what it sees, and blocks
nothing until the user decides otherwise.

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
innerwarden dashboard                    # local UI, read-only, optional
innerwarden notify                       # Telegram, Slack, Discord, webhook
innerwarden allow "<glob>"               # stop it asking about a trusted command
innerwarden enforce                      # when they are ready: denials become real
```

## Things that will cost you an hour if you skip them

- **A wired agent that was not restarted is not protected.** Check
  `innerwarden agents list`, not your memory of having run `connect`.
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
