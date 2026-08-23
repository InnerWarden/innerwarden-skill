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

A screening step between the agent and execution. Every shell command and MCP
tool call gets a verdict before it runs:

- **allow** with a reason,
- **review** when it is ambiguous and a human should look,
- **deny** with the signals that produced the refusal.

The verdict is computed **on your machine**. No command is sent anywhere for a
judgement, there is no control plane, no account, and no service that has to be
up for the guard to work.

## Two tiers, one command

**Community**, free and Apache-2.0, protects the agent: its commands and its tool
calls. Linux, macOS and Windows. This is a complete product and it is what most
people run.

**Enterprise**, licensed, protects the host underneath: an eBPF sensor, host
detectors, cross-layer correlation, autonomous response, and the kernel
Execution Gate, which pre-authorises what is allowed to execute at all. Linux
today. macOS and Windows are in development.

Enterprise adds capability under the **same `innerwarden` command**. Nothing
learned in the free tier is discarded when a licence is added, and an evaluation
can start free and grow without redoing anything.

## The design decisions worth knowing

**Observe before enforce.** Every enforcing control starts in a mode that records
and blocks nothing. You get to see a week of real decisions on your own traffic
before anything is refused. A guard that blocks something legitimate on its first
day gets uninstalled on its second, and the product is built around that fact.

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
all on your machine. There is no telemetry about your commands.

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

The Enterprise tier is licensed per host and the licence is a file you are
issued. It is what selects the paid tier at install time:

```sh
curl -fsSL https://innerwarden.com/install | sudo bash -s -- --license=/path/to/license.key
```

Pricing is not published. See <https://innerwarden.com/pricing> to start that
conversation.
