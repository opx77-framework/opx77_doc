---
title: Reference overview — the sixteen resources
description: The sixteen resources OPX//77 ships, with the version, reload policy and role of each, which of them are optional, what a missing one costs, and how they depend on one another at runtime.
---

# Reference

OPX//77 ships as sixteen resources. One of them, `opx77_core`, owns the
character: the roster, money, jobs, gangs, metadata, appearance, clothing,
persistence and the entry gate. The other fifteen are services, surfaces and
tools that read it.
`opx77_status` is the one that owns state of its own — the gameplay needs, in a
table of its own. `opx77_inventory` holds what a character carries, in tables
`opx77_core` owns and writes for it.

| Resource | Version | Reload policy | Role |
|---|---|---|---|
| [`opx77_core`](opx77_core/index.md) | 0.6.0 | `local` | The framework. Characters, money, jobs, gangs, metadata, appearance, clothing, persistence, entry gate, and the server exports that store the inventory. |
| [`opx77_menu`](opx77_menu/index.md) | 0.6.0 | `reconnect` | Shared keyboard-driven menu service. |
| [`opx77_input`](opx77_input/index.md) | 0.2.0 | `reconnect` | The one form on the client: text, choice and slider fields answered together, drawn as `opx77_menu`'s strip. |
| [`opx77_hud`](opx77_hud/index.md) | 0.6.0 | `reconnect` | Player HUD: gauges, money, job, and the status strip. |
| [`opx77_chat`](opx77_chat/index.md) | 0.6.0 | `reconnect` | Chat box, and the only path a slash command typed in game takes to the host's dispatcher. |
| [`opx77_status`](opx77_status/index.md) | 0.5.0 | `reconnect` | The gameplay needs, in its own table, and the status-effect registry. Owns no surface of its own. |
| [`opx77_notify`](opx77_notify/index.md) | 0.3.0 | `reconnect` | Toast notifications, drop-in for the platform's own notification API. |
| [`opx77_prompts`](opx77_prompts/index.md) | 0.2.0 | `reconnect` | The key strip: rows of "press this key to do that" any resource puts up while it matters, named by the player's own binding. |
| [`opx77_weather`](opx77_weather/index.md) | 0.5.0 | `local` | Synchronised clock and weather authority. |
| [`opx77_elevators`](opx77_elevators/index.md) | 0.5.0 | `local` | Job-gated in-world elevators. |
| [`opx77_appearance`](opx77_appearance/index.md) | 0.10.0 | `local` | The character's face and clothes, and a panel on `F5`; the character bootstrap spent at join, so the world loads first; the readiness announcement that opens the platform's gate; and every player's look handed to the others, so they are drawn. |
| [`opx77_charselector`](opx77_charselector/index.md) | 0.4.0 | `local` | The character roster, drawn by `opx77_menu` in the gameplay world, and the stage camera while the player chooses. |
| [`opx77_charcreator`](opx77_charcreator/index.md) | 0.2.0 | none declared | The creation flow: the identity form, the write through `opx77_core`, the hand-back to the roster, and the call that opens the in-world face editor. |
| [`opx77_animations`](opx77_animations/index.md) | 0.3.0 | `local` | Emotes: a command, a picker drawn by `opx77_menu` one screen at a time, and client exports that ask the platform's animation service to play one. |
| [`opx77_admin`](opx77_admin/index.md) | 0.2.0 | `local` | Staff tool: forty-four ACL-restricted commands and a keyboard menu that drives them, audited in the platform log. |
| [`opx77_inventory`](opx77_inventory/index.md) | 0.3.0 | `reconnect` | The inventory: a bag of slots and grams per character, stashes, vehicle storage and piles on the ground, weapons as items, stored by `opx77_core`. |

Every version and reload policy in that table is read from the resource's own
`open77.lua`. A `reload_policy` is a **client transition** policy, not a
statement about the server: `local` rebuilds the client half in place, and
`reconnect` is what a WebUI surface needs, because a CEF page is never replaced
in place. `opx77_charcreator` declares none, so the host's default applies.

## What is optional, and what a missing one costs {#optional}

`opx77_core` is the only one the set cannot start without. Everything else can
be stopped, deleted or never installed, and the set still starts — because
**no manifest in this framework declares a `dependency`**. That is deliberate:
a declared dependency is hard, and an incompatible dependency graph prevents the
candidate resource from starting at all. Starting is not the same as playing,
though: three of them are what gets a player into the world.

