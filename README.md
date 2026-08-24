<div align="center">

# InnerWarden, installed by your AI agent

**Your agent has a shell. This puts a verdict in front of every command it runs.**

[![install](https://img.shields.io/badge/install-curl%20innerwarden.com%2Ffree-0b7285?style=flat-square)](https://innerwarden.com/docs/installation)
[![platforms](https://img.shields.io/badge/Linux%20%C2%B7%20macOS%20%C2%B7%20Windows-supported-334155?style=flat-square)](docs/platforms.md)
[![licence](https://img.shields.io/badge/this%20repo-Apache--2.0-334155?style=flat-square)](LICENSE)

</div>

Point your coding agent at this repository and tell it:

> **install InnerWarden and verify it is actually screening my commands**

It installs the guardrail, wires your agent to it, adds the Enterprise host layer
if you have a licence, and then **proves** the result rather than assuming it.
Claude Code, Cursor, Codex, or anything that reads a repo and runs a shell.

Nothing to configure here and nothing to build. This repository is instructions
and one verification script.

```
$ ./scripts/verify-install.sh

  PASS  a destructive command is DENIED (rm -rf / -> deny)
  PASS  an ordinary command is ALLOWED (ls -la -> allow)
  PASS  the hook REFUSES a denied command (exit 2, which is what an agent obeys)
  PASS  1 agent(s) wired to the guard

  Screening confirmed: 9 checks passed.
```

---

## In 60 seconds

| | |
|---|---|
| **What it does** | screens every command and tool call your agent tries, **before it runs**, and answers allow / review / deny with reasons |
| **Where it decides** | on your machine. No account, no control plane, nothing sent anywhere for a verdict |
| **How it starts** | monitor mode: records everything, blocks nothing, until you say otherwise |
| **What it costs to try** | nothing. The guardrail is Apache-2.0 |
| **How you know it works** | `./scripts/verify-install.sh` sends real commands through it and reads the verdicts |

---

## What InnerWarden is

Your agent has a shell. That is the point of it, and it is also the exposure. It
can be prompt-injected by a file it reads or a page it fetches, and it can simply
be wrong about a path.

InnerWarden screens what the agent tries **before it runs** and returns
**allow**, **review** or **deny**, with the reasons. Claude Code is covered by a
pre-execution hook on its Bash calls; Cursor, Codex and Gemini have no such
hook, so their MCP configuration is wired through the guard's proxy instead.
`innerwarden agents list` names the mechanism it used. The verdict is
computed on your machine: no command is sent anywhere for a judgement, there is
no account, and no service has to be reachable for the guard to work.

| | protects | platforms |
|---|---|---|
| **Community** (free, Apache-2.0) | the agent: commands and tool calls | Linux, macOS, Windows |
| **Enterprise** (licensed) | the host: eBPF sensor, detectors, correlation, autonomous response, kernel Execution Gate | Linux today; macOS and Windows in development |

Both are the same `innerwarden` command. Adding a licence extends what it can do
without changing anything you already learned.

---

## If you would rather type it yourself

```sh
curl -fsSL https://innerwarden.com/free | sh     # signed binary, no root, ~/.local/bin
innerwarden agents connect --all --monitor
#   ^ now RESTART your agent: the hook is read at agent startup
./scripts/verify-install.sh                      # prove it, do not assume it
```

On Windows, `irm https://innerwarden.com/free.ps1 | iex`.

`npm install -g innerwarden` is the other supported channel and adds npm
provenance, but on Linux it usually needs `sudo`: npm's prefix is root-owned on a
distro-packaged Node, so it fails with EACCES before InnerWarden is reached.
InnerWarden itself never needs root.

With an Enterprise licence, on Linux:

```sh
curl -fsSL https://innerwarden.com/install | sudo bash -s -- --license=/path/to/license.key
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
test. It reads the decision counter *before* it probes, so it cannot mistake its
own test calls for your traffic. Whatever it cannot demonstrate, it says so and
prints the command that fixes it.

```
== 3. is any agent actually wired to it ==
  FAIL  1 agent(s) found on this machine and NONE of them are wired
        The guard is installed and judging correctly, and your agent is not
        sending it anything. This is the state an evaluation mistakes for
        'it does not work'.
          innerwarden agents connect --all --monitor
        Then RESTART the agent.
```

Exit codes: `0` screening confirmed, `1` installed but nothing reaching it, `2`
not installed, `3` installed but judging wrongly.

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

---

## Links

- Product and pricing: <https://innerwarden.com>
- Documentation: <https://innerwarden.com/docs/install-and-first-run>
- Community source (Apache-2.0): <https://github.com/InnerWarden/inner-warden>
- Signed releases: <https://github.com/InnerWarden/innerwarden-releases/releases>

The Enterprise host stack is a licensed, source-available product and is not
open source. The Community guardrail is Apache-2.0 and its source is linked
above.

---

## Licence

The contents of this repository are Apache-2.0. See [LICENSE](LICENSE).
