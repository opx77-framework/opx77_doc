---
title: opx77_core server exports
description: The eleven server exports opx77_core publishes to other server resources — who a player is, a cursor over characters loading and leaving, a spawned vehicle's plate, the version, and the seven inventory storage calls — with who may call them, each one's arguments, answer and codes, and which resources call them.
---

# Server exports

`opx77_core`'s `server/exports.lua` publishes eleven exports that another
**server** resource calls with `Open77.exports.call("opx77_core", name, ...)`.
Four are **reads**, open to the resources `EXPORTS.READ` names. Seven are the
**inventory storage** calls, open only to a resource `EXPORTS.CALLERS` grants
the `inventory` scope.

| Export | Admission | Answers | Called by |
|---|---|---|---|
| [`GetVersion`](#getversion) | `EXPORTS.READ` | the version, the contract number and the caller's scopes | — |
| [`GetIdentity`](#getidentity) | `EXPORTS.READ` | who a player id or a citizen id is, online or not | `opx77_inventory`, `opx77_status` |
| [`GetChanges`](#getchanges) | `EXPORTS.READ` | the characters loaded, unloaded and deleted after a cursor | `opx77_inventory` |
| [`GetVehiclePlate`](#getvehicleplate) | `EXPORTS.READ` | the plate and owner of a vehicle the core has out | `opx77_inventory` |
| [`InventoryEnsure`](#inventoryensure) | `inventory` scope | a container, found or created | `opx77_inventory` |
| [`InventoryRead`](#inventoryread) | `inventory` scope | one page of a container's stacks | `opx77_inventory` |
| [`InventoryStage`](#inventorystage) | `inventory` scope | stacks appended to a save staged under a token | `opx77_inventory` |
| [`InventoryCommit`](#inventorycommit) | `inventory` scope | everything staged under a token, written as one transaction | `opx77_inventory` |
| [`InventoryResize`](#inventoryresize) | `inventory` scope | a container's new slot count and weight limit | — |
| [`InventoryDelete`](#inventorydelete) | `inventory` scope | a container deleted, its stacks with it | — |
| [`InventoryHolders`](#inventoryholders) | `inventory` scope | which containers hold an item, largest stacks first | `opx77_inventory` |

These exports answer closed shapes about identity and storage. They are not the
core's server API: money, jobs, gangs, metadata and the hooks are reached from a
file inside the core — see [What the exports are not](#not-the-api).

## How to call one {#how-to-call}

```lua
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_core", "GetIdentity", playerId)
  if not promise then return print("not dispatched: " .. tostring(reason)) end
  local answer, callError = promise:await()
  if callError then return print("call failed: " .. tostring(callError)) end
  if answer.ok ~= true then return print("refused: " .. tostring(answer.error)) end
  print(answer.citizenId, answer.loaded)
end)
```

- **Call from a thread, an event handler or a command handler**, never at file
  scope: a call made while the calling resource is still being prepared is
  refused with `resource_preparing`.
- **Keep the promise until it is awaited.** A collected promise releases the
  request.
- **A server call times out after 30 seconds**, and a reload of the core
  rejects the calls in flight with `export_resource_stopped`. A call can have
  written before it timed out: the inventory writes are safe to retry, because a
  commit rewrites a container whole.
- **Every answer is `{ ok = true, ... }` or `{ ok = false, error = <code> }`**,
  and no export raises. Read anything without `ok = true` as a refusal. Every
  `error` is a key of the core's catalogue.

The three levels of failure — not dispatched, not resolved, refused — are in
[The export contract](../../../concepts/export-contract.md).

## Who may call {#admission}

Every export runs the same gates, in this order, before its own body:

1. **The caller.** Its name and generation are read from the host with
   `GetInvokingResource()` and `GetInvokingResourceGeneration()`, once, on entry
   — never from an argument. A name that is empty, longer than 64 bytes or
   outside letters, digits, `_`, `-` and `.` is refused with
   `export.callerDenied`.
2. **The boot.** Until the core's boot thread has settled the schema, every
   export answers `core.booting`. A core that booted degraded — no database, or
   a table that could not be created — answers from then on, and the calls that
   need storage answer `error.unavailable`.
3. **The scope.** A read is admitted when
   [`EXPORTS.READ`](../config.md#server-exports-read) is `"*"` or names the
   caller. An inventory call is admitted when
   [`EXPORTS.CALLERS`](../config.md#server-exports-callers) lists the caller
   with `scopes = { inventory = true }`. A refusal answers
   `export.callerDenied` and writes an `export.denied` security line to the
   audit log, naming the caller, its generation, the export and the scope.

Then the body runs inside a `pcall`. A body that raises is logged —
`[exports] <export> raised for <caller>: <error>` — and answered
`error.unavailable`. Last, the answer is encoded once to measure it: one heavier
than [`EXPORTS.MAX_RESULT_BYTES`](../config.md#server-exports-max-result-bytes)
is refused with `export.tooLarge` rather than reaching the caller as a codec
failure.

| Code | Answered when |
|---|---|
| `export.callerDenied` | The host named no usable caller, or the caller is not admitted to this export. |
| `core.booting` | The core has not finished booting. |
| `export.badArgument` | An argument is missing, of the wrong type, out of bounds or malformed. |
| `export.tooLarge` | The answer would weigh more than `EXPORTS.MAX_RESULT_BYTES`, or a staging bound was reached. |
| `error.unavailable` | A storage call failed, or the export body raised. The cause is in the server log. |

!!! warning "Narrowing `EXPORTS.READ` shuts out two resources"
    The shipped `EXPORTS.READ` is `"*"`. Replaced with a set, it must still name
    `opx77_inventory` and `opx77_status`: both call `GetIdentity`, and neither
    works without it. `opx77_inventory` also needs its entry in
    `EXPORTS.CALLERS`.

---

## GetVersion {#getversion}

Answers the core's version, the export contract number, and the scopes this
caller holds.

```lua
Open77.exports.call("opx77_core", "GetVersion")
```

Takes no parameters.

**Returns** `{ ok: true, version: string, exports: integer, scopes: string[] }`

- `version` — `OPX.VERSION`, `"0.6.0"` on this release.
- `exports` — the contract number, `1`. It is bumped on any breaking change to
  an export's arguments or answer; an export name is never reused.
- `scopes` — the scopes `EXPORTS.CALLERS` grants this caller, sorted. Empty for
  a resource that is only admitted to the reads.

**Errors** the admission codes only.

**Side** `server` export — admitted by `EXPORTS.READ`. No OPX//77 resource calls
it.

---

## GetIdentity {#getidentity}

Answers who a player id or a citizen id is: the account, the character loaded,
and whether the core still holds their readiness gate.

```lua
Open77.exports.call("opx77_core", "GetIdentity", target)
```

- target: `integer|string`
    - A player id, `1` to `2147483647`, or a citizen id. A citizen id is parsed
      like any player input — upper-cased, separators ignored, check symbol
      verified — and answered in its normal grouped form.

**Returns**, for a player id:

| Field | Type | |
|---|---|---|
| `ok` | `true` | |
| `source` | `integer` | the player id asked about |
| `online` | `boolean` | `false` when the core holds no session for that id; only `source` and `loaded = false` come with it then |
| `userId` | `string` | the account behind the session |
| `citizenId` | `string?` | the character loaded on it, absent when none is |
| `loaded` | `boolean` | whether a character is loaded |
| `gateHeld` | `boolean` | whether the core still holds the player's readiness gate |
| `released` | `boolean` | whether the core has released that gate this session |

For a citizen id, a character **loaded** on a connection is answered exactly as
its player id is. Otherwise the stored row is read: a living character answers
`{ ok = true, userId, citizenId, online = false, loaded = false }`, with no
`source`.

**Errors**

| Code | Meaning |
|---|---|
| `export.badArgument` | Not a whole number in range, and not a valid citizen id. |
| `character.notFound` | No living character carries that citizen id. A deleted one is not found. |
| `error.unavailable` | The character row could not be read. |

!!! warning
    An identity is true at the moment it is read. A character can unload a
    moment later; a resource that keeps state per character follows
    [`GetChanges`](#getchanges) rather than asking once.

**Side** `server` export — admitted by `EXPORTS.READ`. Called by
[`opx77_inventory`](../../opx77_inventory/index.md), to key a bag on the
character a player has loaded, and by
[`opx77_status`](../../opx77_status/index.md), which admits a pull of stored
needs only for the character the core reports `loaded` on that player id.

---

## GetChanges {#getchanges}

Answers the character changes the core recorded after a cursor: characters
loaded, unloaded and deleted.

```lua
Open77.exports.call("opx77_core", "GetChanges", since)
```

- since: `integer`
    - The `cursor` of the previous answer, or `0` to start.

**Returns** `{ ok: true, cursor: integer, head: integer, reset: boolean, more: boolean, generation: integer, events: table[] }`

- `cursor` — pass it as `since` next time.
- `head` — the newest cursor recorded.
- `reset` — `true` when `since` is not a cursor of this journal: it is ahead of
  `head`, because the core reloaded and started again from `0`, or it is older
  than the ring still holds. The answer then starts from the oldest change kept.
- `more` — `true` while changes past `cursor` remain; ask again at once.
- `generation` — the core's resource generation, which changes on every reload.
- `events` — at most 16, oldest first, each
  `{ cursor, kind, source?, citizenId?, at }`:
    - `kind` — `loaded`, `unloaded` or `deleted`.
    - `source` — the player id. For `deleted`, the player who deleted it.
    - `citizenId` — the character.
    - `at` — the core's millisecond clock when it was recorded. A process
      clock, not a wall-clock instant.

**Errors**

| Code | Meaning |
|---|---|
| `export.badArgument` | `since` is not a whole number of `0` or more. |

It is a cursor rather than a callback, because another server VM cannot hear the
core's internal events. The ring keeps the last 512 changes. On `reset = true`,
re-read whatever you keep per character — with [`GetIdentity`](#getidentity) —
rather than trusting the events alone: some were missed.

**Side** `server` export — admitted by `EXPORTS.READ`. Called by
[`opx77_inventory`](../../opx77_inventory/index.md), which polls it to load and
drop bags.

---

## GetVehiclePlate {#getvehicleplate}

Answers the plate and the owner of a vehicle the core has spawned and not yet
put away.

```lua
Open77.exports.call("opx77_core", "GetVehiclePlate", vehicleId)
```

- vehicleId: `integer`
    - The runtime vehicle id the host issued.

**Returns** `{ ok: true, plate?: string, citizenId?: string }` — both absent for
a vehicle the core does not have out: one another resource spawned, or one
already stored or removed. That is an answer, not a refusal.

**Errors**

| Code | Meaning |
|---|---|
| `export.badArgument` | `vehicleId` is not a whole number of `1` or more. |

**Side** `server` export — admitted by `EXPORTS.READ`. Called by
[`opx77_inventory`](../../opx77_inventory/index.md), to find the trunk and
glovebox of the vehicle a player stands at.

---

## Inventory storage {#inventory-storage}

The seven `Inventory*` exports read and write `opx77_inventories` and
`opx77_inventory_items` — see [Persistence](../../../concepts/persistence.md#schema).
The core stores what it is handed and checks only that it fits the tables:
what goes in a container, and how big a container is, is
[`opx77_inventory`](../../opx77_inventory/index.md)'s decision. The bounds come
from [`INVENTORY`](../config.md#server-inventory) in `config/server.lua`.

| Value | Accepted |
|---|---|
| container id | a whole number, `1` to `4294967295` |
| `kind` | 1–32 bytes, a lower-case letter then lower-case letters, digits or `_` |
| `owner` | 1–64 bytes of letters, digits, `_`, `-`, `.` or `:` |
| `slots` | `1` to `INVENTORY.MAX_SLOTS` |
| `maxWeight` | grams, `0` to `INVENTORY.MAX_WEIGHT` |
| item `name` | 1–48 bytes of letters, digits, `_`, `-` or `.` |
| `count` | `1` to `2147483647` |
| `metadata` | a table whose encoded JSON is at most `INVENTORY.MAX_METADATA_BYTES`; an empty table is stored as none |
| token | 1–32 bytes of letters, digits, `_` or `-` |

A stack, on the way in and on the way out, is
`{ slot: integer, name: string, count: integer, metadata?: table }`.

### InventoryEnsure {#inventoryensure}

Finds the container a kind and an owner name, or creates it with the size
given.

```lua
Open77.exports.call("opx77_core", "InventoryEnsure", kind, owner, { slots = 40, maxWeight = 30000 })
```

- kind: `string`
- owner: `string`
- options: `{ slots: integer, maxWeight: integer }`
    - Used only when the container is created. An existing container answers the
      size it was created with, or last resized to.

A kind listed in [`INVENTORY.LINKED_KINDS`](../config.md#server-inventory) has
an owner that is another row, which must exist:

| Link | `owner` must be | Stored |
|---|---|---|
| `citizen` (`character` as shipped) | a citizen id in its normal grouped form, of a living character | with the citizen id, so the container goes when the character row is really deleted |
| `plate` (`trunk`, `glovebox`) | a plate of at most 12 bytes with a row in `opx77_vehicles` | with the plate, so the container goes with the vehicle row |

Any other kind — a stash — stands alone.

**Returns** `{ ok: true, id: integer, kind: string, owner: string, slots: integer, maxWeight: integer, created: boolean }`

**Errors**

| Code | Meaning |
|---|---|
| `export.badArgument` | A value out of bounds, or a `citizen` owner that is not a normal citizen id. |
| `inventory.noOwner` | The linked character or vehicle does not exist. |
| `error.unavailable` | The tables could not be read or written. |

The unique key on `(kind, owner)` settles two callers creating the same
container at once: both get it, one with `created = true`.

**Side** `server` export — `inventory` scope. Called by `opx77_inventory`.

### InventoryRead {#inventoryread}

Answers one page of a container's stacks, after a slot.

```lua
Open77.exports.call("opx77_core", "InventoryRead", id, after)
```

- id: `integer`
- after?: `integer`
    - The last slot of the previous page, `0` to `65535`.
    - Default: `0`, the first page.

**Returns** `{ ok: true, id: integer, items: table[], nextAfter?: integer, kind?: string, owner?: string, slots?: integer, maxWeight?: integer }`

- `items` — stacks in slot order, at most
  [`INVENTORY.PAGE_ROWS`](../config.md#server-inventory), and trimmed so their
  encoded size stays within half of `EXPORTS.MAX_RESULT_BYTES`. A page always
  carries at least one stack when the container has one past `after`.
- `nextAfter` — present while there may be more: pass it as `after`.
- `kind`, `owner`, `slots`, `maxWeight` — the header, on the first page only.

**Errors**

| Code | Meaning |
|---|---|
| `export.badArgument` | `id` or `after` out of bounds. |
| `inventory.notFound` | No container has that id. Checked on the first page only. |
| `error.unavailable` | The tables could not be read. |

Pages are keyed on the slot rather than an offset, so a save landing between two
pages cannot make a stack appear in both or neither.

**Side** `server` export — `inventory` scope. Called by `opx77_inventory`.

### InventoryStage {#inventorystage}

Appends stacks to a container's save, staged under a token until
[`InventoryCommit`](#inventorycommit) writes it.

```lua
Open77.exports.call("opx77_core", "InventoryStage", token, id, rows)
```

- token: `string`
    - Chosen by the caller. Tokens are kept per calling resource, so two callers
      cannot collide.
- id: `integer`
    - The container.
- rows: `table[]`
    - Stacks, at most `INVENTORY.MAX_SLOTS` in one call.

**Returns** `{ ok: true, staged: integer }` — how many stacks that container
holds under the token so far.

A save is staged across calls because one export argument carries at most
48 KiB. A container staged under a token is **rewritten whole** at commit: its
stored stacks are deleted and the staged ones inserted, so a container staged
with an empty `rows` is saved empty.

| Bound | Refusal |
|---|---|
| 8 open tokens per calling resource | `export.tooLarge` on the ninth |
| 64 containers per token | `export.tooLarge` |
| `INVENTORY.MAX_SLOTS` stacks per container per token | `export.tooLarge` |
| 30 seconds since a token was last staged to | the token is forgotten |

**Errors**

| Code | Meaning |
|---|---|
| `export.badArgument` | The token, the id or `rows` is unusable. A stack that is out of bounds, or a slot already staged for that container, **drops the whole token**. |
| `export.tooLarge` | One of the bounds above. |

**Side** `server` export — `inventory` scope. Called by `opx77_inventory`.

### InventoryCommit {#inventorycommit}

Writes everything staged under a token as one transaction, and forgets the
token.

```lua
Open77.exports.call("opx77_core", "InventoryCommit", token)
```

- token: `string`

**Returns** `{ ok: true, saved: integer }` — the number of containers written.

For each container, in the order it was first staged: every stored stack is
deleted, the staged stacks are inserted, and `updated_at` is stamped. Either all
of it is written or none of it.

**Errors**

| Code | Meaning |
|---|---|
| `export.badArgument` | The token is malformed. |
| `inventory.unknownToken` | Nothing is staged under it: never staged, expired, dropped, or already committed. |
| `inventory.saveFailed` | The transaction failed and nothing was written. The token is gone: stage again and commit again. |

**Side** `server` export — `inventory` scope. Called by `opx77_inventory`.

### InventoryResize {#inventoryresize}

Changes a container's slot count and weight limit.

```lua
Open77.exports.call("opx77_core", "InventoryResize", id, slots, maxWeight)
```

- id: `integer`
- slots: `integer`
- maxWeight: `integer`

**Returns** `{ ok: true }` — also for an id that names no container.

**Errors** `export.badArgument` for a value out of bounds, `error.unavailable`
when the write failed.

The stored stacks are not touched: a stack in a slot past the new count stays
where it is, and deciding what to do with it is the caller's.

**Side** `server` export — `inventory` scope. No OPX//77 resource calls it.

### InventoryDelete {#inventorydelete}

Deletes a container; its stacks go with it by cascade.

```lua
Open77.exports.call("opx77_core", "InventoryDelete", id)
```

- id: `integer`

**Returns** `{ ok: true }` — also for an id that names no container.

**Errors** `export.badArgument`, `error.unavailable`.

**Side** `server` export — `inventory` scope. No OPX//77 resource calls it.

### InventoryHolders {#inventoryholders}

Answers which containers hold an item, one row per stack, largest first.

```lua
Open77.exports.call("opx77_core", "InventoryHolders", name, limit)
```

- name: `string`
    - The item name.
- limit?: `integer`
    - `1` to `50`.
    - Default: `20`

**Returns** `{ ok: true, holders: { id: integer, kind: string, owner: string, slot: integer, count: integer }[] }`

**Errors** `export.badArgument`, `error.unavailable`.

**Side** `server` export — `inventory` scope. Called by `opx77_inventory` for its
holders command.

---

## Fixed limits {#limits}

Besides the `EXPORTS` and `INVENTORY` keys in
[Configuration](../config.md#server-exports-read), these are constants of
`server/exports.lua`:

| Constant | Value | Bounds |
|---|---|---|
| `CONTRACT` | `1` | the `exports` number `GetVersion` answers |
| `JOURNAL_SIZE` | `512` | changes the `GetChanges` ring keeps |
| `EVENTS_PER_READ` | `16` | events in one `GetChanges` answer |
| `STAGE_TTL_MS` | `30000` | how long an idle staged token is kept |
| `TOKENS_PER_CALLER` | `8` | open tokens per calling resource |
| `CONTAINERS_PER_TOKEN` | `64` | containers staged under one token |

The platform adds its own: 32 values, depth 16 and a 48 KiB transfer budget per
argument tuple and per answer, and a 30-second timeout per call.

---

## What the exports are not {#not-the-api}

The exports answer who a player is and store what an inventory hands over. They
do not move money, set a job or read `PlayerData`. Those stay where the core's
single writer can guard them.

| You want | Use | Synchronous? |
|---|---|---|
| Who a player is, and whether a character is loaded, from your own server resource | [`GetIdentity`](#getidentity) and [`GetChanges`](#getchanges) | No — a promise |
| To call the core's server API — `GetPlayer`, `AddMoney`, `SetJob` — and get an answer | [A file inside `opx77_core/server/`](#a-file-in-the-core) | Yes |
| To read the character for a UI, without touching the core | [Your client half, calling a client export](#the-client-leg) | No — a promise |
| To be told a player has been placed, from a resource that does not poll | [The `onPlayerReady` release note](#loose) | No |

### A file inside `opx77_core/server/` {#a-file-in-the-core}

A plug-in that needs the core's state is **a file you add to the core and a
line you add to its manifest** — files inside one resource share a Lua state,
so your file sees the whole `OPX` namespace exactly as the core's own files do,
with no codec and no promise.

```lua
-- opx77_core/server/plugins/paydirt.lua, listed in open77.lua after server/player.lua
local ok, why = OPX.AddMoney(source, "EDDIES", 500, "paydirt")
if not ok then
  OPX.NotifyLocale(source, why, nil, "error")
end
```

Read [Writing a server plugin](../../../guides/writing-a-server-plugin.md) for
the layout, the reserved manifest block and what you inherit by living inside
the core; every function you can call is in the
[Server API](../server-api.md), and the veto points are in [Hooks](../hooks.md).

What it costs: your code ships inside somebody else's resource, and you own a
merge every time the core is updated.

### Your own client half {#the-client-leg}

For presentation — a job label, a balance on a HUD — ask the core's client half
from your client half.

```lua
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_core", "GetPlayerData")
  if not promise then return end
  local result, callError = promise:await()
  if callError or result.ok ~= true then return end
  TriggerServerEvent("myresource:sawCharacter", result.data.citizenId)
end)
```

!!! warning
    Anything that arrives at your server through a client is a **hint**, not
    proof. A citizen id a client reports is a claim; the character a player has
    loaded is what [`GetIdentity`](#getidentity) answers.

The full list is in [client exports](client.md).

### The release note, and the shared database {#loose}

- **The `onPlayerReady` `detail` note** reaches every server VM, once per player
  per join. The core passes `opx77_core:character-placed` or
  `opx77_core:character-loaded`. See [Events](../events.md#onplayerready).
- **The shared database** is one connection with one credential, so a resource
  holding `database.access` can read the core's tables — and write them,
  bypassing every guard the core has.

!!! danger
    The core is the only writer of its tables. Read them if you must; do not
    write them. A row written behind the core's back is overwritten by the next
    autosave at best, and silently disagrees with the loaded character at worst.

Both, with what each cannot do, are in
[Integration channels](../../../concepts/integration-channels.md#release-note).

## Coming from ESX or Qbox {#converting}

| There | Here |
|---|---|
| `ESX.GetPlayerFromId(source)` | `OPX.GetPlayer(source)`, in a file inside the core; from another resource, `GetIdentity` for who it is |
| `exports.qbx_core:GetPlayer(source)` | the same — there is no export answering a `Player` object |
| `exports['es_extended']:getSharedObject()` | Nothing. `OPX` is the shared object, inside the core, and a function cannot cross an export |
| `xPlayer.addAccountMoney(...)` | `OPX.AddMoney(identifier, moneyType, amount, reason)`, inside the core |
| `exports.ox_inventory:AddItem(...)` | [`opx77_inventory`](../../opx77_inventory/exports.md#server)'s server exports, not these storage calls |

The full walk-through is in [Converting from ESX or
Qbox](../../../guides/converting.md).

## Where to go next {#next}

- [Configuration](../config.md#server-exports-read) — `EXPORTS` and `INVENTORY`.
- [The export contract](../../../concepts/export-contract.md) — the three levels
  of failure.
- [Client exports](client.md) — the seventeen the client half publishes.
- [Writing a server plugin](../../../guides/writing-a-server-plugin.md) — the
  file inside the core, end to end.
