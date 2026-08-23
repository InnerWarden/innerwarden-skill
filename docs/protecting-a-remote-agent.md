# Protecting an agent you cannot install onto

The usual setup puts the guardrail on the same machine as the agent, and a local
hook screens every command. Sometimes you cannot do that: the agent runs in a
managed cloud runtime, in a container image you do not build, or in CI.

For those, the guardrail runs somewhere you control and the agent asks it over
HTTP.

## Start the screening endpoint

```sh
innerwarden serve --bind 127.0.0.1:9911
```

It serves one route, `POST /api/agent/check-command`, over plain HTTP bound to
loopback by default.

## Ask it for a verdict

```sh
curl -s -X POST http://127.0.0.1:9911/api/agent/check-command \
  -H 'Content-Type: application/json' \
  -d '{"command":"rm -rf /"}'
```

```json
{
  "command": "rm -rf /",
  "recommendation": "deny",
  "risk_score": 90,
  "severity": "high",
  "explanation": "recursive removal of a root / system directory; dangerous command: rm -rf of root (destructive)",
  "asi_ids": ["ASI02", "ASI10"],
  "signals": [
    {"signal": "destructive_command", "score": 50,
     "detail": "recursive removal of a root / system directory"}
  ]
}
```

An ordinary command comes back like this, and the wording is deliberate:

```json
{
  "command": "ls -la",
  "recommendation": "allow",
  "risk_score": 0,
  "severity": "none",
  "explanation": "no rule matched (absence of a match is not a safety judgement)"
}
```

Read `recommendation`: `allow`, `review` or `deny`. `signals` tells you *why*,
which is what you show a human when you refuse something.

## Wiring it into an agent

Whatever your agent framework calls its pre-execution hook, the shape is the
same: before you run a command, POST it, and act on `recommendation`.

```python
import requests

GUARD = "http://127.0.0.1:9911/api/agent/check-command"

def screen(command: str) -> tuple[bool, str]:
    """Returns (may_run, reason). Fails CLOSED: if the guard cannot be reached,
    the command does not run. An unreachable guard is not an approval."""
    try:
        v = requests.post(GUARD, json={"command": command}, timeout=3).json()
    except requests.RequestException as e:
        return False, f"guard unreachable ({e}); refusing rather than guessing"
    if v["recommendation"] == "deny":
        return False, v["explanation"]
    return True, v["explanation"]
```

**Fail closed.** If the endpoint is down, refuse. A guard that waves commands
through when it cannot answer is worse than no guard, because it is trusted.

## Exposing it beyond loopback

The default binding is loopback, and that default is right. If the agent is on
another host you have to widen it, and then the endpoint is a thing anyone who
can reach it can query:

- put it on a private network or a VPN, never a public interface;
- restrict it at the firewall to the agent's address;
- treat commands sent to it as sensitive, because they are.

The verdict is computed locally on the machine running `serve`. Nothing leaves
it, there is no upstream service, and no account is involved.

## The trade compared with a local install

A local hook screens **everything** the agent tries, because it sits in the
execution path. HTTP screening only covers commands your integration remembers
to send.

That is a real gap and you should know which one you have. Where you can install
locally, do; use HTTP where you genuinely cannot.
