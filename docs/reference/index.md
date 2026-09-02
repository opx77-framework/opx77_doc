---
title: Reference overview — the seven resources
description: The seven resources OPX//77 ships, with the version, reload policy and role of each, which of them are optional, what a missing one costs, and how they depend on one another at runtime.
---

# Reference

OPX//77 ships as seven resources. One of them, `opx77_core`, owns the server
state: characters, money, jobs, gangs, metadata, persistence and the entry gate.
The other six are client-side services and surfaces that read it.

| Resource | Version | Reload policy | Role |
|---|---|---|---|
| [`opx77_core`](opx77_core/index.md) | 0.2.0 | `local` | The framework. Characters, money, jobs, gangs, metadata, persistence, entry gate. |
| [`opx77_menu`](opx77_menu/index.md) | 0.1.0 | `reconnect` | Shared keyboard-driven menu service. |
| [`opx77_hud`](opx77_hud/index.md) | 0.1.0 | `reconnect` | Player HUD: gauges, money, job, and the status strip. |
| [`opx77_chat`](opx77_chat/index.md) | 0.1.0 | `reconnect` | Chat box, and the only path a slash command typed in game takes to the host's dispatcher. |
| [`opx77_status`](opx77_status/index.md) | 0.2.0 | `reconnect` | Status-effect registry. Owns no surface of its own. |
| [`opx77_weather`](opx77_weather/index.md) | 0.1.0 | `local` | Synchronised clock and weather authority. |
| [`opx77_elevators`](opx77_elevators/index.md) | 0.2.0 | `local` | Job-gated in-world elevators. |

Every version and reload policy in that table is read from the resource's own
`open77.lua`. A `reload_policy` is a **client transition** policy, not a
statement about the server: `local` rebuilds the client half in place, and
`reconnect` is what a WebUI surface needs, because a CEF page is never replaced
in place.

## What is optional, and what a missing one costs {#optional}

`opx77_core` is the only one that is not optional. Everything else can be
stopped, deleted or never installed, and the set still starts — because
**no manifest in this framework declares a `dependency`**. That is deliberate:
a declared dependency is hard, and an incompatible dependency graph prevents the
candidate resource from starting at all.

| Resource | Optional? | What is lost without it |
|---|---|---|
| `opx77_core` | **No** | Everything. No characters, no money, no persistence, no entry gate. Nothing else in the set has a state to read. |
| `opx77_menu` | Yes | Any resource that borrows the menu falls back. `opx77_elevators` answers `menu_not_running` and logs one line; the elevator itself still works from its exports. |
| `opx77_hud` | Yes | Nothing is drawn on screen: no gauges, no money, no job, and no status strip. `opx77_status` still registers effects; nobody paints them. Cyberpunk's own HUD is left on, since this is the resource that hides it. |
| `opx77_chat` | Yes | No chat box — and no way to type a command in game at all. A slash command never reaches this resource's *server* half, but its *client* half is what tokenises the line and hands it to the host's dispatcher, so without it every `RegisterCommand` in the set is reachable only from the OPEN//77 developer terminal and `startup.commands`. |
| `opx77_status` | Yes | The HUD's status strip stays empty. The HUD draws everything else exactly as before. |
| `opx77_weather` | Yes | The sky and clock are whatever the host defaults to. Nothing else reads this resource. |
| `opx77_elevators` | Yes | The scripted lifts are inert. It is the worked example of a satellite, and the resource most safely deleted. |

!!! info
    A missing resource is a runtime condition, not a boot failure. Every
    consumer in this set checks `GetResourceState(...) ~= "running"` before it
    calls, and treats a stopped provider as an answer rather than an error. Copy
    that habit: see [Integration channels](../concepts/integration-channels.md#client-resource).

## How they depend on one another {#dependencies}

Every arrow below is a **runtime** dependency discovered by a state check, never
a manifest declaration.

```text
                      opx77_core            (server state — the only writer)
                           │
             client exports│+ local events
                           │
        ┌──────────────────┴───────────────┐
        │                                  │
    opx77_hud                        opx77_elevators
        ▲                                  │
        │ opx77:status:effects             │ menu spec, optional
        │                                  ▼
   opx77_status                        opx77_menu

    opx77_chat        opx77_weather        (depend on nothing in this set)
```

- **`opx77_hud` reads `opx77_core`** through `Open77.exports.call("opx77_core", "GetPlayerData")`
  and through the core's local events, and it draws the effects `opx77_status`
  publishes on `opx77:status:effects`. `opx77_status` owns no surface of its
  own — two surfaces for one corner of the screen was two things to place, theme
  and keep in step.
- **`opx77_elevators` reads the character's job from `opx77_core`** and draws its
  floor panel with `opx77_menu`. Both are optional at runtime: a missing menu
  costs one log line and a `menu_not_running` answer.
- **`opx77_chat` and `opx77_weather` depend on nothing else in the set.**
- **`opx77_core` declares no dependency at all**, in either direction. It must
  install on a bare server, and it consults `open77_appearance` and
  `open77_playerstate` through the host rather than requiring them.

## Reading these pages {#reading}

Every export listed under `reference/` is **client-side**. The OPEN//77 server
runtime installs no export mechanism, which is why
[`opx77_core`'s server exports page](opx77_core/exports/server.md) exists to say
that there are none, and what to use instead.

Calls always look like this — inside a `CreateThread`, checking every level of
failure:

```lua
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_core", "GetPlayerData")
  if not promise then return print(reason) end   -- dispatch failed
  local result, callError = promise:await()      -- resolution failed
  if callError or not result.ok then return end
  print(result.data.citizenId)
end)
```

The three levels are dispatch, resolution and the callee's own refusal, and
collapsing any of them turns a remote error into a silent `nil`. The full
contract is in [The export contract](../concepts/export-contract.md).

## Where to go next {#next}

- [opx77_core](opx77_core/index.md) — the framework itself.
- [Integration channels](../concepts/integration-channels.md) — the four ways a third-party resource reaches OPX//77.
- [Writing a resource](../guides/writing-a-resource.md) — a satellite, end to end.
