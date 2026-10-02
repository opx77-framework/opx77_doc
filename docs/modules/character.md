---
title: character module
description: Accounts, characters, money, jobs, gangs, metadata and placement — the module every other module reads a player through.
---

# character

The `character` module owns everything that outlives a session: the account row, the characters on it, their money, jobs, gangs and metadata, and where they stand. There is no selection screen. Each account is **locked** on one character and a connection enters on that character; an account locked on nothing gets a new, empty character, which the player then builds in the game's own creator and names in the world (see [`entry`](entry.md)). Players move the lock with `/opx.select`, `/opx.create` and `/opx.delete`. Every other gameplay module reads a player through this module, so it is fatal: if it fails, the runtime does not start.

| | |
|---|---|
| Side | both |
| Requires | nothing |
| Optional | `spawn` (read with `OPX.Api.Get` when a join is placed) |
| Configuration | `config/character.lua` (shared script) |
| Contract | `character` v1 — server, client |
| Data | `opx77_users`, `opx77_characters`, `opx77_character_groups`, `opx77_active_characters` |

## How a player enters {#entry-flow}

1. The platform reports a connection. The server holds the readiness gate, moves the player into a private bucket and reads the account's lock.
2. **Locked on a character:** that character is loaded. **Locked on nothing** (or on a character that cannot be entered): a new row is created with no name and no body, the lock is set to it, and it is loaded.
3. The client receives `opx:net:character:loaded`. The gate is released and the player leaves the private bucket.
4. When the platform says the body is alive (`onPlayerReady`), the character is **placed**. The server first asks the [`spawn`](spawn.md) module; if spawn takes over, the player picks a place and spawn calls `PlaceCharacter`. Otherwise the character is placed from its stored position, or from `DEFAULT_SPAWN` when it has none.
5. A new character is then sent to the game's creator (appearance module) and asked for a name (entry module). The name is accepted once.

Placement is always a kill followed by a respawn (with fade, preload and a 5 s grace), never a teleport. Health is restored from `metadata.health` as a fraction of `HEALTH.MAX` in `config/shared.lua` (at least 15 %), then armour from `metadata.armor`.

### Changing character {#switching}

| Command | What happens |
|---|---|
| `/opx.select <citizenId>` | Under `CHARACTERS.SWITCH = 'relog'` (shipped): the current character is saved (and waited on), the other is loaded and placed in the world, no disconnect. If that fails, or under `'reconnect'`: the lock moves and the player is disconnected; the next connection enters on the new character. |
| `/opx.create` | Clears the lock and **always disconnects**. The next connection builds a new character. A new body needs the game's main-menu creator, which cannot be reopened mid-session. |
| `/opx.delete <citizenId>` | Soft-deletes the character. If somebody is playing it, they are disconnected. |

## Commands {#commands}

