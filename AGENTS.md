# InnerWarden: install, wire, verify

The full instructions live in [`SKILL.md`](SKILL.md) in this repository. It is
written for you, not for a human, and it is the same content whichever agent you
are. Read it before running anything.

If you only read four lines:

1. Install the **free CLI first**, always:
   `curl -fsSL https://innerwarden.com/free | sh` (Windows: `irm
   https://innerwarden.com/free.ps1 | iex`). Signed, verified, no root. Use
   `npm install -g innerwarden` only if the user prefers npm, and expect EACCES
   on Linux, where npm's prefix is root-owned.
2. Wire the agent in monitor mode: `innerwarden agents connect --all --monitor`,
   then tell the user to **restart the agent** or it is still unscreened.
3. Add the Enterprise host layer only with a licence, Linux only:
   `curl -fsSL https://innerwarden.com/install | sudo bash -s -- --license=/path/to/license.key`
4. Do not report success until `./scripts/verify-install.sh` exits 0. "Installed
   without errors" and "protecting you" are different claims.

Read the command surface from `innerwarden --help` on the machine, never from a
list in documentation. Lists drift from what ships.
