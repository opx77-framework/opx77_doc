---
title: opx77_core — overview
description: What opx77_core is, the state it owns, its manifest at a glance, the file layout behind it, and why the order of the lines in its manifest is the contract every file in the resource depends on.
---

# opx77_core

## At a glance {#at-a-glance}

| At a glance | |
|---|---|
| **Version** | `0.6.0` |
| **Requires** | `open77_version ">=0.0.1"`. **No `dependency` is declared**, in either direction: a declared dependency is hard, and this core must install on a bare server. |
| **Auto start** | yes |
| **Reload policy** | `local` — a reload is a script reload, not a reconnect: both halves rebuild |
| **Permissions** | `network.events`, `database.access`, `players.life.read`, `players.life.kill`, `players.life.respawn`, `players.life.revive`, `players.damage.apply`, `world.vehicles`, `acl.read`, `players.disconnect` — see [Permissions](permissions.md) |
| **Sides** | server, which owns every decision and the database, and client, which holds a read-only mirror and publishes the client exports |
| **Exports** | 17 client exports — see [client exports](exports/client.md) — and 11 server exports, for identity, a change cursor, a vehicle's plate and the inventory storage — see [server exports](exports/server.md) |
| **Schema** | seven `opx77_` tables, created at boot from `server/storage/schema.lua`; `sql/schema.sql` is the copy an operator reads — see [Persistence](../../concepts/persistence.md#schema) |
| **Commands** | 14 — nine ACL-restricted, five a player runs on their own character — see [Commands](commands.md) |
| **Events** | four channels it owns — `Client` and `Server` on the wire, `Local` and `Internal` in-VM. `Client` and `Local` are deliberately disjoint vocabularies — see [Events](events.md) |
| **Licence** | MIT |

## What it is {#what-it-is}

`opx77_core` is the whole server side of OPX//77. It owns the character roster,
the money ledger, jobs, gangs, per-character metadata, the face and the clothing,
vehicle ownership, the storage of every inventory, the database schema and the
join-time readiness gate — and it owns all of them alone. Nothing else on the
server writes to `opx77_characters`, and nothing else decides where a character
stands when they enter the world.

Its server API, `OPX.*`, lives in one Lua state, and a plug-in that needs it is
one more file added to `opx77_core/server/` and one more line added to its
manifest — which keeps one roster, one ledger and one writer. What another
server resource needs from outside is published as **server exports**: who a
player is, the characters loading and leaving, a spawned vehicle's plate, and
the inventory storage `opx77_inventory` calls. The reasoning, and every channel
a third party can use, are in [Architecture](../../concepts/architecture.md) and
[Integration channels](../../concepts/integration-channels.md).

The core's **client** half draws nothing. It mirrors the character the server
sent, publishes 17 exports over that mirror, and re-fires every change on a local
event channel any resource on the host can hear. Pixels belong in satellite
client resources reaching it through `Open77.exports.call("opx77_core", …)`.

!!! warning
    Everything the client half answers is a **hint**. It is read from a copy of
    the character living in the player's own process. Gate a menu on it, skip a
    prompt with it, draw a HUD from it — and re-derive anything that must be
    unforgeable inside the core.

## File layout {#layout}

| Directory | Contents |
|---|---|
| `config/` | The only files an operator edits. `UPPER_SNAKE` keys. `shared.lua` is shipped to every client; `server.lua` and `vehicles.lua` are not. |
| `data/` | Jobs, gangs, lifepaths. Definitions, not settings: changing one renames something players already hold. |
| `locales/` | `en.lua` and `fr.lua`, registered immediately after the catalogue so no file below them can call `locale()` against an empty one. |
| `shared/` | `OPX` itself — result, table, string, math, validate, hooks, locale, citizen ids. Loaded into both VMs. |
| `sql/` | `schema.sql`, every `CREATE TABLE IF NOT EXISTS` statement the core runs, with a comment per table: the copy an operator reads, and may run by hand on an empty database. Not loaded by the manifest — see [Persistence](../../concepts/persistence.md#schema). |
| `server/storage/` | Every SQL statement the resource actually runs: `main.lua` (the bridge and `OPX.Storage.applySchema`), `schema.lua` (`OPX.Schema`, the single schema), `players.lua`, `vehicles.lua` and `inventories.lua`. Nothing else in the resource writes SQL. |
| `server/` | Sessions, players, groups, characters, appearance, clothing, vehicles, the gate, the selection bucket, events, commands, loops, and `exports.lua`, the server exports, loaded last. |
| `client/` | The state mirror, the character-screen requests, the event re-emissions and the exports surface. |
| `std/` | The LuaLS annotations: `std/types.lua` for the shapes, and one stub per namespace function under `std/client/`, `std/server/` and `std/shared/`. Not loaded by the manifest. |
| `docs/` | `ARCHITECTURE.md`, in French: why the code is written as it is — load order, one line per permission, invariants and known limits. |

## Load order is the contract {#load-order}

Scripts load in **manifest order**, and order inside each block of
`open77.lua` is dependency order. A file publishes into the `OPX` table, and
every file listed below it may read what was published. `shared/main.lua`
creates the namespace; `server/functions.lua` publishes the getters that every
file after it reaches for; `server/exports.lua` and `client/exports.lua` are last
in their blocks, because publishing the
surface claims everything it reads.

Two rules cost somebody something before they were written down.

!!! warning
    Do not `require` one of the resource's own files. A file both listed in the
    manifest and loaded by `require` executes **twice** — the manifest loader
    does not populate the `require` cache — and `require` is confined to the
    resource anyway, resolving only `<resource>/shared/helpers.lua` and its
    `init.lua`, so it could never have reached a library living elsewhere.

!!! danger
    Never glob a script entry. `**` needs at least one intermediate directory,
    so `server/**/*.lua` matches **nothing** against flat files, and an empty
    glob result stops the resource starting — on the client that refuses the
    whole session's resource set with `script_pattern_empty:…` and **no player
    can connect**. Every script is listed one per line for this reason.
    `web_files { "web/**" }` is not this case and is safe; the core declares no
    web files at all.

## Where to go next {#next}

- [Client exports](exports/client.md) — the 17 the client half publishes.
- [Server exports](exports/server.md) — the 11 another server resource calls, and who may call them.
- [Server API](server-api.md) — the `OPX.*` functions a file inside the core may call.
- [Player](player.md) — the `Player` object and `PlayerData`.
- [Hooks](hooks.md) — the four veto points.
- [Events](events.md) — every event name, in four tables.
- [Commands](commands.md) — the fourteen `/opx77*` commands and their ACL permissions.
- [Configuration](config.md) — every key an operator edits.
- [Jobs, gangs and origins](data.md) — the shipped definitions.
- [Permissions](permissions.md) — the manifest block, and what is deliberately not requested.
- [Types](types.md) — the annotated shapes.
