---
title: inventory module
description: The bag, fixed stashes, vehicle trunks and gloveboxes, piles on the ground, weapons drawn from the bag and eddies carried as an item.
---

# inventory

The inventory module holds every item a character carries. A player presses `I` to open a grid of slots with a weight bar. Beside the bag the screen can show a second container: a stash, a vehicle's trunk or glovebox, a pile on the ground, or (for staff) another player's bag. Items are dragged between the two, used, split, sorted, handed to a nearby player or dropped. Weapons in the bag are drawn by using them, and ammunition is loaded into the drawn weapon the same way. The server decides every move. The screen only sends what the player asked for. Use this module whenever your code needs to give, take, count or check items.

| | |
|---|---|
| Side | both |
| Requires | `character` (hard) |
| Optional | `vehicles` (owned trunks are stored by plate), `target` (pile, trunk, glovebox and stash rows), `downed` (no screen while down), `panel` (declared, not used yet). The client also reads `needs`, `progress` and `animations` when an item is used. |
| Configuration | `config/inventory.lua` (shared script) |
| Contract | `inventory` v1 — server, client |
| Data | `opx77_inventories`, `opx77_inventory_items` |

## Containers {#containers}

A container is a `(kind, owner)` pair. A container with a positive id is a database row. A container with a negative id lives only in memory and is never written.

