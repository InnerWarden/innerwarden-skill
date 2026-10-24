# What InnerWarden is, for someone deciding whether to run it

Written for a human evaluating the product, not for the agent doing the install.

## The problem it addresses

An AI coding agent has a shell. That is the point of it, and it is also the
exposure. The agent can be prompt-injected by a file it reads, an issue it is
asked to triage, or a web page it fetches. It can also simply be wrong: it
misreads a path and deletes the wrong directory, or it pipes a URL to a shell
because that is what the README said.

In every one of those cases the dangerous thing is the same: **a command reaches
the machine without a human having looked at it.**

Reviewing every command yourself defeats the purpose of the agent. Reviewing none
is what people actually do.

## What it puts in the way

A screening step between the agent and execution. What the agent tries gets a
verdict before it runs, over whichever surface that agent exposes: a
pre-execution hook for Claude Code; for OpenClaw (Community 1.6.11 or newer,
OpenClaw 2026.9.7 or newer) a plugin on its `before_tool_call` hook for its own
`exec`, `process`, `write`, `edit` and `apply_patch`, plus its MCP servers; the
MCP path for Cursor, Codex and Gemini (for those, calls to their MCP servers,
not their built-in tools).

- **allow** with a reason,
- **review** when it is ambiguous and a human should look,
- **deny** with the signals that produced the refusal.

The verdict is computed **on your machine**. No command is sent anywhere for a
judgement, there is no control plane, no account, and no service that has to be
up for the guard to work.

## Three plans

**InnerWarden Community**, free and Apache-2.0, protects the agent: its commands
and its tool calls. Linux and macOS; Windows experimental. This is a complete
product and it is what most people run.

**InnerWarden Pro**, paid and source-available (not open source), protects the
host underneath: its own sensor, host detectors, cross-layer correlation,
evidence-backed response, and the kernel Execution Gate, which, once enforcing,
lets nothing the guarded agent starts execute unless it was authorised in
advance (the host itself is never gated). Linux only. Its
software is released under the name InnerWarden Active Defence.

**Enterprise** is Pro for fleets, scoped with InnerWarden.

Pro adds its own tools (`innerwarden-ctl`) beside the same `innerwarden`
command, and `innerwarden host` reaches them. Nothing learned in the free tier
is discarded when a licence is added, and an evaluation can start free and grow
without redoing anything.

**What it is not.** It is not a replacement for endpoint detection and response,
backups or patching, and it is not a compliance certificate. It reduces risk; it
does not promise that every attack is caught.

## The design decisions worth knowing

**Observe before enforce is the recommended start.** Monitor records and blocks
nothing, and the person turns it on from their own terminal; wiring an agent
without `--monitor` enforces at once. Pro's host layer installs observing, and
its kernel controls are armed later, on purpose. A week of real decisions on
your own traffic before anything is refused is what keeps a guard installed: one
that blocks something legitimate on its first day gets uninstalled on its
second, and the product is built around that fact.

**It says when it cannot tell.** An allow verdict reads *"no rule matched
(absence of a match is not a safety judgement)"*, because those are different
statements and conflating them is how a security tool earns trust it has not
got. The same discipline runs through the product: a capability it could not
measure is reported as not measured, never as passing.

**Refusing to answer is a feature.** Where a check cannot be performed honestly,
the product declines rather than guessing. Telling an operator their protection
is broken when it is fine destroys the tool's usefulness faster than having no
check at all.

**Your data stays yours.** Decisions, the audit trail and the local dashboard are
all on your machine. There is no telemetry about your commands. InnerWarden
Pro's installer sends an install ping, and a Pro host sends an anonymous daily
heartbeat and a daily licence check; what each carries, and how to switch the
first two off, is at <https://innerwarden.com/privacy>.

## Judge it on your own traffic, not on ours

Every claim above is testable on your machine in an afternoon, and you should
test it rather than take it. The section below is how.

The product is built to be checked. Where a capability cannot be measured
honestly it reports "not measured" rather than passing, and an allow verdict
says in words that it is not a safety judgement. Point that scepticism at the
product itself: run your own dangerous commands through `innerwarden check`, run
your real work through it in monitor mode, and see whether the verdicts match
what you would have decided.

## How to evaluate it in an afternoon

1. Install the free CLI, wire your agent, restart it.
2. Run `./scripts/verify-install.sh`. Do not accept "it installed" as an answer;
   accept that script exiting 0.
3. Work normally for a day in monitor mode.
4. Read `innerwarden graph`. That is your traffic, judged, with reasons.
5. Decide whether the verdicts match your judgement. That is the real question,
   and it is the only one worth answering before you enforce anything.

If it disagrees with you, `innerwarden allow "<glob>"` teaches it. If it agrees,
`innerwarden enforce` makes the denials real.

## Getting a licence

InnerWarden Pro is priced per protected agent and bought at
<https://innerwarden.com/pricing>. The licence arrives as a file attached to the
purchase email (`license.txt`, also downloadable from
<https://innerwarden.com/account>), renews itself on the host while the
subscription runs, and is what selects the paid tier at install time:

```sh
curl -fsSL https://innerwarden.com/install | sudo bash -s -- --license=/path/to/license.txt
```

If it lapses, the host keeps running in free mode: within about a minute the
paid controls turn off and a High "Licence: Free Mode" alert says so; a valid
licence brings them back without a restart. Enterprise is scoped on request
from the same page.
