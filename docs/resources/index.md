# Resources

OPX//77 ships as seven resources. One of them, `opx77_core`, owns the server
state; the rest are client-side services and surfaces that read it.

| Resource | Version | Reload policy | Role |
|---|---|---|---|
| [`opx77_core`](opx77_core.md) | 0.2.0 | `local` | The framework. Characters, money, jobs, gangs, metadata, persistence, entry gate. |
| [`opx77_menu`](opx77_menu.md) | 0.1.0 | `reconnect` | Shared keyboard-driven menu service. |
| [`opx77_hud`](opx77_hud.md) | 0.1.0 | `reconnect` | Player HUD: gauges, money, job. |
| [`opx77_chat`](opx77_chat.md) | 0.1.0 | `local` | Chat box, and the path a slash command takes to the host dispatcher. |
| [`opx77_status`](opx77_status.md) | 0.2.0 | `reconnect` | Shared status-effect strip. |
| [`opx77_weather`](opx77_weather.md) | 0.1.0 | `local` | Synchronized clock and weather authority. |
| [`opx77_elevators`](opx77_elevators.md) | 0.2.0 | `local` | Job-gated in-world elevators. |

## Reading these pages

Every export listed on these pages is **client-side**. The Open77 server
runtime installs no export mechanism, so a server resource that needs data from
another resource sends a net event to its own client half, which calls the
export there. See [the client export contract](../index.md#the-client-export-contract) for the full contract.

Calls look like this, always inside a `CreateThread`, always checking both
levels of failure:

```lua
local promise, reason = Open77.exports.call("opx77_core", "GetPlayerData")
if not promise then return print(reason) end
local result, callError = promise:await()
```

## Dependencies between them

- `opx77_hud` reads `opx77_core` and draws the effects registered in
  `opx77_status`. `opx77_status` owns no surface of its own — two surfaces for
  one corner of the screen was two things to place, theme and keep in step.
- `opx77_elevators` reads the character's job from `opx77_core` and draws its
  floor panel with `opx77_menu`. Both are optional at runtime: a missing menu
  costs one log line.
- `opx77_chat` and `opx77_weather` depend on nothing else in the set.
- `opx77_core` declares **no** dependencies at all: a declared dependency is
  hard, and the core must install on a bare server.
