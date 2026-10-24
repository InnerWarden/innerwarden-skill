<div align="center">

# InnerWarden, installed by your AI agent

**Your agent has a shell. This puts a verdict in front of every command it runs.**

[![install](https://img.shields.io/badge/install-curl%20innerwarden.com%2Ffree-0b7285?style=flat-square)](https://innerwarden.com/docs/installation)
[![platforms](https://img.shields.io/badge/Linux%20%C2%B7%20macOS%20%C2%B7%20Windows%20(experimental)-supported-334155?style=flat-square)](docs/platforms.md)
[![licence](https://img.shields.io/badge/this%20repo-Apache--2.0-334155?style=flat-square)](LICENSE)

</div>

Point your coding agent at this repository and tell it what you want. It reads
the machine, asks you for what only you can supply, installs, **proves** the
result rather than assuming it, and then helps you run it day to day. Claude
Code, Codex, Gemini, Cursor, OpenClaw (as a ClawHub skill), or anything that
reads a repo and runs a shell.

Nothing to configure here and nothing to build. This repository is instructions
and one verification script.

## Agents: start here

Pick by what the user asked for, before reading anything else.

| The user wants… | Read, in this order |
|---|---|
| **InnerWarden Pro on a server** (they mention a licence, a server, SSH, or the dashboard) | [`docs/pro-on-a-server.md`](docs/pro-on-a-server.md) **first**, then [`SKILL.md`](SKILL.md) for the agent half |
| **their AI agent screened** (Claude Code, Codex, Gemini, Cursor, OpenClaw on this machine) | [`SKILL.md`](SKILL.md); for OpenClaw also [`docs/openclaw.md`](docs/openclaw.md) |
| **it is installed; run it** (is it on, what did it decide, enforce, alerts, upgrade, licence, remove) | [`docs/managing-community.md`](docs/managing-community.md), and [`docs/managing-pro.md`](docs/managing-pro.md) on a Pro host |
| **someone must decide whether it works** | [`docs/evaluating-a-pilot.md`](docs/evaluating-a-pilot.md) |
| **"install InnerWarden"**, and you cannot tell which | Ask. One question: *is this to protect an AI agent on a machine, or to install InnerWarden Pro on a server?* Do not guess: the two paths differ from the first command. |

**If the user handed you an `ssh` command, they mean the server path.** Go to
[`docs/pro-on-a-server.md`](docs/pro-on-a-server.md) and follow it in order.
There is one mistake in it that locks the user's terminal so hard that Ctrl+C
does not work, and the document tells you how not to make it.

**An agent cannot lower its own guard.** Switching to monitor, disconnecting,
allowing a command or removing InnerWarden are the person's to type, in their
own terminal. The CLI refuses them inside Claude Code, Codex or Gemini, an
enforcing Claude Code hook blocks them too, and the skill hands them over
instead of working around it.

```
$ ./scripts/verify-install.sh --proof iw-proof-ca77e0c4

  PASS  innerwarden 1.6.8
  PASS  a destructive command is DENIED (rm -rf / -> deny)
  PASS  an ordinary command is ALLOWED (ls -la -> allow)
  PASS  the hook REFUSES a denied command (exit 2, which is what an agent obeys)
  PASS  monitor mode blocks nothing, as promised (exit 0)
  PASS  2 agent(s) wired to the guard
  PASS  the agent's own command carrying 'iw-proof-ca77e0c4' was judged by the guard (channel: hook)

  Screening confirmed: 7 checks passed, 2 note(s).
```

The first run, without `--proof`, ends in "Wiring confirmed" and prints the
token for the restarted agent to run; only the run with it can say
"Screening confirmed".

---

## In 60 seconds

| | |
|---|---|
| **What it does** | screens every command and tool call your agent tries, **before it runs**, and answers allow / review / deny with reasons |
| **Where it decides** | on your machine. No account, no control plane, nothing sent anywhere for a verdict |
| **How it starts** | you choose: monitor records everything and blocks nothing (the person's command); enforce refuses what it denies. Pro's host layer installs observing |
| **What it costs to try** | nothing. InnerWarden Community is Apache-2.0 |
| **How you know it works** | `./scripts/verify-install.sh` sends real commands through it and reads the verdicts |

---

## What InnerWarden is

Your agent has a shell. That is the point of it, and it is also the exposure. It
can be prompt-injected by a file it reads or a page it fetches, and it can simply
be wrong about a path.

InnerWarden screens what the agent tries **before it runs** and returns
**allow**, **review** or **deny**, with the reasons. Claude Code is covered by a
pre-execution hook on its Bash and file-tool calls; for Codex, Gemini, Cursor
and OpenClaw the guard wraps their MCP servers instead, which screens calls to
those servers and not the agents' own built-in tools.
`innerwarden agents list` names the mechanism it used. The verdict is
computed on your machine: no command is sent anywhere for a judgement, there is
no account, and no service has to be reachable for the guard to work.

| | protects | platforms |
|---|---|---|
| **InnerWarden Community** (free, Apache-2.0) | the agent: commands and tool calls | Linux, macOS; Windows experimental |
| **InnerWarden Pro** (paid, per protected agent) | the host underneath: its own sensor, detectors, correlation, response, and the kernel Execution Gate, Secret Read Guard and DNS Guard | Linux |
| **Enterprise** | Pro for fleets, scoped with InnerWarden | as Pro |

Pro adds its own tools beside the same `innerwarden` command. Adding a licence
extends what it can do without changing anything you already learned.

---

## If you would rather type it yourself

```sh
curl -fsSL https://innerwarden.com/free | sh     # signed binary, no root, ~/.local/bin
innerwarden agents connect --all --monitor
#   ^ now RESTART your agent: the hook is read at agent startup
./scripts/verify-install.sh                      # wiring; it prints a token for the last step
./scripts/verify-install.sh --proof <token>      # after the agent itself ran the token: the proof
```

On Windows, `irm https://innerwarden.com/free.ps1 | iex`.

`npm install -g innerwarden` is the other supported channel and adds npm
provenance, but on Linux it often needs `sudo`: npm's prefix is root-owned on a
distro-packaged Node, so it fails with EACCES before InnerWarden is reached.
InnerWarden itself never needs root.

With an InnerWarden Pro licence (the `license.txt` attached to the purchase
email), on Linux:

```sh
curl -fsSL https://innerwarden.com/install | sudo bash -s -- --license=/path/to/license.txt
```

The `=` is required. `--license /path` with a space is rejected on purpose, so a
mistyped flag cannot quietly leave you on the free tier.

---

## The verification script is the point

Most failed evaluations of this product are the same failure: the CLI installs,
every command exits 0, and **no agent was ever wired**, so nothing is being
screened. It looks installed. It is not protecting anything.

```sh
./scripts/verify-install.sh
```

It does not check that files exist. It sends real commands through the guard and
reads the verdicts. It checks a dangerous command is denied **and** an ordinary
one is allowed, because a guard that refuses everything would pass a one-sided
test. Counting recorded decisions would be reading its own test calls and your
hand-run checks, so it does not: the last step is a one-off token that the
restarted agent itself runs, found in the guard's record on the agent's own
channel. Whatever it cannot demonstrate, it says so and prints the command that
fixes it.

```
== 3. is any agent actually wired to it ==
  FAIL  1 agent(s) found on this machine and NONE of them are wired
        The guard is installed and judging correctly, and your agent is not
        sending it anything. This is the state an evaluation mistakes for
        'it does not work'.
        The PERSON runs this, in their own terminal (an AI agent cannot: ...):
          innerwarden agents connect <agent> --monitor
        or, to enforce from the start (an agent may run this one, once the
        person has chosen it):
          innerwarden agents connect <agent>
        with <agent> one of the names listed below. Then RESTART the agent.
```

Exit codes: `0` confirmed (wiring, or screening with `--proof`), `1` installed
but nothing reaching it, `2` not installed, `3` installed but judging wrongly.

---

## Contents

| file | for |
|---|---|
| [`SKILL.md`](SKILL.md) | the agent: the full install and verify procedure |
| [`AGENTS.md`](AGENTS.md) | the same, under the filename most agents look for |
| [`scripts/verify-install.sh`](scripts/verify-install.sh) | proving the guard is live |
| [`docs/what-it-does.md`](docs/what-it-does.md) | a human deciding whether to run it |
| [`docs/platforms.md`](docs/platforms.md) | what runs where, and the kernel requirements |
| [`docs/protecting-a-remote-agent.md`](docs/protecting-a-remote-agent.md) | agents in the cloud, in containers, or in CI |
| [`docs/pro-on-a-server.md`](docs/pro-on-a-server.md) | installing InnerWarden Pro on someone's server, and its dashboard |
| [`docs/managing-community.md`](docs/managing-community.md) | running the free guard day to day |
| [`docs/managing-pro.md`](docs/managing-pro.md) | running a Pro host day to day: licence, dashboard, responder, kernel controls, upgrade |
| [`docs/evaluating-a-pilot.md`](docs/evaluating-a-pilot.md) | proving each layer works, for whoever decides |
| [`docs/openclaw.md`](docs/openclaw.md) | what is and is not screened for OpenClaw |
| [`clawhub/innerwarden-security/`](clawhub/innerwarden-security/SKILL.md) | the same skill, shaped for OpenClaw and published on ClawHub |

---

## Links

- Product and pricing: <https://innerwarden.com>
- Documentation: <https://innerwarden.com/docs/install-and-first-run>
- Community source (Apache-2.0): <https://github.com/InnerWarden/inner-warden>
- Signed releases: <https://github.com/InnerWarden/innerwarden-releases/releases>

InnerWarden Pro is a paid, source-available product and is not open source; its
software is released under the name InnerWarden Active Defence. InnerWarden
Community is Apache-2.0 and its source is linked above.

---

## Licence

The contents of this repository are Apache-2.0. See [LICENSE](LICENSE).