| Resource | Optional? | What is lost without it |
|---|---|---|
| `opx77_core` | **No** | Everything. No characters, no money, no persistence, no entry gate. Nothing else in the set has a state to read. |
| `opx77_menu` | Yes | Any resource that borrows the menu falls back. `opx77_elevators` answers `menu_not_running` and logs one line; the elevator itself still works from its exports. Without it `opx77_charselector` has nothing to draw the roster on. |
| `opx77_input` | Yes | No form. `opx77_charcreator` logs two lines and hands the player straight back to the roster, so no character can be created in game. |
| `opx77_hud` | Yes | Nothing is drawn on screen: no gauges, no money, no job, and no status strip. `opx77_status` still registers effects; nobody paints them. Cyberpunk's own HUD is left on, since this is the resource that hides it. |
| `opx77_chat` | Yes | No chat box — and no way to type a command in game at all. A slash command never reaches this resource's *server* half, but its *client* half is what tokenises the line and hands it to the host's dispatcher, so without it every `RegisterCommand` in the set is reachable only from the OPEN//77 developer terminal and `startup.commands`. |
| `opx77_status` | Yes | The HUD's status strip stays empty **and its needs gauges blank**: hunger, thirst, stamina and street cred live in this resource, not in `opx77_core`, so nothing else can answer for them. The HUD draws health, armour, money and job exactly as before. |
| `opx77_prompts` | Yes | No key strip: `opx77_menu`'s key hints, `opx77_admin`'s noclip controls and `opx77_animations`' stop key are simply not shown. Every key still works. |
| `opx77_notify` | Yes | No toasts. A server resource calling `Open77.notifications.send` reaches nothing unless the official `open77_notifications` is installed, and every client call answers `export_not_found`. |
| `opx77_weather` | Yes | The sky and clock are whatever the host defaults to. Nothing else reads this resource. |
| `opx77_elevators` | Yes | The scripted lifts are inert. It is the worked example of a satellite, and the resource most safely deleted. |
| `opx77_appearance` | **No, in practice** | Nothing spends the character bootstrap, so the platform's loading cover never lifts and no world loads. No stored face is applied, and **the platform's readiness gate never opens for anybody**: every joiner carries a `__platform` hold that clears only on a client announcing `open77:session:gameplayReady`, and this is the resource that sends it. `opx77_core` places characters regardless, because it never waits on `Open77.ready.isReady` or `onPlayerReady`; anything that does wait on them hangs. **Nobody sees anybody else's body** either: this resource hands every player's look to the others. The official `open77_appearance` also spends the bootstrap, sends the announcement and hands looks out, and the core's boot check accepts either name, but it follows the platform's own join model, not this framework's — and running both conflicts over the bootstrap and the face. Run one. |
| `opx77_charselector` | **No, in practice** | Nobody plays: nothing draws the roster or calls `SelectCharacter`, so a joining player stays unplaced in the world. `opx77.select` from the terminal still works. |
| `opx77_charcreator` | Yes, with a consequence | No in-game character creation, and nothing answers `opx77_appearance`'s `needsCreation`: a character with no face enters on the default face after `CREATION_WAIT_MS`. |
| `opx77_animations` | Yes | No emotes: no `/e`, no picker, no animation exports. Nothing else in the set calls it, and it has no effect on the platform's own `open77_animations`. |
| `opx77_admin` | Yes | No staff menu and no staff commands for teleport, heal, revive, god mode, kick, ban, vehicles, weapons, bags, announcements or destinations. `opx77_core`'s, `opx77_inventory`'s and `opx77_weather`'s own staff commands still work typed. Nothing else reads it. |
| `opx77_inventory` | Yes | No bags, stashes, vehicle storage or piles, and no weapons drawn from a bag. Every `opx77_admin` weapon command but the holster, and every inventory command, refuses with `inventory_unavailable`; its weapon rows are greyed and its inventory rows hidden. |

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
    opx77_notify      opx77_input
```

The entry has a shape of its own, because four resources hand a player from one
to the next — see [The entry gate](../concepts/entry-gate.md#world-first):

```text
 opx77_appearance ── spends the bootstrap at join; the world loads
        │
 opx77_charselector ── roster in the world, through opx77_menu; holds the stage
        │  createRequested                         ▲ open, holdStage,
        ▼                                          │ releaseStage
 opx77_charcreator ── identity form, through opx77_input; CreateCharacter
        │  openCreator, on needsCreation
        ▼
 opx77_appearance ── the in-world face editor; gameplayReady
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
- **`opx77_chat`, `opx77_weather`, `opx77_notify` and `opx77_input` depend on
  nothing else in the set**, and neither does `opx77_prompts`, which only asks
  `opx77_hud` whether the HUD is toggled off. `opx77_notify` is the one resource whose main
  inbound channel comes from *outside* the framework: it registers the
  platform's own four `open77:notifications:*` net events, so a server resource
  written against `Open77.notifications` renders here without knowing this
  framework exists.
