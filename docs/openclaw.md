# InnerWarden with OpenClaw

What is screened for an OpenClaw agent is narrower than for Claude Code, and the
person deserves to know exactly how much before they rely on it. Say it before
you install, not after.

## What InnerWarden Community covers today

**Calls to OpenClaw's MCP servers.** `innerwarden agents connect` rewrites each
local server under `mcp.servers` in `~/.openclaw/openclaw.json` so that it runs
through the guard's proxy:

```
<path>/innerwarden proxy --label openclaw --agent openclaw --mode advisory|guard -- <original command>
```

`advisory` is monitor (records, refuses nothing) and `guard` is enforce.
Remote MCP servers (a `url` instead of a command) are left alone. If the file
has no local MCP servers, there is nothing to wire, and `connect` says so.

**Not covered: OpenClaw's own built-in tools**, its shell and file tools
included. `innerwarden status` says it in its own words: "judged before they
run: calls to its MCP servers. Its built-in tools are not screened by this
edition." Repeat that sentence to the person. Do not describe an OpenClaw
install as having its commands screened.

## Wiring it

The same choice as any agent ([`../SKILL.md`](../SKILL.md), step 2): the person
runs `innerwarden agents connect openclaw --monitor` in their own terminal, or
you run `innerwarden agents connect openclaw` to wire it in enforce. Then OpenClaw
must be restarted; the CLI prints "OpenClaw: Quit OpenClaw and start it
again." `innerwarden agents list` then shows:

```
  openclaw      ✓ guarded (MCP proxy, monitor)
```

One more thing to know when you are the OpenClaw agent: the CLI's
"an agent cannot lower its own guard" check does not recognise OpenClaw's shell
today, so it will not stop you. The rule is the same anyway: monitor, disconnect,
allow, mute and anything that loosens the guard are the person's commands.

## Recording what reaches the agent: observe

```sh
innerwarden observe install    # the person runs it; then restart the OpenClaw gateway
innerwarden observe status
```

This adds two things to OpenClaw: a hook that records dangerous asks arriving
in conversation (including ones the model refuses), and a small plugin that
records how each turn ended. The plugin is granted
`allowConversationAccess` in `openclaw.json`, which the person should know
before agreeing. It is **observation, not enforcement**, and it says so: if the
model declines and no tool call follows, no control was exercised. A model
saying no is not the guard working. `innerwarden upgrade` keeps it current.

## With InnerWarden Pro on a Linux host

Pro adds the layer underneath, where OpenClaw's built-in tools do end up: the
processes it starts and the domains it resolves.

```sh
sudo innerwarden-ctl agent connect --unit <OpenClaw's systemd unit>   # a user unit works too
```

pairs the gateway's unit with the host, so the Execution Gate and the userns
guard (and the Secret Read Guard, while it is kept on) are scoped to OpenClaw
and follow it across restarts. The DNS Guard is scoped separately
(`sudo innerwarden-config-sign dns-guard scope-agent --pid <PID> --apply`).
Armed in enforce, the Execution Gate refuses, in the kernel, a program
OpenClaw's processes try to run that was not authorised in advance, whichever
tool started it. Once it enforces, the free CLI in the user's home is not on
its allowlist either; `arm` lays a verified copy the gate trusts, and
`sudo innerwarden-ctl agent pin-guard-cli --pid <PID>` does that on its own.
Until then, in observe or rehearse, it records and blocks nothing. Turning
it on is in [`managing-pro.md`](managing-pro.md), and it is a decision for after
a week of watching, not part of the install. The per-agent controls for jailed
agents (Programs, Private files, DNS per agent) cover Claude Code only today.

## The ClawHub skill

`innerwarden-security` on ClawHub is the OpenClaw-shaped version of this
repository's skill; its source is
[`clawhub/innerwarden-security/SKILL.md`](../clawhub/innerwarden-security/SKILL.md).
Install it with the ClawHub CLI, run from OpenClaw's workspace folder (it
installs into the `skills/` folder there):

```sh
npx clawhub install @maiconburn/innerwarden-security
```