| Kind | Owner | Size | Stored | Opened by |
|---|---|---|---|---|
| `character` (the bag) | citizen id | [`BAG`](#config-inventory-bag), fixed when the row is created | yes | the open key, or `/opx.inventory.open` (staff search) |
| `stash` | the stash name | from [`STASHES`](#config-inventory-stashes) or the caller of [`OpenStash`](#server-inventory-openstash) | yes | a target row at a configured stash, or `OpenStash` |
| `trunk` | plate of an owned vehicle, or `vehicle:<id>` | [`TRUNK`](#config-inventory-trunk); a bike gets it divided by [`BIKES.TRUNK_DIVISOR`](#config-inventory-bikes) | only for an owned vehicle | a target row on the vehicle, standing outside it |
| `glovebox` | plate, or `vehicle:<id>` | [`GLOVEBOX`](#config-inventory-glovebox); bikes have none | only for an owned vehicle | the open key or a target row, seated in the vehicle |
| `drop` (a pile) | — | [`DROPS.SLOTS`](#config-inventory-drops) | never | the open key or a target row near the pile |

- A vehicle nobody owns (no plate known to `vehicles`) gets memory-only storage that lives as long as the vehicle.
- [`TRUNK_OWNER_ONLY`](#config-inventory-trunk-owner-only) (default `true`) refuses an owned trunk to anyone but its owner, with `not_yours`.
- A locked vehicle refuses its trunk to everyone, with `locked`. An open trunk closes when the vehicle is locked. The lock is the host's own lock state (`Open77.vehicles.isLocked`); the [vehiclekeys](vehiclekeys.md) module moves it. The glovebox ignores both rules: it opens only from a seat.
- Reach is measured on the server: [`REACH.DISTANCE`](#config-inventory-reach) to a stash, pile or player, `REACH.VEHICLE` from a vehicle's centre to its trunk. A second container out of reach is closed by a sweep every second.
- A pile is swept after `DROPS.LIFETIME_MINUTES` untouched, and nothing in it survives a restart.
- Changes are written [`SAVE.DELAY_MS`](#config-inventory-save) after the last change, in batches.
- Deleting a character deletes all its containers and their items.

### Weight and slots

Weight is in whole grams. A container refuses a change that would pass its `maxWeight` (`too_heavy`) or that finds no slot (`no_room`). A stackable item holds up to [`MAX_STACK`](#config-inventory-max-stack) units per slot; a non-stackable item and every weapon hold one per slot. Two stacks merge only when their metadata is equal. A stored item the catalogue no longer has weighs [`DEFAULT_ITEM_WEIGHT`](#config-inventory-default-item-weight) per unit.

## Item catalogue {#catalogue}

Items are declared in `modules/inventory/data/items.lua` (`M.Data.ITEMS`) and weapons in `modules/inventory/data/weapons.lua` (`M.Data.WEAPONS`). The key is the item name: letters, digits, `_`, `-` and `.`, up to 48 bytes. A malformed row is a boot warning and is left out. There is no way to add items at runtime.

### Item fields

| Field | Default | What it does |
|---|---|---|
| `WEIGHT` | `DEFAULT_ITEM_WEIGHT` | Grams per unit. |
| `CATEGORY` | `misc` | Which [tab](#config-inventory-tabs) shows it. |
| `STACK` | `true` | `false`: one unit per slot. |
| `DROP` | `true` | `false`: cannot be dropped on the ground or moved into any memory-only container (`no_drop`). |
| `LABEL` | locale `inventory.item.<name>`, else the name | A locale key or plain text. |
| `DESCRIPTION` | locale `inventory.item.<name>.description` | A locale key or plain text. |
| `IMAGE` | none | Image name for the screen. |
| `MODEL` | `DROPS.MODEL` | A curated `Open77.props` alias drawn for a pile. A `.mesh` path is refused at load. |
| `USE` | none | Makes the item usable. See below. |

`USE` sub-fields:

| Field | Default | What it does |
|---|---|---|
| `CONSUME` | `1` | Units removed per use. A [use handler](#server-inventory-registerusable) can override it. |
| `CLOSE` | `true` | `false` keeps the screen open after a use. |
| `STATUS` | none | `{ needName = amount }`, passed to the `needs` contract on the client. |
| `ANIMATION` | none | `{ NAME, VARIANT?, DURATION_MS? }`. With `DURATION_MS` a non-cancellable `progress` bar plays it; without, `animations` plays it once. |

An item with neither `USE` nor a registered use handler cannot be used (`not_usable`).

### Weapons as items

`M.Data.WEAPONS` has three tables:

| Table | Fields | Meaning |
|---|---|---|
| `AMMO` | `WEIGHT`, `MAX`, `MODEL` | Ammunition items. Category `ammo`, always stackable and usable. `MAX` is stored but no code reads it. |
| `CLASSES` | `AMMO`, `MODEL`, `MAGAZINE` | Shared settings per class (`handgun`, `rifle`, `melee`, …). |
| `WEAPONS` | `RECORD`, `CLASS`, `WEIGHT`, `MAGAZINE?`, `MODEL?` + item fields | One weapon item each. `RECORD` is an `Items.*` TweakDB record. A weapon whose class is unknown is left out. |

- A weapon is never stackable. Each unit gets metadata `{ serial, ammo }`: a serial of two letters and eight hex digits, and `ammo = 0`. A `serial` passed in metadata is kept only when one weapon is added.
- Using a weapon draws it into game weapon slot [`WEAPONS.SLOT`](#config-inventory-weapons). Using it again puts it away. Moving it out of the bag puts it away.
- Using an ammunition item loads it into the drawn weapon of the matching class, up to the weapon's `MAGAZINE` (or its class's). The rounds are kept on the weapon's `ammo` metadata and are read back from the game every `WEAPONS.AMMO_SYNC_MS`; they only ever go down that way.
- With `WEAPONS.REMOVE_UNBACKED = true`, any equipped weapon that no bag item backs is taken off the player every `WEAPONS.SCAN_MS`.
- Drawing a weapon needs the host's `Open77.weapons` relay. Without it the use answers `weapons_unavailable`.

### Shipped items

The catalogue ships drinks, food, medical items, materials (`scrap_metal`, `electronics`), `lockpick`, `hauling_crate` (10 kg, used by the `hauling` module), `phone`, `id_card`, `shard`, `vehicle_key`, `eddies`, four ammunition types and 189 weapons.

`vehicle_key` is non-stackable and carries metadata `{ plate, label }`, written by the [vehiclekeys](vehiclekeys.md) module. The screen and the hotbar show a stack's own `metadata.label` when it has one. Use [`CountWhere`](#server-inventory-countwhere) to find a key by plate.

## Eddies as an item {#currency}

When [`CURRENCY`](#config-inventory-currency) is on, cash can be carried as the `eddies` item. The balance stays the real money; the item is a note drawn against it.

- `/withdraw <amount>` (or [`Withdraw`](#server-inventory-withdraw)) takes the amount from the `EDDIES` balance, then puts that many `eddies` in the bag. If the item cannot be added, the money is refunded.
- Using an `eddies` stack (or [`Deposit`](#server-inventory-deposit)) removes the units, then credits the balance. If the credit fails, the units are put back.
- Shops, garages and the dealership read the balance only. Notes in a bag cannot be spent until they are deposited.
- `eddies` weighs `0` and has `DROP = false`, so it cannot be left on the ground or put in a memory-only trunk.

The bridge does not wire itself (boot warning) when `CURRENCY.ITEM` is not in the catalogue, `MONEY_TYPE` is not a declared money type, or there is no `character` contract.

## Commands {#commands}

| Command | Access | Arguments | What it does |
|---|---|---|---|
| <a id="opx-inventory-give"></a>`/opx.inventory.give` | ACL `command.opx.inventory.give` | `<playerId\|citizenId> <item> [count]` | Adds items to a bag (online or offline). Count 1 to [`MAX_COMMAND_COUNT`](#config-inventory-max-command-count). |
| <a id="opx-inventory-remove"></a>`/opx.inventory.remove` | ACL `command.opx.inventory.remove` | `<playerId\|citizenId> <item> [count]` | Removes items from a bag. |
| <a id="opx-inventory-clear"></a>`/opx.inventory.clear` | ACL `command.opx.inventory.clear` | `<playerId\|citizenId>` | Empties a bag. |
| <a id="opx-inventory-open"></a>`/opx.inventory.open` | ACL `command.opx.inventory.open` | `<playerId\|citizenId>` | Opens that bag beside yours (staff search). In game only. Reach does not close it. |
| <a id="opx-inventory-holders"></a>`/opx.inventory.holders` | ACL `command.opx.inventory.holders` | `<item>` | Lists up to 20 containers holding the item, largest stacks first. Reads the database, so changes not yet written are missing. |
| <a id="opx-withdraw"></a>`/opx.withdraw` (alias `/withdraw`) | everyone | `<amount>` | Turns balance into `eddies` items. 1 to `CURRENCY.MAX_WITHDRAW`. In game only. |

The staff commands are audited (`inventory.give`, `inventory.remove`, `inventory.clear`, `inventory.search`, `inventory.holders`).

## Server contract {#server-contract}

`local inventory = OPX.Api.Get('inventory')` on the server, from code inside opx_infinity.

A **target** is a player id (their loaded character's bag) or a citizen id (also reaches an offline bag: it is loaded for the call, then written and released). Every function that takes a target, a vehicle or a container **yields**: call it from a thread. A Result is `{ ok = true, value }` or `{ ok = false, error, detail }`.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="server-inventory-additem"></a>`AddItem` | `target, name, count?, metadata?` | Result `true` | Yields. `count` defaults to 1. Metadata is copied onto each unit, max [`MAX_METADATA_BYTES`](#config-inventory-max-metadata-bytes) encoded. Adds nothing on `no_room` / `too_heavy`. Audited. |
| <a id="server-inventory-removeitem"></a>`RemoveItem` | `target, name, count?, metadata?` | Result `true` | Yields. Takes from the last slot backwards. `nil` metadata matches any stack. `not_enough` removes nothing. |
| <a id="server-inventory-removefromslot"></a>`RemoveFromSlot` | `target, slot, count?` | Result `true` | Yields. One slot only. `count` defaults to the whole stack. |
| <a id="server-inventory-setmetadata"></a>`SetMetadata` | `target, slot, metadata?` | Result `true` | Yields. Replaces the stack's metadata (`nil` clears it). |
| <a id="server-inventory-clearinventory"></a>`ClearInventory` | `target` | Result `true` | Yields. Empties the bag. |
| <a id="server-inventory-getitemcount"></a>`GetItemCount` | `target, name, metadata?` | Result integer | Yields. With metadata, counts only stacks whose metadata is equal as a whole. |
| <a id="server-inventory-countwhere"></a>`CountWhere` | `target, name, match` | Result integer | Yields. Counts stacks whose metadata has every field of `match` (scalar values only; a table value matches nothing). `match` must be a non-empty table. |
| <a id="server-inventory-hasitem"></a>`HasItem` | `target, name, count?` | Result boolean | Yields. Ignores metadata. |
| <a id="server-inventory-cancarry"></a>`CanCarry` | `target, name, count?, metadata?` | Result boolean | Yields. Checks slots and weight. Gives no reason when false. |
| <a id="server-inventory-getinventory"></a>`GetInventory` | `target` | Result `{ id, kind, title, slots, maxWeight, weight, items }` | Yields. `items` is a list of `{ slot, name, count, metadata }`. For a very large container, metadata other than `serial`, `ammo`, `durability`, `label`, `description` may be trimmed. |
| <a id="server-inventory-getslot"></a>`GetSlot` | `target, slot` | Result `{ slot, name, count, metadata }` or Result `nil` | Yields. A copy. |
| <a id="server-inventory-addtostash"></a>`AddToStash` | `name, item, count?, metadata?, options?` | `Result` `true` | **Yields.** Adds to a stash by its storage key, loading it without opening it. A missing stash is created at the configured size (or 50 slots / 100 000 g). `options = { creator, cap }` (what the export passes) limits creation: configured stashes, or names `<creator>.<name>` while the creator holds fewer than `cap` (default 25, counted in the database); else `stash_namespace` / `stash_cap`. Audited `inventory.stashAdd`. |
| <a id="server-inventory-removefromstash"></a>`RemoveFromStash` | `name, item, count?, metadata?` | `Result` `true` | **Yields.** Never creates a stash: a missing one answers `not_enough`. `nil` metadata matches any stack. Audited `inventory.stashRemove`. |
| <a id="server-inventory-countinstash"></a>`CountInStash` | `name, item, metadata?` | `Result` integer | **Yields.** `0` for a stash that does not exist (none is created). |
| <a id="server-inventory-removewhere"></a>`RemoveWhere` | `target, name, match` | `Result` integer (units taken) | **Yields** for an offline bag. Takes **every** unit of `name` whose metadata carries all fields of `match` (plain values only), whatever its other fields. Used to revoke keys. Audited `inventory.removeWhere`. |
| <a id="server-inventory-addtotrunk"></a>`AddToTrunk` | `vehicleId, name, count?, metadata?, source?` | Result `true` | Yields. `vehicleId` is the host id (number or decimal string). Refused `locked` when the vehicle is locked. With `source`, an owned trunk answers to its owner only while `TRUNK_OWNER_ONLY` is on (`not_yours`). No reach check. |
| <a id="server-inventory-removefromtrunk"></a>`RemoveFromTrunk` | `vehicleId, name, count?, metadata?, source?` | Result `true` | Yields. Same rules as `AddToTrunk`. |
| <a id="server-inventory-countintrunk"></a>`CountInTrunk` | `vehicleId, name, metadata?, source?` | Result integer | Yields. Same rules as `AddToTrunk`. |
| <a id="server-inventory-trunklocked"></a>`TrunkLocked` | `vehicleId` | boolean | Does not yield. `false` when the host cannot answer. |
| <a id="server-inventory-getitem"></a>`GetItem` | `name` | table or `nil` | Does not yield. `{ label, description, weight, image, usable, stackable, droppable, category, weapon, ammo }`; `weapon` and `ammo` are booleans. |
| <a id="server-inventory-getitems"></a>`GetItems` | — | `{ [name] = item }` | Does not yield. The whole catalogue, same shape as `GetItem`. |
| <a id="server-inventory-holders"></a>`Holders` | `name, limit?` | Result list of `{ id, kind, owner, slot, count }` | Yields. Database read, largest stacks first. `limit` 1–200, default 20. |
| <a id="server-inventory-resizecontainer"></a>`ResizeContainer` | `kind, owner, slots, maxWeight` | Result container id | Yields. The only way to change a stored container's size. `slots` 1–200. Stacks past the new slot count are kept but not drawn. |
| <a id="server-inventory-deletecontainer"></a>`DeleteContainer` | `kind, owner` | Result `true` | Yields. Deletes the row and **everything in it**. Refuses memory-only containers. |
| <a id="server-inventory-openstash"></a>`OpenStash` | `playerId, name, options?` | Result container id | Yields. Opens a stash beside the player's bag and raises their screen. `options`: `slots` (default 50), `maxWeight` (default 100000), `label`, `position {x,y,z}`, `bucket`. The caller decides who may open it; this only checks reach, and only when `position` is given. |
| <a id="server-inventory-closeinventory"></a>`CloseInventory` | `playerId` | Result `true` | Closes the player's screen and the second container. |
| <a id="server-inventory-registerusable"></a>`RegisterUsable` | `name, handler, owner?` | `ok, code` | Sets the function called when the item is used. The last registration wins. `handler(source, info)` gets `info = { name, slot, count, metadata, label, citizenId }` and must return `{ ok = true, consume? }` or `{ ok = false, error? }` within [`USE_HANDLER_MS`](#config-inventory-use-handler-ms). It runs on its own thread and may yield. `consume` overrides `USE.CONSUME`. Not called for weapons or ammunition. |
| <a id="server-inventory-unregisterusable"></a>`UnregisterUsable` | `name, owner?` | boolean | Removes the handler only if `owner` matches the one that registered it. |
| <a id="server-inventory-withdraw"></a>`Withdraw` | `source, amount` | `ok, code` | Yields. Balance → `eddies` items. See [Eddies as an item](#currency). |
| <a id="server-inventory-deposit"></a>`Deposit` | `source, slot, count?` | `ok, code` | Yields. `eddies` in that bag slot → balance. `count` defaults to the whole stack. |
| <a id="server-inventory-currencywired"></a>`CurrencyWired` | — | `wired, item, moneyType` | Whether the money bridge is on. |
| <a id="server-inventory-getheldweapon"></a>`GetHeldWeapon` | `playerId` | `{ name, serial, slot }` or `nil` | The weapon this module put in the player's hands. |

```lua
CreateThread(function()
    local inventory = OPX.Api.Get('inventory')
    local result = inventory.AddItem(source, 'water', 2)
    if not result.ok then print('refused: ' .. result.error) end
end)
```

## Client contract {#client-contract}

`local inventory = OPX.Api.Get('inventory')` on the client, from code inside opx_infinity. Reads answer from the last bag the server pushed, never from what the screen predicts. None of them yields.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="client-inventory-open"></a>`Open` | — | nothing | Opens the bag screen. Does nothing while down, dead or already opening. |
| <a id="client-inventory-close"></a>`Close` | — | nothing | Closes the screen. |
| <a id="client-inventory-isopen"></a>`IsOpen` | — | boolean | |
| <a id="client-inventory-getinventory"></a>`GetInventory` | — | bag table or `nil` | Same shape as the server's `GetInventory` value. `nil` before the first push. |
| <a id="client-inventory-getitemcount"></a>`GetItemCount` | `name` | integer | `0` before the first push. No metadata filter. |
| <a id="client-inventory-hasitem"></a>`HasItem` | `name, count?` | boolean | |
| <a id="client-inventory-getitem"></a>`GetItem` | `name` | table or `nil` | Same shape as the server's `GetItem`. |
| <a id="client-inventory-getheldweapon"></a>`GetHeldWeapon` | — | `{ name, serial, slot }` or `nil` | |
| <a id="client-inventory-openstash"></a>`OpenStash` | `name` | nothing | Asks to open a stash from [`STASHES`](#config-inventory-stashes). The server checks reach. A stash not in `STASHES` is refused. |

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-on-inventory-changed"></a>`opx:on:inventory:changed` | client local | `{ inventory, changes = { { name, delta } } }` | The server pushed this player's bag. Raised after the mirror is updated. |
| <a id="opx-on-inventory-used"></a>`opx:on:inventory:used` | client local | `{ name, slot, label, close, status?, animation? }` | A use went through. |
| <a id="opx-on-inventory-armed"></a>`opx:on:inventory:armed` | client local | `{ name, serial, slot }` or `nil` | A bag weapon was drawn or put away. |
| <a id="opx-on-inventory-opened"></a>`opx:on:inventory:opened` | client local | — | The screen opened. |
| <a id="opx-on-inventory-closed"></a>`opx:on:inventory:closed` | client local | — | The screen closed. |
| <a id="opx-on-character-loaded"></a>`opx:on:character:loaded` | listened (client) | — | Sends `hello` to reload the bag. Raised by `character`. |
| <a id="opx-on-character-unloaded"></a>`opx:on:character:unloaded` | listened (client) | — | Closes the screen and clears the mirror. Raised by `character`. |
| <a id="opx-net-inventory-request"></a>`opx:net:inventory:request` | client → server | `requestId, action, payload` | One screen request: `open`, `close`, `closeSecondary`, `move`, `split`, `sort`, `use`, `drop`, `give`, `takeDrop`, `openStash`, `openTrunk`, `openGlovebox`, `nearby`. Rate limited. |
| <a id="opx-net-inventory-hello"></a>`opx:net:inventory:hello` | client → server | — | Client is ready: send piles, bag and held weapon. At most once per 2 s. |
| <a id="opx-net-inventory-answer"></a>`opx:net:inventory:answer` | server → client | `requestId, ok, code, data` | Answer to one request. |
| <a id="opx-net-inventory-own"></a>`opx:net:inventory:own` | server → client | bag | The player's bag changed. |
| <a id="opx-net-inventory-container"></a>`opx:net:inventory:container` | server → client | container | A container the player is viewing changed. |
| <a id="opx-net-inventory-secondary"></a>`opx:net:inventory:secondary` | server → client | container or `false` | A second container was opened, or closed. |
| <a id="opx-net-inventory-nearby"></a>`opx:net:inventory:nearby` | server → client | `{ { id, distance } }` | Players in reach, for "give to". |
| <a id="opx-net-inventory-open"></a>`opx:net:inventory:open` | server → client | — | Raise the screen (after `OpenStash` or a staff search). |
| <a id="opx-net-inventory-reset"></a>`opx:net:inventory:reset` | server → client | — | Close the screen and clear the mirror. |
| <a id="opx-net-inventory-used"></a>`opx:net:inventory:used` | server → client | `{ name, slot, label, close, status?, animation? }` | A use went through: play it. |
| <a id="opx-net-inventory-armed"></a>`opx:net:inventory:armed` | server → client | `{ name, serial, slot }` or `false` | Held weapon changed. |
| <a id="opx-net-inventory-drops"></a>`opx:net:inventory:drops` | server → client | `{ first, done, drops = { { id, x, y, z, bucket } } }` | Every pile, in parts. |
| <a id="opx-net-inventory-drop"></a>`opx:net:inventory:drop` | server → all clients | `'add', pile` or `'remove', id` | A pile appeared or went. |

The server also listens to `opx:in:character:loaded`, `:unloaded` and `:deleted` (private).

On the **server**, the module raises `opx:on:inventory:changed` `(playerId?, { kind, owner, container, citizenId })` when a container is written and `opx:on:inventory:used` `(playerId, { citizenId, name, slot, consumed, metadata })` when an item is used, for every server resource. See [Public server events](../creators/server-events.md#inventory).

A stash loaded by name (by the stash functions above) and not opened by a player is saved and put away after `SERVER.EXPORTS.STASHES.IDLE_MS` (60 s) without use; a sweep runs every 15 s.

## Page channels {#page-channels}

| Channel | Direction | Payload | Meaning |
|---|---|---|---|
| <a id="page-inventory-ready"></a>`inventory:ready` | page → Lua | — | The page mounted. Lua sends the config and the catalogue. |
| <a id="page-inventory-request"></a>`inventory:request` | page → Lua | `{ handle, action, payload, ref }` | Forwarded to the server as a request; the answer comes back under `ref`. |
| <a id="page-inventory-dismiss"></a>`inventory:dismiss` | page → Lua | `{ handle }` | The player closed the screen. |
| `inventory:open` | Lua → page | `{ handle, config, primary, secondary }` | Draw the screen. |
| `inventory:close` | Lua → page | `{ handle }` | Close it. |
| `inventory:update` | Lua → page | `{ handle, container }` | A container changed. |
| `inventory:secondary` | Lua → page | `{ handle, container \| false }` | Second container opened or closed. |
| `inventory:nearby` | Lua → page | `{ handle, players }` | Players in reach. |
| `inventory:config` | Lua → page | `{ labels, hotbar, openKey, drops, defaultWeight }` | Words, tabs and keys. |
| `inventory:catalog` | Lua → page | `{ entries, first, done }` | The catalogue, in parts. |
| `inventory:slotbar` | Lua → overlay | `{ slots, holdMs }` | The hotbar row on the overlay page. |

## Keys {#keys}

| Mapping id | Default | What it does |
|---|---|---|
| `opx.inventory.open` | `I` | Toggles the screen. Seated: opens the glovebox. Beside a pile: takes the pile. Otherwise: the bag. |
| `opx.inventory.hotbar1` … `hotbar5` | `4` … `8` | Uses bag slot 1 … 5 with the screen closed. An empty slot does nothing. |
| `opx.inventory.peek` | `Y` | Shows the hotbar row for `HOTBAR.PEEK_MS`. |

Players rebind them in Pause → Settings → KEY BINDINGS.

## Configuration {#configuration}

`config/inventory.lua` sets `OPX.Config.MODULES.inventory`. Shared script. `enabled = false` switches the module off. Out-of-range values fall back to the default with a boot warning.

| Key | Default | What it does |
|---|---|---|
| <a id="config-inventory-enabled"></a>`enabled` | `true` | Switches the module on or off. |
| <a id="config-inventory-bag"></a>`BAG` | `{ SLOTS = 40, MAX_WEIGHT = 30000 }` | Size of a **new** bag. Slots 1–200, grams. An existing bag keeps its size; use [`ResizeContainer`](#server-inventory-resizecontainer). |
| <a id="config-inventory-default-item-weight"></a>`DEFAULT_ITEM_WEIGHT` | `100` | Grams per unit for an item the catalogue no longer has, and for a catalogue row with a bad `WEIGHT`. |
| <a id="config-inventory-max-stack"></a>`MAX_STACK` | `1000000` | Most units per slot of a stackable item. |
| <a id="config-inventory-max-metadata-bytes"></a>`MAX_METADATA_BYTES` | `1024` | Largest encoded metadata per stack (64–4096). |
| <a id="config-inventory-reach"></a>`REACH` | `{ DISTANCE = 3.0, VEHICLE = 4.5 }` | Metres. `DISTANCE`: to a stash, pile or player. `VEHICLE`: vehicle centre to trunk; also the vehicle target rows' distance. |
| <a id="config-inventory-hotbar"></a>`HOTBAR` | `{ ENABLED = true, SLOTS = 5, PEEK_MS = 4000 }` | Bag slots usable by key without the screen (0–9), and how long the peek shows the row (500–30000 ms). |
| <a id="config-inventory-keys"></a>`KEYS` | `{ OPEN = 'I', HOTBAR = { '4','5','6','7','8' }, PEEK = 'Y' }` | Default keys. `false` registers no mapping. A hotbar or peek key equal to the open key is dropped. |
| <a id="config-inventory-use-cooldown-ms"></a>`USE_COOLDOWN_MS` | `750` | Least time between two uses by one player. Also the live tunable `INVENTORY_USE_COOLDOWN_MS`. |
| <a id="config-inventory-use-handler-ms"></a>`USE_HANDLER_MS` | `5000` | Time a use handler has to answer (500–25000). |
| <a id="config-inventory-rate-limit"></a>`RATE_LIMIT` | `{ WINDOW_MS = 1000, REQUESTS = 20 }` | Screen requests per player per window. Refused requests are still answered `too_fast`. |
| <a id="config-inventory-save"></a>`SAVE` | `{ DELAY_MS = 2000, SWEEP_MS = 1000, BATCH = 16 }` | A container is written `DELAY_MS` after its last change, `BATCH` per transaction, looked for every `SWEEP_MS`. |
| <a id="config-inventory-drops"></a>`DROPS` | `{ ENABLED = true, SLOTS = 25, LIFETIME_MINUTES = 30, MAX = 200, MAX_PER_CHARACTER = 10, COOLDOWN_MS = 1000, DISTANCE = 1.5, MODEL = 'crate.small', PROMPT_RADIUS = 20.0 }` | Piles on the ground. `DISTANCE`: a drop this close to a pile joins it. `MODEL`: prop alias for a pile whose item has none. `PROMPT_RADIUS`: where a pile gets a target row. |
| <a id="config-inventory-trunk"></a>`TRUNK` | `{ SLOTS = 30, MAX_WEIGHT = 80000 }` | Trunk size. `SLOTS = 0` gives vehicles no trunk. |
| <a id="config-inventory-glovebox"></a>`GLOVEBOX` | `{ SLOTS = 10, MAX_WEIGHT = 10000 }` | Glovebox size. `SLOTS = 0` gives none. |
| <a id="config-inventory-trunk-owner-only"></a>`TRUNK_OWNER_ONLY` | `true` | An owned vehicle's trunk opens for its owner only. `false` lets anyone in reach open it. |
| <a id="config-inventory-bikes"></a>`BIKES` | `{ PATTERNS = { 'sportbike', '_bike_' }, TRUNK_DIVISOR = 3 }` | A vehicle record containing a pattern is a bike: no glovebox, trunk divided by `TRUNK_DIVISOR`. |
| <a id="config-inventory-stashes"></a>`STASHES` | `{}` | Fixed stashes, each `{ NAME, LABEL?, SLOTS? (50), MAX_WEIGHT? (100000), POSITION = { X, Y, Z }, BUCKET? (0) }`. `NAME` is the storage key: renaming it gives an empty stash. Anyone in reach may open one. |
| <a id="config-inventory-weapons"></a>`WEAPONS` | `{ ENABLED = true, SLOT = 1, REMOVE_UNBACKED = true, SCAN_MS = 5000, AMMO_SYNC_MS = 2000 }` | Weapons from the bag. `SLOT`: game weapon slot 1–3. `REMOVE_UNBACKED`: take off weapons no bag item backs. |
| <a id="config-inventory-nearby"></a>`NEARBY` | `{ MAX = 4, SCAN_MS = 1000 }` | Players offered in "give to", and the refresh rate. |
| <a id="config-inventory-tabs"></a>`TABS` | `all`, `weapons` (weapon, ammo), `food` (food, drink), `medical`, `materials` (material, tool), `misc` (`REST = true`) | Category tabs over the grid. `REST` takes every category no other tab names. |
| <a id="config-inventory-currency"></a>`CURRENCY` | `{ ENABLED = true, ITEM = 'eddies', MONEY_TYPE = 'EDDIES', MAX_WITHDRAW = 1000000 }` | The money bridge. `MAX_WITHDRAW` caps one withdraw. |
| <a id="config-inventory-max-command-count"></a>`MAX_COMMAND_COUNT` | `10000` | Largest count a staff command accepts. |

Live tunables (operator panel): `INVENTORY_SAVE_DELAY_MS` (2000), `INVENTORY_RATE_REQUESTS` (20), `INVENTORY_DROP_LIFETIME_MIN` (30), `INVENTORY_USE_COOLDOWN_MS` (750).

## Refusal codes {#codes}

Codes are toasted to the player as locale `inventory.error.<code>` (commands use `inventory.command.error.<code>`). An unknown code shows `inventory.error.failed`.

| Code | Meaning |
|---|---|
| `bad_argument` | A contract argument is invalid (`detail` names it). |
| `bad_request` | A request or a slot number is malformed. |
| `bad_target` | Not a player id or a citizen id. |
| `not_loaded` | No character loaded on that player id. |
| `no_character` | No living character has that citizen id. |
| `storage` | The `character` contract or the database is unavailable. |
| `not_ready` | The player is held at the readiness gate. |
| `dead` | The player is dead. |
| `not_found` | The container or pile is gone. |
| `empty_slot` | Nothing in that slot. |
| `bad_count` | Count out of range. |
| `bad_slot` | That slot cannot take it. |
| `not_enough` | Fewer units than asked for. |
| `no_room` | No free or stackable slot. |
| `too_heavy` | Over the weight limit. |
| `cannot_swap` | Only whole stacks swap places. |
| `unknown_item` | Not in the catalogue. |
| `not_usable` | No `USE` and no handler. |
| `use_refused` | The use handler answered `ok = false` with no code. |
| `handler_failed` | The use handler did not return a table. |
| `handler_timeout` | The use handler raised or took longer than `USE_HANDLER_MS`. |
| `too_fast` | Rate limit or use cooldown. |
| `stash_namespace` | A resource tried to create a stash outside its own `<resource>.<name>` namespace. |
| `stash_cap` | That resource already created `CREATE_CAP` stashes. |
| `hands_full` | The player is carrying a `hauling` crate; no use or draw. |
| `too_far` | Out of reach. |
| `target_unavailable` | The player to hand to cannot receive. |
| `drops_disabled` | Piles are switched off. |
| `drop_limit` | Too many piles on the server or for this character. |
| `no_drop` | The item has `DROP = false`. |
| `in_vehicle` / `seated` | Get out of the vehicle first. |
| `not_seated` | The glovebox needs a seat. |
| `no_position` | The player's position could not be read. |
| `no_vehicle` | The vehicle is gone. |
| `no_storage` | The vehicle has no trunk or glovebox. |
| `not_yours` | Someone else's owned trunk, with `TRUNK_OWNER_ONLY` on. |
| `locked` | The vehicle is locked. |
| `weapons_unavailable` | No weapon relay on this host. |
| `weapon_refused` | The host refused to draw the weapon. |
| `no_weapon_for_ammo` | No drawn weapon takes this ammunition. |
| `weapon_full` | The weapon is fully loaded. |
| `not_enough_money` | Balance too low to withdraw. |
| `unavailable` | The money bridge is off, or a stash could not be opened. |
| `load_timeout` | A container did not load in time. |
