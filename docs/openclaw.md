# InnerWarden with OpenClaw

What is screened for an OpenClaw agent depends on the Community version and on
OpenClaw's own version, and the person deserves to know exactly what before
they rely on it. Say it before you install, not after.

## What InnerWarden Community covers today

Since Community 1.6.11, `innerwarden agents connect openclaw` puts two things
in place.

**OpenClaw's own tools, through the plugin `innerwarden-guard`.** It is
installed in `~/.openclaw/extensions/innerwarden-guard` and enabled under
`plugins.entries.innerwarden-guard` in `~/.openclaw/openclaw.json`. OpenClaw
asks it, on its `before_tool_call` hook, about each call to its own `exec`,
`process`, `write`, `edit` and `apply_patch` before the call runs, and the
plugin asks InnerWarden: the same screening the Claude Code hook uses (the
general rules, the person's allow and mute rules, the per-agent profiles, and
for a file tool, where it writes, never what it writes), and where InnerWarden
Pro is installed, Pro's `check-command` too, with the stricter answer
standing. It needs **OpenClaw 2026.9.7 or newer**: on an older OpenClaw, do
not describe its own tools as screened.

- **Monitor** (the plugin's default, whatever mode `connect` used for the MCP
  servers) records what enforce would refuse and refuses nothing.
- **Enforce** (after `innerwarden enforce`): a denied call does not run, and
  the model is told only "Refused by InnerWarden."; a review asks the owner to
  allow it once or deny it, and no answer is a refusal.
- In enforce the plugin also refuses an agent's attempts to take it off or
  rewrite it: a file tool writing into `~/.openclaw/extensions` or
  `~/.openclaw/hooks`, removing them, `openclaw plugins disable|uninstall` of
  InnerWarden's plugin or hook, adding or enabling an OpenClaw plugin,
  `openclaw config set` of the plugin or MCP wiring, and `sed -i` on
  `openclaw.json`.

**Calls to OpenClaw's MCP servers, through the proxy, as before.** `connect`
rewrites each local server under `mcp.servers` in `~/.openclaw/openclaw.json`
so that it runs through the guard's proxy:

```
<path>/innerwarden proxy --label openclaw --agent openclaw --mode advisory|guard -- <original command>
```

`advisory` is monitor (records, refuses nothing) and `guard` is enforce.
Remote MCP servers (a `url` instead of a command) are left alone. If the file
has no local MCP servers, `connect` says so ("has no local MCP servers to
guard") and still installs the plugin, on the next line.

**Its stated limits.** Say these too:

- The plugin runs inside the OpenClaw gateway process, so it is as
  trustworthy as that process. Something that controls the gateway itself is
  not stopped by it; on a Linux host, InnerWarden Pro's kernel Execution Gate
  is the layer that does not depend on the gateway (below).
- A `write` or `edit` with a relative path is judged from the gateway's
  working directory.
- A plugin that rewrites a call and freezes its own rewrite under an approval
  of its own, before the guard answers, decides what runs; the guard records
  afterwards that the call ran other than as it was screened.

## Wiring it

The same choice as any agent ([`../SKILL.md`](../SKILL.md), step 2): the person
runs `innerwarden agents connect openclaw --monitor` in their own terminal, or
you run `innerwarden agents connect openclaw` (MCP servers in enforce, the
plugin still in monitor until `innerwarden enforce`). It prints, among its
lines:

```
  openclaw - its own tools (exec, process, write, edit, apply_patch) are screened by the plugin innerwarden-guard (<home>/.openclaw/extensions/innerwarden-guard), mode monitor
    monitor records what enforce would refuse and refuses nothing; `innerwarden enforce` turns refusals on
```

Then the OpenClaw gateway must be restarted, because it loads plugins and
reads their mode when it starts: "OpenClaw: Quit OpenClaw and start it
again." The same goes after `innerwarden enforce` or `innerwarden dry-run`.
`innerwarden agents list` then shows the MCP side on OpenClaw's row and the
plugin on a line of its own:

```
  openclaw      ✓ guarded (MCP proxy, monitor)
  OpenClaw's own tools: screened, monitor
```

With no local MCP servers the row reads "not guarded" while the second line
says "screened": the row only knows the MCP side. `innerwarden openclaw
status` prints the plugin's line alone.

**`innerwarden status` is wrong about this in 1.6.11.** For OpenClaw it still
says "Its built-in tools are not screened by this edition", even with the
plugin installed. Do not repeat that sentence: for OpenClaw, the line in
`agents list` ("OpenClaw's own tools: screened, monitor|enforce") is the
accurate one.

**When you are the OpenClaw agent**: since 1.6.11 the CLI recognises
OpenClaw's exec shell (`OPENCLAW_SHELL`) as an agent's shell, so
`agents disconnect`, `connect --monitor`, `install --monitor`, `contain`,
`dry-run`, `monitor` and `uninstall` refuse there as they do in Claude Code's.
With the plugin in enforce, they are refused before they run. Either way they
are the person's commands, and so are `allow` and `mute`; never route around a
refusal.

**Removing it**: `innerwarden agents disconnect openclaw` (the person's) takes
the plugin out as well as the proxy wrapping. Run it before
`innerwarden uninstall`, which leaves the plugin in place: a plugin left
calling a binary that is gone refuses every one of OpenClaw's own tool calls in
enforce.

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

Pro adds the layer underneath, where OpenClaw's built-in tools end up whatever
the plugin decided: the processes it starts and the domains it resolves. It
does not run inside the gateway, so it holds where the plugin's limits stop.

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
