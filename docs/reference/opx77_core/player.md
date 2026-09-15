---
title: Player
description: The Player object in opx77_core — how to get one, the difference between an online and an offline Player, every field of PlayerData with who writes it and whether it persists, and each of the fourteen Player.Functions methods with its errors and whether it yields.
---

# Player

A **Player** is one loaded character, held in memory by `opx77_core`. It is the
handle almost every server-side operation starts from, and it is what
`OPX.Players` is a table of.

```lua
local player = OPX.GetPlayer(source)
if not player then return end                 -- still choosing a character, or gone

local name = player.PlayerData.charInfo.firstName
local ok, why = player.Functions.AddMoney("EDDIES", 500, "gig payout")
```

!!! info "This surface is reachable from inside `opx77_core` only"

    `OPX` is a global in the core's own Lua state, so a second server resource
    cannot reach a Player at all — it would call a `nil` global and its own
    `pcall` would swallow the raise. The core's
    [server exports](exports/server.md) answer who a player is, but hand out no
    Player. A server-side plug-in is a **file added to
    `opx77_core/server/`**. Read
    [Writing a server plugin](../../guides/writing-a-server-plugin.md) before
    anything on this page, and
    [Integration channels](../../concepts/integration-channels.md) for the
    channels that remain if you cannot add a file.

    A client resource does not use this object. It uses
    [the client exports](exports/client.md), which serve a read-only mirror.

## Getting one {#getting}