| Command | Access | Arguments | What it does |
|---|---|---|---|
| <a id="opx-characters"></a>`/opx.characters` | everyone (alias `chars`) | — | Lists your characters, your slot count and which one you enter on (`>`). In game only. 2 s cooldown. |
| <a id="opx-select"></a>`/opx.select` | everyone | `<citizenId>` | Switches to another of your characters (see [Changing character](#switching)). 3 s cooldown. |
| <a id="opx-create"></a>`/opx.create` | everyone | — | Clears your lock and disconnects you; your next connection builds a new character. Refused at the slot limit or `ROW_CEILING`. |
| <a id="opx-delete"></a>`/opx.delete` | everyone | `<citizenId>` | Soft-deletes one of your own characters. Refused when `CHARACTERS.SELF_DELETE` is false. |
| <a id="opx-duty"></a>`/opx.duty` | everyone (alias `duty`) | — | Toggles on/off duty for your primary job. Refused (`job.noDuty`) for a job with `defaultDuty = true`. 2 s cooldown. |
| <a id="opx-players"></a>`/opx.players` | ACL `command.opx.players` | — | Lists loaded characters: player id, citizen id, name, job. |
| <a id="opx-where"></a>`/opx.where` | ACL `command.opx.where` | `[playerId]` | Prints what the server holds on a player: account, character, gate, life phase, position and bucket, job, gang, balances. |
| <a id="opx-here"></a>`/opx.here` | ACL `command.opx.here` | — | Prints your position as a ready-to-paste `DEFAULT_SPAWN` block. In game only. |
| <a id="opx-money"></a>`/opx.money` | ACL `command.opx.money` | `<playerId\|citizenId> <TYPE> <amount>` | Adds money; a negative amount removes it. Loaded characters only. |
| <a id="opx-job"></a>`/opx.job` | ACL `command.opx.job` | `<playerId\|citizenId> <job> [grade]` | Sets the primary job (grade defaults to 0). |
| <a id="opx-gang"></a>`/opx.gang` | ACL `command.opx.gang` | `<playerId\|citizenId> <gang> [grade]` | Sets the primary gang (grade defaults to 0). |
| <a id="opx-group"></a>`/opx.group` | ACL `command.opx.group` | `<job\|gang> <name>` | Lists up to 200 members, online or not, highest grade first. |
| <a id="opx-save"></a>`/opx.save` | ACL `command.opx.save` | — | Saves every loaded character now. Use before a planned restart. |

`/opx.money`, `/opx.job` and `/opx.gang` act on **loaded** characters only: a player id or citizen id that is not in the world answers the usage line.

## Server contract {#server-contract}

`local character = OPX.Api.Get('character')` on the server, from code inside opx_infinity.

An **identifier** is a `Player` table, a player id (number) or a citizen id (string). Only a citizen id can reach an offline character. Functions marked *Yields* read or write the database and must run in a coroutine (`CreateThread`). `Result` is `{ ok = true, value = ... }` or `{ ok = false, error = code, detail = ... }`.

### Players

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="server-character-getplayer"></a>`GetPlayer` | `source` | `Player\|nil` | The loaded character on that player id. Nil for a connection with no character. |
| <a id="server-character-getplayerbycitizenid"></a>`GetPlayerByCitizenId` | `citizenId` | `Player\|nil` | Loaded characters only. |
| <a id="server-character-getplayerbyuserid"></a>`GetPlayerByUserId` | `userId` | `Player\|nil` | Loaded characters only. |
| <a id="server-character-getplayers"></a>`GetPlayers` | — | `Player[]` | Every loaded character. Evicts slots whose account changed. |
| <a id="server-character-getplayercount"></a>`GetPlayerCount` | — | `integer` | Count without building a table. |
| <a id="server-character-resolveplayer"></a>`ResolvePlayer` | `identifier` | `Player\|nil` | Turns any identifier into a loaded `Player`. |
| <a id="server-character-getcharacter"></a>`GetCharacter` | `citizenId` | `Result` | Yields when offline. `value` is `{ player, offline = false }` or `{ entity, offline = true }` (the stored row). |
| <a id="server-character-placecharacter"></a>`PlaceCharacter` | `player, target?` | `ok, reason` | Yields. Kill-then-respawn placement. `target = { x, y, z, heading?, bucket? }`; omitted, the stored position, then `DEFAULT_SPAWN`, is used. |
| <a id="server-character-save"></a>`Save` | `identifier, loggedOut?` | `Result` | Yields. Writes the row now. `loggedOut = true` stamps `last_logged_out`. |
| <a id="server-character-logout"></a>`Logout` | `source` | — | Unloads the character and dispatches its save on a thread. The player stays connected, in a private bucket. |

### Money

Money types come from `MONEY.TYPES` in `config/shared.lua` (`EDDIES`, `BANK` shipped). The mutators work on **loaded characters only** and answer `ok, code` where `code` is a locale key. They do not yield; the autosave writes the change.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="server-character-addmoney"></a>`AddMoney` | `identifier, moneyType, amount, reason?` | `ok, code` | `amount` is rounded and must be positive and finite. Runs hook `money:beforeAdd`. |
| <a id="server-character-removemoney"></a>`RemoveMoney` | `identifier, moneyType, amount, reason?` | `ok, code` | Refuses (`money.insufficient`) rather than going below zero, unless the type is in `MONEY.ALLOW_NEGATIVE`. Runs `money:beforeRemove`. |
| <a id="server-character-setmoney"></a>`SetMoney` | `identifier, moneyType, amount, reason?` | `ok, code` | Sets the balance outright; the only way to reach zero. Runs `money:beforeSet`. |
| <a id="server-character-getmoney"></a>`GetMoney` | `identifier, moneyType?` | `integer\|table\|nil` | One balance, or the whole money table when `moneyType` is nil. Nil when not loaded. |
| <a id="server-character-formatmoney"></a>`FormatMoney` | `amount, moneyType?` | `string` | Grouped digits; `EDDIES` (or nil) gets ` €$`, other types their name. |
| <a id="server-character-ismoneytype"></a>`IsMoneyType` | `moneyType` | `boolean` | Whether the type exists on this server. |
| <a id="server-character-addmoneyoffline"></a>`AddMoneyOffline` | `citizenId, moneyType, amount, reason?` | `Result` `{ balance, offline }` | **Yields.** Adds money whether or not the character is being played. Online: same as `AddMoney` (`offline = false`). Offline: runs hook `money:beforeAddOffline`, writes the row directly, audits `money.addOffline` and publishes `opx:on:character:money` with `offline = true`. Errors `character.notFound`, `money.badType`, `money.badAmount`, `money.vetoed`, `error.unavailable` (row being written, or boot failed). |

Every successful change sends `opx:net:character:money` to the owner, raises the internal money event and writes an audit line.

### Metadata and identity

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="server-character-getmetadata"></a>`GetMetadata` | `identifier, key?` | `any` | One key, or the whole table. Nil when not loaded. |
| <a id="server-character-setmetadata"></a>`SetMetadata` | `identifier, key, value` | `boolean` | Loaded characters only. Sends the new PlayerData to the owner. |
| <a id="server-character-setname"></a>`SetName` | `identifier, firstName, lastName` | `Result` | Yields (saves at once). **Write-once**: refused with `character.nameSet` if a name exists. Each half is checked against `CHARACTERS.NAME`. |
| <a id="server-character-publicview"></a>`PublicView` | `player` | `table` | `{ source, citizenId, userId, firstName, lastName, money, job, gang, jobs, gangs }`: copies, no metadata. What the `GetPlayerData` export and `opx:on:character:loaded` carry. |
| <a id="server-character-setbodyfamily"></a>`SetBodyFamily` | `identifier, family` | `Result` | Yields. `family` is `'female'` or `'male'`. Write-once (`character.bodySet`); the same value again is OK. Called by the appearance module. |

### Jobs and gangs

A character can hold any number of jobs and gangs, each at one grade; one of each is **primary** (`PlayerData.job`, `PlayerData.gang`). Functions that write membership rows yield even for a loaded character. With a citizen id of an offline character, the change is written to the row.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="server-character-getjob"></a>`GetJob` | `name` | `table\|nil` | The job **definition** from `JOBS`. |
| <a id="server-character-getgang"></a>`GetGang` | `name` | `table\|nil` | The gang definition from `GANGS`. |
| <a id="server-character-setjob"></a>`SetJob` | `identifier, name, grade` | `Result` | Yields. Joins (or regrades) and makes primary. Duty resets to the job's `defaultDuty`. `value` is the job table. |
| <a id="server-character-setgang"></a>`SetGang` | `identifier, name, grade` | `Result` | Yields. Same for gangs. |
| <a id="server-character-setjobduty"></a>`SetJobDuty` | `identifier, onDuty` | `Result` | Yields only when offline. `value` is the new duty. Refused (`job.noDuty`) for a `defaultDuty` job. Toasts the owner. |
| <a id="server-character-hasjob"></a>`HasJob` | `identifier, name, onDutyOnly?, minGrade?` | `boolean` | Primary job only, loaded only. Never yields. |
| <a id="server-character-hasgang"></a>`HasGang` | `identifier, name, minGrade?` | `boolean` | Primary gang only, loaded only. |
| <a id="server-character-addplayertojob"></a>`AddPlayerToJob` | `identifier, name, grade` | `Result` | Yields. Adds a membership without changing the primary job. |
| <a id="server-character-addplayertogang"></a>`AddPlayerToGang` | `identifier, name, grade` | `Result` | Yields. |
| <a id="server-character-removeplayerfromjob"></a>`RemovePlayerFromJob` | `identifier, name` | `Result` | Yields. If it was primary, the character falls back to `PLAYER.DEFAULT_JOB`. |
| <a id="server-character-removeplayerfromgang"></a>`RemovePlayerFromGang` | `identifier, name` | `Result` | Yields. Falls back to `PLAYER.DEFAULT_GANG`. |
| <a id="server-character-setplayerprimaryjob"></a>`SetPlayerPrimaryJob` | `identifier, name` | `Result` | Yields. Refused (`job.notMember`) unless already a member. |
| <a id="server-character-setplayerprimarygang"></a>`SetPlayerPrimaryGang` | `identifier, name` | `Result` | Yields. Refused (`gang.notMember`). |
| <a id="server-character-getplayersbyjob"></a>`GetPlayersByJob` | `name, onDutyOnly?` | `Player[]` | Loaded characters whose primary job matches. |
| <a id="server-character-getplayersbygang"></a>`GetPlayersByGang` | `name` | `Player[]` | Loaded characters whose primary gang matches. |
| <a id="server-character-getgroupmembers"></a>`GetGroupMembers` | `groupType, name` | `Result` | Yields. `groupType` is `'job'` or `'gang'`. Up to 200 `{ citizenId, grade, name }`, online or not. |

### Characters and accounts

The self-service functions take the caller's `source` and act on that account only. Somebody else's character answers `character.notFound`, the same as a missing one, and the attempt is audited.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="server-character-listcharacters"></a>`ListCharacters` | `source` | `Result` | Yields. `{ characters, slots, active }`; each entry is a summary `{ citizenId, cid, firstName, lastName, gender, job, gang, lastLoggedOut }`. |
| <a id="server-character-entersession"></a>`EnterSession` | `source` | `Result` | Yields. The whole entry: loads the locked character, or creates one. Called by the runtime on connect. |
| <a id="server-character-selectcharacter"></a>`SelectCharacter` | `source, citizenId` | `Result` | Yields. Loads and enters one of the caller's characters, in the world. 1 s cooldown. `value` is the `Player`. |
| <a id="server-character-switchto"></a>`SwitchTo` | `source, citizenId` | `Result` | Yields. What `/opx.select` runs: moves the lock, then relogs or disconnects per `CHARACTERS.SWITCH`. |
| <a id="server-character-newcharacter"></a>`NewCharacter` | `source` | `Result` | Yields. What `/opx.create` runs: clears the lock and **disconnects**. `value` is `{ used, slots }`. |
| <a id="server-character-createcharacter"></a>`CreateCharacter` | `source` | `Result` | Yields. Inserts an empty character (no name, no body) on the caller's account. 3 s cooldown. Does not load it. |
| <a id="server-character-deletecharacter"></a>`DeleteCharacter` | `source, citizenId` | `Result` | Yields. Soft-deletes one of the caller's own characters. Honours `SELF_DELETE`. 3 s cooldown. |
| <a id="server-character-listcharactersfor"></a>`ListCharactersFor` | `userId` | `Result` | Yields. **Staff.** Any account's characters; summaries also carry `createdAt`. No ownership check. |
| <a id="server-character-findcharacters"></a>`FindCharacters` | `{ mode, term?, seenAt?, cursor? }` | `Result` | Yields. **Staff.** `mode = 'recent'` (last played first) or `'search'` (term of 3–48 bytes against name, account name, citizen id). 25 per page; `value` is `{ characters, mode, more, cursor, seenAt }`. |
| <a id="server-character-renamecharacter"></a>`RenameCharacter` | `citizenId, firstName, lastName, source?` | `Result` | Yields. **Staff.** Renames any character, online or offline. Same name rules as `SetName`. |
| <a id="server-character-removecharacter"></a>`RemoveCharacter` | `citizenId, source?` | `Result` | Yields. **Staff.** Soft-deletes any character. Ignores `SELF_DELETE`. |

The staff functions do no permission check of their own. Call them only after your own ACL check (the `admin` module does).

!!! danger "Deleting a character"
    A delete stamps `deleted_at` and keeps the row, but every module that owns per-character data (clothes, needs, containers, vehicles…) **really deletes** its rows, and so does every `CASCADE_TABLES` entry. There is no undo. A character being played is disconnected.

### The Player object {#player}

`GetPlayer` and friends answer a `Player`. Read `player.PlayerData`; change it through the contract or `player.Functions`, which bump `player.Revision` (what the autosave looks at) and send the update. A direct write to `PlayerData` is never sent and only saved by chance.

| `PlayerData` field | Shape |
|---|---|
| `source` | player id |
| `citizenId`, `userId`, `cid` | identity (cannot be set) and slot number |
| `charInfo` | `{ firstName?, lastName?, gender?, phone }` — names and gender are nil until set |
| `money` | `{ [MoneyType] = integer }` |
| `job` | `{ name, label, type, payment, onDuty, isBoss, bankAuth, grade = { name, level } }` |
| `gang` | `{ name, label, isBoss, bankAuth, grade = { name, level } }` |
| `jobs`, `gangs` | every membership, `{ [name] = grade }` |
| `metadata` | free-form; `health`, `armor`, `isDead`, `inLastStand` are read by the runtime |
| `position` | `{ x, y, z, heading, bucket }`, or nil for a character never placed |
| `appearance` | owned by the appearance module |

`player.Functions` carries `UpdatePlayerData`, `SetPlayerData(key, value)`, `SetMetaData`, `GetMetaData`, `SetCharInfo`, `AddMoney`, `RemoveMoney`, `SetMoney`, `GetMoney`, `SetJob`, `SetGang`, `SetJobDuty`, `Save` and `Logout`. Each calls the contract function of the same name on this player.

## Client contract {#client-contract}

`local character = OPX.Api.Get('character')` on the client, from code inside opx_infinity. These read a local mirror of the server; nothing is authoritative. Never yields.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="client-character-getplayerdata"></a>`GetPlayerData` | — | `table` | The mirrored PlayerData; `{}` before a character loads. Read only. |
| <a id="client-character-getcitizenid"></a>`GetCitizenId` | — | `string\|nil` | |
| <a id="client-character-isloggedin"></a>`IsLoggedIn` | — | `boolean` | True between loaded and unloaded. |
| <a id="client-character-isnamed"></a>`IsNamed` | — | `boolean` | Whether the loaded character has a first name. |
| <a id="client-character-getjobdata"></a>`GetJobData` | — | `table\|nil` | The primary job. |
| <a id="client-character-getgangdata"></a>`GetGangData` | — | `table\|nil` | The primary gang. |
| <a id="client-character-getjobgrade"></a>`GetJobGrade` | `name?` | `integer` | Grade level of the primary job, or `-1` when that job is not held. |
| <a id="client-character-hasjob"></a>`HasJob` | `name, onDutyOnly?, minGrade?` | `boolean` | Primary job only. |
| <a id="client-character-hasgang"></a>`HasGang` | `name, minGrade?` | `boolean` | Primary gang only. |
| <a id="client-character-getmoney"></a>`GetMoney` | `moneyType` | `integer` | `0` when unknown. |
| <a id="client-character-getmetadata"></a>`GetMetadata` | `key?` | `any` | One key, or the whole table. |
| <a id="client-character-getposition"></a>`GetPosition` | — | `{ x, y, z }\|nil` | The local player's position. |
| <a id="client-character-setname"></a>`SetName` | `firstName, lastName` | `ok, code` | Checks the name locally and sends it. The server checks again and accepts it once. |
| <a id="client-character-getplayerstate"></a>`GetPlayerState` | `playerId` | `table` | Any player in your bucket, from the [state bag](#state-bag). `{}` when unknown. Cached; do not write to it. |
| <a id="client-character-getplayername"></a>`GetPlayerName` | `playerId` | `string\|nil` | The character name, nil while unnamed. |
| <a id="client-character-getplayeridentity"></a>`GetPlayerIdentity` | `playerId` | `{ name?, username?, citizenId? }` | Three strings for a name tag. |

The client also puts each player's character name on the platform nameplate above their head.

## State bag {#state-bag}

The server writes the public part of each loaded character to that player's state bag. Any client in the same routing bucket can read it, from any resource, with `Open77.state.player(playerId)`. Inside opx_infinity, use `GetPlayerState`. Money, metadata, user id, pay and `bankAuth` are never on the bag.

| Key | Shape | Who can read |
|---|---|---|
| `citizenId` | `string` | every client in the bucket |
| `name` | `string` `"First Last"`, absent until the character is named | every client in the bucket |
| `charInfo` | `{ firstName?, lastName?, gender?, origin? }` — `origin` is always empty today | every client in the bucket |
| `job` | `{ name, label, type?, onDuty, isBoss, grade = { name, level } }` | every client in the bucket |
| `gang` | `{ name, label, onDuty, isBoss, grade = { name, level } }` | every client in the bucket |
| `username` | `string`, the platform account name | every client in the bucket |
| `life` | `{ dead, lastStand }` from `metadata.isDead` / `metadata.inLastStand` | every client in the bucket |

Keys are written only when they change, and cleared on logout or character switch.

## Hooks {#hooks}

Register with `OPX.Hooks.Register(name, fn, priority?)` on the server, inside opx_infinity. Lower priority runs first. A hook that returns exactly `false` vetoes; a hook that raises is logged and skipped.

| Hook | Payload | Can veto | When |
|---|---|---|---|
| `money:beforeAdd` | `{ player, moneyType, amount, reason }` | yes — `AddMoney` answers `false, 'money.vetoed'` | After type and amount checks, before the balance moves. `amount` is the positive delta. |
| `money:beforeRemove` | `{ player, moneyType, amount, reason }` | yes — `money.vetoed` | After the sufficiency check, before the balance moves. |
| `money:beforeSet` | `{ player, moneyType, amount, reason }` | yes — `money.vetoed` | `amount` is the new balance. |
| `paycheck:before` | `{ player, amount }` | yes — that character is not paid this cycle | Before each paycheck. The payment itself then goes through `AddMoney` and `money:beforeAdd`. |
| `money:beforeAddOffline` | `{ citizenId, moneyType, amount, reason }` | yes — `AddMoneyOffline` answers `money.vetoed` | Before an offline character's balance is written. (An online character goes through `money:beforeAdd`.) |
| `job:beforeSet` | `{ player, citizenId, offline, name, grade, previous }` | yes — `SetJob` answers `job.vetoed`, nothing is written | Before the primary job changes. `player` may be an offline Player (`offline = true`); `previous` is the current job. |
| `gang:beforeSet` | `{ player, citizenId, offline, name, grade, previous }` | yes — `gang.vetoed` | The same for `SetGang`. |
| `character:loading` | `{ citizenId, entity, data = {} }` | no — the verdict is ignored | During login, before the Player is built. A hook may yield and may fill `data`; every key in `data` is copied onto `PlayerData`. |

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-net-character-loaded"></a>`opx:net:character:loaded` | server → client | `playerData` | A character is loaded on this client. Also re-sent when a reloaded client announces. |
| <a id="opx-net-character-unloaded"></a>`opx:net:character:unloaded` | server → client | — | The character was unloaded. |
| <a id="opx-net-character-data"></a>`opx:net:character:data` | server → client | `playerData` | The whole PlayerData after any change. |
| <a id="opx-net-character-money"></a>`opx:net:character:money` | server → client | `moneyType, amount, action, balance` | `action` is `add`, `remove` or `set`. |
| <a id="opx-net-character-job"></a>`opx:net:character:job` | server → client | `job` | Primary job or duty changed. |
| <a id="opx-net-character-gang"></a>`opx:net:character:gang` | server → client | `gang` | Primary gang changed. |
| <a id="opx-net-character-announce"></a>`opx:net:character:announce` | client → server | — | "I am here." Sent at start and on world ready. The server loads or re-sends the character. 2 s cooldown. |
| <a id="opx-net-character-name"></a>`opx:net:character:name` | client → server | `{ firstName, lastName }` | The typed name. Accepted once per character. 1 s cooldown. |
| <a id="opx-net-character-heading"></a>`opx:net:character:heading` | client → server | `{ heading }` | Heading hint, sent every `HEADING_REPORT_MS` when it moved 2° or more. Position is read by the server. |
| <a id="opx-on-character-loaded"></a>`opx:on:character:loaded` | client local | `playerData` | Raised after the mirror is updated. |
| <a id="opx-on-character-unloaded"></a>`opx:on:character:unloaded` | client local | — | |
| <a id="opx-on-character-changed"></a>`opx:on:character:changed` | client local | `playerData` | After every `data` update. |
| <a id="opx-on-character-money"></a>`opx:on:character:money` | client local | `moneyType, amount, action, balance` | |
| <a id="opx-on-character-job"></a>`opx:on:character:job` | client local | `job` | |
| <a id="opx-on-character-gang"></a>`opx:on:character:gang` | client local | `gang` | |

The rows above marked *client local* are client events: only client code inside opx_infinity hears them. The **server** also raises `opx:on:character:loaded`, `unloaded`, `money`, `job` and `gang` for every server resource, with `(playerId, payload)` — see [Public server events](../creators/server-events.md#character).

Server-side, the module also raises private `opx:in:character:` events (`loaded`, `unloaded`, `money`, `job`, `gang`, `paycheck`, `deleted`) for other modules of the runtime. `job` and `gang` are now raised on removal too, not only on a set. Because server `TriggerEvent` is host-wide, these private events are visible to every server resource; do not depend on them.

## Configuration {#configuration}

`config/character.lua` sets `OPX.Config.MODULES.character`. It is a shared script, so every client receives it: put nothing secret in it.

| Key | Default | What it does |
|---|---|---|
| <a id="config-character-enabled"></a>`enabled` | `true` | Switches the module off. The runtime needs it; leave it on. |
| <a id="config-character-autosave-seconds"></a>`AUTOSAVE_SECONDS` | `300` | How often changed characters are written (floor 30). A character counts as changed after any mutation or a move of 1 m or more. |
| <a id="config-character-heading-report-ms"></a>`HEADING_REPORT_MS` | `5000` | How often the client may report its heading (floor 1000). |
| <a id="config-character-money"></a>`MONEY` | see below | Starting money and paychecks. |
| <a id="config-character-characters"></a>`CHARACTERS` | see below | Slots, switching, deletion, names. |
| <a id="config-character-player"></a>`PLAYER` | see below | New-character defaults. |
| <a id="config-character-default-spawn"></a>`DEFAULT_SPAWN` | `{ SET = true, X = -1600.137451, Y = -2340.758057, Z = 43.250328, HEADING = 139.650009 }` | Where a character with no stored position is placed. With `SET = false` it is left where the game put it. `/opx.here` prints this block. |
| <a id="config-character-jobs"></a>`JOBS` | 12 jobs | Job definitions. See [Job and gang format](#group-format). |
| <a id="config-character-gangs"></a>`GANGS` | 12 gangs (incl. `none`) | Gang definitions. |
| <a id="config-character-origins"></a>`ORIGINS` | `nomad`, `streetkid`, `corpo` | Lifepaths `{ label, description }`. **Not read by anything yet.** |

### MONEY

| Key | Default | What it does |
|---|---|---|
| `STARTING` | `{ EDDIES = 500, BANK = 5000 }` | What a **new** character gets. A type missing on an existing character loads as 0. |
| `PAYCHECK_MINUTES` | `10` | Minutes between paychecks. `0` turns them off. |
| `PAYCHECK_REQUIRES_DUTY` | `true` | Pay only characters on duty, unless their job has `offDutyPay = true`. |
| `PAYCHECK_TYPE` | `'BANK'` | Money type paid into. An unknown type falls back to `MONEY.DEFAULT` in `config/shared.lua`, with a warning at start. |

### CHARACTERS

| Key | Default | What it does |
|---|---|---|
| `SWITCH` | `'relog'` | How `/opx.select` switches: `'relog'` in the world, `'reconnect'` by disconnecting. Unknown values fall back to `'reconnect'`. |
| `DEFAULT_SLOTS` | `3` | Characters per account. |
| `SLOTS_BY_USER` | `{}` | Per-account overrides, `{ [userId] = slots }`. |
| `ROW_CEILING` | `60` | Character rows ever created per account, deleted ones included (floor 5). Keep it well above `DEFAULT_SLOTS`. |
| `CASCADE_TABLES` | `{}` | Extra `{ TABLE, COLUMN }` pairs whose rows are **hard-deleted** with a character. Only for tables the runtime does not own. |
| `SELF_DELETE` | `true` | Whether players may use `/opx.delete`. Staff deletes are not affected. |
| `NAME` | `{ MIN = 2, MAX = 32 }` | Length of each half of a name, in characters. Letters, spaces, `'` and `-`; must start with a letter. Keep `config/entry.lua` `NAME` the same. |

### PLAYER

| Key | Default | What it does |
|---|---|---|
| `STARTING_METADATA` | `{ health = HEALTH.MAX or 100, armor = 0, isDead = false, inLastStand = false }` | Metadata a new character starts with; also filled into existing characters that lack a key. |
| `DEFAULT_JOB` | `'unemployed'` | Job of a new character, and the fallback when a job is removed or no longer defined. |
| `DEFAULT_GANG` | `'none'` | The same for gangs. |

### Job and gang format {#group-format}

The table key (`ncpd`, `maelstrom`) is stored on character rows: add entries freely, **never rename one**. Grades start at `0` and must be contiguous.

```lua
JOBS = {
	ncpd = {
		label = 'NCPD',
		type = 'leo',          -- free-form category
		defaultDuty = false,   -- true: always on duty, /opx.duty refused
		offDutyPay = true,     -- paid even when off duty
		grades = {
			[0] = { name = 'Cadet', payment = 150 },
			[3] = ...,         -- every level from 0 up must exist
			-- { name, payment, isBoss = true, bankAuth = true }
		},
	},
},
GANGS = {
	maelstrom = {
		label = 'Maelstrom',
		grades = { [0] = { name = 'Chromehead' }, [3] = { name = 'Warlord', isBoss = true, bankAuth = true } },
	},
},
```

| Field | Jobs | Gangs | Meaning |
|---|---|---|---|
| `label` | yes | yes | Display name. |
| `type` | yes | — | Category, copied to `PlayerData.job.type`. |
| `defaultDuty` | yes | — | On duty from the start; no shift to clock into. |
| `offDutyPay` | yes | — | Paid while off duty even when `PAYCHECK_REQUIRES_DUTY` is true. |
| `grades[n].name` | yes | yes | Grade name. |
| `grades[n].payment` | yes | — | Paycheck amount. |
| `grades[n].isBoss` | yes | yes | Copied to `PlayerData.job/gang.isBoss`. |
| `grades[n].bankAuth` | yes | yes | Copied to `bankAuth`. Not on the state bag. |

`unemployed` (`defaultDuty = true`, 25 per paycheck) and the gang `none` must stay: they are the defaults.

## Data {#data}

Tables are created with `CREATE TABLE IF NOT EXISTS`. There are no migrations.

| Table | Holds |
|---|---|
| `opx77_users` | One row per account: `user_id`, `display_name`, `created_at`, `last_seen_at`. |
| `opx77_characters` | One row per character: `citizen_id`, `user_id`, `cid`, `name`, JSON `char_info`, `money`, `job`, `gang`, `position`, `metadata`, `appearance`, `last_logged_out`, `created_at`, `updated_at`, `deleted_at` (soft delete). |
| `opx77_character_groups` | Job and gang memberships: `citizen_id`, `group_type`, `group_name`, `grade`, `joined_at`. |
| `opx77_active_characters` | The lock: which character each account enters on. |

!!! warning "Existing databases miss one index"
    `idx_opx77_characters_seen` is only created on a fresh install. On an existing `opx77_characters`, run once:
    `ALTER TABLE opx77_characters ADD KEY idx_opx77_characters_seen (deleted_at, last_logged_out, citizen_id);`
    Without it the staff "recent characters" view scans the whole table.

## Refusal codes {#codes}

The code is also the locale key shown to the player.

| Code | Meaning |
|---|---|
| `entry.noIdentity` | The connection has no verified session. |
| `entry.failed` | The player could not be brought into the world. |
| `error.notLoggedIn` | No character is loaded for that identifier. |
| `error.tooFast` | Cooldown. |
| `error.unavailable` | Database failure or the runtime booted degraded. Detail in the server log. |
| `error.badRequest` | Malformed argument. |
| `character.notFound` | No such character — or it belongs to another account. |
| `character.inUse` | Loaded on another connection. |
| `character.alreadyPlaying` | `/opx.select` on the character you are playing. |
| `character.limit` | Every slot is used. |
| `character.rowLimit` | The account reached `ROW_CEILING`. |
| `character.deleteNotAllowed` | `SELF_DELETE` is false. |
| `character.badName` | A name half fails length or alphabet. |
| `character.nameSet` | The character is already named. |
| `character.badBody` / `character.bodySet` | Not `female`/`male`; body already set. |
| `character.searchShort` | Search term under 3 bytes. |
| `money.badType` / `money.badAmount` | Unknown type; zero, negative, NaN or infinite amount. |
| `money.insufficient` | Removal would go below zero. |
| `money.negative` | `SetMoney` below zero on a type that does not allow it. |
| `money.vetoed` | A hook refused it. |
| `money.offline` | The character is not loaded. Use `AddMoneyOffline` to credit an offline character. |
| `job.vetoed` / `gang.vetoed` | A `job:beforeSet` / `gang:beforeSet` hook refused the change. |

Other resources reach `SetJob`, `SetGang`, `RemovePlayerFromJob`, `RemovePlayerFromGang` and `SetJobDuty` through the `SetJob`, `SetGang`, `RemoveJob`, `RemoveGang` and `SetDuty` [server exports](../creators/server-exports.md#jobs), and their own metadata keys (`ext.<resource>.<key>`) through `GetMetadata`/`SetMetadata`.
| `job.notFound` / `job.gradeNotFound` | Unknown job or grade. |
| `job.noDuty` | The job has `defaultDuty = true`. |
| `job.notMember` | Not a member of that job. |
| `gang.notFound` / `gang.gradeNotFound` / `gang.notMember` | Same for gangs. |
