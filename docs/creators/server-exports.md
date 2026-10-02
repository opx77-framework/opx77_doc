---
title: Server exports
description: Every server export opx_infinity publishes for other resources — players, money, jobs, items, stashes, chat, vehicle keys and vehicle state — with arguments, answers, error codes and examples.
---

# Server exports

These are the functions a **server** script of another resource can call on
`opx_infinity`. They are defined in `core/server/exports.lua`. Read
[For creators](index.md) first: every export answers `{ ok, value | error }`,
the operator decides who may call it, and writes must be **awaited**.

**Scope** says which allowlist applies: `read` → `SERVER.EXPORTS.READ`,
`write` → `SERVER.EXPORTS.WRITERS`. **Await** says whether the call can wait on
the database; such a call made synchronously answers `export.mustAwait`.

Arguments used everywhere:

| Name | Accepts |
|---|---|
| `source` | a connected player id (number) |
| `citizenId` | a citizen id string |
| `target` | a connected player id **or** a citizen id (a citizen id reaches an offline bag and must be awaited) |
| `metadata` | `nil` or a plain table |

## Players {#players}

| Export | Scope | Await | Arguments | `value` on success | Errors |
|---|---|---|---|---|---|
| <a id="export-server-getversion"></a>`GetVersion` | read | no | — | `{ version, exports }` — the resource version and the export surface version (`1`; bumped on a breaking change) | — |
| <a id="export-server-getplayerdata"></a>`GetPlayerData` | read | no | `source` | the public view: `{ source, citizenId, userId, firstName, lastName, money, job, gang, jobs, gangs }` (no metadata) | `export.badArgument`, `error.notLoggedIn` |
| <a id="export-server-getplayerbycitizenid"></a>`GetPlayerByCitizenId` | read | no | `citizenId` | the same public view, for a character that is **online** | `export.badArgument`, `error.notLoggedIn` |
| <a id="export-server-isstaff"></a>`IsStaff` | read | no | `source` | `true` when the player holds [`STAFF_PERMISSION`](../reference/core-config.md#config-server-exports) (`command.opx.admin` by default) | `export.badArgument` |

`money`, `job`, `gang`, `jobs` and `gangs` have the shapes of the
[Player object](../modules/character.md#player).

## Money {#money}

Money types are the server's [`MONEY.TYPES`](../reference/core-config.md#config-shared-money) (`EDDIES`, `BANK` shipped). Amounts are whole numbers from 1 to 9 999 999 999. `reason` is optional text (cut to 64 characters) and is stored as `ext:<your resource>:<reason>`.

| Export | Scope | Await | Arguments | `value` on success | Errors |
|---|---|---|---|---|---|
| <a id="export-server-getmoney"></a>`GetMoney` | read | no | `source, moneyType?` | the balance, or every balance as `{ [type] = amount }` when `moneyType` is nil | `export.badArgument`, `error.notLoggedIn`, `money.badType` |
| <a id="export-server-addmoney"></a>`AddMoney` | write | yes | `source, moneyType, amount, reason?` | the new balance | `money.badType`, `money.badAmount`, `money.vetoed`, `error.notLoggedIn`, `export.badArgument` |
| <a id="export-server-removemoney"></a>`RemoveMoney` | write | yes | `source, moneyType, amount, reason?` | the new balance | as `AddMoney`, plus `money.insufficient` |
| <a id="export-server-addmoneyoffline"></a>`AddMoneyOffline` | write | **yes** | `citizenId, moneyType, amount, reason?` | `{ balance, offline }` — `offline = false` when the character turned out to be online | as `AddMoney`, plus `character.notFound`; `error.unavailable` while the row is being written |

`AddMoney` and `RemoveMoney` answer from memory today, but they are writes: use
the promise form. Money moved by an export runs the same
[hooks](../modules/character.md#hooks) as any other change and raises
[`opx:on:character:money`](server-events.md#character).

## Jobs and gangs {#jobs}

| Export | Scope | Await | Arguments | `value` on success | Errors |
|---|---|---|---|---|---|
| <a id="export-server-hasjob"></a>`HasJob` | read | no | `source, name, onDuty?, minGrade?` | `true`/`false`. `onDuty = true` requires being on duty; `minGrade` 0–255. | `export.badArgument`, `error.notLoggedIn` |
| <a id="export-server-hasgang"></a>`HasGang` | read | no | `source, name, minGrade?` | `true`/`false` | `export.badArgument`, `error.notLoggedIn` |
| <a id="export-server-getjob"></a>`GetJob` | read | no | `source` | a copy of the primary job `{ name, label, type, payment, onDuty, isBoss, bankAuth, grade = { name, level } }` | `export.badArgument`, `error.notLoggedIn` |
| <a id="export-server-getgang"></a>`GetGang` | read | no | `source` | a copy of the primary gang | `export.badArgument`, `error.notLoggedIn` |

| <a id="export-server-setjob"></a>`SetJob` | write | **yes** | `target, name, grade?` | the new primary job table | `job.notFound`, `job.gradeNotFound`, `job.vetoed`, `character.notFound`, `export.badArgument`, `error.unavailable` |
| <a id="export-server-setgang"></a>`SetGang` | write | **yes** | `target, name, grade?` | the new primary gang table | `gang.notFound`, `gang.gradeNotFound`, `gang.vetoed`, `character.notFound`, `export.badArgument`, `error.unavailable` |
| <a id="export-server-removejob"></a>`RemoveJob` | write | **yes** | `target, name` | `true` | `job.notMember`, `character.notFound`, `export.badArgument`, `error.unavailable` |
| <a id="export-server-removegang"></a>`RemoveGang` | write | **yes** | `target, name` | `true` | `gang.notMember`, `character.notFound`, `export.badArgument`, `error.unavailable` |
| <a id="export-server-setduty"></a>`SetDuty` | write | no | `source, onDuty` | the new duty (`true`/`false`) | `job.noDuty` (a job that is always on duty), `error.notLoggedIn`, `export.badArgument` |

`target` is a connected player id or a citizen id (a character nobody is
playing). `grade` is 0–255 and defaults to 0. `SetJob`/`SetGang` join the job
(or regrade) and make it primary; duty resets to the job's `defaultDuty`.
Removing the primary job falls back to the server's default job. These go
through the same functions as the staff commands, so the
[`job:beforeSet` / `gang:beforeSet` hooks](../modules/character.md#hooks) can
veto them, and a change raises
[`opx:on:character:job` / `gang`](server-events.md#character).

## Metadata {#metadata}

Each resource has its **own** metadata space on a character. A key you name is
stored as `ext.<your resource>.<key>`, so you cannot read or change OPX's keys
or another resource's.

| Export | Scope | Await | Arguments | `value` on success | Errors |
|---|---|---|---|---|---|
| <a id="export-server-getmetadata"></a>`GetMetadata` | read | no | `source, key?` | the value of your key, or with no `key` every key you stored as `{ [key] = value }` | `export.badArgument`, `error.notLoggedIn` |
| <a id="export-server-setmetadata"></a>`SetMetadata` | write | no | `source, key, value` | `true` | `export.badArgument`, `export.badValue`, `export.tooLarge`, `error.notLoggedIn` |

- **Online characters only.** It is saved with the character.
- `key`: one segment, 1–48 characters, letters, digits, `_` and `-` (no dot).
- `value`: plain data only — booleans, finite numbers, text, and tables of those
  keyed by text or position, at most 8 levels deep. Anything else is
  `export.badValue`. `nil` deletes the key.
- Limits from [`SERVER.EXPORTS.METADATA`](../reference/core-config.md#server-exports):
  4096 bytes per value (encoded), 32 keys and 16384 bytes in total per resource
  per character. Over a limit: `export.tooLarge`.

!!! warning "No secrets in metadata"

    Metadata travels with the character's data to the **player's own client**.
    The player can read anything you store there.

## Down and revive {#downed}

| Export | Scope | Await | Arguments | `value` on success | Errors |
|---|---|---|---|---|---|
| <a id="export-server-isdown"></a>`IsDown` | read | no | `source` | `{ down, waiting, downForMs? }`; `downForMs` only when down | `export.badArgument`, `error.unavailable` |
| <a id="export-server-revive"></a>`Revive` | write | no | `source, reason?` | `true` | `not_down`, `not_incarnated`, `gate_closed`, `caller_denied`, `export.badArgument`, `error.unavailable` |

`Revive` goes through the [downed module](../modules/downed.md)'s own revive:
the player gets up where the body lies. Your resource name must be allowed by
the module's `REVIVERS` (everyone by default), or it answers `caller_denied`.
The audit line names your resource and `reason` (up to 256 characters, cut to 64
in the log).

## Items {#items}

`item` is a catalogue item name (1–64 characters). `count` is 1–1 000 000 and
defaults to 1. With a `metadata` table, only stacks with exactly that metadata
match. Errors other than those listed come from the
[inventory](../modules/inventory.md#codes) (for example `no_room`, `too_heavy`,
`not_enough`).

| Export | Scope | Await | Arguments | `value` on success | Errors |
|---|---|---|---|---|---|
| <a id="export-server-hasitem"></a>`HasItem` | read | when `target` is a citizen id | `target, item, count?, metadata?` | `true` when the bag holds at least `count` | `export.badArgument`, inventory codes |
| <a id="export-server-countitem"></a>`CountItem` | read | when `target` is a citizen id | `target, item, metadata?` | how many units the bag holds | `export.badArgument`, inventory codes |
| <a id="export-server-additem"></a>`AddItem` | write | yes | `target, item, count?, metadata?` | `true` | `export.badArgument`, inventory codes |
| <a id="export-server-removeitem"></a>`RemoveItem` | write | yes | `target, item, count?, metadata?` | `true` | `export.badArgument`, inventory codes |

## Stashes {#stashes}

A stash is named by its storage key (1–48 characters: letters, digits, `_`,
`-`, `.`). The stash is loaded, never opened in front of a player.

| Export | Scope | Await | Arguments | `value` on success | Errors |
|---|---|---|---|---|---|
| <a id="export-server-countinstash"></a>`CountInStash` | read | **yes** | `stash, item, metadata?` | units held; `0` for a stash that does not exist (none is created) | `export.badArgument`, inventory codes |
| <a id="export-server-addtostash"></a>`AddToStash` | write | **yes** | `stash, item, count?, metadata?` | `true` | `stash_namespace`, `stash_cap`, `export.badArgument`, inventory codes |
| <a id="export-server-removefromstash"></a>`RemoveFromStash` | write | **yes** | `stash, item, count?, metadata?` | `true` | `not_enough` (also for a stash that does not exist; none is created), inventory codes |

**Creating a stash.** `AddToStash` on a stash that does not exist creates it
only when:

- it is listed in `config/inventory.lua` (`STASHES`), or
- its name starts with **your resource name and a dot** — `my_shop.backroom` —
  and your resource has created fewer than
  [`STASHES.CREATE_CAP`](../reference/core-config.md#config-server-exports)
  (25) of those. The count is read from the database, so a restart does not
  reset it.

Otherwise it answers `stash_namespace` (wrong name) or `stash_cap` (too many).
A stash that already exists is used whatever its name. A stash loaded this way
and not opened by a player is saved and put away
[`STASHES.IDLE_MS`](../reference/core-config.md#config-server-exports) (60 s)
after its last use.

## Chat {#chat}

A message is a string, or `{ text, author?, kind? }`. `kind` is one of
`chat`, `system` (default), `info`, `warning`, `error`. The line is not
attributed to a player.

| Export | Scope | Await | Arguments | `value` on success | Errors |
|---|---|---|---|---|---|
| <a id="export-server-sendchat"></a>`SendChat` | write | yes | `source, message` | `true` | `chat.noPlayer`, `chat.invalidMessage`, `chat.invalidKind` |
| <a id="export-server-broadcastchat"></a>`BroadcastChat` | write | yes | `message, options?` | how many players got the line | `chat.invalidMessage`, `chat.invalidKind`, `chat.invalidScope`, `export.badArgument` |

`options` for `BroadcastChat`: `bucket` (a routing bucket), `radius` (metres,
up to 10 000) with `origin` (a player id, or `{ x, y, z }`). With a player as
origin and no `bucket`, only that player's bucket is reached. With no options,
everyone gets the line.

## Vehicles and keys {#vehicles}

| Export | Scope | Await | Arguments | `value` on success | Errors |
|---|---|---|---|---|---|
| <a id="export-server-revokekeys"></a>`RevokeKeys` | write | **yes** | `target, plate` | `{ plate, removed }` — every key to that plate in that bag | `export.badArgument`, `error.badRequest`, `vehiclekeys.unavailable` |
| <a id="export-server-revokeallkeys"></a>`RevokeAllKeys` | write | **yes** | `plate` | `{ plate, removed, holders }` — from the bags of every **loaded** character | `export.badArgument`, `error.badRequest`, `vehiclekeys.unavailable` |
| <a id="export-server-setvehiclestate"></a>`SetVehicleState` | write | **yes** | `plate, state, garage?` | `{ plate, state, garage }` | `vehicle.badState`, `vehicle.notFound`, `vehicle.occupied`, `vehicle.busy`, `error.badRequest`, `export.badArgument` |

`state` is `'stored'` or `'impounded'`. A vehicle that is out is put away first
(refused with `vehicle.occupied` while anyone sits in it). An impounded vehicle
cannot be brought out (`vehicle.impounded`) until it is set back to `'stored'`.
Keys in stashes or trunks are not revoked; to re-key a car for good, change its
plate. See [vehicles](../modules/vehicles.md) and
[vehiclekeys](../modules/vehiclekeys.md).

## Examples {#examples}

### Pay a player for a job step {#example-pay}

```lua
-- my_jobs/server/main.lua — needs `my_jobs = true` in SERVER.EXPORTS.WRITERS
RegisterNetEvent('my_jobs:delivered', function()
	local playerId = source
	CreateThread(function()
		-- re-check on the server that the delivery really happened, then:
		local pending, why = Open77.exports.call('opx_infinity', 'AddMoney',
			playerId, 'EDDIES', 350, 'delivery')
		if not pending then return print('not sent: ' .. tostring(why)) end
		local answer, failure = pending:await()
		if answer == nil then return print('call failed: ' .. tostring(failure)) end
		if answer.ok ~= true then return print('refused: ' .. tostring(answer.error)) end
		print(('paid, balance is now %d'):format(answer.value))
	end)
end)
```

### Check a job before letting someone in {#example-job}

```lua
-- a read: the synchronous form is fine
local answer = exports.opx_infinity:HasJob(playerId, 'police', true, 2)
if answer.ok and answer.value then
	-- on-duty police, grade 2 or more
end
```

### Restock a shop's back room {#example-stash}

```lua
-- creates `my_shop.backroom` on first use (needs my_shop in WRITERS)
CreateThread(function()
	local pending = Open77.exports.call('opx_infinity', 'AddToStash',
		'my_shop.backroom', 'water', 24)
	local answer = pending and pending:await()
	if not (answer and answer.ok) then
		print('restock refused: ' .. tostring(answer and answer.error))
	end
end)
```
