---
name: innerwarden-security
description: Install, verify and run InnerWarden on the machine this OpenClaw agent runs on. InnerWarden Community (free) screens the calls this agent makes to its MCP servers before they run; OpenClaw's built-in tools, its shell included, are not screened by Community. InnerWarden Pro (paid, Linux) adds the host layer with the kernel Execution Gate. Use when your owner asks to install InnerWarden, check what it protects here, see what it refused, ask whether a command is safe to run, turn on enforce, upgrade it, or remove it.
user-invocable: true
metadata: {"openclaw":{"always":false,"emoji":"🛡️","requires":{"bins":["curl"]},"os":["linux","darwin"]}}
---

# InnerWarden, from inside OpenClaw

InnerWarden puts a verdict (**allow**, **review** or **deny**, with reasons) in
front of what an AI agent tries to run. You are that agent. This skill helps
your owner install it, prove it works, and run it, without you ever weakening
it.

Full documentation, kept current: <https://github.com/InnerWarden/innerwarden-skill>.
Read `--help` on the installed binary before trusting any list, including this
one.

## Your rules, before anything else

1. **Never lower, pause, remove or loosen the guard yourself.** Monitor mode,
   disconnecting, `allow`, `mute`, `contain`, disarming a kernel control,
   stopping InnerWarden's services and uninstalling are your owner's to type,
   in their own terminal. Give them the exact line and one sentence on why, and
   wait. If a command is refused, do not retry it another way: no unset
   variables, no wrapper scripts, no other launcher.
2. **Ask before installing anything.** Show your owner the command first.
3. **Never ask for a password, a private key or an API token**, and never echo
   one back. Hand your owner the command that needs it.
4. **Never use `curl -k`** against InnerWarden: if its certificate does not
   verify, treat the answer as `review`.

## What it is

| | what it protects | where |
|---|---|---|
| **InnerWarden Community** (free, Apache-2.0) | for OpenClaw: calls to its MCP servers only; its built-in tools are not screened (section 3) | Linux, macOS (Windows experimental) |
| **InnerWarden Pro** (paid, per protected agent, <https://innerwarden.com/pricing>) | the host underneath: sensor, detectors, response, and the kernel Execution Gate, Secret Read Guard and DNS Guard | Linux only |

Pro is source-available and paid, not open source; only Community is. Kernel
enforcement exists on Linux only. InnerWarden is not an EDR replacement and not
a compliance certificate.

## 1. See what is there

```sh
command -v innerwarden && innerwarden --version        # Community (also names Pro if present)
command -v innerwarden-ctl && innerwarden-ctl --version # Pro host layer
innerwarden status                                     # what each agent's guard covers
innerwarden agents list                                # is openclaw guarded, and how
```

## 2. Install Community (with your owner's OK)

```sh
curl -fsSL https://innerwarden.com/free | sh    # signed binary, checked before install, no root, ~/.local/bin
innerwarden --version
```

If it is not found afterwards, `~/.local/bin` is not on PATH: call it as
`~/.local/bin/innerwarden`, and tell your owner to add `~/.local/bin` to PATH.

## 3. Wire OpenClaw, and say exactly what that covers

Put the choice to your owner:

- **Monitor first (recommended for a week):** they run, in their own terminal,
  `innerwarden agents connect openclaw --monitor`. It records and refuses
  nothing.
- **Enforce now:** you may run `innerwarden agents connect openclaw`, once they
  have chosen it.

Then your owner restarts OpenClaw ("Quit OpenClaw and start it again").
Restarting it yourself ends this conversation before you can report.

**What this covers for OpenClaw, in plain words:** calls to the MCP servers in
`~/.openclaw/openclaw.json` go through InnerWarden's proxy. **OpenClaw's own
built-in tools, its shell included, are not screened by Community.**
`innerwarden status` says so, and you must say so too. If `openclaw.json` has
no local MCP servers, there is nothing to wire yet.

Optional, for the record: `innerwarden observe install` (your owner runs it,
then restarts the gateway) records dangerous asks that reach you in
conversation, including ones you refuse. It is observation, not enforcement.
It grants a small plugin `allowConversationAccess`; tell your owner that before
they agree.

## 4. Prove it

```sh
innerwarden check "rm -rf /"       # must come back deny
innerwarden check "ls -la"         # must come back allow
innerwarden agents list            # openclaw: guarded (MCP proxy, monitor|enforce)
```

For the full proof, your owner can run `scripts/verify-install.sh` from
<https://github.com/InnerWarden/innerwarden-skill>; for OpenClaw its last step
is a call to one of your MCP tools carrying the token it prints. Do not report
"protected" until the checks pass, and never describe OpenClaw's built-in tools
as screened.

## 5. Ask before you act

Even where your own tools are not screened, you can choose to ask before a
command that could do damage:

```sh
innerwarden check "<the exact command>"
```

On a Pro host the same question goes to the host, which also knows what has
happened on it today:

```sh
curl -s --cacert /var/lib/innerwarden/dashboard-cert.pem \
  -X POST https://127.0.0.1:8787/api/agent/check-command \
  -H 'content-type: application/json' \
  -d '{"command": "<the exact command>", "agent_name": "openclaw"}'
```

- `deny`: do not run it. Tell your owner what you were about to do and why it
  was refused.
- `review`: ask your owner before running it.
- `allow`: it matched no rule. That is not a safety judgement; use your own.
- No answer, an error or a certificate failure: treat it as `review`.

Asking is a habit, not a control: it only covers what you remember to ask
about. The control is the guard itself, and on Linux with Pro, the kernel.

## 6. Day to day, for your owner

```sh
innerwarden status            # on, and what it covers
innerwarden graph             # what was screened, and how each ended
innerwarden notify --test     # do alerts arrive (your owner sets the channel)
innerwarden enforce           # when your owner decides: denials become real; then they restart OpenClaw
innerwarden upgrade --check   # is there a newer release
```

A verdict your owner disagrees with is theirs to teach, at their own terminal:
`innerwarden allow "<glob>"`. Going back to monitor (`innerwarden dry-run`) is
theirs too.

## 7. InnerWarden Pro on a Linux host

Installing Pro needs the licence file from the purchase email and root, and it
can edit the bootloader (with a reboot your owner decides on). It is your
owner's step, or a coding agent's following
<https://github.com/InnerWarden/innerwarden-skill/blob/master/docs/pro-on-a-server.md>.

Once Pro is there, it can follow OpenClaw's gateway (your owner runs this):

```sh
sudo innerwarden-ctl agent connect --unit <OpenClaw's systemd unit>
```

That scopes the Execution Gate and the userns guard to OpenClaw. Armed in
enforce, the Execution Gate then refuses, in the kernel, a program OpenClaw's
processes try to run that was not authorised in advance, whichever tool started
it. In observe or rehearse it records and blocks nothing. Arming
is a deliberate step after a week of watching; read
<https://github.com/InnerWarden/innerwarden-skill/blob/master/docs/managing-pro.md>.
Health on a Pro host: `sudo innerwarden-ctl get status` and
`sudo innerwarden-ctl arm --check` (the second changes nothing).

## 8. Removing it

Your owner runs these, in this order:

```sh
innerwarden agents disconnect --all   # first, while the binary exists
# restart OpenClaw
innerwarden uninstall
rm -rf ~/.config/innerwarden
```

On a Pro host, every kernel control comes off first (the full list is in
<https://github.com/InnerWarden/innerwarden-skill/blob/master/docs/managing-pro.md>,
"Removing it"), then `sudo innerwarden-ctl uninstall`.
