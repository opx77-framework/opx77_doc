---
title: Storage and the database
description: How opx_infinity reads and writes the database through OPX.Storage, how modules add their tables with OPX.Schema, and what OPX.Carry keeps across a resource reload.
---

# Storage

`opx_infinity` stores characters, inventories, vehicles and the rest in the
server's MySQL database, through the platform's MySQL bridge (`MySQL`, an alias
of `Open77.database`, which needs the `database.access` permission). All access
goes through [`OPX.Storage`](../reference/lib.md#opx-storage-query) in
`lib/server/storage.lua`. It is server only.

## Reading and writing {#calls}

Every call **yields**, so call it from a thread (a module's `Start`, a
`CreateThread`, a command or event handler running on a thread). Every call
answers a [`Result`](../reference/lib.md#opx-result-ok) instead of raising:

```lua
local found = OPX.Storage.Single(
	'SELECT name FROM my_table WHERE citizen_id = @citizen',
	{ citizen = citizenId })
if not found.ok then
	return Open77.log.error('my_table read failed: ' .. tostring(found.detail))
end
local row = found.value   -- nil means "no row", not a failure
```

| Code | Meaning |
|---|---|
| `no-database` | The bridge is not installed. |
| `query-failed` | The statement raised; `detail` holds the raw error (for logs only). |

Use **named parameters** (`@citizen`), not `?`, and never put an SQL comment
inside a statement.

## Adding a table {#schema}

A module adds its `CREATE TABLE IF NOT EXISTS` statements in `Init`:

```lua
function M.Init()
	OPX.Schema.Add({
		[[CREATE TABLE IF NOT EXISTS opx_thing (
			citizen_id VARCHAR(16) NOT NULL PRIMARY KEY,
			value INT NOT NULL DEFAULT 0
		)]],
	})
end
```

The server applies every statement once, after `Api` and before `Start`, and
stops at the first failure. If the schema fails, the server boots in degraded
mode with `OPX.BootError` set (`schema failed: ...`) and nobody can load a
character.

There are **no migrations**. A table that changes shape needs a hand-written
`ALTER` by the operator. Never `DROP DATABASE`: the server's grants live with
it.

## Tables from the old resources {#legacy}

Several modules still **read** tables written by the old `opx77_*` resources at
boot and adopt their rows (for example `opx77_garages` and
`opx77_dealership_previews`), printing each adopted row as the config line that
replaces it. Each module page names the tables it reads.

## Keeping state across a reload: OPX.Carry {#carry}

[`OPX.Carry.Save(namespace, value)`](../reference/lib.md#opx-carry-save) and
[`OPX.Carry.Load(namespace)`](../reference/lib.md#opx-carry-load) keep a small
value across a resource reload, using the platform's resource-private
`Open77.state.save`/`load`. The weather module uses it to keep the sky and clock
when the resource is reloaded.

## Player state bags {#state-bags}

The [character module](../modules/character.md#state-bag) publishes a few
public facts about each player (name, job, gang…) on the player's replicated
state bag. Any client in the same routing bucket can read them with
`Open77.state.player(id)`. Nothing private (money, metadata) goes there.
