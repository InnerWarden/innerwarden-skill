# What runs where

Written so an evaluation starts on the right machine, and so nobody discovers a
platform limit on day three.

## Today

| | Linux | macOS | Windows |
|---|---|---|---|
| **InnerWarden Community** (free) | full | full | experimental |
| Command and tool-call screening | yes | yes | yes |
| MCP proxy, local dashboard, notifications | yes | yes | yes |
| Sandboxed execution (`innerwarden contain`) | yes, bubblewrap | yes, sandbox-exec | no |
| **InnerWarden Pro host layer** (paid) | full | no | no |
| eBPF sensor, host detectors, correlation, response | yes | no | no |
| Kernel Execution Gate, Secret Read Guard, DNS Guard, anti-tamper watchdog | yes | no | no |
| Per-agent kernel controls (Programs, Private files, DNS per agent) | Claude Code in a jail | no | no |

The free guardrail is the same product on all three (Windows is experimental).
It is not a trial and it is not crippled: it is Apache-2.0 and it is what most
people run.

**InnerWarden Pro's host layer, and all kernel enforcement, is Linux only.**
No date for anything else is promised here, and you should not infer one. If a
Windows or macOS host is central to your evaluation, say so before you start, so
the scope is agreed rather than discovered.

On macOS and Windows right now, an agent gets the full free guardrail: what it
sends through its hook or its MCP servers is screened, denied, recorded and
alerted on (which surface depends on the agent; see below). What is missing is
the host layer underneath, the part that watches the machine itself.

## Kernel requirements for InnerWarden Pro

The eBPF sensor needs a reasonably recent Linux kernel and root or `CAP_BPF`.
Detection, correlation and response work on any such kernel.

The **kernel Execution Gate** additionally needs `bpf` in the active LSM stack:

```sh
grep bpf /sys/kernel/security/lsm
```

If it is absent, that is a boot-cmdline setting (`lsm=...,bpf`) and a reboot;
on Debian and Ubuntu the installer writes it for you and asks for the reboot.
Without it the gate cannot enforce, and the product says so rather than
pretending. Everything else still works, and for a jailed Claude Code
`innerwarden-ctl agent kernel kill-mode on` stops an untrusted program at the
end of exec instead.

This matters for cloud images: many distributions ship without `bpf` in the
stack. Check it before you plan a demo around the gate.

## Where the agent is running

The guardrail does not have to run on your laptop, and for most real deployments
it should not.

- **Agent on a cloud VM or a container.** Install the guardrail on the same
  machine as the agent. That is the normal case, and it is what the pilot
  instructions in this repository describe.
- **Agent somewhere you cannot install into.** Run the guardrail on a machine you
  control and point the agent at it over HTTP. See
  `protecting-a-remote-agent.md`.
- **Several agents, one host.** One installation screens all of them.
  `innerwarden agents connect --all` wires everything it finds (the person's
  call: it also rewires agents already set). What it covers
  differs by agent (Claude Code: hook; Codex, Gemini, Cursor, OpenClaw: their
  MCP servers only; Aider: in a jail), and `innerwarden status` says which.

The screening decision is local either way. Commands are not sent anywhere for a
verdict, there is no account to create, and there is no service that has to be
reachable for the guard to work. (Pro's installer sends an install ping, and a
Pro host sends a daily heartbeat and a daily licence check; none carries
commands or events.)
