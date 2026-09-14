---
title: opx77_inventory exports
description: The seventeen server exports another server resource changes and reads a bag through, gated by EXPORTS.READ and EXPORTS.WRITERS, the nine client exports that answer from the bag the server last pushed, and every error code they carry.
---

# Exports

Every export answers `{ ok = true, ... }` or `{ ok = false, error = code }` and
never answers anything else; `error` is a stable code from
[the list below](#errors), meant for branching. The caller is read from the host
with `GetInvokingResource()`, never from an argument.

## Server exports {#server}

Called from another **server** resource, from a `CreateThread`, an event handler
or a command handler — never at file scope, where the host answers
`resource_preparing`:

```lua
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_inventory", "AddItem", playerId, "water", 2)
  if not promise then return print("not dispatched: " .. tostring(reason)) end
  local answer, callError = promise:await()
  if callError then return print("call failed: " .. tostring(callError)) end
  if not answer.ok then return print("refused: " .. tostring(answer.error)) end
end)
```

Test the promise for presence, never for its Lua type: the host's promise is a
userdata. A **read** answers the resources in [`EXPORTS.READ`](config.md#exports),
every one by default; everything that changes something needs the caller in
[`EXPORTS.WRITERS`](config.md#exports), which ships with `opx77_admin` alone.
Anybody else is answered `caller_denied`.

**A target** is a player id, whose loaded character's bag is meant, or a citizen
id, which also reaches an offline character's bag: loaded for the call, written,
and forgotten. A write lands in memory at once and in the database within
[`SAVE.DELAY_MS`](config.md#save). Every write is audited:

```text
[audit] event=inventory.export.add severity=info citizen=H7K-M4X3 data={"caller":"opx77_admin","citizenId":"H7K-M4X3","count":1,"item":"weapon_lexington"}
```

An answer that would weigh more than 32 KiB encoded is refused `too_large`, so
`GetInventory` and `GetItems` answer in pages.

| Export | Kind | Answers |
|---|---|---|
| [`AddItem`](#additem) | write | `added` |
| [`RemoveItem`](#removeitem) | write | `removed` |
| [`RemoveFromSlot`](#removefromslot) | write | `removed` |
| [`SetMetadata`](#setmetadata) | write | nothing more |
| [`ClearInventory`](#clearinventory) | write | nothing more |
| [`GetItemCount`](#server-getitemcount) | read | `count` |
| [`HasItem`](#server-hasitem) | read | `result`, `count` |
| [`CanCarry`](#cancarry) | read | `result`, and `reason` when false |
| [`GetInventory`](#server-getinventory) | read | one page of a bag |
| [`GetSlot`](#getslot) | read | `item`, or nothing |
| [`GetItem`](#server-getitem), [`GetItems`](#getitems) | read | the catalogue |
| [`GetHeldWeapon`](#server-getheldweapon) | read | `weapon`, or nothing |
| [`OpenStash`](#server-openstash) | write | `id` |
| [`CloseInventory`](#closeinventory) | write | nothing more |
| [`RegisterUsable`](#registerusable), [`UnregisterUsable`](#unregisterusable) | write | nothing more; `removed` |

### AddItem {#additem}

```lua
Open77.exports.call("opx77_inventory", "AddItem", target, name, count, metadata)
```

- name: `string` — an item of the catalogue, otherwise `unknown_item`.
- count?: `integer` — `1` to [`MAX_STACK`](config.md#items), default `1`.
- metadata?: `table` — copied onto every unit added, at most
  [`MAX_METADATA_BYTES`](config.md#items) encoded. A weapon is added one unit
  per slot, each with a serial of its own and its `ammo` from the metadata, `0`
  when absent.

**Returns** `{ ok = true, added = count }`. Refused `no_room` or `too_heavy`
without adding anything.

### RemoveItem {#removeitem}

```lua
Open77.exports.call("opx77_inventory", "RemoveItem", target, name, count, metadata)
```

Removes units from the last slot backwards. `nil` metadata matches any stack.
The name need not be in the catalogue any more. **Returns**
`{ ok = true, removed = count }`, or `not_enough` removing nothing.

### RemoveFromSlot {#removefromslot}

```lua
Open77.exports.call("opx77_inventory", "RemoveFromSlot", target, slot, count)
```

Removes units from one precise slot. **Returns** `{ ok = true, removed = count }`.

### SetMetadata {#setmetadata}

```lua
Open77.exports.call("opx77_inventory", "SetMetadata", target, slot, metadata)
```

Replaces the metadata of one stack. `opx77_admin`'s
[`weapon.ammo`](../opx77_admin/commands.md#weapon-ammo) writes a weapon's rounds
with it.

### ClearInventory {#clearinventory}

```lua
Open77.exports.call("opx77_inventory", "ClearInventory", target)
```

Empties a bag.

### GetItemCount {#server-getitemcount}

```lua
Open77.exports.call("opx77_inventory", "GetItemCount", target, name, metadata)
```

**Returns** `{ ok = true, count }`; `nil` metadata counts every stack of the name.

### HasItem {#server-hasitem}

```lua
Open77.exports.call("opx77_inventory", "HasItem", target, name, count)
```

**Returns** `{ ok = true, result = held >= count, count = held }`; `count`
defaults to `1`.

### CanCarry {#cancarry}

```lua
Open77.exports.call("opx77_inventory", "CanCarry", target, name, count, metadata)
```

**Returns** `{ ok = true, result }`, and `reason` — `too_heavy` or `no_room` —
when `result` is false. A name outside the catalogue is `unknown_item`.

### GetInventory {#server-getinventory}

```lua
Open77.exports.call("opx77_inventory", "GetInventory", target, { offset = 0, limit = 64 })
```

- options?: `{ offset?, limit? }` — `offset` stacks in, `0` by default; `limit`
  `1` to `64`, `64` by default.

**Returns** `{ ok = true, citizenId, slots, maxWeight, weight, items, total,
nextOffset }`. `items` is one page of `{ slot, name, count, metadata }` in slot
order, cut short when it grows too heavy; `nextOffset` is present while there are
more.

### GetSlot {#getslot}

```lua
Open77.exports.call("opx77_inventory", "GetSlot", target, slot)
```

**Returns** `{ ok = true, item = { slot, name, count, metadata } }`, or
`{ ok = true }` for an empty slot.

### GetItem {#server-getitem}

```lua
Open77.exports.call("opx77_inventory", "GetItem", name)
```

**Returns** `{ ok = true, item }` — `name`, `label` in the configured locale,
`weight`, `stackable`, `category`, `usable`, `weapon = { record, class, ammo }`
for a weapon, and `ammo = { max }` for an ammunition item.

### GetItems {#getitems}

```lua
Open77.exports.call("opx77_inventory", "GetItems", { offset = 0 })
```

**Returns** `{ ok = true, items, total, nextOffset }`, up to 64 items a page in
the same shape as `GetItem`'s. `opx77_admin` reads the whole catalogue this way
for its pickers and its weapon names.

### GetHeldWeapon {#server-getheldweapon}

```lua
Open77.exports.call("opx77_inventory", "GetHeldWeapon", playerId)
```

**Returns** `{ ok = true, weapon = { name, serial, record, drawn } }` for the
weapon the bag put in that player's hands, or `{ ok = true }`.

### OpenStash {#server-openstash}

```lua
Open77.exports.call("opx77_inventory", "OpenStash", playerId, name, {
  slots = 50, maxWeight = 100000, label = "Locker", position = { x = 0, y = 0, z = 0 }, bucket = 0,
})
```

Opens a stash beside the player's bag, and their screen with it. The calling
resource makes its own checks — a job, a key, a code. With a `position`, reach
is checked too: another bucket or past [`REACH.DISTANCE`](config.md#reach) is
`too_far`. A player whose readiness gate is closed is `not_ready`. **Returns**
`{ ok = true, id }`.

### CloseInventory {#closeinventory}

```lua
Open77.exports.call("opx77_inventory", "CloseInventory", playerId)
```

Closes that player's screen.

### RegisterUsable {#registerusable}

```lua
Open77.exports.call("opx77_inventory", "RegisterUsable", name, exportName)
```

Registers the calling resource's server export `exportName` — `OnInventoryUse`
by default — as the handler of an item's use. The handler has
[`USE_HANDLER_MS`](config.md#use) to answer `{ ok = true, consume? }` or
`{ ok = false, error? }`; a raise, a timeout or a missing export refuses the use.
A handler belongs to the resource that registered it and ends with that
resource's generation; the latest registration of an item wins.

### UnregisterUsable {#unregisterusable}

```lua
Open77.exports.call("opx77_inventory", "UnregisterUsable", name)
```

**Returns** `{ ok = true, removed }` — whether the caller's handler was there.

## Client exports {#client}

For client resources on the same machine. They answer from the bag the server
last pushed to this client, which is the server's copy, not a prediction.

| Export | Does |
|---|---|
| [`Open`](#open), [`Close`](#close), [`IsOpen`](#isopen) | the screen |
| [`GetInventory`](#client-getinventory) | the bag |
| [`GetItemCount`](#client-getitemcount), [`HasItem`](#client-hasitem) | from that bag |
| [`GetItem`](#client-getitem) | one catalogue entry, in the configured locale |
| [`GetHeldWeapon`](#client-getheldweapon) | the weapon drawn from the bag |
| [`OpenStash`](#client-openstash) | asks to open a configured stash |

### Open {#open}

```lua
Open77.exports.call("opx77_inventory", "Open")
```

Opens the screen, or does nothing when it is already open. **Returns**
`{ ok = true }`.

### Close {#close}

```lua
Open77.exports.call("opx77_inventory", "Close")
```

**Returns** `{ ok = true }`.

### IsOpen {#isopen}

```lua
Open77.exports.call("opx77_inventory", "IsOpen")
```

**Returns** `{ ok = true, open }`.

### GetInventory {#client-getinventory}

```lua
Open77.exports.call("opx77_inventory", "GetInventory")
```

**Returns** `{ ok = true, inventory }` — `id`, `slots`, `maxWeight`, `weight`,
`items` — or `not_loaded` before the server has pushed a bag.

### GetItemCount {#client-getitemcount}

```lua
Open77.exports.call("opx77_inventory", "GetItemCount", name)
```

**Returns** `{ ok = true, count }`.

### HasItem {#client-hasitem}

```lua
Open77.exports.call("opx77_inventory", "HasItem", name, count)
```

**Returns** `{ ok = true, result, count }`.

### GetItem {#client-getitem}

```lua
Open77.exports.call("opx77_inventory", "GetItem", name)
```

**Returns** `{ ok = true, item }`, or `unknown_item`.

### GetHeldWeapon {#client-getheldweapon}

```lua
Open77.exports.call("opx77_inventory", "GetHeldWeapon")
```

**Returns** `{ ok = true, weapon = { name, serial, slot } }`, or `{ ok = true }`.

### OpenStash {#client-openstash}

```lua
Open77.exports.call("opx77_inventory", "OpenStash", name)
```

Asks the server to open a stash from [`STASHES`](config.md#stashes); the server
checks the player stands at it. **Returns** `{ ok = true, queued = true }`.

## Error codes {#errors}

The annotations in `types.lua`. Where the catalogue has
`inventory.error.<code>`, that line is what a player is shown.

| Code | Means |
|---|---|
| `export_call_required` | no invoking resource, so the call came from inside |
| `caller_denied` | the caller is not in `EXPORTS.READ`, or not in `EXPORTS.WRITERS` |
| `internal_error` | an export answered something that is not a table, or a client export raised |
| `too_large` | the answer would not fit the host's transfer budget |
| `bad_argument` | an export argument is missing, the wrong type, or out of range |
| `bad_target` | not a player id and not a citizen id |
| `bad_request` | a screen request the server could not read |
| `bad_count` | a count that is not a whole number in range |
| `bad_slot` | a slot outside the container |
| `no_character` | no living character carries that citizen id |
| `not_loaded` | that player has no character in the world |
| `not_ready` | the player's readiness gate is still closed |
| `dead` | the player is dead or not incarnated |
| `core_unavailable` | `opx77_core` did not answer |
| `not_found` | the container, pile or stash is not there |
| `empty_slot` | nothing in that slot |
| `unknown_item` | not in `data/items.lua` or `data/weapons.lua` |
| `no_room` | no free or stackable slot takes it |
| `too_heavy` | past the container's weight |
| `cannot_swap` | a swap moves whole stacks only |
| `not_enough` | fewer units than asked for |
| `not_usable` | the item has no `USE` and no resource handles it |
| `too_fast` | inside `USE_COOLDOWN_MS`, or past `RATE_LIMIT` |
| `use_refused` | a use handler answered `ok = false` without a code |
| `handler_failed` | a use handler could not be called, or raised |
| `handler_timeout` | a use handler took longer than `USE_HANDLER_MS` |
| `too_far` | out of reach, or in another routing bucket |
| `target_unavailable` | the player handed something has no bag loaded |
| `drops_disabled` | `DROPS.ENABLED` is false |
| `drop_limit` | the pile cooldown, `DROPS.MAX` or `DROPS.MAX_PER_CHARACTER` |
| `in_vehicle` | nothing is dropped from a seat |
| `no_position` | the server has no position for the player |
| `no_vehicle` | the vehicle no longer exists |
| `no_storage` | that vehicle has no trunk or glovebox of that size |
| `not_seated` | a glovebox is opened from a seat |
| `seated` | a trunk is opened from outside |
| `weapons_unavailable` | `WEAPONS.ENABLED` is false, or `Open77.weapons` is missing |
| `weapon_refused` | the relay refused or the engine did not draw it |
| `no_weapon_for_ammo` | no drawn weapon takes that ammunition |
| `weapon_full` | the drawn weapon already holds its `AMMO.MAX` |

## See also {#see-also}

- [Configuration](config.md#exports) — `EXPORTS.READ` and `EXPORTS.WRITERS`.
- [The client export contract](../../concepts/export-contract.md) — the three
  levels a call fails at.
