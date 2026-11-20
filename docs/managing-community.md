# Running InnerWarden Community day to day

For an agent helping someone whose guard is already installed and wired. If it
is not installed yet, start at [`../SKILL.md`](../SKILL.md). If the machine also
runs InnerWarden Pro, read [`managing-pro.md`](managing-pro.md) as well.

Read the command surface from the binary in front of you (`innerwarden --help`,
`innerwarden <verb> --help`). `--help` never changes anything. What follows is
the order things usually come up in, and who may do each one.

## Who does what

You are an AI agent, and the guard you are managing screens you. The CLI
refuses, inside Claude Code, Codex or Gemini, since 1.6.11 OpenClaw's exec
shell and since 1.6.15 Hermes Agent's shell (a script they run included), connecting or installing in monitor,
disconnecting, starting a jail, `allow`, `mute`, and since 1.6.9 `dry-run` /
`monitor` and `uninstall`. An enforcing Claude Code hook blocks the same
(since 1.6.15 so do the enforcing hooks of Codex, Gemini and Hermes), and
so does OpenClaw's `innerwarden-guard` plugin in enforce. Treat every lowering command as the person's,
whatever the agent and whatever lets it through. That is the product working,
not something to route around.

Since 1.6.12 an enforcing hook also refuses a write from the shell to what
carries the guard (the agent settings that load its hook, the guard's
configuration, the `innerwarden` program) and a line that names the guard and
holds a part it cannot read, such as a program run from a variable. That
refusal reads like the one for a lowering command. Write such a line with
every program named in plain sight (`ssh -i <key> <user>@<host> '...'`, not
`$SSH '...'`) and run it again; if the plain line is refused too, it is the
person's. Copying a new
`innerwarden` binary into place, or writing a project's `.mcp.json` or
`.claude/settings.json` from the shell, is refused by the same rule and is the
person's to run.

Since 1.6.13 an enforcing hook also refuses starting another agent without the
hook that screens it (Claude Code in its bare, safe or restricted mode, or with
settings or a variable that switch its hooks off or move them), a container
that hands the agent the host, and a Claude Code `Read`, `Grep` or `Glob` of a
secret, judged as `cat` of the same file is (`~/.ssh/config` and a stored login
included). Since 1.6.14 it also gives a command inside `sh -c` the verdict
the same command typed directly gets, refuses every shell write of
`authorized_keys`, the sudo rules, a crontab, a stored credential or
`~/.ssh/config`, and refuses running the guard's own hook. Since 1.6.15 it
holds for review a line with a part it cannot read (a command substitution,
a variable the line does not set) where that part names the program, is code
a shell or an interpreter runs, or is what the line writes to; write the
value out, and if the plain line is held too, it is the person's. It also
refuses an agent switching its own hook off, and `innerwarden mcp approve`
and `forget`. The rest of the list, and what ordinary work it costs, is in
[`../SKILL.md`](../SKILL.md), "You are inside the thing being guarded".

| You may run it | Only the person runs it, in their own terminal |
|---|---|
| `innerwarden status`, `agents list`, `check`, `graph`, `notify --test`, `demo` (1.6.14), `mcp list` (1.6.15) | `innerwarden agents connect ... --monitor` |
| `allow --list`, `mute --list`, every `--help` | `innerwarden agents disconnect` |
| `innerwarden agents connect <agent>` (enforce, only when the person chose it) | `innerwarden install <agent> --monitor` |
| `innerwarden enforce`, `innerwarden install claude-code` (same condition) | `innerwarden dry-run` (back to monitor) |
| `innerwarden contain --dry-run -- <command>` | `innerwarden contain ...` (starting a jail, `--pass-env` included) |
| `innerwarden upgrade --check` | `innerwarden allow "<glob>"`, `innerwarden mute <rule>` |
| | `innerwarden mcp approve`, `innerwarden mcp forget` (1.6.15) |
| | `innerwarden graph --clear`, `innerwarden uninstall` |

When a command is the person's, give them the exact line and one sentence on
why, then wait. If the CLI or the hook refuses you, do not retry it another
way. The refusal itself tells the person: "only you can authorise a blocked
command, from your own terminal".

## Is it on?

```sh
innerwarden status        # per agent: what is judged before it runs, and what is not
innerwarden agents list   # per agent: guarded or not, and the mechanism (hook, MCP proxy, OpenClaw's plugin)
```

