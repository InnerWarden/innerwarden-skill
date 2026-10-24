---
name: innerwarden
description: Install, verify and run InnerWarden day to day. InnerWarden Community (free) screens an AI agent's shell commands and tool calls before they run, on Linux, macOS and Windows. InnerWarden Pro (paid) adds the host layer on Linux servers, with the kernel Execution Gate and a dashboard. Use when the user asks to install InnerWarden, protect an agent, install Pro on a server with a licence, reach the dashboard, check whether the guard is actually screening anything, read what it decided, move it from monitor to enforce, upgrade it, renew a licence, or remove it.
---

> **Which page?** Decide before you type anything.
>
> - **Installing on a SERVER, InnerWarden Pro, a licence, or the Pro dashboard
>   (port 8787):**
>   read [`docs/pro-on-a-server.md`](docs/pro-on-a-server.md) and follow it
>   start to finish. The paths diverge at the first command. **If the user
>   handed you an `ssh` command, they mean the server.**
> - **Already installed, and someone has to decide whether it WORKS:**
>   [`docs/evaluating-a-pilot.md`](docs/evaluating-a-pilot.md).
> - **Already installed, day to day** (is it on, what did it decide, a verdict
>   looks wrong, alerts, enforce, upgrade, licence, remove):
>   [`docs/managing-community.md`](docs/managing-community.md), and for a Pro
>   host also [`docs/managing-pro.md`](docs/managing-pro.md).
> - **The agent is OpenClaw:** read [`docs/openclaw.md`](docs/openclaw.md)
>   too. What is screened there is narrower than for Claude Code.
> - **Otherwise** (protect the agent on this machine, or the free CLI's own
>   dashboard, `innerwarden dashboard`): this page.

# Installing and verifying InnerWarden

You are setting up a guardrail that sits between an AI agent and the machine it
can act on. What the agent tries is screened first and comes back **allow**,
**review** or **deny**, with the reasons.

Which surface that covers depends on the agent, and there is one mechanism per
agent:

| Agent | How it is screened |
|---|---|
| Claude Code | a pre-execution hook on its `Bash` calls and on its file tools (`Write`, `Edit`, `MultiEdit`, `NotebookEdit`), plus a post-tool hook that remembers where a value came from |
| Codex CLI, Gemini CLI, Cursor | their MCP servers are rewired to run through the guard's proxy |
| OpenClaw | the same MCP proxy, so only calls to its MCP servers are screened; its built-in tools are not ([`docs/openclaw.md`](docs/openclaw.md)) |
| Aider | no hook and no MCP: the person starts it inside `innerwarden contain` |
| Goose, Windsurf, Cline | not wirable yet |

`innerwarden agents list` names the mechanism it used for each one. Read it
rather than assume.

There are three plans, and the free one is a complete product:

