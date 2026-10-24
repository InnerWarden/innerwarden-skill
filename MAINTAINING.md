# Keeping this skill current

This skill is the first thing a customer's AI agent reads about InnerWarden,
and it goes stale the day a release changes a verb, a flag, a default, what an
agent is refused, the installer, or what an agent gets screened. A stale skill
sends agents to commands that no longer exist or that the guard now refuses.

So it moves with every user-visible change, in the same round as the release:

1. `sh scripts/check-current.sh`: are the versions SKILL.md cites behind the
   latest final releases, and is the ClawHub copy behind `clawhub/`?
2. Check every command the docs show against the new binaries' `--help`
   (download the release asset into an empty folder and run it with a
   throwaway `HOME`). Never from memory.
3. `sh scripts/tests/install-lead-works-without-root.sh`, and
   `scripts/verify-install.sh` with the new binary in a throwaway home: no
   agent exits 1; a wired agent gives "Wiring confirmed"; `--proof` with a
   token sent through `innerwarden hook` (or, for OpenClaw, through
   `innerwarden openclaw screen`, the path its plugin uses) exits 0.
4. Pull request, review, merge.
5. Republish the ClawHub copy from the merge commit:

   ```sh
   npx clawhub skill publish ./clawhub/innerwarden-security --slug innerwarden-security \
     --name InnerWarden --version <x.y.z> --changelog "<what changed>" \
     --source-repo InnerWarden/innerwarden-skill --source-commit <sha> \
     --source-ref master --source-path clawhub/innerwarden-security
   ```

   Run it with `--dry-run` first. ClawHub scans a new version before it
   becomes public.

What the content must always hold: an agent never lowers its own guard
(monitor, disconnect, allow, mute, contain, disarm, uninstall are the
person's); each agent's coverage is stated exactly (for OpenClaw since
Community 1.6.11, its own `exec`, `process`, `write`, `edit` and `apply_patch`
through the `innerwarden-guard` plugin on OpenClaw 2026.9.7 or newer, plus
calls to its MCP servers, with the plugin's limits); InnerWarden Pro is never
called open source; kernel enforcement is Linux only; no em dashes.
