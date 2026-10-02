---
title: Write a separate resource that works with OPX//77
description: How a resource outside opx_infinity uses OPX//77 — server and client exports, public server events, the player state bag, opx_lib — and what it still cannot do.
---

# Write a separate resource

This page is for a resource that is **not** part of `opx_infinity` — your own
`my_jobs` resource, for example. It can use the curated surface `opx_infinity`
publishes for creators. If you need a module's full contract (every function
of `character`, `inventory`…), write a [module](writing-a-module.md) instead.

## What a separate resource can use {#surface}

| Surface | Side | Use it for | Read |
|---|---|---|---|
| Server exports | server | read a player's data, money, job, items; change money, items, stashes, chat, keys, vehicle state | [Server exports](../creators/server-exports.md) |
| Client exports | client | open a menu or form, show a toast, run a progress bar, play an animation on the local player | [Client exports](../creators/client-exports.md) |
| Public server events | server | react when a character loads, money moves, an item is used, a car is bought… | [Server events](../creators/server-events.md) |
| [Player state bag](#state-bag) | client and server, read | name, job, gang, citizen id of any player in the same bucket, with no call at all | below |
| [opx_lib](#opx-lib) | client | input, markers, zones, RPC helpers… | [opx_lib](../reference/opx-lib.md) |
| [Ordinary commands](#commands) | server | running an unrestricted command | below |

Start with [For creators](../creators/index.md): it explains the answer every
export gives, the allowlist the operator controls (writes are refused until your
resource is added to `SERVER.EXPORTS.WRITERS`), and when you must
`await`.

## A minimal example {#example}

```lua
-- my_jobs/open77.lua
resource "my_jobs"
version "1.0.0"
dependency "opx_infinity"
server_script "server.lua"
client_script "client.lua"
permissions { "network.events" }
```

```lua
-- my_jobs/client.lua
exports('OnOpxEvent', function(event, payload) TriggerEvent(event, payload) end)

RegisterCommand('jobmenu', function()
	exports.opx_infinity:OpenMenu({
		title = 'ODD JOBS',
		closeOnSelect = true,
		items = { { id = 'deliver', label = 'Deliver a parcel' } },
	})
end)

AddEventHandler('opx:on:menu:action', function(p)
	if p.action == 'select' and p.itemId == 'deliver' then
		TriggerServerEvent('my_jobs:start')
	end
end)
```

```lua
-- my_jobs/server.lua   (operator adds my_jobs = true to SERVER.EXPORTS.WRITERS)
RegisterNetEvent('my_jobs:start', function()
	local playerId = source
	CreateThread(function()
		local job = exports.opx_infinity:GetJob(playerId)        -- a read: sync is fine
		if not job.ok then return end
		-- ... run the job, check it on the server, then pay:
		local pending = Open77.exports.call('opx_infinity', 'AddMoney',
			playerId, 'EDDIES', 200, 'odd job')
		local answer = pending and pending:await()
		if answer and answer.ok then
			exports.opx_infinity:SendChat(playerId, { text = 'Paid 200 €$', kind = 'info' })
		end
	end)
end)

AddEventHandler('opx:on:character:unloaded', function(playerId, payload)
	-- forget anything you kept for payload.citizenId
end)
```

`SendChat` is a write too, so it needs the same allowlist entry; it answers at
once, so the sync form works.

## The player state bag {#state-bag}

The [character module](../modules/character.md#state-bag) writes public facts
about each loaded character on the player's replicated state bag. Any resource
can read them with no permission and no call:

```lua
local who = Open77.state.player(playerId)
if who.job and who.job.name == 'police' then
	-- ...
end
```

Keys: `citizenId`, `name`, `charInfo`, `job`, `gang`, `username`, `life`. A
client only receives bags of players in **its own routing bucket**. Money,
metadata and inventory are not in the bag; use the server exports.

## opx_lib {#opx-lib}

`opx_lib` is a client library any resource may use:

```lua
-- my_resource/open77.lua
dependency "opx_lib"
```

```lua
local Lib = require('@opx_lib')
print(Lib.Manifest())   -- the permissions line your manifest needs
```

## Commands {#commands}

A server resource whose manifest declares `runtime.commands` can queue an
**unrestricted** command line with `ExecuteCommand(line)`. Restricted (staff)
commands are refused, and the answer goes to the server log.

## Things to avoid {#avoid}

| Do not | Why |
|---|---|
| Listen to or raise `opx:in:*` events | Server `TriggerEvent` is host-wide, so you can see them, but they are private and change without notice. Use the [public events](../creators/server-events.md). |
| Write to `opx_infinity`'s tables directly | It bypasses its rules, hooks and audit, and its in-memory copy overwrites your change. Read-only access is possible with `database.access`. |
| Trust a client | The client exports act on one player's screen. Charge, give and check on the server. |

## What you still cannot do {#cannot}

| You want to | Status |
|---|---|
| Set a job or gang | No export. Use the staff commands or a module. |
| Read or change metadata | No export. |
| Veto an action (hooks) | `OPX.Hooks` runs inside `opx_infinity` only. |
| Open a panel, prompts or the target eye from your resource | No client export for them. |
| Hear an OPX client event | Client events stay in one resource; answers to your own calls come through the [reply export](../creators/client-exports.md#replies). |

Code written for the old `opx77_*` exports does not work as is; see
[From opx77_* to opx_infinity](../migration/from-opx77.md).