`status` speaks plainly about coverage. From 1.6.11 to 1.6.14 it had one
known exception: for OpenClaw it said "Its built-in tools are not screened
by this edition", even when the `innerwarden-guard` plugin was installed and
screening them. Since 1.6.15 it names the plugin and its mode. On an older
CLI, read for OpenClaw the line `agents list` prints, "OpenClaw's own tools:
screened, monitor" (or `enforce`), which is the accurate one, and do not
repeat the old `status` sentence. For every other agent, repeat what `status`
says; do not improve on it.

For Codex, Gemini and Hermes, `status` in 1.6.15 says what their own hook
screens, line by line, and what it leaves out. When it says the hook is not
on (not written, not trusted by Codex, not approved in Hermes, or its
program gone), the line names the step that fixes it, usually
`innerwarden agents connect <agent>` (yours once the person chose enforce;
the `--monitor` form is the person's), then a restart of that agent.

For Claude Code, `status` in 1.6.13 names the read tools it judges. When its
line is `[off]` and says the read tools "can read a private key or a stored
login unchecked", the hook was wired before 1.6.13: rewire it as the line
says (`innerwarden install claude-code` once the person chose enforce; the
`--monitor` form is the person's), then restart Claude Code.

`agents list` reads the configuration on disk. It shows a new mode at once and
is NOT evidence that a running session picked it up: only a restart does that.

The strongest single check is still the script in this repository:

```sh
./scripts/verify-install.sh   # exit 0 and "Screening confirmed" is the bar
```

## What did it decide?

```sh
innerwarden graph            # sessions and commands, with verdicts and how each ended
innerwarden graph --stats    # one line: sessions, commands, verdict counts
innerwarden dashboard        # the same, in a browser; see below
```

Every decision is also written to the local decision log (under
`~/.config/innerwarden`, or `/var/lib/innerwarden/guard/` on a Pro host), with
the command, the verdict and the reason. Nothing is sent anywhere to reach a
verdict.

`innerwarden dashboard` is a **foreground server** on <http://127.0.0.1:8788>
and does not return. Give it a terminal the person owns, or background it. On a
remote machine reach it with `ssh -L 8788:127.0.0.1:8788 <host>`. It has no
login, so never expose it (`--expose` exists; do not use it on a reachable
interface).

## A verdict looks wrong

First see why it decided:

```sh
innerwarden check "<the exact command>"
innerwarden check "<the exact command>" --json   # the signals behind it
```

Then it depends on which way it was wrong.

- **It refused or held something legitimate.** If it is a one-off, the person
  runs it themselves. If it will keep happening, the person teaches the guard,
  at their own terminal (it needs one):

  ```sh
  innerwarden allow "<glob>"        # e.g. "terraform plan*"
  innerwarden allow --list
  innerwarden allow --remove "<glob>"
  innerwarden mute <rule>           # silence one rule; mute --list, mute --remove
  ```

  `allow '*'` is refused, and a pattern whose first word holds `*` can only lift
  a review, never a deny. Keep allow patterns as narrow as the real command.
  A provisioning script (CI, Ansible) adds entries with `--operator`; that flag
  is ignored inside an agent's shell.

- **It allowed something it should not have.** An allow verdict reads "no rule
  matched (absence of a match is not a safety judgement)": that is a statement
  about rules, not a safety rating. Report it to InnerWarden with the command
  and the `check --json` output. Do not try to build a deny rule yourself.

Either way, say what you saw. A wrong verdict reported plainly is worth more to
the person than a quiet workaround.

## Moving from monitor to enforce, and back

```sh
innerwarden enforce     # denials become real; you may run it once the person has decided
```

Then the person restarts every guarded agent, and the CLI prints how for each
one. Read that line back: an agent that is not restarted keeps the old mode.

Going back to monitor (`innerwarden dry-run`) lowers the guard, so it is the
person's command. If they want it, give them the line.

A good moment to suggest `enforce` is after a week in monitor, when
`innerwarden graph` shows the would-be refusals were all things the person
agrees should be refused.

## Alerts

```sh
innerwarden notify                            # which channels are wired, and where the config lives
innerwarden notify --telegram-token <T> --telegram-chat <C>
innerwarden notify --slack-webhook <URL>      # or --discord-webhook, --webhook-url
innerwarden notify --test                     # always finish with this
```

By default only deny verdicts are announced; add `--notify-review` when the
channel is set up to announce review verdicts too. Ask the person for tokens
and webhooks; never invent one, and never echo a token back in your reply.

## A new agent appears

```sh
innerwarden agents list    # it shows as "not guarded"
```

Then the same choice, for that agent only: the person runs
`innerwarden agents connect <name> --monitor`, or you run
`innerwarden agents connect <name>` to wire it in enforce. `--all` rewires every
agent, including ones already set, so do not use it here. Either way, restart
it.

## Running an agent in a jail

`innerwarden contain -- <command>` starts an agent inside a sandbox (bubblewrap
on Linux, sandbox-exec on macOS; not on Windows). It is how Aider is guarded,
and `innerwarden contain --identity -- claude` is what lets InnerWarden Pro's
per-agent kernel controls see a Claude Code session ([`managing-pro.md`](managing-pro.md)).

Starting a jail rewires the agent's hook, so it is the person's command. You
may show what it would do:

```sh
innerwarden contain --dry-run -- <command>
```

Since 1.6.15 the jail hands in only what a shell needs of the person's
environment: `PATH`, `HOME`, `USER`, `LOGNAME`, `SHELL`, `LANG`, `LC_*`,
`TERM`, `TZ`, `TMPDIR`, `COLORTERM` and the proxy settings (`*_PROXY`,
`NO_PROXY`). It names every variable it kept out, never a value. An agent that
reads its API key or any other variable from the environment needs
`--pass-env NAME` on the person's line, once per variable.

On Ubuntu 26.04, if the jail cannot start, the distribution's bubblewrap
AppArmor profile may need loading:
`sudo apparmor_parser -r /etc/apparmor.d/bwrap-userns-restrict`. Since 1.6.15
a Linux kernel that refuses an unprivileged user namespace gets the reason
and the setting that resolves it, and nothing runs unjailed.

## An MCP tool went missing or is refused

Since 1.6.15 the MCP proxy pins each tool's definition the first time a
server lists it. In `guard` and `kill`, a tool whose definition changes, a
tool new after the first listing (mid-session or after a restart), a possible
rename and a definition over 64 KiB are held: left out of the list the agent
sees and refused when called. Updating a server that gains tools is the
common case.

```sh
innerwarden mcp list                         # you may run it: what is pinned, what is held and what changed
innerwarden mcp approve <server> <tool>      # the person, at their terminal (or --all)
innerwarden mcp forget <server>              # the person, after reinstalling a server on purpose
```

Read `mcp list` back to the person, with what changed, and hand them the
approve line. The guard refuses an agent that runs approve or forget.

## Upgrading

```sh
innerwarden upgrade --check    # what is installed, what is current
innerwarden upgrade            # the installer's copy upgrades itself
```

A copy installed by `apt` or `dnf` is upgraded by that package manager
(`innerwarden upgrade` says so and stops); an npm copy with
`npm install -g innerwarden@latest`. `upgrade` also brings the hooks it wrote
up to date; when it says it rewrote one, restart that agent.

An upgrade to 1.6.13 from an earlier version is the exception: the rewiring is
done by the version being replaced, which does not know the read tools, so a
Claude Code hook comes out of it without them. Run `innerwarden status` after
it and follow Claude Code's line (above, "Is it on?"). Since 1.6.14
`upgrade` rewires the hooks with the new binary, keeping each hook's mode, and
the first hook run of a new version rewires once. A hook line connected by an
earlier version has no `timeout` until it is connected again; `status` says
so. Going back from 1.6.14 to 1.6.13 or older needs `innerwarden uninstall`
with the newer binary first (the person's): the older one does not recognise
the new hook line.

`upgrade` to 1.6.15 rewires the Claude Code hooks but does not add the new
Codex, Gemini or Hermes hooks: a Codex or Gemini CLI connected by an earlier
version keeps only its MCP side until `innerwarden agents connect codex` (or
`gemini`) runs again, and Hermes is connected with
`innerwarden agents connect hermes`. MCP pins start empty, so the first
listing of each server after the upgrade is pinned and asks for no approval.

On a Pro host the Pro installer does not upgrade an existing free CLI, so the
person upgrades it this way too.

## Removing it

Removal lowers the guard, so the person runs every line, in this order:

```sh
innerwarden agents disconnect --all   # FIRST, while the binary still exists
# restart every agent that was connected
innerwarden uninstall --dry-run       # what it will remove
innerwarden uninstall                 # the installer's copy; apt, dnf or npm remove theirs
rm -rf ~/.config/innerwarden          # local state and the decision log
```

`disconnect` comes first, with the restart, because every wiring calls the
guard by absolute path (the MCP wrappers, the Claude Code, Codex, Gemini and
Hermes hooks, OpenClaw's plugin), and an enforcing hook whose program is gone
refuses every tool call. `uninstall` runs the same disconnect itself, and
since 1.6.15 it stops, binary and configuration in place, when a hook would
outlive the binary, and names the file to fix. Before removing the package
with apt, dnf or npm, disconnect first in the same way.
