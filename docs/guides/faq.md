---
title: Frequently asked questions
description: Short answers to the questions OPX//77 actually provokes — why a server resource cannot call the core, why every export is client-side and asynchronous, whether ox_lib works, and whether the elevator job check is secure.
---

# FAQ

Short answers, each with a link to the page that explains it properly. If you
are hunting a fault rather than a design decision,
[Troubleshooting](troubleshooting.md) is organised by symptom.

## Why can't my server resource call the core? {#why-no-server-calls}

Because the OPEN//77 **server** runtime installs no `exports`, no
`GetInvokingResource` and no cross-resource event bus, and `TriggerEvent` on the
server walks only its own Lua state. There is no channel between two server
resources at all — not a slow one, not a restricted one, none.

This is a platform fact, not an OPX//77 decision. The platform documents it, its
own gamemode kernel is built around it, and its flagship gamemode `pursuit`
carries a byte-identical copy of another resource's data file because there is no
way to share one.

What to do instead: put your code in `opx77_core/server/` as a file plus a
manifest line — see [Writing a server plugin](writing-a-server-plugin.md) — or
route through your own client half, or read the database. All three, ranked, are
in [Integration channels](../concepts/integration-channels.md).

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

On the server there is no object to fetch because there is nothing to fetch it
from. `OPX` is a plain global living in one Lua state, and code that needs it has
to be compiled into that state. See
[Converting from ESX or Qbox](converting.md#getting-the-framework).

## Why is every export asynchronous? {#why-async}

Because the runtime dispatches a cross-resource call rather than executing it
inline. `Open77.exports.call` hands you a promise; `promise:await()` resolves it,
and `await` is coroutine-only, so every call site is inside a `CreateThread`.

The cost is real and the benefit is that a resource cannot be blocked by another
resource's handler. It also means an **export handler cannot itself await**,
because a handler is not a coroutine — an export that needs to call out queues
the work and answers "asked", which is why `opx77_elevators`' `panel` export
returns `{ ok = true, queued = true }` rather than "the menu is on screen".

See [The export contract](../concepts/export-contract.md).

## Why is every OPX//77 export client-side? {#why-client-side}

Because the client is the only runtime that has `exports` and
`GetInvokingResource` to publish them with. It is not that the server side was
left for later — there is no `exports` function in the server VM to call.

The consequence catches everyone arriving from FiveM: a **server** resource that
needs core data cannot ask for it. It sends a net event to its own client half,
which calls the export, and the client sends the answer back — and the answer
therefore came from the player's machine and is a hint, not proof.

## Why does every export answer `{ ok = boolean, ... }`? {#why-ok-tables}

Because the value crosses a serialising codec and lands in a Lua state that does
not have OPX//77 loaded. It has no `OPX.Result`, no metatables of yours, and no
error class of yours. A plain table with a boolean and a short stable string code
is the only shape that survives the trip and can still be branched on.

It also means an export never raises. A refusal is a value, so a caller that
checks `result.ok` has handled every case the target can produce — and a caller
that does *not* check it gets a table with `ok = false` rather than a nil that
looks like an empty answer.

## Is there a server callback, like `ESX.RegisterServerCallback` or `lib.callback`? {#no-callbacks}

No, and there cannot be one across resources. Both of those libraries work by
being loaded into your resource and reaching the core with a cross-resource call
at the far end; neither half exists here.

Within one resource, a client asking its own server half a question is a pair of
net events with a correlation id, and you write it yourself — it is about a dozen
lines. Between two client resources, `Open77.exports.call` already returns a
promise, so that case is solved. Between two server resources, there is no
channel. See
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

## Why is there no inventory? {#why-is-there-no-inventory}

Because an inventory is a large, opinionated system that every server wants
differently, and shipping one badly is worse than not shipping one. ESX's costs a
database row per item per player *including zero counts*; Qbox delegates to
`ox_inventory` and inherits its shape.

OPX//77 ships characters, money, jobs, gangs, metadata and persistence, and
nothing that pretends to be an item system. If you build one, its authoritative
half belongs in `opx77_core/server/` alongside the money it will need — see
[Writing a server plugin](writing-a-server-plugin.md) — and `metadata` is where
per-character state already lives.

## Is the job check on the elevators secure? {#elevator-security}

**No,** and the resource says so in four places: its README, its `config.lua`, its
`types.lua` and its `client/main.lua`.

The job gate on `opx77_elevators` is decided on the **client**, from the client's
own mirror of `PlayerData`. A modified client skips the whole of it. There is no
setting that turns it into anything else, and there cannot be one, because the
resource's server half cannot ask `opx77_core` who the player is — see
[the first question on this page](#why-no-server-calls).

That is the right trade for an elevator: the cost of a bypass is reaching a floor
early. It is emphatically **not** the right trade for money, contraband, or
anything a player would pay for. Anything unforgeable belongs in
`opx77_core/server/`.

## Does a client-side `HasJob` count as a permission check? {#hasjob-hint}

No, for the same reason. `HasJob` and `HasGang` read the client's mirror and are
the right call for deciding what to *draw* — greying a row, hiding a prompt,
choosing a label. They are never the right call for deciding what a player is
allowed to *do*.

## Do I really need `open77_appearance`? {#need-appearance}

For OPX//77 itself, no: the core neither reads `Open77.ready.isReady` nor waits
for `onPlayerReady`, so characters load and are placed without it.

For the platform's readiness gate, yes. Every joiner holds a `__platform` hold
that no Lua can release and that has no deadline; it clears only when the client
sends `open77:session:gameplayReady`, which in practice means
`open77_appearance`. Without it the gate never opens for anybody, and any
resource written to wait on it waits for ever. See
[Getting started](getting-started.md#the-appearance-requirement).

## Why does nothing listen for `playerDropped`? {#no-playerdropped}

Because the host never emits it. The departure event on this platform is
`onPlayerDisconnected`. A handler registered for `playerDropped` is not an error
and will not warn — it simply never runs, which is the worst kind of dead code.

## Why is the server side one resource instead of a core plus plug-ins? {#one-server-resource}

Because a plug-in resource on this platform could never be asked for anything and
could never ask the core for anything. Splitting the server side into resources
would produce several mutually unreachable Lua states, which is strictly worse
than one reachable one.

The client side is the opposite and is split properly: client exports exist,
`GetInvokingResource` exists, and the client's local event bus is host-wide. That
asymmetry is the single most important thing to understand about this platform,
and [Architecture](../concepts/architecture.md) is the long version.

## Where do I find every export, event and config key? {#where-is-the-reference}

[Reference](../reference/index.md) — one section per resource, with the error
codes each call can produce and, for every entry, which side it can be called
from.