| | what it protects | where it runs |
|---|---|---|
| **InnerWarden Community** (free, Apache-2.0) | the agent: its commands and tool calls | Linux, macOS; Windows experimental |
| **InnerWarden Pro** (paid, per protected agent, <https://innerwarden.com/pricing>) | adds the host underneath: its own sensor, detectors, cases, response, and the kernel Execution Gate, Secret Read Guard and DNS Guard | Linux. Kernel enforcement is Linux only; on macOS and Windows the agent gets the free guardrail's screening |
| **Enterprise** | Pro for fleets, scoped with InnerWarden | as Pro |

Pro is source-available and paid. It is not open source; only Community is.
Its software is released under the name InnerWarden Active Defence, which is
what you will see on the release pages. Its tools are `innerwarden-ctl` and
`innerwarden-config-sign`, and `innerwarden host <command>` forwards to
`innerwarden-ctl`, so nothing learned on the free tier is thrown away.

## You are inside the thing being guarded

Read this before any command that changes the guard.

Since Community 1.6.6 an AI agent **cannot lower its own guard**. From inside
Claude Code, Codex or Gemini the CLI refuses, exits 1, changes nothing and says
so:

- `innerwarden agents connect ... --monitor`
- `innerwarden agents disconnect`
- `innerwarden install <agent> --monitor`
- `innerwarden contain` (its `--dry-run` is fine)
- `innerwarden allow` and `innerwarden mute` (they need a person at a terminal)
- `innerwarden dry-run` / `monitor` and `innerwarden uninstall` (since 1.6.9;
  `uninstall --dry-run` and every `--help` stay open)

In Claude Code, an enforcing hook blocks all of the above with exit 2, plus
turning a kernel control off and stopping InnerWarden's services. Agents wired
through the MCP proxy have no such hook on their shell. Treat every one of
these as the person's either way.

That is the product working. **Do not look for a way around it**: no unsetting
environment variables, no wrapper script, no other launcher, no `--operator`
flag. Hand the exact command to the person, say in one sentence why it is
theirs, and wait. The rule is the same for an agent the CLI does not recognise
(OpenClaw, Cursor, Aider and Goose are not detected today): you never lower,
pause, remove or loosen the guard yourself.

What you may run, because it only reads: `innerwarden --version`, `status`,
`agents list`, `check`, `graph`, `notify --test`, `allow --list`,
`mute --list`, every `--help`.

What tightens, and so is allowed to you, but only when the person chose
enforce (on a machine they set to monitor it overrides their choice):
`innerwarden agents connect <agent>` without `--monitor`, `innerwarden enforce`,
`innerwarden install claude-code`.

## Read this before you type anything

**On the machine the user works at, install the free CLI first.** It is the
front door and their muscle memory is built on it.

**On a SERVER, do not.** The Pro installer installs the free CLI itself when
none is present, as the human user. Follow
[`docs/pro-on-a-server.md`](docs/pro-on-a-server.md), which starts with the
host installer on purpose.

**`innerwarden setup` is safe for you to run.** It is an arrow-key wizard for
humans; with no terminal it prints a summary instead and configures nothing, so
it will not hang your session. The lines its summary suggests (connecting in
monitor, an `alias claude='innerwarden contain --identity -- claude'` for the
shell rc) are the person's. Use the explicit commands below.

**A hook is read at agent startup.** After any wiring or mode change the
person must restart the agent, and the CLI prints how for each one ("In Claude
Code, type /exit, then run claude.", "OpenClaw: Quit OpenClaw and start it
again."). Read that line back. A session that was already open keeps running
unscreened, and this is the single most common reason someone concludes the
product "does not work".

**Monitor first is the person's choice, and the person's command.** Monitor
records verdicts and blocks nothing; a week of real decisions before anything
is refused is what keeps a guard installed. Because monitor is lower than
enforce, you cannot set it from inside an agent. Offer the choice in step 2.

## The sequence

**Be on current versions.** At the time of writing, Community is 1.6.9 and Pro
is 0.17.2. Check what is actually installed rather than assuming:

```sh
innerwarden --version        # 1.6.9 or newer; it also names Pro when present
innerwarden-ctl --version    # only on a Pro host: 0.17.2 or newer
```

An older free CLI upgrades itself with `innerwarden upgrade` (installer copy) or
through the package manager that installed it.

### 1. Install the free CLI

```sh
# macOS and Linux
curl -fsSL https://innerwarden.com/free | sh
# Windows (experimental), in PowerShell
irm https://innerwarden.com/free.ps1 | iex
```

It picks the signed binary for the machine, checks its sha256 **and** its
Ed25519 signature before installing anything, and puts `innerwarden` (with the
short names `iw` and `iw-guard`) in `~/.local/bin`. No root at any point.

If `innerwarden` is not found afterwards, `~/.local/bin` is not on PATH:

```sh
export PATH="$HOME/.local/bin:$PATH"   # and add that line to the user's shell rc
```

An `export` does not last between your own commands in most agent shells, so
until the person opens a new terminal, call it by its path:
`~/.local/bin/innerwarden`.

npm is the other supported channel and carries npm provenance. On Linux with a
distribution's Node, `npm install -g` writes to a root-owned prefix and fails
with EACCES; that is npm, not the product:

```sh
npm install -g innerwarden
# on Linux, if that fails with EACCES:
sudo npm install -g innerwarden
# or give npm a prefix the user owns:
npm config set prefix ~/.npm-global   # then put ~/.npm-global/bin on PATH
```

`.deb`, `.rpm`, Scoop and from-source are at
<https://innerwarden.com/docs/installation>. Do not copy a version-pinned
filename into anything: it is stale the next release.

### 2. Wire the agent

```sh
innerwarden agents list     # what is on this machine, and what is not guarded yet
```

Wire the agent the user asked about, by the name `agents list` prints for it
(for example `claude-code` or `openclaw`). Do not use `--all` on your
own: it wires every agent it finds, including ones the user never mentioned,
and it rewires agents that are already set, resetting the mode the person chose
for them. Then put the choice to the person, in these words or close to them:

- **Monitor first (recommended for the first week).** They run, in their own
  terminal: `innerwarden agents connect <agent> --monitor`. It records what it
  would refuse and refuses nothing.
- **Enforce from the start.** You may run `innerwarden agents connect <agent>`
  yourself. Denials are real from the next restart.

If Pro is going on this machine too (step 3), install it **before** wiring
enforce: an enforcing guard holds the Pro install line when you run it.

Either way the agent must restart: **a session opened before the wiring is
still running unscreened.** If you are the agent being wired, set up the alerts
below first and ask for the restart last, because the restart ends this
conversation. Tell the person to ask the new session to run
`<absolute path to this repo>/scripts/verify-install.sh`.

To put the guard in front of an MCP server that `connect` did not wire, the
server's own command is wrapped in that agent's MCP config:

```sh
innerwarden proxy --mode advisory -- <server command>   # records only
innerwarden proxy --mode guard    -- <server command>   # blocks a denied call
```

Never change an existing `--mode guard` wrapper to `advisory`; that lowers the
guard, and it is the person's.

**If `connect` says an agent "does not exist yet" or "has no local MCP servers
to guard", running it again changes nothing. Stop looping.** That agent becomes
wirable when the user adds the MCP server they actually run, or when the
person starts the agent under `innerwarden contain -- <command>`.

For an agent on another machine, in a container you do not build, or in CI,
the local hook does not apply: read
[`docs/protecting-a-remote-agent.md`](docs/protecting-a-remote-agent.md).

Set up alerts while you are here. The second command is not optional:

```sh
innerwarden notify --telegram-token <T> --telegram-chat <C>
#   or --slack-webhook <URL>, --discord-webhook <URL>, --webhook-url <URL>
innerwarden notify --test
```

Ask the person for the token or webhook; never invent one, and do not echo it
back in your reply.

### 3. Add InnerWarden Pro, if there is a licence

Linux. Buying Pro at <https://innerwarden.com/pricing> emails the licence as a
file named `license.txt` (it is also on <https://innerwarden.com/account>).

> **On a REMOTE server, or asked for the dashboard?** Read
> [`docs/pro-on-a-server.md`](docs/pro-on-a-server.md) instead of this section
> and follow it exactly. It covers what to ask for first, the sudo-password case
> you cannot solve from a script, the dashboard and its tunnel, and the one
> mistake that can lock the user's terminal.

```sh
curl -fsSL https://innerwarden.com/install | sudo bash -s -- --license=/path/to/license.txt
```

- **The `=` matters.** `--license /path` with a space is rejected on purpose,
  so a mistyped flag cannot quietly leave the host on the free tier.
- **The value is a local file.** If the licence arrived as a link, download it
  first: `curl -fsSL <url> -o ~/license.txt` (not `/tmp`, where anyone on the
  machine can read it).
- **From inside an agent that is already wired in enforce, the guard holds this
  line** (an unreviewed download piped into a shell is held for an agent), and
  `sudo` has no terminal in your shell to ask for a password. Both are correct.
  Hand the line to the person for their own terminal, or install Pro before
  wiring enforce in step 2. If it is refused, do not rephrase it to get past
  the guard.
- **Never give that command a terminal it does not need.** Run it over `ssh`
  without `-t`. With no usable terminal the installer skips its interactive
  wizard and says so, which is what you want; the server document explains why.
- **The host layer comes up observing**: it watches, explains, and blocks
  nothing until the person decides otherwise. The installer also wires its own
  agent hook in **monitor** and prints `Agent hook: MONITOR`. Read that line
  back.
- **On Debian and Ubuntu without `bpf` in the boot LSM list, the installer
  edits the bootloader** (`/etc/default/grub.d/99-innerwarden-lsm.cfg`, then
  `update-grub`) and prints REBOOT REQUIRED. It never reboots. On RHEL, Rocky,
  Alma and Fedora it edits nothing and prints the `grubby` command instead. Say
  this BEFORE you run the installer: it changes how the machine boots, and no
  kernel control can enforce until it reboots.

### 4. Prove it, do not assume it

```sh
./scripts/verify-install.sh
```

Run it from this repository. It does not check that files exist. It sends real
commands through the guard and reads the verdicts, then reports what it could
**not** demonstrate and the exact command that fixes each one.

Exit codes: `0` confirmed, `1` installed but nothing is reaching it, `2` not
installed, `3` installed but the engine is judging wrongly.

The first run ends in **"Wiring confirmed"**: the engine judges, the hook
refuses, an agent is wired. It cannot know whether the running agent goes
through the guard, because commands run by hand are recorded too. So it prints
a one-off token and the last step:

1. the person restarts the agent;
2. the restarted agent runs `echo iw-proof-<token>` (an agent wired through the
   MCP proxy: any call to one of its MCP tools with the token in it, since its
   own shell is not screened);
3. `./scripts/verify-install.sh --proof iw-proof-<token>`.

Only that run can say **"Screening confirmed"**, and it is the one to report.
Running the token through `innerwarden check` yourself does not count, by
design.

Do not tell the user the install succeeded until this exits 0. "It installed
without errors" and "it is protecting you" are different claims, and the gap
between them is where an evaluation goes wrong.

## After it is working

Day-to-day running lives in
[`docs/managing-community.md`](docs/managing-community.md) (and
[`docs/managing-pro.md`](docs/managing-pro.md) on a Pro host). Read the command
surface from the tool itself rather than from any list, including this one:

```sh
innerwarden --help              # every verb, from the binary that is installed
innerwarden <verb> --help       # one verb in detail; --help never changes anything
innerwarden host --help         # the Pro host layer, same command
```

The ones worth showing a new user, in this order:

```sh
innerwarden status                       # is it on, and what each agent's guard covers
innerwarden check "rm -rf /"             # ask for a verdict directly
innerwarden graph                        # what has been screened, and how it ended
innerwarden notify --test                # do the alerts arrive
innerwarden allow "<glob>"               # the PERSON's: stop asking about a trusted command
innerwarden enforce                      # when the person decides: denials become real, THEN restart
```

`innerwarden dashboard` is a **foreground server** on <http://127.0.0.1:8788>,
not a one-shot command: it does not return. Background it or give it a terminal
the user owns. On a remote machine reach it with
`ssh -L 8788:127.0.0.1:8788 <host>`. Never expose it: it has no login.
`innerwarden status` looks for it at `http://127.0.0.1:8788/api/meta`.

## Things that will cost you an hour if you skip them

- **Every mode change needs a restart, not just the first wiring.** `connect`,
  `dry-run` and `enforce` all print the restart line; read it back, especially
  after `enforce`. `innerwarden agents list` reads the config on disk, so it
  shows the new mode at once and is NOT evidence the running session picked it
  up.
- **Counting decisions does not prove traffic is flowing.** Running
  `innerwarden check` yourself records decisions too, and so does the verify
  script. Only the `--proof` token, run by the agent itself, proves it.
- **On a Pro host the agent unit reads `inactive` while running.** The watchdog
  owns its lifecycle. Never `systemctl start innerwarden-agent` there.
- **The kernel Execution Gate needs `bpf` in the boot LSM list**
  (`grep bpf /sys/kernel/security/lsm`). Without it the gate enforces nothing;
  detection and response are unaffected.
- **Do not arm the kernel controls during an install or an evaluation's first
  day.** They are agent-scoped and deliberate, and they come last.

## Removing it

A pilot has an end date, so know this before it starts. Removal lowers the
guard, so **the person runs these, in their own terminal**; give them the list:

```sh
innerwarden agents disconnect --all   # FIRST, while the binary still exists
# restart every agent that was connected
innerwarden uninstall                 # removes the installer's copy; apt, dnf or npm remove theirs
rm -rf ~/.config/innerwarden          # local state and the decision log
```

The first line comes first because `innerwarden uninstall` unwires Claude Code
only. Every other agent was wired by rewriting its MCP config to call the guard
by absolute path, so removing the binary first leaves those servers pointing at
a path that no longer exists, and the command that would have fixed it went
with the binary. `innerwarden uninstall --dry-run` shows what it would remove.

For a Pro host, [`docs/managing-pro.md`](docs/managing-pro.md) has the full
order: kernel controls off first, then `sudo innerwarden-ctl uninstall`.

## What to tell the user when you are done

Report what you did and what you proved, then get out of the way. The product
is built to be tested, so let them test it rather than reading claims from you.

Say:

- which plan is installed and on which machine;
- that their agent is wired **and that they must restart it**;
- whether it is in **monitor** (records, blocks nothing yet) or **enforce**;
- that `./scripts/verify-install.sh --proof <token>` exited 0 and said
  "Screening confirmed", which means the running agent's own command reached
  the guard (or, if the restart has not happened yet, that the last step is
  still theirs).

Then give them the two things to do next, in this order:

```sh
innerwarden check "<something you would never want an agent to run>"
innerwarden graph            # after a day of normal work: their traffic, judged
```

That second one is the evaluation: their own commands, with verdicts and
reasons. If the verdicts match what they would have decided, `innerwarden
enforce` makes the denials real. If one does not, they run
`innerwarden allow "<glob>"` at their own terminal.

Do not characterise the product's limits for them, and do not promise coverage.
Point them at [`docs/what-it-does.md`](docs/what-it-does.md) and let the tool
answer for itself. Facts they need BEFORE they start are different, and you
SHOULD state those plainly: which platforms enforce in the kernel (Linux only),
that the Execution Gate needs `bpf` in the boot LSM list, that a licence file
selects Pro, and, for OpenClaw, what is and is not screened.
[`docs/platforms.md`](docs/platforms.md) has them.
