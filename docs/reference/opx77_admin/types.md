---
title: opx77_admin types
description: The shapes opx77_admin answers and sends — every refusal code a command can answer, the export answers, the session and roster rows on the wire, the audit entry, a destination, a vehicle row, a weapon class, and an inventory item, catalogue and bag as read from opx77_inventory.
---

# Types

The annotations in `std/types.lua`, as the code uses them. It is a `---@meta`
file that no manifest entry loads: nothing here exists at runtime. The stubs of
the namespace functions live beside it, one file per code file, under
`std/client/`, `std/server/` and `std/shared/`.

The classes of the command registry — `AdminCommandSpec`, `AdminParameter`,
`AdminCommand` — and `CatalogClass` describe this resource's own internals and
are not listed here.

## AdminError {#adminerror}

A refusal code a command answers. Meant for branching and for the audit, never
for a player to read: a player reads the `admin.error.*` catalogue key the code
maps to in `server/main.lua`, and the console reads its English line.

```lua
---@alias AdminError
---| "in_game_only"          the command acts on the caller's own body, and the console has none
```

The file declares one `---|` line per code:

| Code | Means |
|---|---|
| `in_game_only` | the command acts on the caller's own body, and the console has none |
| `too_fast` | inside [`RATE.ACTION_MS`](config.md#rate) or [`RATE.READ_MS`](config.md#rate) of the last run |
| `failed` | the handler raised; the log has the line |
| `no_target` | no player named |
| `bad_target` | not a player id and not `me` |
| `console_has_no_player` | `me`, `near` or `mine` typed at the console |
| `not_connected` | nobody holds that player id |
| `self_target` | `goto`, `bring` or `observe` aimed at the caller |
| `bad_holder` | not a player id, `me`, or a citizen id; also `opx77_inventory`'s `bad_target` |
| `not_incarnated` | no life state: loading, or the continue screen |
| `gate_closed` | the readiness gate is still held for that player |
| `gate_unreadable` | `Open77.ready` is missing or raised; fails closed |
| `no_position` | no replicated position for that player yet |
| `kill_refused` | the first half of a placement was refused |
| `respawn_refused` | the second half was refused; the player was revived in place |
| `refused` | a native answered `false`; the answer carries the host's own reason |
| `bad_coordinates` | a point that is not three finite numbers inside a million, or a heading that is not a number |
| `bad_switch` | not on, off, or nothing |
| `bad_duration` | looks like a ban duration and is out of range |
| `empty_text` | an announcement with nothing in it |
| `unknown_vehicle` | not a `NAME` or `RECORD` in `data/vehicles.lua` |
| `vehicle_cap` | [`VEHICLES.PER_OWNER`](config.md#vehicles) reached for that player |
| `no_vehicle` | no such vehicle id, or nothing within `NEAR_RADIUS` |
| `occupied` | somebody is aboard; remove refuses |
| `unsafe_repair` | `full` or `mechanical` with somebody aboard |
| `bad_scope` | not a repair scope |
| `unknown_flag` | not in `VEHICLES.FLAGS`, or the host has no mask of that name |
| `not_ours` | the host refused a removal: another resource created it |
| `vehicles_unavailable` | `Open77.vehicles` is missing on this host |
| `unknown_weapon` | not a weapon item of `opx77_inventory`, `weapon_` prefix or not |
| `weapons_unavailable` | `Open77.weapons`, the relay the holster needs, is missing on this host |
| `weapon_no_answer` | the target's client never answered the relay: `request_timeout` |
| `unknown_ammo` | neither an ammo item nor a weapon item of `opx77_inventory` |
| `melee_no_ammo` | ammunition asked for a weapon that takes none |
| `give_partial` | a weapon's ammunition was refused and the weapon could not be taken back out of the bag |
| `inventory_unavailable` | `opx77_inventory` is not running, or its export was not found, stopped or timed out |
| `inventory_denied` | `opx77_inventory` answered `caller_denied`: this resource is not in its `EXPORTS.WRITERS` |
| `no_character` | that player has no character in the world: the inventory's `not_loaded` |
| `unknown_citizen` | no living character carries that citizen id: the inventory's `no_character` |
| `core_unavailable` | `opx77_core` did not answer `opx77_inventory` |
| `unknown_item` | not an item of `opx77_inventory`'s catalogue |
| `bad_count` | a count outside `1`..[`INVENTORY.MAX_COUNT`](config.md#inventory); `weapon.give`'s ammunition may be `0` |
| `not_enough` | the bag holds fewer units than asked to remove |
| `bag_no_room` | `CanCarry` or `AddItem`: no free or stackable slot |
| `bag_too_heavy` | `CanCarry` or `AddItem`: past the bag's weight |
| `unknown_location` | no destination of that name |
| `bad_location_name` | not 1 to 32 letters, digits, `_` or `-` |
| `seeded_location` | configured in `config.lua`, so not removable in game |

Two reasons travel inside `refused` rather than as codes of their own:
`access_unavailable`, when the host has no `Open77.access.ban`, and
`no_identity`, when a ban target's account id cannot be read. So does any
refusal code `opx77_inventory` answers that has no row above — `bad_argument`,
`too_large` — and a malformed answer from it, `malformed_answer`.

`bad_number` is gone: every typed count, the ammunition of a weapon give
included, answers `bad_count`.

## AdminResponse {#adminresponse}

What every [export](exports.md) answers. It never raises.

```lua
--- Every export answers a table carrying `ok` and never raises.
---@class AdminResponse
---@field ok boolean
---@field error "export_call_required"|"menu_not_running"|"not_sent"|nil
---@field queued boolean|nil  `open`: the opener command was sent; the host decides the rest
---@field open boolean|nil
```

## AdminState {#adminstate}

What [`state`](exports.md#state) answers.

```lua
---@class AdminState : AdminResponse
---@field screen string|nil  "root", "players", "player", ... while the menu is up
```

## AdminSession {#adminsession}

The payload of [`opx77_admin:open`](events.md#open), server to client.

```lua
--- `opx77_admin:open`, server to client.
---@class AdminSession
---@field access table<string, true>  command names the ACL grants; absent means refused
---@field aclKnown boolean            false when the host has no ACL reader: nothing is greyed
---@field weapons boolean             Open77.weapons, the holster's relay, exists on this host
---@field inventory boolean           opx77_inventory is running: its rows are drawn
```

The access map is a hint for drawing. The host still resolves every command
line the menu sends. The session carries no operator id: every command the menu
sends targets `me` or an id from the roster.

## AdminRosterRow {#adminrosterrow}

One player as the menu's roster draws them, in
[`opx77_admin:roster`](events.md#roster).

```lua
--- One player as the menu's roster draws them. No character: that lives in opx77_core's VM.
---@class AdminRosterRow
---@field id integer
---@field name string            the Master-verified display name
---@field state "up"|"down"|"gate"|"loading"
---@field bucket integer
---@field distance integer|nil   metres from the operator, same bucket only
```

| `state` | Drawn as | Means |
|---|---|---|
| `up` | in world | a life state, the gate open, alive |
| `down` | down | a life state, the gate open, dead |
| `gate` | joining | a life state, the gate still held |
| `loading` | loading | no life state yet |

There is no character in a row: the citizen id and the character's name live in
`opx77_core`'s VM, which nothing here can ask.

## AuditEntry {#auditentry}

One entry of the in-memory audit ring that
[`read.audit`](commands.md#audit) reads. The log line written beside it is the
record — see [The audit](index.md#audit).

```lua
--- One entry of the in-memory audit ring. The log line written beside it is the record.
---@class AuditEntry
---@field seq integer
---@field atMs integer
---@field event string          "admin.player.kill"
---@field ok boolean
---@field actor integer         0 for the console
---@field actorName string
---@field target integer|nil
---@field targetName string|nil
---@field detail string
```

`event` is the command name without its `opx77.` prefix — `admin.player.kill`,
`admin.moderate.ban`, `admin.world.loc.add` — and is stable and greppable.

## AdminLocation {#adminlocation}

A destination, from [`LOCATIONS`](config.md#locations) or saved in game.

```lua
---@class AdminLocation
---@field name string
---@field label string
---@field x number
---@field y number
---@field z number
---@field heading number
---@field runtime boolean  added in game; gone at the next restart
```

## CatalogEntry {#catalogentry}

One row of `data/vehicles.lua`, after the index checked it — see
[Catalogues](config.md#catalogues). Weapons are not rows of this resource.

```lua
--- One row of data/vehicles.lua, after the index checked it.
---@class CatalogEntry
---@field name string    what staff type, lower-cased
---@field label string
---@field record string  the exact TweakDB record
---@field class string   a class key
```

## WeaponClass {#weaponclass}

One class of `data/weapons.lua`. The weapons themselves are
`opx77_inventory`'s items — see [Weapons and items](config.md#weapons-catalogue).

```lua
--- One class of data/weapons.lua. The weapons are opx77_inventory's items, not rows here.
---@class WeaponClass
---@field key string        CLASS in opx77_inventory's data/weapons.lua
---@field label string
```

A class carries no rounds: a weapon is given empty.

## InventoryItem {#inventoryitem}

One item of `opx77_inventory`'s catalogue, as `server/inventory.lua` keeps it
from `GetItems`.

```lua
--- One item of opx77_inventory's catalogue, as server/inventory.lua keeps it from GetItems.
---@class InventoryItem
---@field name string
---@field label string       in opx77_inventory's LOCALE
---@field category string    `ammo` for an ammunition item
---@field weight integer     grams per unit
---@field weapon { class: string, ammo: string|nil }|nil  ammo is the item that loads it
---@field ammoMax integer|nil an ammo item: the most rounds one weapon holds, and a full load
```

`ammoMax` is the inventory's `AMMO.MAX` for that ammunition. It is the count
[`weapon.giveammo`](commands.md#weapon-giveammo) and
[`weapon.ammo`](commands.md#weapon-ammo) give when none is typed, and it travels
to the menu as `max` in [`opx77_admin:items`](events.md#items).

## InventoryCatalog {#inventorycatalog}

`opx77_inventory`'s catalogue as `server/inventory.lua` caches it — see
[Weapons and items](config.md#weapons-catalogue).

```lua
--- opx77_inventory's catalogue as server/inventory.lua caches it from GetItems.
---@class InventoryCatalog
---@field items InventoryItem[]            sorted by label
---@field byName table<string, InventoryItem>
---@field atMs integer                      when it was read, for the cache lifetime
```

## InventoryBag {#inventorybag}

A bag as `server/inventory.lua` reads it, every `GetInventory` page joined.

```lua
--- A bag as server/inventory.lua reads it, every GetInventory page joined.
---@class InventoryBag
---@field citizenId string
---@field slots integer
---@field maxWeight integer   grams
---@field weight integer      grams
---@field items { slot: integer, name: string, count: integer, metadata: table|nil }[]
```
