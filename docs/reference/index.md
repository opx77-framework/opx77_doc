---
title: Reference overview — the nine resources
description: The nine resources OPX//77 ships, with the version, reload policy and role of each, which of them are optional, what a missing one costs, and how they depend on one another at runtime.
---

# Reference

OPX//77 ships as nine resources. One of them, `opx77_core`, owns the character:
the roster, money, jobs, gangs, metadata, appearance, persistence and the entry
gate. Seven of the other eight are client-side services and surfaces that read
it. `opx77_status` is the one exception — it owns the gameplay needs, in a table
of its own.

| Resource | Version | Reload policy | Role |
|---|---|---|---|
| [`opx77_core`](opx77_core/index.md) | 0.3.0 | `local` | The framework. Characters, money, jobs, gangs, metadata, appearance, persistence, entry gate. |
| [`opx77_menu`](opx77_menu/index.md) | 0.3.0 | `reconnect` | Shared keyboard-driven menu service. |
| [`opx77_hud`](opx77_hud/index.md) | 0.3.0 | `reconnect` | Player HUD: gauges, money, job, and the status strip. |
| [`opx77_chat`](opx77_chat/index.md) | 0.3.0 | `reconnect` | Chat box, and the only path a slash command typed in game takes to the host's dispatcher. |
| [`opx77_status`](opx77_status/index.md) | 0.4.0 | `reconnect` | The gameplay needs, in its own table, and the status-effect registry. Owns no surface of its own. |
| [`opx77_notify`](opx77_notify/index.md) | 0.2.0 | `reconnect` | Toast notifications, drop-in for the platform's own notification API. |
| [`opx77_weather`](opx77_weather/index.md) | 0.3.0 | `local` | Synchronised clock and weather authority. |
| [`opx77_elevators`](opx77_elevators/index.md) | 0.4.0 | `local` | Job-gated in-world elevators. |
| [`opx77_appearance`](opx77_appearance/index.md) | 0.4.0 | `local` | The character's face, client-side, and the readiness announcement that opens the platform's gate. |

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
| `opx77_status` | Yes | The HUD's status strip stays empty **and its needs gauges blank**: hunger, thirst, stamina and street cred live in this resource, not in `opx77_core`, so nothing else can answer for them. The HUD draws health, armour, money and job exactly as before. |
| `opx77_notify` | Yes | No toasts. A server resource calling `Open77.notifications.send` reaches nothing unless the official `open77_notifications` is installed, and every client call answers `export_not_found`. |
| `opx77_weather` | Yes | The sky and clock are whatever the host defaults to. Nothing else reads this resource. |
| `opx77_elevators` | Yes | The scripted lifts are inert. It is the worked example of a satellite, and the resource most safely deleted. |
| `opx77_appearance` | Yes, with a consequence | No character creator, no stored face applied, and — the part that catches people — **the platform's readiness gate never opens for anybody**. Every joiner carries a `__platform` hold that clears only on a client announcing `open77:session:gameplayReady`, and this is the resource that sends it. `opx77_core` places characters regardless, because it reads neither `Open77.ready.isReady` nor `onPlayerReady`; anything that does read them hangs. The official `open77_appearance` satisfies the same requirement, and the core's boot check accepts either name. |

!!! info
    A missing resource is a runtime condition, not a boot failure. Every
    consumer in this set checks `GetResourceState(...) ~= "running"` before it
    calls, and treats a stopped provider as an answer rather than an error. Copy
    that habit: see [Integration channels](../concepts/integration-channels.md#client-resource).

## How they depend on one another {#dependencies}

Every arrow below is a **runtime** dependency discovered by a state check, never
a manifest declaration.

```text
                          opx77_core        (the character — the only writer of it)
                               │
                 client exports│+ local events
                               │
     ┌───────────────┬─────────┴─────────┬──────────────────┐
     │               │                   │                  │
 opx77_hud     opx77_status       opx77_elevators     opx77_appearance
     ▲               │                   │                  │
     │ needs +       │ owns              │ menu spec,       │ saveAppearance,
     │ effects       │ opx77_character_  │ optional         │ back to the core
     └───────────────┘ status            ▼
                                    opx77_menu

    opx77_chat        opx77_weather        (depend on nothing in this set)
    opx77_notify
```

- **`opx77_hud` reads `opx77_core`** through `Open77.exports.call("opx77_core", "GetPlayerData")`
  and through the core's local events, and it reads the needs and the effects
  from `opx77_status` — the `getNeeds` export at boot, then `opx77:status:needs`
  and `opx77:status:effects`. `opx77_status` owns no surface of its own — two
  surfaces for one corner of the screen was two things to place, theme and keep
  in step.
- **`opx77_elevators` reads the character's job from `opx77_core`** and draws its
  floor panel with `opx77_menu`. Both are optional at runtime: a missing menu
  costs one log line and a `menu_not_running` answer.
- **`opx77_chat`, `opx77_weather` and `opx77_notify` depend on nothing else in
  the set.** `opx77_notify` is the one resource whose main inbound channel comes
  from *outside* the framework: it registers the platform's own four
  `open77:notifications:*` net events, so a server resource written against
  `Open77.notifications` renders here without knowing this framework exists.
- **`opx77_appearance` reads and writes the character's face through
  `opx77_core`.** It is client-only: it has no `server/`, no `sql/`, no table and
  no `database.access`. It captures a snapshot and sends it to the core on
  `opx77:server:saveAppearance`; the core validates it, stores it on the
  character row and publishes it back inside `PlayerData`.
- **`opx77_status` is the one satellite that owns a table.** It keeps the
  character's needs in `opx77_character_status`, keyed on the citizen id, and
  declares `database.access` for it. Everything else still applies to it: it
  writes nothing of the core's, and it reads the live character from the core
  like any other satellite.
- **`opx77_core` declares no dependency at all**, in either direction. It must
  install on a bare server, and it checks for an appearance resource and for
  `open77_playerstate` through `GetResourceState` rather than requiring them.

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