- **`opx77_appearance` reads and writes the character's face through
  `opx77_core`.** It has no `sql/`, no table and no `database.access`. It
  captures a snapshot and sends it to the core on
  `opx77:server:saveAppearance`; the core validates it, stores it on the
  character row and publishes it back inside `PlayerData`. At join it reads the
  core's roster — `GetCharacters` and `opx77:client:charactersReady`, never a
  request — to pick the body the world loads with. Its one server file,
  `server/presence.lua`, reads nothing of the core's: it hands each player's
  look — body, equipment, outfit — to the other players, in memory, so they are
  drawn at all.
- **`opx77_inventory` is stored by `opx77_core`.** It calls the core's server
  exports — `opx77_core` 0.4.0 or later, with `opx77_inventory` in its
  [`EXPORTS.CALLERS`](opx77_core/config.md) — for every container, and the core's `GetChanges` cursor for
  who is in the world. It draws its own screen, and uses `opx77_notify`,
  `opx77_status` and `opx77_animations` when they run. `opx77_admin` changes a
  bag through its server exports.
- **`opx77_charselector` reads `opx77_core`** — `charactersReady`,
  `GetCharacters`, `RequestCharacters`, `SelectCharacter`, `IsLoggedIn` and the
  refusal channel — and draws through `opx77_menu`. It listens for
  `opx77_appearance`'s `needsCreation`, raises `createRequested` for
  `opx77_charcreator`, and owns the stage camera.
- **`opx77_charcreator` listens to `opx77_charselector`'s `createRequested`** and
  draws its form with `opx77_input`. It uses `opx77_core` (`GetOrigins`,
  `GetSharedConfig`, `CreateCharacter`, `GetCharacters`, `IsLoggedIn`), calls
  `opx77_charselector`'s `open`, `isOpen`, `holdStage` and `releaseStage`, and
  `opx77_appearance`'s `openCreator`.
- **`opx77_animations` draws its picker with `opx77_menu`** and its refusals with
  `opx77_notify`, and never calls `opx77_core`. Every request waits on
  `Open77.ready.isReady`, so it needs `opx77_appearance`, or the platform's
  `open77_appearance`, to do anything at all.
- **`opx77_admin` drives other resources' commands.** It draws with
  `opx77_menu` and `opx77_input`, reads `GetJobs`, `GetGangs` and
  `GetSharedConfig` from `opx77_core`, and runs the core's and `opx77_weather`'s
  staff commands for the screens that act on a character or the sky. Its weapon
  and inventory commands call `opx77_inventory`'s server exports, and two of its
  bag rows run that resource's `open` and `holders` commands. Every command that
  touches a body waits on `Open77.ready.isReady` too. It owns no table.
- **`opx77_status` is the one satellite that owns a table.** It keeps the
  character's needs in `opx77_character_status`, keyed on the citizen id, and
  declares `database.access` for it. Everything else still applies to it: it
  writes nothing of the core's, and it reads the live character from the core
  like any other satellite. Its server half asks the core's
  [`GetIdentity`](opx77_core/exports/server.md#getidentity) server export which
  character a player has loaded before it answers a pull.
- **`opx77_core` declares no dependency at all**, in either direction. It must
  install on a bare server, and it checks for an appearance resource and for
  `open77_playerstate` through `GetResourceState` rather than requiring them.

## Reading these pages {#reading}

Most exports listed under `reference/` are **client-side**. Two resources also
publish server exports, which another server resource calls with the same
`Open77.exports.call`: [`opx77_core`](opx77_core/exports/server.md), eleven of
them, admitted by caller, and
[`opx77_inventory`](opx77_inventory/exports.md#server).

Calls always look like this — inside a `CreateThread`, checking every level of
failure:

```lua
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_core", "GetPlayerData")
  if not promise then return print(reason) end   -- dispatch failed; a userdata
  local result, callError = promise:await()      -- resolution failed
  if callError or result.ok ~= true then return end
  print(result.data.citizenId)
end)
```

The three levels are dispatch, resolution and the callee's own refusal, and
collapsing any of them turns a remote error into a silent `nil`. The promise is
a userdata, so it is tested for presence and never for being a table, and an
answer without `ok = true` is a refusal. The full
contract is in [The export contract](../concepts/export-contract.md).

## Where to go next {#next}

- [opx77_core](opx77_core/index.md) — the framework itself.
- [The entry gate](../concepts/entry-gate.md#world-first) — how a player gets from connecting to a character in the world.
- [Integration channels](../concepts/integration-channels.md) — the four ways a third-party resource reaches OPX//77.
- [Writing a resource](../guides/writing-a-resource.md) — a satellite, end to end.
