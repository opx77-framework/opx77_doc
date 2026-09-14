---
title: Architecture — one server resource, many client resources
description: Why OPX//77's server side is a single resource split into files while its client side is a set of independent resources, and why the manifest's load order is the framework's only dependency contract.
---

# Architecture

OPX//77 is shaped by one platform fact, and almost every decision on this page
is a consequence of it. Stated once, plainly: **on the OPEN//77 server runtime,
resources cannot call each other.** On the client runtime they can. The
framework is asymmetric because the platform is asymmetric, and reading it as
"the server half is unfinished" is the single most common misreading.

!!! info
    This page explains the shape. [The OPEN//77 platform](the-platform.md)
    states the constraints it follows from, with the evidence for each, and
    [Integration channels](integration-channels.md) says what a third-party
    developer can actually plug into.

## The constraint that decides everything {#the-constraint}

The OPEN//77 server Lua runtime installs no `exports`, no
`GetInvokingResource` and no cross-resource event bus. `TriggerEvent` walks the
handler table of its own VM and stops there; only the host fans a closed,
hard-coded set of names — player connect, disconnect and ready, resource start
and stop, tunable changes, the entity registries — into every resource.

The platform documents this itself, and reached the same conclusion OPX//77
did, about its own code:

> Early planning […] called for a third shared resource, `open77_gamemode`: a
> kernel owning "roster and disconnect handling, the lobby bucket, the queue,
> bucket allocation and release, the countdown, the state machine with guarded
> transitions, the scoreboard, and the return transaction" — callable the same
> way `open77_zones` and `open77_worldui` are.
>
> **It was never built, and Phase F's conclusion is that it should not be.**
>
> […] A second server resource could not be asked for anything — not "define a
> state machine," not "allocate a bucket," nothing. […] it is why **a gamemode's
> entire server side is one resource**.
>
> Compare this with `open77_zones` and `open77_worldui`, which genuinely are
> shared services: both are **client-only**, and the client runtime *does* have
> `exports` and `GetInvokingResource()`. That asymmetry is the whole reason two
> of the three planned shared resources exist and the third does not — **it is a
> platform fact, not an oversight to be fixed later.**
>
> — OPEN//77, *The gamemode kernel (and why it is not a resource)*

An `es_extended`-style core that third-party server resources call is therefore
not merely hard on this platform. There is no mechanism for it, and OPEN//77
cancelled its own attempt at one for exactly that reason.

## The server side is one resource, split by file {#server-side}

`opx77_core` is a single server resource. What would be a plug-in resource on
another framework is here **one more file added to `opx77_core/server/` and one
more line in `opx77_core/open77.lua`**. That file runs in the same Lua state as
the rest of the core, so it types `OPX.` and finds the whole framework already
in scope — `OPX.GetPlayer`, `OPX.AddMoney`, `OPX.Result`, `OPX.Storage`. There
is no second global, nothing to import, and nothing to negotiate.

This is not a workaround for the missing export mechanism; it is the only shape
that survives it. The alternative the platform recommends for gamemodes — a
scaffolder that generates a copy of the shared code into each new resource —
gives every generated resource its own player roster, its own money ledger and
its own writes against the same character rows. For a lobby-based gamemode
that is fine, because two of them are never live at once. For a persistent city
it is last-writer-wins data loss, and the platform makes it easy: `database.access`
is a boolean gate, not an allocation, so nothing stops two copies of the
framework from saving over each other.

One roster, one ledger, one writer. That is what "split by file" buys, and it is
the whole argument for it.

## The client side is many resources {#client-side}

On the client, `exports` and `GetInvokingResource()` both exist, and the local
event bus is host-wide rather than per-resource — a fact demonstrated by the
platform's own shipped code, where `open77_zones` fires a caller-supplied event
name with `TriggerEvent` and `pursuit`, a different resource, receives it with a
bare `AddEventHandler`.

So the client side is split the way you would expect a framework to be split.
`opx77_core` publishes a client half that mirrors the character and exposes it;
`opx77_menu`, `opx77_input`, `opx77_notify` and `opx77_status` are services
that own one piece of the screen each; `opx77_hud`, `opx77_chat`,
`opx77_weather`, `opx77_elevators`, `opx77_appearance`, `opx77_charselector`,
`opx77_charcreator`, `opx77_animations` and `opx77_admin` are consumers. Every
one of them is reachable from any other resource, because on this side of the
wire that is possible.

Two of them bend the shape, and both are worth knowing about:
[`opx77_status`](../reference/opx77_status/index.md) is the one satellite with a
server half and a table of its own — the character's gameplay needs — and
[`opx77_appearance`](../reference/opx77_appearance/index.md) is client-only yet
writes something durable, by sending it to a name the core's server half
registered. Neither is an exception to the rule below.

Two consequences are worth stating up front, because they surprise everyone
arriving from FiveM:

1. **Every OPX//77 export is client-side.** A server resource that needs core
   data sends a net event to its own client half, which calls the export and
   answers back. See [The export contract](export-contract.md).
2. **Anything that must be unforgeable lives in `opx77_core`'s server VM.** A
   client-side job check is a hint. It is a good hint, worth drawing a UI from,
   and no configuration turns it into proof.

## The layers {#layers}

Inside `opx77_core`, the directories are layers and the order is dependency
order.

| Directory | Contents |
|---|---|
| `config/` | The only files an operator edits. `UPPER_SNAKE` keys, split by who may read them: `shared.lua` reaches every client, `server.lua` and `client.lua` do not cross. |
| `data/` | Jobs, gangs and origins. Definitions, not settings — changing one renames something players already hold. |
| `shared/` | `OPX` itself: result, table, string, math, validate, hooks, locales, citizen ids. |
| `sql/` | One `.sql` file per table — the copy an operator reads. Not listed in the manifest, and not what runs. |
| `server/storage/` | Every SQL statement the resource runs, and the migrations. Nothing above this layer writes SQL. |
| `server/` | Roster, player, groups, characters, appearance, vehicles, the entry gate, events, commands, loops. |
| `client/` | The mirrored state and the exports surface. |

`config/shared.lua` is shipped to every client. Nothing secret belongs in it.

`client/exports.lua` is loaded **last**, because publishing the export surface
claims everything the surface reads: if it were published first, a caller could
arrive before the state it reads existed.

## Load order is the contract {#load-order}

`open77.lua` lists one file per line, and the order inside each block is
dependency order. A file publishes into `OPX`, and every file below it may read
what was published. That list is the framework's only dependency declaration —
there is no module system underneath it, and adding a server-side plug-in means
adding a line to it in the right place.

Two rules follow, and each of them has cost somebody something.

**No `require` on the resource's own files.** A file that is both listed in the
manifest and loaded through `require` executes **twice**, because the manifest
loader does not populate the `require` cache. The second execution re-runs every
top-level statement, which for a file that registers handlers means registering
them again. `require` is confined to the resource in any case, so it could never
have reached a library living elsewhere; there is nothing it can do here that a
manifest line cannot.

**No globs.** `server/**/*.lua` matches nothing against a flat directory, and an
empty glob is not a no-op:

!!! warning
    An empty glob in a manifest refuses the whole set it belongs to. In a
    `client_script` or `files` block that means no player can connect, and the
    failure appears only after a rename — the manifest that worked yesterday is
    unchanged, and the directory it pointed at is not. Every shipped OPEN//77
    resource lists its files one per line, and so does every OPX//77 resource.

## Where to go next {#next}

- [The OPEN//77 platform](the-platform.md) — the constraint sheet: sandbox,
  quotas, the network envelope, identity, the manifest, the database, ACL.
- [Integration channels](integration-channels.md) — what a third-party
  developer can plug into, and what each channel cannot do.
- [The export contract](export-contract.md) — the shape every client call takes.
- [Writing a server plugin](../guides/writing-a-server-plugin.md) — the file and
  the manifest line, step by step.
