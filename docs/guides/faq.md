---
title: Frequently asked questions
description: Short answers to the questions OPX//77 actually provokes — why a server resource cannot call OPX.GetPlayer but can call the core's server exports, why most exports are client-side and every one asynchronous, whether ox_lib works, and whether the elevator job check is secure.
---

# FAQ

Short answers, each with a link to the page that explains it properly. If you
are hunting a fault rather than a design decision,
[Troubleshooting](troubleshooting.md) is organised by symptom.

## Why can't my server resource call `OPX.GetPlayer`? {#why-no-server-calls}

Because `OPX` is a plain Lua global in `opx77_core`'s own server VM, and every
resource runs in a VM of its own. The server API — `OPX.GetPlayer`,
`OPX.AddMoney`, `OPX.Hooks.register` and the rest — hands out live tables and
takes functions, and none of it is an export.

What a server resource *can* call is a server export. OPEN//77 server resources
publish them with `exports` and call them with `Open77.exports.call`, the same
asynchronous surface as on the client, and `opx77_core` publishes
[eleven](../reference/opx77_core/exports/server.md): `GetIdentity`,
`GetChanges`, `GetVehiclePlate` and `GetVersion` for any server resource its
`EXPORTS.READ` admits, and seven inventory storage exports for a caller its
`EXPORTS.CALLERS` grants a scope. `opx77_status` asks `GetIdentity` which
character a player has loaded; `opx77_admin` calls
[`opx77_inventory`'s server exports](../reference/opx77_inventory/exports.md#server).
What no server export answers is a character's money, job or metadata, and no
export can veto anything.

For those: put your code in `opx77_core/server/` as a file plus a manifest line —
see [Writing a server plugin](writing-a-server-plugin.md) — or route through your
own client half, or read the database. The options, ranked, are in
[Integration channels](../concepts/integration-channels.md).

## Where is `ESX.GetSharedObject`? {#where-is-getsharedobject}

Nowhere, and it does not exist in current ESX either — it was removed several
releases ago. The ESX path that still works is
`exports["es_extended"]:getSharedObject()` or the `@es_extended/imports.lua`
textual include.

Neither has an OPX//77 equivalent. On the client you do not fetch an object at
all; you name the resource on every call:

```lua
local promise = Open77.exports.call("opx77_core", "GetPlayerData")
```

On the server there is no object to fetch either. `OPX` is a plain global living
in one Lua state, and code that needs it has to be compiled into that state; what
the core offers other server resources is a handful of server exports, called by
name the same way. See
[Converting from ESX or Qbox](converting.md#getting-the-framework).

## Why is every export asynchronous? {#why-async}

Because the runtime dispatches a cross-resource call rather than executing it
inline. `Open77.exports.call` hands you a promise; `promise:await()` resolves it,
and `await` is coroutine-only, so every call site is inside a `CreateThread`.

The cost is real and the benefit is that a resource cannot be blocked by another
resource's handler. On the client it also means an **export handler cannot
itself await**, because a handler is not a coroutine — an export that needs to
call out queues the work and answers "asked", which is why `opx77_elevators`'
`openPanel` export returns `{ ok = true, queued = true }` rather than "the menu is
on screen". A server export runs as a managed coroutine on the target's
scheduler, and may await.

See [The export contract](../concepts/export-contract.md).

## Why are most OPX//77 exports client-side? {#why-client-side}

Because what a satellite asks about is mostly the local player: the loaded
character, a menu, a toast, a prompt. `GetPlayerData`, `HasJob` and `HasGang`
read the core's client mirror, and every drawing service lives with its WebUI
surface on the client. Server exports exist too — `opx77_core` publishes identity,
a change cursor, a vehicle's plate and the inventory storage, and
`opx77_inventory` publishes its bag operations — but they answer only what they
list.

The consequence catches everyone arriving from FiveM: a **server** resource that
needs a character's job cannot ask the core for it. It sends a net event to its
own client half, which calls the export, and the client sends the answer back —
and the answer therefore came from the player's machine and is a hint, not proof.

## Why does every export answer `{ ok = boolean, ... }`? {#why-ok-tables}

Because the value crosses a serialising codec and lands in a Lua state that does
not have OPX//77 loaded. It has no `OPX.Result`, no metatables of yours, and no
error class of yours. A plain table with a boolean and a short stable string code
is the only shape that survives the trip and can still be branched on.

It also means an export never raises. A refusal is a value, so a caller that
treats anything but `ok == true` as a refusal — `if result.ok ~= true then` —
has handled every case the target can produce, including an answer that carries
no `ok` at all. A caller that does *not* check it gets a table with `ok = false`
rather than a nil that looks like an empty answer.

## Is there a server callback, like `ESX.RegisterServerCallback` or `lib.callback`? {#no-callbacks}

No, and there cannot be one across resources. Both of those libraries are loaded
into your resource and hand the far end a closure to call back; there is no
library to load into another resource's VM here, and a function cannot cross a
resource boundary.

Within one resource, a client asking its own server half a question is a pair of
net events with a correlation id, and you write it yourself — it is about a dozen
lines. Between two client resources, or two server resources,
`Open77.exports.call` already returns a promise, so that case is solved for
whatever the target exports. See
[Converting from ESX or Qbox](converting.md#no-server-callbacks).

## Why are there two sets of event names for the same thing? {#two-event-vocabularies}

`opx77:client:playerLoaded` is what the **server sends over the wire**; listening
on it needs `network.events` and `RegisterNetEvent`.
`opx77:client:onPlayerLoaded` is what the **core's client half raises locally**
after its mirror has been updated; listening on it needs a bare `AddEventHandler`
and no permission. Both are public and supported, and the local one is what a
satellite should normally use.

They must not share a name. On this platform a `TriggerEvent` also reaches every
`RegisterNetEvent` handler of the same name — the dispatcher matches on the name
and never looks at the network flag — so a local re-emission that reused its own
wire name would re-enter the handler that fired it. It is tick-paced rather than
recursive, which makes it a **silent permanent busy loop** rather than a crash:
nothing errors, nothing is logged, the resource simply stops. Keeping the two
vocabularies disjoint is what prevents it.

## Can I use ox_lib, ox_inventory, or any other FiveM resource? {#ox-lib}

No. OPEN//77 is not FiveM. It is a different runtime with a different manifest
grammar (`open77.lua`, not `fxmanifest.lua`), a different permission model, a
different event and export API, and none of the CitizenFX natives those resources
are built on. `lib.callback`, `lib.registerContext`, statebags, `exports.name:fn()`
and `Citizen.*` do not exist here.

Port the *idea*, not the file. `opx77_menu` is the context-menu equivalent,
[`opx77_notify`](../reference/opx77_notify/index.md) is the toast service, and
[Converting from ESX or Qbox](converting.md) maps the rest.

## Is there an inventory? {#why-is-there-no-inventory}

Yes: [`opx77_inventory`](../reference/opx77_inventory/index.md). A character
carries a bag of slots and grams; stashes, vehicle trunks and gloveboxes, and
piles on the ground sit beside it on one screen; weapons are items, drawn by
using them. The server is the only authority on what a container holds, and the
resource owns no table of its own: `opx77_core` stores every container and every
stack, and needs to be 0.4.0 or later for it.

Another server resource changes a bag through its
[server exports](../reference/opx77_inventory/exports.md#server) — a shop charges
through the core and calls `AddItem` — once it is listed in
[`EXPORTS.WRITERS`](../reference/opx77_inventory/config.md#exports). Money stays
in `opx77_core` and is not an item, and worn clothing is not an item either.

## Is the job check on the elevators secure? {#elevator-security}

**No,** and the resource says so: at the top of its README, and again in its
`std/types.lua` and its `docs/ARCHITECTURE.md`.

The job gate on `opx77_elevators` is decided on the **client**, from the client's
own mirror of `PlayerData`. A modified client skips the whole of it. There is no
setting that turns it into anything else, because the resource's server half
cannot ask `opx77_core` which job a character holds: none of the core's server
exports answers it — see [the first question on this page](#why-no-server-calls).
The server half re-derives everything else: the elevator, the floor, the
player's position and routing bucket, and the rate.

That is the right trade for an elevator: the cost of a bypass is reaching a floor
early. It is emphatically **not** the right trade for money, contraband, or
anything a player would pay for. Anything unforgeable belongs in
`opx77_core/server/`.

## Does a client-side `HasJob` count as a permission check? {#hasjob-hint}

No, for the same reason. `HasJob` and `HasGang` read the client's mirror and are
the right call for deciding what to *draw* — greying a row, hiding a prompt,
choosing a label. They are never the right call for deciding what a player is
allowed to *do*.

## Do I really need an appearance resource? {#need-appearance}

For OPX//77 itself, no: the core never waits on `Open77.ready.isReady` or
`onPlayerReady`, so characters load and are placed without one. It only reads
the gate at a client's `opx77:server:ready`, to put a player still behind it
back in their own selection bucket, and logs `onPlayerReady` when a gate opened
on lost liveness.

For the platform's readiness gate, yes. Every joiner holds a `__platform` hold
that no Lua can release and that has no deadline; it clears only when the client
sends `open77:session:gameplayReady`. In this resource set
[`opx77_appearance`](../reference/opx77_appearance/index.md) is what sends it,
and it ships with the framework — so on a stock install this is already handled.
Stop it, or run the set without it, and the gate never opens for anybody: any
resource written to wait on it waits for ever. The official `open77_appearance`
sends the announcement too, and the core's boot check accepts either name, but it
is not a replacement for this one: it follows the platform's own join model, and
running both conflicts — they fight over the bootstrap and the face. Run one. See
[Getting started](getting-started.md#the-appearance-requirement).

And for seeing each other, yes. The engine does not replicate a player's look,
and another client draws a player only from the body, equipment and outfit it is
handed; `opx77_appearance` hands every player's look to the others. See
[How other players see this one](../reference/opx77_appearance/index.md#presence).

And for the join itself, yes again. The platform's loading cover stays up until
something spends the one-shot character bootstrap, and nothing a server resource
draws shows through it — the roster included. `opx77_appearance` spends it at
join, on the body of the account's most recently played character, so the world
loads first and the character is chosen in it. See
[The entry gate](../concepts/entry-gate.md#world-first).

## Why is the character chosen in the world, not in a menu before it? {#select-in-world}

Because there is no "before it" a server resource can draw on. Until the
character bootstrap is spent, the player sees the platform's opaque loading
cover and nothing else: a roster opened there is open, holds the keyboard, and
is invisible, so nobody ever chooses. The platform's own model agrees — its
`open77_appearance` README makes character selection the gamemode's job, after
the world, with a body reload for a character on the other body.

So OPX//77 loads a body it can guess before anybody is chosen — the last
character played — and puts the roster, the identity form and the face editor
in the gameplay world, with the camera turned to face the player's character.

## Why does nothing listen for `playerDropped`? {#no-playerdropped}

Because the host never emits it. The departure event on this platform is
`onPlayerDisconnected`. A handler registered for `playerDropped` is not an error
and will not warn — it simply never runs, which is the worst kind of dead code.

## Why is the server side one resource instead of a core plus plug-ins? {#one-server-resource}

Because the server API is not data. A plug-in works on a `Player` with its
`Functions`, vetoes a money movement with a hook function, and reads `OPX.Events`
raised with `TriggerEvent` — and a function cannot cross an export, while
`TriggerEvent` on the server walks only its own VM. Split into resources, those
plug-ins would each be left with what the core chooses to export, which is plain
data and nothing that can veto.

So the core stays one server resource with a file-based plug-in convention, and
publishes server exports only for what a separate server resource needs:
identity, a change cursor, a vehicle's plate and the inventory storage. The
client side is split properly into satellites: client exports and
`GetInvokingResource` exist there, and the client's local event bus is host-wide.
[Architecture](../concepts/architecture.md) is the long version.

## Where do I find every export, event and config key? {#where-is-the-reference}

[Reference](../reference/index.md) — one section per resource, with the error
codes each call can produce and, for every entry, which side it can be called
from.
