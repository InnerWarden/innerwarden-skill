# What runs where

Written so an evaluation starts on the right machine, and so nobody discovers a
platform limit on day three.

## Today

| | Linux | macOS | Windows |
|---|---|---|---|
| **Community guardrail** (free) | full | full | full |
| Command and tool-call screening | yes | yes | yes |
| MCP proxy, local dashboard, notifications | yes | yes | yes |
| Sandboxed execution (`innerwarden contain`) | yes, bubblewrap | yes, sandbox-exec | no |
| **Enterprise host layer** (licensed) | full | **in development** | **in development** |
| eBPF sensor, host detectors, correlation, response | yes | no | no |
| Kernel Execution Gate, DNS Guard, anti-tamper watchdog | yes | no | no |

The free guardrail is the same product on all three. It is not a trial and it is
not crippled: it is Apache-2.0 and it is what most people run.

**The Enterprise host layer is Linux only today.** The macOS and Windows versions
are in development. No date is promised here, and you should not infer one. If a
Windows or macOS host is central to your evaluation, say so before you start, so
the scope is agreed rather than discovered.

On macOS and Windows right now, an agent gets the full free guardrail: its
commands and tool calls are screened, denied, recorded and alerted on. What is
missing is the host layer underneath, the part that watches the machine itself.

## Kernel requirements for the Enterprise layer

The eBPF sensor needs a reasonably recent Linux kernel and root or `CAP_BPF`.
Detection, correlation and response work on any such kernel.

The **kernel Execution Gate** additionally needs `bpf` in the active LSM stack:

```sh
grep bpf /sys/kernel/security/lsm
```

If it is absent, that is a boot-cmdline setting (`lsm=...,bpf`) and a reboot.
Without it the gate cannot enforce, and the product says so rather than
pretending. Everything else still works.

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
  `innerwarden agents connect --all` wires everything it finds.

The screening decision is local either way. Commands are not sent anywhere for a
verdict, there is no account to create, and there is no service that has to be
reachable for the guard to work.
