# InnerWarden: install, wire, verify

## Which job is this? Decide before you type anything

Two different jobs live in this repository and they diverge at the FIRST
command. Pick by what the user actually asked for.

**If the user mentioned a server, an `ssh` command, the Enterprise or Active
Defence tier, a licence, or a dashboard, this is the SERVER job.** Read
[`docs/active-defence-on-a-server.md`](docs/active-defence-on-a-server.md) now
and follow it in order, start to finish. It is written for exactly this shape:
you on the user's machine, a Linux server over SSH. Do not improvise around it
and do not start from the free-CLI instructions below; that is a different
product and it will not give them what they asked for.

**If the user wants their own AI agent screened** (Claude Code, Cursor, Codex on
the machine in front of them), read [`SKILL.md`](SKILL.md).

**If you cannot tell, ask one question** before running anything: *is this to
protect an AI agent on a machine, or to install the licensed host layer on a
server?*

## The one mistake that ends the session

When the Enterprise installer finishes it tries to launch an interactive setup
wizard through `sudo`. Modern sudo ships `Defaults use_pty`, so the wizard lands
on a pty that sudo created while the user types into a different one. Arrow keys
print as `^[[B`, ENTER does nothing, and **Ctrl+C does not work**. The user's
terminal is wedged and the only escape is `ENTER`, `~`, `.`

So: **never allocate a terminal for the install.** Run it over `ssh` WITHOUT
`-t`. The installer then reports `No usable TTY (headless/piped install) -
skipping interactive setup`, which is the outcome you want and is confirmed
working on a clean Ubuntu 26.04 host. Everything that matters is already
configured by the time that wizard would have run.

## If you only read four more lines

1. **Ask the user for what only they can give you**, as you need it: the server
   and key, the licence file, whether `sudo` needs a password. Never ask for a
   password or a private key's contents; hand them the command instead.
2. **Install the free CLI with the shell installer**, not npm:
   `curl -fsSL https://innerwarden.com/free | sh` (Windows: `irm
   https://innerwarden.com/free.ps1 | iex`). `npm install -g innerwarden` needs
   `sudo` on Linux, where npm's prefix is root-owned, and fails with EACCES
   otherwise.
3. **After wiring an agent, tell the user to RESTART it.** The hook is read at
   agent startup, so a session already open stays unscreened. This is the single
   most common reason someone concludes the product does not work.
4. **Do not report success until you have verified it.** For an agent install,
   `./scripts/verify-install.sh` must exit 0. For a server install, the checks in
   step 4 of the server document must pass and you must read the output back to
   the user. "Installed without errors" and "protecting you" are different
   claims.

Read the command surface from `innerwarden --help` and `innerwarden-ctl --help`
on the machine, never from a list in documentation. Lists drift from what ships.
