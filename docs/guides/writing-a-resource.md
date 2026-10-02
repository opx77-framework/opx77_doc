---
title: Write a separate resource that works with OPX//77
description: What a resource outside opx_infinity can read and do today — player state bags, server-side events, ordinary commands, opx_lib and the database — and what it cannot, because opx_infinity publishes no exports.
---

# Write a separate resource

This page is for a resource that is **not** part of `opx_infinity` — your own
`my_jobs` resource, for example. If you can, write a
[module](writing-a-module.md) instead: a module can call every
[contract](../how-it-works/modules-and-contracts.md#contracts); a separate
resource cannot.

!!! warning "opx_infinity publishes no exports"

    The old `opx77_*` resources answered `Open77.exports.call(...)`. The single
    resource that replaced them calls `exports(...)` nowhere. Contracts such as
    `character.AddMoney` live inside its Lua VM and no other resource can reach
    them. What is left is listed below. The missing pieces are tracked as API
    gaps by the maintainers.

## What a separate resource can use {#surface}

| Surface | Side | Stable? | Use it for |
|---|---|---|---|
| [Player state bag](#state-bag) | client and server, read | yes — documented keys | name, job, gang, citizen id of any player in the same bucket |
| [Server internal events](#server-events) | server, listen | **no** — private names that may change | knowing when a character loads, money moves, a job changes |
| [Ordinary commands](#commands) | server | yes — command names are stable | triggering an unrestricted command |
| [opx_lib](#opx-lib) | client | yes — versioned library | input, markers, zones, RPC helpers… |
| [Database tables](#database) | server, read | **no** — schema may change | reports, read-only tools |

### The player state bag {#state-bag}

The [character module](../modules/character.md#state-bag) writes public facts
about each loaded character on the player's replicated state bag. Any resource
can read them with no permission:

```lua
-- client or server, any resource
local who = Open77.state.player(playerId)
if who.job and who.job.name == 'police' then
	-- ...
end
```

Keys: `citizenId`, `name`, `charInfo`, `job`, `gang`, `username`, `life`. A
client only receives bags of players in **its own routing bucket**. Money,
metadata and inventory are deliberately **not** in the bag.

### Server internal events {#server-events}

On the server, `TriggerEvent` reaches every resource. The character module
raises these private events, which another server resource can hear with
`AddEventHandler`:

| Event | Arguments |
|---|---|
| `opx:in:character:loaded` | `source, playerData` |
| `opx:in:character:unloaded` | `source, playerData` |
| `opx:in:character:money` | `source, citizenId, moneyType, amount, action, reason, balance` |
| `opx:in:character:job` | `source, job` |
| `opx:in:character:gang` | `source, gang` |
| `opx:in:character:paycheck` | `source, payment, jobName` |

They are `opx:in:` names: internal, not a promise. They can change in any
release. Never **raise** them from your resource; `opx_infinity` treats them as
its own.

The public `opx:on:` events are all raised on the **client**, where
`TriggerEvent` does not leave `opx_infinity`, so a separate resource cannot hear
them.

### Commands {#commands}

A server resource whose manifest declares `runtime.commands` can queue an
**unrestricted** command line with `ExecuteCommand(line)`. Restricted (staff)
commands are refused. The answer goes to the server log, not back to you. See
each [module page](../modules/index.md) for the commands and who may run them.

### opx_lib {#opx-lib}

`opx_lib` is a client library any resource may use:

```lua
-- my_resource/open77.lua
dependency "opx_lib"
```

```lua
-- my_resource/client/main.lua
local Lib = require('@opx_lib')
print(Lib.Manifest())   -- the permissions line your manifest needs
```

See the [opx_lib reference](../reference/opx-lib.md).

### The database {#database}

With `database.access` your resource can read the tables `opx_infinity` owns.
Each module page names its tables. Treat them as **read-only**: writing a
character row behind `opx_infinity`'s back bypasses its rules, its hooks and
its audit, and its in-memory copy will overwrite your change.

## What you cannot do today {#cannot}

| You want to | Status |
|---|---|
| Give or take money, items, jobs | No public way. Use a [module](writing-a-module.md) and the `character`/`inventory` contracts. |
| Read a player's money or inventory | No public way (not in the state bag). |
| Open an OPX menu, form, panel or toast from your resource | No public way; these are client contracts inside `opx_infinity`. |
| Veto an action (hooks) | `OPX.Hooks` runs inside `opx_infinity` only. |
| Hear an OPX event on the client | Not possible; client events stay in one resource. |

## A note on the old export contract {#old}

Code written for `opx77_*` exports (`Open77.exports.call('opx77_core', ...)`)
no longer works. See [From opx77_* to opx_infinity](../migration/from-opx77.md)
for where each old export went.
