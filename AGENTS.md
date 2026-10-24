# InnerWarden: install, verify, run

## Which job is this? Decide before you type anything

Several jobs live in this repository and they diverge at the FIRST command.
Pick by what the user actually asked for.

**If the user mentioned a server, an `ssh` command, InnerWarden Pro, a
licence, or the Pro dashboard (port 8787), this is the SERVER job.** (The free
CLI's own dashboard is `innerwarden dashboard`; see [`SKILL.md`](SKILL.md).) Read
[`docs/pro-on-a-server.md`](docs/pro-on-a-server.md) now and follow it in order,
start to finish. It is written for exactly this shape: you on the user's
machine, a Linux server over SSH. Do not improvise around it and do not start
from the free-CLI instructions; that path will not give them what they asked
for.

**If the user wants their own AI agent screened** (Claude Code, Codex, Gemini,
Cursor, OpenClaw on the machine in front of them), read [`SKILL.md`](SKILL.md).

**If it is already installed** and the question is "is it on", "what did it
decide", "why did it refuse this", "turn on enforce", "upgrade it", "the
licence", or "remove it", read
[`docs/managing-community.md`](docs/managing-community.md), and on a Pro host
also [`docs/managing-pro.md`](docs/managing-pro.md).

**If you cannot tell, ask one question** before running anything: *is this to
protect an AI agent on a machine, or to install InnerWarden Pro on a server?*

## The rule that is new since the last time you read this

**You cannot lower the guard that screens you, and you must not try.** The CLI
refuses, from inside Claude Code, Codex or Gemini, and since 1.6.11 OpenClaw's
exec shell, the commands that loosen it:
`allow` and `mute` since 1.5.4, `agents connect --monitor`, `agents disconnect`
and `contain` since 1.6.6, `install --monitor` since 1.6.8, `dry-run`, `monitor`
and `uninstall` since 1.6.9. In Claude Code an enforcing hook blocks them too,
and in OpenClaw so does the `innerwarden-guard` plugin in enforce. Hand those
commands to the person, say why, and wait. Never route around a refusal, and
follow the same rule in an agent the CLI does not recognise.

## The one mistake that ends the session

When the Pro installer finishes it may launch an interactive setup wizard
through `sudo`. On a host whose sudo has `Defaults use_pty`, the wizard can land
on a pty that sudo created while the user types into a different one: arrow
keys print as `^[[B`, ENTER does nothing, and **Ctrl+C does not work**. It can
wedge the session; the escape is `ENTER`, `~`, `.`

So: **never allocate a terminal for the install.** Run it over `ssh` WITHOUT
`-t`. The installer then reports `No usable TTY (headless/piped install) -
skipping interactive setup`, which is the outcome you want. Everything that
matters is already configured by the time that wizard would have run.

## If you only read four more lines

1. **Ask the user for what only they can give you**, as you need it: the server
   and key, the licence file, whether `sudo` needs a password. Never ask for a
   password or a private key's contents; hand them the command instead.
2. **Lead with the shell installer for the free CLI:**
   `curl -fsSL https://innerwarden.com/free | sh` (Windows, experimental:
   `irm https://innerwarden.com/free.ps1 | iex`). It needs no root. npm is
   equally supported, but on Linux `npm install -g innerwarden` often fails
   with EACCES, because npm's prefix is root-owned there; that is npm, not the
   product.
3. **After wiring an agent, tell the user to RESTART it.** The hook is read at
   agent startup, so a session already open stays unscreened. This is the single
   most common reason someone concludes the product does not work.
4. **Do not report success until you have verified it.** For an agent install,
   `./scripts/verify-install.sh --proof <token>` must exit 0 and say "Screening
   confirmed" (the first run prints the token and how to use it). For
   a server install, the checks in step 6b of the server document must pass and
   you must read the output back to the user. "Installed without errors" and
   "protecting you" are different claims.

Read the command surface from `innerwarden --help` and `innerwarden-ctl --help`
on the machine, never from a list in documentation. Lists drift from what ships.
