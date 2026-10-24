# Running InnerWarden Community day to day

For an agent helping someone whose guard is already installed and wired. If it
is not installed yet, start at [`../SKILL.md`](../SKILL.md). If the machine also
runs InnerWarden Pro, read [`managing-pro.md`](managing-pro.md) as well.

Read the command surface from the binary in front of you (`innerwarden --help`,
`innerwarden <verb> --help`). `--help` never changes anything. What follows is
the order things usually come up in, and who may do each one.

## Who does what

You are an AI agent, and the guard you are managing screens you. The CLI
refuses, inside Claude Code, Codex or Gemini, and since 1.6.11 OpenClaw's exec
shell (a script they run included), connecting or installing in monitor,
disconnecting, starting a jail, `allow`, `mute`, and since 1.6.9 `dry-run` /
`monitor` and `uninstall`. An enforcing Claude Code hook blocks the same, and
so does OpenClaw's `innerwarden-guard` plugin in enforce. Treat every lowering command as the person's,
whatever the agent and whatever lets it through. That is the product working,
not something to route around.

| You may run it | Only the person runs it, in their own terminal |
|---|---|
| `innerwarden status`, `agents list`, `check`, `graph`, `notify --test` | `innerwarden agents connect ... --monitor` |
| `allow --list`, `mute --list`, every `--help` | `innerwarden agents disconnect` |
| `innerwarden agents connect <agent>` (enforce, only when the person chose it) | `innerwarden install <agent> --monitor` |
| `innerwarden enforce`, `innerwarden install claude-code` (same condition) | `innerwarden dry-run` (back to monitor) |
| `innerwarden contain --dry-run -- <command>` | `innerwarden contain ...` (starting a jail) |
| `innerwarden upgrade --check` | `innerwarden allow "<glob>"`, `innerwarden mute <rule>` |
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

`status` speaks plainly about coverage, with one known exception in 1.6.11:
for OpenClaw it still says "Its built-in tools are not screened by this
edition", even when the `innerwarden-guard` plugin is installed and screening
them. For OpenClaw, read the line `agents list` prints, "OpenClaw's own tools:
screened, monitor" (or `enforce`), which is the accurate one, and do not repeat
the `status` sentence. For every other agent, repeat what `status` says; do not
improve on it.

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

On Ubuntu 26.04, if the jail cannot start, the distribution's bubblewrap
AppArmor profile may need loading:
`sudo apparmor_parser -r /etc/apparmor.d/bwrap-userns-restrict`.

## Upgrading

```sh
innerwarden upgrade --check    # what is installed, what is current
innerwarden upgrade            # the installer's copy upgrades itself
```

A copy installed by `apt` or `dnf` is upgraded by that package manager
(`innerwarden upgrade` says so and stops); an npm copy with
`npm install -g innerwarden@latest`. `upgrade` also brings the hooks it wrote
up to date; when it says it rewrote one, restart that agent.

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

`disconnect` comes first because `uninstall` unwires Claude Code only; every
other agent's MCP config points at the guard by absolute path and would be left
pointing at nothing.