| You have | Call |
|---|---|
| a [`Source`](types.md#source) | [`OPX.GetPlayer(source)`](server-api.md#getplayer) |
| a [`CitizenId`](types.md#citizenid) | [`OPX.GetPlayerByCitizenId(citizenId)`](server-api.md#getplayerbycitizenid) |
| a [`UserId`](types.md#userid) | [`OPX.GetPlayerByUserId(userId)`](server-api.md#getplayerbyuserid) |
| nothing, and you want everyone | [`OPX.GetPlayers()`](server-api.md#getplayers) |
| a citizen id and they may be offline | [`OPX.GetCharacter(citizenId)`](server-api.md#getcharacter) — yields |

All four getters answer `nil` rather than raising when nobody is there, and
`nil` is not an error condition. Somebody sitting in the character-selection
screen has a [`Session`](types.md#session) and no Player, and a caller that
treats that as a failure refuses legitimate joins.

## The object {#object}

**Fields**

- PlayerData: [`PlayerData`](#playerdata)
    - Everything about the character. Mirrored to the owning client in full.
- Functions: [`PlayerFunctions`](#functions)
    - The mutators, bound to this player.
- Offline: `boolean`
    - `true` for a temporary Player built around a character who is not in the
      world. See [Offline players](#offline).
- Revision: `integer`
    - The autosave's dirty counter, bumped by every
      [`UpdatePlayerData`](#updateplayerdata) and never reset.
- MaySample: `boolean`
    - Whether the position sampler is allowed to overwrite
      `PlayerData.position`. False until a placement has succeeded.

`Revision` and `MaySample` live on the Player rather than on `PlayerData`
deliberately: that keeps them out of the client payload and out of every
database column. Both are declared on the `Player` class in `std/types.lua`;
see [Types](types.md#player).

### Revision, and why a direct write is invisible {#revision}

`Revision` moves in exactly one place: `Functions.UpdatePlayerData`. Every
mutator on this page calls it. The autosave compares the counter against the
value at the last successful write, and skips a character whose row would come
out identical.

```lua
-- WRONG: the balance changes, and nothing else does.
player.PlayerData.money.EDDIES = player.PlayerData.money.EDDIES + 500
```

That assignment moves money without touching the counter. No hook sees it, no
audit line is written, the client's mirror still shows the old number, and the
autosave will not write the row — so the change is gone at the next restart.
Use [`Functions.AddMoney`](#addmoney).

If you must assign into `PlayerData` directly — a field with no mutator, say —
call [`Functions.UpdatePlayerData()`](#updateplayerdata) yourself afterwards.

### MaySample, and the frozen position {#maysample}

`MaySample` is false when a Player is created and is set true by exactly one
function: [`OPX.PlaceCharacter`](server-api.md#placecharacter), once the world
agrees with the stored row. While it is false,
[`OPX.SamplePosition`](server-api.md#sampleposition) refuses to read a
coordinate, and `PlayerData.position` keeps whatever the database gave it.

That is deliberate. A character whose placement failed is standing wherever the
engine dropped them, and sampling that would overwrite the very position
placement was trying to restore. The cost is that a placement failure freezes
the stored position until the next successful one — which the core says out
loud in the log, because from every other angle it is invisible.

`OPX.ForgetSession` clears it back to false before an eviction save, so a
recycled slot cannot write the new occupant's coordinates onto the departed
character's row.

## Offline players {#offline}

The job and gang functions accept a character who is not in the world. When they
get one they load the row, build a Player around it with `Offline = true`, apply
the change and write the single affected column back.

An offline Player:

- has the same `Functions`;
- sends **nothing** to any client — `UpdatePlayerData` returns early, and no
  `JOB_UPDATE` or `MONEY_CHANGE` goes out;
- has `PlayerData.source` of `nil`;
- is **refused by every money mutator** with `money.offline`.

!!! danger "Money is never moved on an offline character"

    Nothing writes a money column for a Player that is not in the roster, so a
    credit applied to an offline Player would be announced, audited, and then
    lost at the end of the operation. The three mutators refuse rather than
    pretend. To pay somebody who is not connected, write the intent somewhere
    durable and settle it at their next login.

You do not construct an offline Player yourself. The group functions do it
internally, and [`OPX.GetCharacter`](server-api.md#getcharacter) hands back a
plain stored entity — not a Player — with `offline = true` beside it.

## PlayerData {#playerdata}

The whole character, as one table. The type of every field is in
[Types](types.md#playerdata); the table below is the other half of the story —
**who writes it, whether it persists, and what happens if you assign into it.**

!!! danger "Every field here is mirrored to the client that owns the character"

    `PlayerData` is sent verbatim on login and again on every change. Nothing
    secret may be put in it: not a staff flag another resource trusts, not an
    internal balance, not a moderation note. A plug-in that needs private
    per-character state keys its own table on the
    [`CitizenId`](types.md#citizenid) instead.

| Field | Column | Written by | Notes |
|---|---|---|---|
| `source` | — | login | `nil` offline. Recycled; never key anything durable on it. |
| `userId` | `user_id` | insert only | Identity. `Save` deliberately excludes it from the `SET` list. |
| `citizenId` | `citizen_id` | insert only | Identity, and the primary key. |
| `cid` | `cid` | insert only | Slot number within the account, reused after a delete. |
| `name` | `name` | every save | The **account** display name at the last login. |
| `charInfo` | `char_info` | [`SetCharInfo`](#setcharinfo) | JSON column. |
| `money` | `money` | the three money mutators | JSON column. Whole units only. |
| `job` | `job` | [`SetJob`](#setjob), `SetJobDuty`, `RemovePlayerFromJob` | The **primary** job, flattened. |
| `gang` | `gang` | [`SetGang`](#setgang), `RemovePlayerFromGang` | |
| `jobs` | *(none)* | `AddPlayerToJob`, `RemovePlayerFromJob` | A mirror of `opx77_character_groups`. **Not saved with the character** — that table is the authority. |
| `gangs` | *(none)* | `AddPlayerToGang`, `RemovePlayerFromGang` | Same. |
| `position` | `position` | the 1 Hz sampler | Only while [`MaySample`](#maysample) is true. `nil` means *never known*, not *at the origin*. |
| `metadata` | `metadata` | [`SetMetaData`](#setmetadata) | JSON column, free-form, survives a core upgrade. |
| `appearance` | `appearance` | [`OPX.SaveAppearance`](server-api.md#saveappearance) | The stored face, `nil` until one is captured. Written the moment it is saved, and again from memory by every save. |
| `clothing` | `opx77_character_clothing.clothing` | [`OPX.SaveClothing`](server-api.md#saveclothing) | The record, `false` when none is stored, `nil` when it could not be read at login. Its own table: **not written by a save**, only when it changes. |
| `lastLoggedOut` | `last_logged_out` | a save with `loggedOut` true | Read back from the row; the core never sets it in memory. |
| `reportedHeading` | *(none)* | the client's position report | **Not persisted.** A hint the sampler folds into `position.heading`. |

Three consequences worth stating plainly:

- **`jobs` and `gangs` are a mirror.** `Players.save` does not write them. A
  membership change is a row in `opx77_character_groups`, written by
  [`joinGroup`](server-api.md#addplayertojob) before `PlayerData` is touched. If
  the two ever disagree, the table is right.
- **`citizen_id` and `user_id` are not in the `UPDATE`.** An update that could
  move a character to another account is how characters get stolen, so the
  statement cannot express it.
- **`position` is server-derived.** `x`, `y` and `z` always come from
  `Open77.players.position`. The client supplies only `heading`, and it is a
  hint, never proof.

## Player.Functions {#functions}

Fourteen methods. Each is the module-level `OPX.*` mutator with the player
already supplied — the same code, so a rule added to one is a rule both obey.
Reach for `Functions` when you already hold a Player, and for the
[module-level form](server-api.md) when you hold a source or a citizen id.

**Three of the fourteen yield** — [`Save`](#save), [`SetJob`](#setjob) and
[`SetGang`](#setgang), which go through the database. Everything else is
in-memory and callable from an event handler with no thread. Each entry says
which.

### UpdatePlayerData {#updateplayerdata}

Pushes the whole of `PlayerData` to the client that owns it and bumps
`Revision`; does nothing to the client for an offline Player, though the counter
still moves.

```lua
player.Functions.UpdatePlayerData()
```

**Returns** nothing.

**Side** `server` — inside `opx77_core` only. Does not yield.

Every mutator below calls this for you. Call it yourself only after assigning
into `PlayerData` directly, which is the one case nothing else covers.

The counter is bumped **before** the offline check, because promoting an offline
character is a change too, and the write that follows must not be skipped.

### SetPlayerData {#setplayerdata}

Sets one top-level field of `PlayerData` and announces it; **raises** for
`citizenId`, `userId` and `source`.

!!! warning "Three keys raise rather than refuse"

    `SetPlayerData("citizenId", …)`, `("userId", …)` and `("source", …)` call
    `error()` with a level-2 traceback pointing at your call site. Identity is
    not data — assigning it is how a character ends up owned by the wrong
    account — and a silent refusal would leave a caller believing it had worked.
    This is the only function on the page that raises.

```lua
player.Functions.SetPlayerData(key, value)
```

- key: `string`
    - Any top-level field of [`PlayerData`](#playerdata) except the three above.
- value: `any`

**Returns** nothing.

**Errors**

| Code | Meaning |
|---|---|
| *(raises)* | `key` is `citizenId`, `userId` or `source`. Not a `Result` — a Lua error. |

**Side** `server` — inside `opx77_core` only. Does not yield.

Prefer the specific mutator where one exists: this one performs no validation of
the value, and setting `money` or `job` through it bypasses the hooks, the audit
log and the wire events those fields have.

### SetMetaData {#setmetadata}

Sets one metadata key and announces the change; accepts any key, including one
the core has never heard of.

```lua
player.Functions.SetMetaData(key, value)
```

- key: `string`
- value: `any`
    - Anything JSON can carry. `metadata` is one JSON column, so a key a plug-in
      invents survives every save and every core upgrade.

**Returns** nothing.

**Side** `server` — inside `opx77_core` only. Does not yield.

This is the supported way for a plug-in to keep per-character state. Write
through it rather than into the table: it goes through
[`UpdatePlayerData`](#updateplayerdata), and the autosave has to be able to see
the change.

Reserved names the core itself reads are `health`, `armor`, `isDead` and
`inLastStand` — and only those four. The gameplay needs are not metadata any
more: `hunger`, `thirst`, `stamina` and `streetCred` belong to
[`opx77_status`](../opx77_status/index.md), in its own table, and `ram` was
removed outright. See [`PlayerMetadata`](types.md#playermetadata).

### GetMetaData {#getmetadata}

Returns one metadata value, or the whole metadata table when called with no
argument; returns `nil` for a key nothing has ever written.

```lua
player.Functions.GetMetaData(key)
```

- key?: `string`
    - Omitted returns the live `metadata` table itself, not a copy.

**Returns** `any` — the value, the whole table, or `nil`.

**Side** `server` — inside `opx77_core` only. Does not yield.

!!! warning "The no-argument form hands back the live table"

    Mutating what it returns changes the character's metadata without bumping
    `Revision` and without telling the client. Read from it; write through
    [`SetMetaData`](#setmetadata).

### SetCharInfo {#setcharinfo}

Sets one field of `charInfo` and announces the change; performs no validation.

```lua
player.Functions.SetCharInfo(key, value)
```

- key: `string`
    - A field of [`CharInfo`](types.md#charinfo).
- value: `any`

**Returns** nothing.

**Side** `server` — inside `opx77_core` only. Does not yield.

Names set through here do **not** pass
[`OPX.ValidateName`](server-api.md#validatename) — only character creation does.
Validate before calling if the value came from a player.

### AddMoney {#addmoney}

Adds a positive whole amount to one balance and announces it to all four
audiences; returns `false` and a reason for a bad type, a bad amount, an offline
character or a hook veto.

```lua
local ok, why = player.Functions.AddMoney(moneyType, amount, reason)
```

- moneyType: [`MoneyType`](types.md#moneytype)
- amount: `number`
    - Rounded to a whole unit. Must end up **strictly positive**: zero is
      refused, because a zero here is a caller's arithmetic having gone wrong.
- reason?: `string`
    - Free-form, for the audit log and the internal event. Not shown to the
      player. The convention is `"system:detail"` — `"paycheck:ncpd"`,
      `"heist:payout"`.

**Returns** `boolean, string?` — `true` on success; `false` and a locale key
otherwise.

**Errors**

| Code | Meaning |
|---|---|
| `error.notLoggedIn` | The Player could not be resolved. |
| `money.offline` | The Player is offline. Nothing writes a money column for one. |
| `money.badType` | Not a key of `OPX.Config.SHARED.MONEY.TYPES`. Also logged at error level. |
| `money.badAmount` | Not finite, or not strictly positive after rounding. Writes a security audit line. |
| `money.vetoed` | A `money:beforeAdd` hook returned `false`. |

**Side** `server` — inside `opx77_core` only. Does not yield — **and neither may
your hook**, because it runs inside this call.

On success the core tells four audiences: the owning client
(`opx77:client:onMoneyChange`), the core's own files
(`opx77:player:moneyChange`), the audit log (`money.add`), and `PlayerData`
itself. A direct assignment into `PlayerData.money` reaches none of them.

`NaN` is the case worth naming: it arrives over JSON, passes every comparison,
and once it is in a balance so does the check that would stop the player
spending it. `amountOf` refuses it before anything else happens.

### RemoveMoney {#removemoney}

Takes a positive whole amount off one balance, refusing outright rather than
truncating when there is not enough; returns `false` and a reason on every
refusal.

```lua
local ok, why = player.Functions.RemoveMoney(moneyType, amount, reason)
```

- moneyType: [`MoneyType`](types.md#moneytype)
- amount: `number`
    - Rounded, and must be strictly positive.
- reason?: `string`

**Returns** `boolean, string?`

**Errors**

| Code | Meaning |
|---|---|
| `error.notLoggedIn` | The Player could not be resolved. |
| `money.offline` | The Player is offline. |
| `money.badType` | Not a configured money type. |
| `money.badAmount` | Not finite, or not strictly positive after rounding. |
| `money.insufficient` | The balance would go below zero and this type is not in `MONEY.ALLOW_NEGATIVE`. |
| `money.vetoed` | A `money:beforeRemove` hook returned `false`. |

**Side** `server` — inside `opx77_core` only. Does not yield.

A purchase that half-succeeds is worse than one that fails, so there is no
partial removal: check the return, and do not hand over the goods until it is
`true`. `BANK` is the one type shipped in `ALLOW_NEGATIVE` — an overdraft is a
feature; carried cash going negative never is.

The insufficiency check runs **before** the hook, so a `money:beforeRemove` hook
never sees a removal that was going to fail anyway.

### SetMoney {#setmoney}

Sets a balance outright, allowing zero; returns `false` and a reason for a bad
type, a non-finite amount, an illegal negative or a hook veto.

!!! warning "This overwrites rather than adjusts"

    Two plug-ins computing a new balance from a value they read a moment ago
    will silently clobber each other. Use [`AddMoney`](#addmoney) or
    [`RemoveMoney`](#removemoney) for anything that is really a delta; reach for
    this only when the new balance is the thing you actually know — an admin
    correction, or emptying an account.

```lua
local ok, why = player.Functions.SetMoney(moneyType, amount, reason)
```

- moneyType: [`MoneyType`](types.md#moneytype)
- amount: `number`
    - Rounded. **Zero is allowed here and nowhere else**: it is the only way to
      empty an account.
- reason?: `string`

**Returns** `boolean, string?`

**Errors**

| Code | Meaning |
|---|---|
| `error.notLoggedIn` | The Player could not be resolved. |
| `money.offline` | The Player is offline. |
| `money.badType` | Not a configured money type. |
| `money.badAmount` | Not a finite number. |
| `money.negative` | Below zero and this type is not in `MONEY.ALLOW_NEGATIVE`. |
| `money.vetoed` | A `money:beforeSet` hook returned `false`. |

**Side** `server` — inside `opx77_core` only. Does not yield.

`payload.amount` on the `money:beforeSet` hook is the **resulting balance**, not
a delta. A hook shared with the other two points must branch on the hook name.

Unlike the other two, this one does not write a security audit line for a bad
amount — it simply refuses.

### GetMoney {#getmoney}

Returns one balance, or the whole money table when called with no argument;
returns `nil` for a money type this server does not have.

```lua
local balance = player.Functions.GetMoney(moneyType)
```

- moneyType?: [`MoneyType`](types.md#moneytype)
    - Omitted returns the live `money` table itself, not a copy.

**Returns** `integer|table` — the balance, or the whole table.

**Side** `server` — inside `opx77_core` only. Does not yield.

!!! warning "The no-argument form hands back the live table"

    Assigning into it moves money with no hook, no audit line, no client update
    and no dirty flag. Read from it; write through the three mutators.

### SetJob {#setjob}

Makes a job the character's primary job at a given grade, joining it if they
were not already a member; returns a `Result` that fails for an unknown job, an
unknown grade or a failed database write.

```lua
local outcome = player.Functions.SetJob(name, grade)
```

- name: `string`
    - A key of `OPX.Jobs`, from [`data/jobs.lua`](data.md).
- grade: `integer`
    - `nil` and anything unparseable become `0`.

**Returns** [`Result`](types.md#result) — ok value is the new
[`PlayerJob`](types.md#playerjob).

**Errors**

| Code | Meaning |
|---|---|
| `job.notFound` | No job of that name in `data/jobs.lua`. |
| `job.gradeNotFound` | The job exists; that grade does not. |
| `query-failed` | The membership row could not be written. `detail` carries the database exception. |
| `no-database` | The bridge is unavailable. |

**Side** `server` — inside `opx77_core` only. **Yields**: it writes a membership
row. Call it from inside a `CreateThread`.

Duty comes from the job's `defaultDuty`, not from whatever the character was on
a moment ago — a promotion does not clock you in. The membership row is written
**before** `PlayerData` is touched, so a failed write leaves the character on
the job they had.

### SetGang {#setgang}

Makes a gang the character's primary gang at a given grade, joining it if
needed; returns a `Result` that fails for an unknown gang, an unknown grade or a
failed database write.

```lua
local outcome = player.Functions.SetGang(name, grade)
```

- name: `string`
    - A key of `OPX.Gangs`.
- grade: `integer`

**Returns** [`Result`](types.md#result) — ok value is the new
[`PlayerGang`](types.md#playergang).

**Errors**

| Code | Meaning |
|---|---|
| `gang.notFound` | No gang of that name in `data/gangs.lua`. |
| `gang.gradeNotFound` | The gang exists; that grade does not. |
| `query-failed` | The membership row could not be written. |
| `no-database` | The bridge is unavailable. |

**Side** `server` — inside `opx77_core` only. **Yields.**

### SetJobDuty {#setjobduty}

Clocks the character in or out of their primary job and tells them so; refuses a
job whose `defaultDuty` is true.

```lua
local outcome = player.Functions.SetJobDuty(onDuty)
```

- onDuty: `boolean`
    - Compared with `== true`, so any other value clocks them out.

**Returns** [`Result`](types.md#result) — ok value is the resulting `onDuty`
boolean.

**Errors**

| Code | Meaning |
|---|---|
| `job.notFound` | Their primary job is no longer in `data/jobs.lua`. |
| `job.noDuty` | The job's `defaultDuty` is true — it has no shift to clock into. |

**Side** `server` — inside `opx77_core` only. Does not yield: the change is
made in memory and reaches the `job` column with the next save. The
module-level [`OPX.SetJobDuty`](server-api.md#setjobduty) given a citizen id
for a character who is not in the world is the form that yields.

An online character is also sent a `job.onDuty` / `job.offDuty` notification,
so a caller does not have to send one itself.

`onDuty` is **not** a durable membership. It lives on
[`PlayerData.job`](types.md#playerjob), it is written to the `job` JSON column
by the next save, and it is reset from the job definition's `defaultDuty` the
next time [`SetJob`](#setjob) runs.

### Save {#save}

Samples the position and writes the character's row back; returns a `Result`
that fails when the database refuses the write.

```lua
local outcome = player.Functions.Save()
```

**Returns** [`Result`](types.md#result) — ok value is the number of rows
affected.

**Errors**

| Code | Meaning |
|---|---|
| `error.notLoggedIn` | The Player could not be resolved. |
| `query-failed` | The `UPDATE` raised. `detail` carries the exception; the failure is also logged at error level. |
| `no-database` | `MySQL.update.await` is unavailable. |

**Side** `server` — inside `opx77_core` only. **Yields.** Call it inside a
`CreateThread`.

You rarely need this. The autosave writes every character whose row would come
out different every `AUTOSAVE_SECONDS`, and a logout saves unconditionally. Call
it explicitly only when you are about to do something a crash must not undo.

The position is sampled first, and only if [`MaySample`](#maysample) is true.
`Functions.Save()` never stamps `last_logged_out` — that is the module-level
[`OPX.Save(identifier, true)`](server-api.md#save), which only the logout paths
use.

### Logout {#logout}

Takes the character out of the world, announces it, and dispatches a save on its
own thread; does nothing for a Player that is not in the roster.

!!! danger "The save is dispatched, not awaited"

    `Logout` returns as soon as the roster entry is gone. The write is on
    another thread and may not have committed. A caller that reads the row
    straight afterwards — a character **switch** is exactly this — will get
    pre-save values and then overwrite them. Use
    [`OPX.LogoutAndWait(source)`](server-api.md#logoutandwait) instead, which is
    what `OPX.SelectCharacter` does.

```lua
player.Functions.Logout()
```

**Returns** nothing.

**Side** `server` — inside `opx77_core` only. Does not yield; the save it starts
does.

Idempotent: a second call finds nothing in the roster and returns. The
character leaves the roster **before** the save runs, so a lookup during the
write correctly answers "not here" rather than handing out a Player nobody
holds. A player still connected is moved back into their own selection bucket;
see [`OPX.Logout`](server-api.md#logout).

## A worked example {#example}

A plug-in file that pays an on-duty officer a bounty, correctly.

```lua
-- opx77_core/server/bounties.lua
-- listed in opx77_core/open77.lua below server/player.lua
local BOUNTY = 750

RegisterCommand("bounty.claim", function(source)
  local player = OPX.GetPlayer(source)
  if not player then
    -- not an error: they may still be choosing a character
    return OPX.Refuse(source, "error.notLoggedIn")
  end

  local job = player.PlayerData.job
  if job.name ~= "ncpd" or not job.onDuty then
    return OPX.Refuse(source, "error.noPermission")
  end

  -- seconds since the epoch, NOT OPX.Now(): this value goes into the metadata
  -- column, so it has to still mean something after a restart
  local claimed = player.Functions.GetMetaData("bountyClaimedAt")
  if claimed and Open77.time.unix() - claimed < 600 then
    return OPX.Refuse(source, "error.tooFast")
  end

  local ok, why = player.Functions.AddMoney("EDDIES", BOUNTY, "bounty:claim")
  if not ok then
    Open77.log.warn(("[bounties] refused for %s: %s")
      :format(player.PlayerData.citizenId, why))
    return OPX.Refuse(source, why)
  end

  -- through SetMetaData, so the autosave carries it
  player.Functions.SetMetaData("bountyClaimedAt", Open77.time.unix())
  OPX.NotifyLocale(source, "money.added",
    { amount = BOUNTY, type = "EDDIES" }, "success")
end, false)
```

Five things that example is doing on purpose: it treats a missing Player as a
normal condition, it checks the return of `AddMoney` and hands the refusal code
straight to `OPX.Refuse`, it writes its own state through `SetMetaData` so the
autosave can see it, it stamps that state with `Open77.time.unix()` rather than
`OPX.Now()`, and it logs through `Open77.log` with its own bracketed scope in
the message.

That fourth point is the one that bites. `OPX.Now()` counts from process start,
so a cooldown written with it into a column that **survives a restart** is
meaningless afterwards — every stored value is suddenly in the future, and the
cooldown either never expires or expires instantly depending on the sign.
`OPX.Now()` is for intervals inside one process; the wall clock is for anything
persisted. Earlier revisions of this page used `OPX.Now()` here and called it
good practice. There is no `OPX.Log`
any more; see [Logging](server-api.md#logging).

## Where to go next {#next}

- [Server API](server-api.md) — the module-level form of every mutator here,
  plus the roster, storage, logging and utility surfaces.
- [Hooks](hooks.md) — how to veto a money movement without editing
  `server/player.lua`.
- [Types](types.md#playerdata) — the shape of every field.
- [Events](events.md) — what the core emits when these methods succeed.
- [Persistence](../../concepts/persistence.md) — what a save actually writes.
