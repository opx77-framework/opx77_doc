---
title: For creators — using OPX//77 from your own resource
description: How a separate Open77 resource talks to opx_infinity — server exports, client exports and public server events — who may call them, the answer every export gives, and when you must await.
---

# For creators

This section is for a **separate** Open77 resource — your own job, shop or
heist — that wants to use OPX//77. `opx_infinity` gives you three doors and
nothing else:

| Door | Side | Use it to | Page |
|---|---|---|---|
| Server exports | server | read a player (money, job, items), change money, items, stashes, chat, keys, a vehicle's state | [Server exports](server-exports.md) |
| Client exports | client | open a menu or form, show a toast, run a progress bar, play an animation on the local player | [Client exports](client-exports.md) |
| Public server events | server | react when a character loads, money moves, an item is used… | [Server events](server-events.md) |

The modules' own contracts (`OPX.Api.Get`) stay inside `opx_infinity`. If you
need more than these doors give, write a [module](../guides/writing-a-module.md)
instead.

## Every export answers one table {#answer}

```lua
{ ok = true,  value = <answer> }    -- value may be nil
{ ok = false, error = '<code>' }    -- a stable code you can branch on
```

An export never raises. Always test `answer.ok == true`.

| Code | Meaning |
|---|---|
| `export.callerDenied` | Your resource is not allowed to make this call (see [Who may call](#allowlist)). |
| `export.badArgument` | An argument could not be read (wrong type, bad player id, bad citizen id, name too long…). |
| `export.booting` | The server has not finished starting. Try again later. |
| `export.mustAwait` | This call can reach the database. Call it with `Open77.exports.call(...)` and `:await()` (see below). |
| `error.unavailable` | The module behind the export is not running, or the call failed. |
| `error.notLoggedIn` | That player has no character loaded. |
| other codes | Passed through from the module: `money.insufficient`, `stash_cap`, `vehicle.busy`… Each export lists its own. |

A code is not a sentence. The `export.*` codes have English and French text in
`opx_infinity`, but your resource has its own text; translate the codes you
show. See [Error codes](../reference/error-codes.md).

## Who may call {#allowlist}

The caller is the resource name **the host reports** (`GetInvokingResource`),
never an argument. The operator decides who is allowed:

| Setting | File | Default | Controls |
|---|---|---|---|
| [`SERVER.EXPORTS.READ`](../reference/core-config.md#config-server-exports) | `config/server.lua` | `'*'` (everyone) | server exports that only read |
| [`SERVER.EXPORTS.WRITERS`](../reference/core-config.md#config-server-exports) | `config/server.lua` | `{}` (**nobody**) | server exports that change something |
| [`CLIENT.EXPORTS.CALLERS`](../reference/core-config.md#config-client-exports) | `config/client.lua` | `'*'` (everyone) | client exports |

A list is `'*'`, a set `{ my_shop = true }` or an array `{ 'my_shop' }`.

When a server export refuses your resource, the server journal prints the exact
line to add, once per resource and export:

```text
[exports] my_shop was refused AddMoney; to admit it, add `my_shop = true` to EXPORTS.WRITERS in config/server.lua
```

!!! warning "Writers are trusted with money"

    A resource in `WRITERS` can create money and items. Every write is audited
    with the caller's name (`event=export.<Name>`), and money reasons are
    written `ext:<resource>:<reason>`.

## Sync or await? {#await}

Open77 lets you call an export two ways:

```lua
-- synchronous: answers at once; fails if the export has to wait
local answer = exports.opx_infinity:GetPlayerData(playerId)

-- asynchronous: returns a promise; call it from a thread and await it
local pending, why = Open77.exports.call('opx_infinity', 'AddMoney', playerId, 'EDDIES', 250, 'tip')
local answer = pending and pending:await()
```

| Use the sync form for | Use `Open77.exports.call(...):await()` for |
|---|---|
| `GetVersion`, `GetPlayerData`, `GetPlayerByCitizenId`, `IsStaff`, `GetMoney`, `HasJob`, `HasGang`, `GetJob`, `GetGang` — they answer from memory | **every write**, and every call that may reach the database: `AddMoneyOffline`, the stash exports, `RevokeKeys`, `RevokeAllKeys`, `SetVehicleState`, and the item exports when `target` is a citizen id |

A call that may reach the database, made synchronously, answers
`export.mustAwait` **before** touching anything, so it is safe to retry with the
promise form. `await` needs a thread: call it from `CreateThread`, an event
handler or a command handler, never at file scope.

## Your manifest {#manifest}

```lua
-- my_shop/open77.lua (optional, recommended)
dependency "opx_infinity"
```

A declared dependency makes the platform start `opx_infinity` first and stop
your resource with it. It does not grant anything: the allowlist still decides. Publishing and
calling exports needs no permission. A client resource that wants answers must
publish a reply export; see [Client exports](client-exports.md#replies).
