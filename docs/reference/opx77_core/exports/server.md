---
title: opx77_core server exports
description: opx77_core publishes no server exports, because the OPEN//77 server runtime installs no export mechanism at all — this page proves it from the shipped runtime and routes you to the three channels that replace it.
---

# Server exports

**There are none, and there can be none.** Not in `opx77_core`, not in any
resource, not in a future release. This is the one page most developers arriving
from ESX or Qbox look for first, so it says so plainly rather than being an
empty section.

If you came here to write
`exports.opx77_core:GetPlayer(source)` in a server script, skip to
[what to use instead](#instead).

## Why {#why}

The OPEN//77 **server** runtime installs no export mechanism. Three official
pages say so; this is the shortest of them:

> **Server resources cannot call each other.** The server runtime installs no
> `exports`, no `GetInvokingResource`, and no cross-resource event bus.
> `TriggerEvent` is per-VM; only the host fans events into resources. A second
> server resource could never be asked for anything.
>
> — OPEN//77, *Writing a gamemode*

The shipped server binary agrees. This is the whole of `TriggerEvent` in the
runtime's own Lua bootstrap, recovered from the assembly:

```lua
function TriggerEvent(name, ...)
  local args = table.pack(...)
  for _, entry in pairs(handlers) do
    if entry.name == name then schedule(function() entry.fn(table.unpack(args, 1, args.n)) end, now) end
  end
end
function __open77_emit(name, ...) TriggerEvent(name, ...) end   -- called BY THE HOST, never by Lua
```

`handlers` is a file-local table created at the top of that bootstrap. There is
no path out of the VM: a server `TriggerEvent` walks its own resource's handlers
and stops. `__open77_emit` is the host's way *in*, and the set of names the host
fans is closed and compiled into the server — a framework cannot add one.

!!! warning "A cross-resource server call fails silently, and never reports it"
    There is nothing to raise. `exports` is simply not a global on the server,
    so `exports.opx77_core` indexes a nil value; and a `TriggerEvent` aimed at
    another resource matches no handler and schedules nothing, which looks
    exactly like a handler that ran and did nothing. Nothing is logged either
    way. Whole afternoons have gone into debugging the second one.

**The client is the opposite**, and this catches people out in the other
direction: the client runtime *does* have `exports` and `GetInvokingResource`,
and its local event bus is host-wide. Everything OPX//77 publishes to third
parties lives there — see [client exports](client.md).

## What to use instead {#instead}

| You want | Use | Synchronous? |
|---|---|---|
| To call the core's server API — `GetPlayer`, `AddMoney`, `SetJob` — and get an answer | [A file inside `opx77_core/server/`](#a-file-in-the-core) | Yes |
| To read the character from your own resource, without touching the core | [Your client half, calling a client export](#the-client-leg) | No — a promise |
| To be told when something happened, from a server resource you do not own | [The `onPlayerReady` release note, or the shared database](#loose) | No |

### 1. A file inside `opx77_core/server/` {#a-file-in-the-core}

This is the honest answer to "how do I write a plug-in", and it is the only one
that is synchronous. On this platform a plug-in is **a file you add to the core
and a line you add to its manifest** — files inside one resource share a Lua
state, so your file sees the whole `OPX` namespace exactly as the core's own
files do.

```lua
-- opx77_core/server/plugins/paydirt.lua, listed in open77.lua after server/player.lua
local ok, why = OPX.AddMoney(source, "CASH", 500, "paydirt")
if not ok then
  OPX.NotifyLocale(source, why, nil, "error")
end
```

Read [Writing a server plugin](../../../guides/writing-a-server-plugin.md) for
the layout, the reserved manifest block and what you inherit by living inside
the core; every function you can call is in the
[Server API](../server-api.md), and the veto points are in [Hooks](../hooks.md).

What it costs: your code ships inside somebody else's resource, and you own a
merge every time the core is updated. That is the trade the platform imposes,
not a preference.

### 2. Your own client half {#the-client-leg}

If what you need is the character — their job, their money, their metadata — and
you do not need it to be unforgeable, do not touch the core at all. Ask its
client half, from your client half, and pass the answer down to your server half
over your own net event.

```lua
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_core", "GetPlayerData")
  if not promise then return end
  local result, callError = promise:await()
  if callError or not result.ok then return end
  TriggerServerEvent("myresource:sawCharacter", result.data.citizenId)
end)
```

!!! warning
    Anything that arrives at your server through a client is a **hint**, not
    proof. The client is the player's own machine, and a citizen id it reports
    is a claim. Use this for presentation and convenience; anything that must be
    unforgeable belongs in route 1.

The full list is in [client exports](client.md), the failure model in
[The export contract](../../../concepts/export-contract.md).

### 3. The release note, and the shared database {#loose}

Two more channels exist for a server resource that owns no code inside the core.

- **The `onPlayerReady` `detail` note** reaches every server VM, once per player
  per join, carrying one short string. The core passes
  `opx77_core:character-placed` or `opx77_core:character-loaded`, so a resource
  can learn that a character has been placed without any channel of its own.
  See [Events](../events.md#onplayerready).
- **The shared database** is one connection with one credential and no
  per-resource schema, so a resource holding `database.access` can read the
  core's tables. It is the loosest coupling here and the most dangerous: the
  same grant that lets you read `opx77_characters` lets you write it, bypassing
  every guard the core has.

!!! danger
    The core is the only writer of `opx77_characters`, `opx77_character_groups` and
    `opx77_vehicles`. Read them if you must; do not write them. A row written
    behind the core's back is overwritten by the next autosave at best, and
    silently disagrees with the loaded character at worst.

Both channels, with what each cannot do, are in
[Integration channels](../../../concepts/integration-channels.md#release-note).

## Coming from ESX or Qbox {#converting}

| There | Here |
|---|---|
| `ESX.GetPlayerFromId(source)` | `OPX.GetPlayer(source)`, in a file inside the core |
| `exports.qbx_core:GetPlayer(source)` | `OPX.GetPlayer(source)`, in a file inside the core |
| `exports['es_extended']:getSharedObject()` | Nothing. `OPX` is already the shared object, inside the core |
| `xPlayer.addAccountMoney(...)` | `OPX.AddMoney(identifier, moneyType, amount, reason)` |
| A server-side event another resource fires at the core | A file in the core, or one of the two channels above |

The habits transfer; the call shapes do not. The full walk-through is in
[Converting from ESX or Qbox](../../../guides/converting.md).

## Where to go next {#next}

- [Writing a server plugin](../../../guides/writing-a-server-plugin.md) — route 1, end to end.
- [Server API](../server-api.md) — every `OPX.*` function that file may call.
- [Client exports](client.md) — the fifteen that do exist.
- [Integration channels](../../../concepts/integration-channels.md) — all four channels, with their ceilings.
