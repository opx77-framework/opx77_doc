---
title: Server API
description: Every OPX.* function available on the server in opx77_core — the roster, sessions, money, metadata, jobs, gangs, characters, notifications, cooldowns, storage, logging, tunables and the shared utilities — with each one's error codes, whether it yields, and the side it can be called from.
---

# Server API

`OPX` is a single global in `opx77_core`'s server Lua state, and everything the
framework does server-side hangs off it. This page is the complete list.

!!! danger "None of this is reachable from another resource"

    The OPEN//77 server runtime installs no `exports`, no
    `GetInvokingResource` and no cross-resource event bus. A second server
    resource calling `OPX.GetPlayer` calls a `nil` global, and its own `pcall`
    swallows the raise — you get silence, not an error.

    **A server-side OPX//77 plug-in is a Lua file added to
    `opx77_core/server/`, plus one `server_script` line in
    `opx77_core/open77.lua`.** That file runs in the same Lua state, so `OPX` is
    simply in scope, the call is synchronous, and no codec sits between you and
    it. Read
    [Writing a server plugin](../../guides/writing-a-server-plugin.md) before
    using anything here, and
    [Integration channels](../../concepts/integration-channels.md) if adding a
    file is not an option for you.

    A **client** resource uses [the client exports](exports/client.md) instead.
    They are a different, smaller, asynchronous surface.

## How to read an entry {#how-to-read}

**Side** appears on every entry, because "can I call this from here" has three
answers on this platform rather than two: a *client export* (any resource,
asynchronous, serialising), an *in-core server* call (only a file inside
`opx77_core`), and a *net event* (any resource holding `network.events`).
Everything on this page is the second kind.

**Yielding is stated on every entry, and it matters.** `server/functions.lua`
opens by promising that none of its getters yield, which is what makes them
callable straight from an event handler with no `CreateThread`. Anything that
touches the database does yield, and calling it outside a coroutine raises
`attempt to yield from outside a coroutine` — the failure is loud, but it lands
one frame away from the mistake.

**Errors** are one of two conventions:

- a [`Result`](types.md#result) — branch on `.ok`, read `.error` for the stable
  code and `.value` for the answer;
- `boolean, string?` — the money mutators only, where a caller almost always
  wants `if not ok then` and nothing else.

Error codes double as locale keys. `OPX.Refuse(source, outcome.error)` works
because `locales/en.lua` carries an entry for each one.

## Roster and sessions {#roster}

A **session** is a connected machine. A **player** is a loaded character. They
are different things with different lifetimes: somebody sitting in the
character-selection screen has a [`Session`](types.md#session) and no
[`Player`](types.md#player), and treating that as a failure refuses legitimate
joins. See [Identity](../../concepts/identity.md#session-vs-player).

### OPX.Players {#players}

The roster: player id to [`Player`](types.md#player), holding only those with a
character loaded.

```lua
OPX.Players[source]
```

**Side** `server` — inside `opx77_core` only.

!!! warning "Iterate [`OPX.GetPlayers()`](#getplayers), not this table"

    A slot in `OPX.Players` can outlive its occupant: the platform does not
    always tell the core about a departure, and a player id is recycled
    immediately. `pairs(OPX.Players)` will hand you a `Player` belonging to
    somebody who left. `OPX.GetPlayers` re-checks the account behind every entry
    and evicts the stale ones.

    The one place the core does iterate it directly is the 1 Hz position
    sampler, deliberately: `OPX.GetPlayers` evicts, an eviction saves, and a
    database write inside a 1 Hz loop is not acceptable. Nothing is lost, because
    [`OPX.SamplePosition`](#sampleposition) re-checks the slot itself.

### OPX.Sessions {#sessions}

Everyone connected, character or not: player id to
[`Session`](types.md#session).

```lua
OPX.Sessions[source]
```

**Side** `server` — inside `opx77_core` only.

Read it through [`OPX.EnsureSession`](#ensuresession) rather than directly. That
is the function that notices a slot has changed hands, and going round it is how
one account's action is attributed to another.

### OPX.PlayerRegistry {#playerregistry}

Two reverse indexes into the roster, so the getters resolve in constant time.

```lua
OPX.PlayerRegistry.byCitizenId[citizenId] --> Source|nil
OPX.PlayerRegistry.byUserId[userId]       --> Source|nil
```

**Side** `server` — inside `opx77_core` only.

Maintained by [`OPX.RegisterPlayer`](#registerplayer) and
[`OPX.UnregisterPlayer`](#unregisterplayer) and by nothing else. Treat it as
read-only: writing into it puts the roster and its indexes out of step, and the
disagreement surfaces much later as a character nobody can find.

### OPX.GetPlayer {#getplayer}

Returns the loaded character at a player id, or `nil` when there is none — which
includes somebody still choosing one, and is not an error.

```lua
local player = OPX.GetPlayer(source)
```

- source: [`Source`](types.md#source)`|string`
    - Anything `tonumber` accepts.

**Returns** [`Player`](types.md#player)`|nil`

**Side** `server` — inside `opx77_core` only. Does not yield.

#### Example {#getplayer-example}

```lua
-- a file added to opx77_core/server/, listed in open77.lua
RegisterCommand("whereami", function(source)
  local player = OPX.GetPlayer(source)
  if not player then return OPX.Refuse(source, "error.notLoggedIn") end
  OPX.Notify(source, tostring(player.PlayerData.position and "known" or "nowhere yet"))
end, false)
```

### OPX.GetPlayerByCitizenId {#getplayerbycitizenid}

Returns the loaded character carrying a citizen id, or `nil` when that character
is not in the world.

```lua
local player = OPX.GetPlayerByCitizenId(citizenId)
```

- citizenId: [`CitizenId`](types.md#citizenid)
    - Grouped form, `"H7K-M4X3"`. Not parsed or normalised here — pass what
      [`OPX.CitizenId.parse`](#citizenidparse) gave you.

**Returns** [`Player`](types.md#player)`|nil`

**Side** `server` — inside `opx77_core` only. Does not yield.

`nil` means "not online", not "no such character". For a character who may be
offline, use [`OPX.GetCharacter`](#getcharacter).

### OPX.GetPlayerByUserId {#getplayerbyuserid}

Returns the character an account currently has loaded, or `nil` when that
account has none in the world.

```lua
local player = OPX.GetPlayerByUserId(userId)
```

- userId: [`UserId`](types.md#userid)

**Returns** [`Player`](types.md#player)`|nil`

**Side** `server` — inside `opx77_core` only. Does not yield.

One account holds at most one character at a time, which is why this index is a
single source rather than a list.

### OPX.GetPlayers {#getplayers}

Returns every loaded character as a list, evicting any roster slot whose account
no longer matches on the way through.

!!! warning "This walk can save characters to the database"

    An entry whose account has changed is passed to
    [`OPX.ForgetSession`](#forgetsession), which logs that character out, which
    dispatches a save. Calling it is therefore not free and not purely a read.
    Do not put it in a per-frame loop.

```lua
local players = OPX.GetPlayers()
```

**Returns** [`Player`](types.md#player)`[]` — a fresh list, empty when nobody is
loaded.

**Side** `server` — inside `opx77_core` only. Does not yield; the eviction it
may trigger dispatches its save on another thread.

Eviction happens after the walk, never during it: logging out mutates
`OPX.Players`, and mutating a table being iterated is undefined.

#### Example {#getplayers-example}

```lua
for i = 1, #OPX.GetPlayers() do end   -- rebuilt every call: hoist it
local players = OPX.GetPlayers()
for i = 1, #players do
  OPX.Notify(players[i].PlayerData.source, "Server restarting in 5 minutes.", "warning")
end
```

### OPX.GetPlayerCount {#getplayercount}

Returns how many characters are loaded, building no table.

```lua
local n = OPX.GetPlayerCount()
```

**Returns** `integer`

**Side** `server` — inside `opx77_core` only. Does not yield.

It applies the same account check as [`OPX.GetPlayers`](#getplayers) but
**evicts nothing**, so it is the cheap one and safe to call often.

### OPX.GetCharacter {#getcharacter}

Returns a character whether or not they are in the world, so a caller does not
have to ask "are they here" first.

```lua
local outcome = OPX.GetCharacter(citizenId)
```

- citizenId: [`CitizenId`](types.md#citizenid)

**Returns** [`Result`](types.md#result) — ok value is
`{ player = Player, offline = false }` for somebody in the world, or
`{ entity = table, offline = true }` for somebody who is not.

**Errors**

| Code | Meaning |
|---|---|
| `character.notFound` | No living row carries that citizen id. A soft-deleted character is not found. |
| `query-failed` | The read raised. `detail` carries the database exception. |
| `no-database` | The MySQL bridge is unavailable. |

**Side** `server` — inside `opx77_core` only. **Yields when the character is
offline** — a database read. Call it inside a `CreateThread`.

The two branches carry different keys on purpose: the offline one is a plain
stored entity, **not** a [`Player`](types.md#player). It has no `Functions` and
no `PlayerData`, so code that treats the two shapes alike will index `nil`.
A character with no row at all is a **failure**, not an empty success: the read
answers `character.notFound`.

#### Example {#getcharacter-example}

```lua
CreateThread(function()
  local outcome = OPX.GetCharacter("H7K-M4X3")
  if not outcome.ok then return end

  if outcome.value.offline then
    print(outcome.value.entity and outcome.value.entity.charInfo.firstName or "no such character")
  else
    print(outcome.value.player.PlayerData.charInfo.firstName)
  end
end)
```

### OPX.EnsureSession {#ensuresession}

Returns the session for a player id, creating one this VM has not seen and
dropping one whose slot now belongs to a different account; returns `nil` when
the host will not vouch for who they are.

```lua
local session = OPX.EnsureSession(playerId)
```

- playerId: [`Source`](types.md#source)`|string`

**Returns** [`Session`](types.md#session)`|nil`

**Side** `server` — inside `opx77_core` only. Does not yield.

Everything that wants a session goes through here, which is what makes the
recycled-slot check unskippable. A `nil` return means the platform gave no
verified identity for that slot, and **nothing may be attributed to them**: the
core refuses entry rather than guessing. It also drops any session already
recorded for the slot, so a half-authenticated connection leaves nothing behind.

The account is re-read on every call — `GetPlayerIdentifier` is resolved once
and cached, but only on a hit, because during boot the global may not be
installed yet and a cached `nil` would make every later call answer "nobody is
there". See [Identity](../../concepts/identity.md#ensure-session).

### OPX.ForgetSession {#forgetsession}

Drops a session and logs out any character still attached to the slot, saving it
on the way.

!!! warning "This is a departure, not a cleanup"

    It logs the character out and dispatches a save. It clears `MaySample`
    first, deliberately: the slot may already belong to somebody else, and a
    save that sampled now would write the new occupant's coordinates onto the
    departed character's row.

```lua
OPX.ForgetSession(playerId)
```

- playerId: [`Source`](types.md#source)

**Returns** nothing.

**Side** `server` — inside `opx77_core` only. Does not yield; the save it starts
does.

This is the net for a departure nobody reported. What is in the roster has not
been written since the last autosave, so silently discarding it would lose up to
`AUTOSAVE_SECONDS` of play.

### OPX.RegisterPlayer {#registerplayer}

Puts a loaded character into the roster and both reverse indexes, evicting any
other player already occupying the slot.

```lua
OPX.RegisterPlayer(player)
```

- player: [`Player`](types.md#player)

**Returns** nothing.

**Side** `server` — inside `opx77_core` only. Does not yield.

Called by [`OPX.Login`](#login). A plug-in has no reason to call it: a Player
that reaches the roster by any other route has skipped the ownership check, and
that is how a character ends up loaded on the wrong account.

### OPX.UnregisterPlayer {#unregisterplayer}

Takes a player back out of the roster and both indexes, removing an index entry
only while it still points at that player.

```lua
OPX.UnregisterPlayer(player)
```

- player: [`Player`](types.md#player)

**Returns** nothing.

**Side** `server` — inside `opx77_core` only. Does not yield.

The "only if it still points at this player" rule is what makes a reconnect
safe: for a moment both sessions of one account are in the roster, and an
unconditional removal would delete the new one's index entry.

### OPX.UserIdOf {#useridof}

Returns the durable account id behind a player id, or `nil` when the host will
not answer.

```lua
local userId = OPX.UserIdOf(playerId)
```

- playerId: [`Source`](types.md#source)

**Returns** [`UserId`](types.md#userid)`|nil`

**Side** `server` — inside `opx77_core` only. Does not yield.

A thin wrapper over the platform's `GetPlayerIdentifier`, resolved lazily and
cached only on success. This is the comparison every recycled-slot check is
built on.

### OPX.ResolvePlayer {#resolveplayer}

Returns a [`Player`](types.md#player) from whichever of the three identifier
shapes you are holding, or `nil` when none of them names a loaded character.

```lua
local player = OPX.ResolvePlayer(identifier)
```

- identifier: [`Player`](types.md#player)` | `[`Source`](types.md#source)` | `[`CitizenId`](types.md#citizenid)
    - A table with a `PlayerData` field is passed straight back; a number goes
      through [`OPX.GetPlayer`](#getplayer); a string through
      [`OPX.GetPlayerByCitizenId`](#getplayerbycitizenid).

**Returns** [`Player`](types.md#player)`|nil`

**Side** `server` — inside `opx77_core` only. Does not yield.

Every module-level mutator on this page starts with this, which is why they all
accept all three shapes. Use it when you are writing one of your own.

### OPX.CreatePlayer {#createplayer}

Builds a [`Player`](types.md#player) around a stored entity, normalising
anything the row is missing.

```lua
local player = OPX.CreatePlayer(entity, offline)
```

- entity: `table`
    - A stored character, as
      [`OPX.Storage.Players.fetchOne`](#storageplayersfetchone) returns.
- offline?: `boolean`
    - `true` builds an [offline Player](player.md#offline): same `Functions`,
      but it sends nothing, places nobody, and every money mutator refuses it.
    - Default: `false`

**Returns** [`Player`](types.md#player)

**Side** `server` — inside `opx77_core` only. Does not yield.

`Revision` starts at `0` and `MaySample` at `false`. The entity is normalised in
place: missing money types become `0` — not the configured starting amount,
which is a new-character grant — and every key of
`PLAYER.STARTING_METADATA` that the row lacks is **deep-copied** in, because a
table default shared by reference is one table every character on the server
shares.

A job or gang that has since been deleted from `data/` falls back to the
configured default. Refusing to load a character because it predates a rename is,
in effect, deleting it.

### OPX.NormaliseEntity {#normaliseentity}

Fills in whatever a stored entity is missing, in place, and returns it.

```lua
local entity = OPX.NormaliseEntity(entity)
```

- entity: `table`

**Returns** `table` — the same table.

**Side** `server` — inside `opx77_core` only. Does not yield.

[`OPX.CreatePlayer`](#createplayer) calls it for you. It is published for the
one case that does not go through a Player: reading a row for display, and
wanting the same defaults applied.

### OPX.Login {#login}

Loads a character into the world for a connected player and announces it;
returns a `Result` that fails when the character is missing, is not theirs, is
already loaded, or the database will not answer.

!!! danger "Nothing here proves who is asking"

    `Login` checks that the character belongs to the account on the session, and
    that check is the whole of the ownership boundary. A plug-in that calls it
    with a citizen id taken from a client payload without going through
    [`OPX.SelectCharacter`](#selectcharacter) has not skipped the check — but it
    has skipped the cooldown, the parse and the switch-safe teardown that
    surround it.

```lua
local outcome = OPX.Login(source, citizenId)
```

- source: [`Source`](types.md#source)
- citizenId: [`CitizenId`](types.md#citizenid)

**Returns** [`Result`](types.md#result) — ok value is the loaded
[`Player`](types.md#player).

**Errors**

| Code | Meaning |
|---|---|
| `entry.noIdentity` | The host would not vouch for that slot. |
| `error.unavailable` | The core booted without a usable schema; `OPX.BootError` says why. |
| `character.notFound` | No such character — **or** it belongs to another account. The same code deliberately: distinguishing them is an existence oracle. |
| `character.inUse` | Already loaded on another slot. Two Players writing one row means the last save silently wins. |
| `query-failed` / `no-database` | The read failed. |

**Side** `server` — inside `opx77_core` only. **Yields.** Call it inside a
`CreateThread`.

Order is the contract, and it is not arbitrary: ownership is checked before any
teardown, memberships load before the Player is built, and the roster entry is
made before the client is told — so a handler woken by `playerLoaded` finds the
character already in the roster.

The character's stored face rides along in `PlayerData.appearance` rather than
being announced separately. The core used to fire an
`open77:appearance:setCharacter` here; it does not, and it never reached
anything when it did — a server-side `TriggerEvent` walks the handler table of
its own VM and no further, and the host fans only its own closed set of names.
[`opx77_appearance`](../opx77_appearance/index.md) follows the live character on
the client-local bus instead, which is host-wide and is the only channel that
can work from here.

It does **not** place the character and does **not** release the readiness gate.
[`OPX.SelectCharacter`](#selectcharacter) is what does both, in the right order.

### OPX.Save {#save}

Samples the position and writes a character's row back; returns a `Result` that
fails when the character cannot be resolved or the write is refused.

```lua
local outcome = OPX.Save(identifier, loggedOut)
```

- identifier: [`Player`](types.md#player)` | `[`Source`](types.md#source)` | `[`CitizenId`](types.md#citizenid)
- loggedOut?: `boolean`
    - `true` stamps `last_logged_out` on the row. Only the logout paths pass it.
    - Default: `false`

**Returns** [`Result`](types.md#result) — ok value is the number of rows
affected.

**Errors**

| Code | Meaning |
|---|---|
| `error.notLoggedIn` | The identifier did not resolve to a Player. |
| `query-failed` | The `UPDATE` raised. Also logged at error level. |
| `no-database` | `MySQL.update.await` is unavailable. |

**Side** `server` — inside `opx77_core` only. **Yields.**

The position is sampled first, and only for an online Player whose
[`MaySample`](player.md#maysample) is true. `citizen_id` and `user_id` are not
in the statement's `SET` list at all: an update that could move a character to
another account is how characters get stolen.

You rarely need to call this. The autosave writes every character whose row
would come out different, every `AUTOSAVE_SECONDS`; a logout saves
unconditionally; and a resource stop dispatches one per character as a best
effort.

### OPX.Logout {#logout}

Takes a character out of the world, announces it, and dispatches a save on
another thread; does nothing for a player id holding no character.

!!! danger "The save is dispatched, not awaited"

    `Logout` returns before the row is written. A read that follows it — a
    character **switch** is exactly this — beats the write and hands back
    pre-save values, which are then written over the top. Use
    [`OPX.LogoutAndWait`](#logoutandwait) whenever anything happens afterwards.

```lua
OPX.Logout(source)
```

- source: [`Source`](types.md#source)

**Returns** nothing.

**Side** `server` — inside `opx77_core` only. Does not yield.

Idempotent: both platform disconnect events may fire for one departure. The
roster entry is removed **before** the save, so a lookup during the write
answers "not here" rather than handing out a Player nobody holds.

### OPX.LogoutAndWait {#logoutandwait}

Logs a character out and blocks until its row has been written; returns the
save's `Result`, or `Result.ok(false)` when there was nobody to log out.

```lua
local outcome = OPX.LogoutAndWait(source)
```

- source: [`Source`](types.md#source)

**Returns** [`Result`](types.md#result) — ok value is the save result, or
`false` when nothing was loaded.

**Errors**

| Code | Meaning |
|---|---|
| `error.notLoggedIn` | Reached only via the save; normally the no-player case returns `Result.ok(false)` instead. |
| `query-failed` / `no-database` | The write failed. **The old character is unsaved** — do not load another over it. |

**Side** `server` — inside `opx77_core` only. **Yields.**

This is what a character switch needs. `OPX.SelectCharacter` calls it and
refuses the whole switch when it fails, because loading the next character over
an unwritten row makes the loss permanent.

### OPX.SamplePosition {#sampleposition}

Re-derives a character's position from the platform and stores it; returns
`false` without touching anything when it cannot be trusted to.

```lua
local sampled = OPX.SamplePosition(player)
```

- player: [`Player`](types.md#player)

**Returns** `boolean` — whether a new position was stored.

**Side** `server` — inside `opx77_core` only. Does not yield.

It returns `false` — leaving the last known position in place — when the Player
is offline, when [`MaySample`](player.md#maysample) is false, when the slot now
belongs to a different account, or when the platform's snapshot is unreadable.
"Cannot tell" and "here" must never collapse into each other, so a failure
never writes.

`x`, `y` and `z` come from `Open77.players.position`. `heading` is the single
field taken from the client's own report, falling back to the previous heading
and then to `0.0`; `bucket` comes from the snapshot.

## Money {#money}

Four functions, and one rule: **never assign into `PlayerData.money`.** A direct
write is invisible to the hooks, the audit log, the client's mirror and the
autosave's dirty counter, so the change is unseen, unrecorded and gone at the
next restart.

The three mutators return `boolean, string?` rather than a
[`Result`](types.md#result), because a caller almost always wants
`if not ok then` and nothing else. The string is a locale key, so it can be
handed straight to [`OPX.Refuse`](#refuse).

All amounts are whole units. A fractional balance round-tripped through a JSON
column drifts, so every mutator rounds before it writes.

### OPX.AddMoney {#addmoney}

Adds a positive whole amount to one balance and announces it to all four
audiences; returns `false` and a locale key for a bad type, a bad amount, an
offline character or a hook veto.

```lua
local ok, why = OPX.AddMoney(identifier, moneyType, amount, reason)
```

- identifier: [`Player`](types.md#player)` | `[`Source`](types.md#source)` | `[`CitizenId`](types.md#citizenid)
- moneyType: [`MoneyType`](types.md#moneytype)
- amount: `number`
    - Rounded to a whole unit, and must end up **strictly positive**. Zero is
      refused: a zero here is a caller's arithmetic having gone wrong.
- reason?: `string`
    - For the audit log and the internal event, never shown to the player. The
      convention is `"system:detail"` — `"paycheck:ncpd"`, `"heist:payout"`.

**Returns** `boolean, string?`

**Errors**

| Code | Meaning |
|---|---|
| `error.notLoggedIn` | The identifier did not resolve to a Player. |
| `money.offline` | The Player is offline. Nothing writes a money column for one, so the credit would be announced, audited and then lost. |
| `money.badType` | Not a key of `OPX.Config.SHARED.MONEY.TYPES`. Also logged at error level. |
| `money.badAmount` | Not finite, or not strictly positive after rounding. Writes a security audit line naming the citizen id. |
| `money.vetoed` | A [`money:beforeAdd`](hooks.md#money-beforeadd) hook returned `false`. |

**Side** `server` — inside `opx77_core` only. Does not yield — **and no hook
registered at this point may yield either**, because it runs inside this call.

On success the core tells four audiences: the owning client
(`opx77:client:onMoneyChange`), the core's own files
(`opx77:player:moneyChange`), the audit log (`money.add`), and `PlayerData`.

`NaN` is the case worth naming. It arrives over JSON, passes every comparison,
and once it is in a balance so does the check that would stop the player
spending it — so it is refused before anything else happens.

#### Example {#addmoney-example}

```lua
-- a file added to opx77_core/server/, listed in open77.lua
local ok, why = OPX.AddMoney(source, "EDDIES", 500, "gig:payout")
if not ok then
  OPX.Refuse(source, why)
  return
end
```

### OPX.RemoveMoney {#removemoney}

Takes a positive whole amount off one balance, refusing outright rather than
truncating when there is not enough; returns `false` and a locale key on every
refusal.

```lua
local ok, why = OPX.RemoveMoney(identifier, moneyType, amount, reason)
```

- identifier: [`Player`](types.md#player)` | `[`Source`](types.md#source)` | `[`CitizenId`](types.md#citizenid)
- moneyType: [`MoneyType`](types.md#moneytype)
- amount: `number`
    - Rounded, and must be strictly positive.
- reason?: `string`

**Returns** `boolean, string?`

**Errors**

| Code | Meaning |
|---|---|
| `error.notLoggedIn` | The identifier did not resolve to a Player. |
| `money.offline` | The Player is offline. |
| `money.badType` | Not a configured money type. Also logged at error level. |
| `money.badAmount` | Not finite, or not strictly positive after rounding. Writes a security audit line. |
| `money.insufficient` | The balance would go below zero and this type is not in `MONEY.ALLOW_NEGATIVE`. |
| `money.vetoed` | A [`money:beforeRemove`](hooks.md#money-beforeremove) hook returned `false`. |

**Side** `server` — inside `opx77_core` only. Does not yield.

There is no partial removal — a purchase that half-succeeds is worse than one
that fails — so check the return and do not hand over the goods until it is
`true`. `BANK` is the one type shipped in `MONEY.ALLOW_NEGATIVE`: an overdraft is
a feature; carried cash going negative never is.

The sufficiency check runs **before** the hook, so a `money:beforeRemove` hook
never sees a debit that was going to fail anyway.

### OPX.SetMoney {#setmoney}

Sets a balance outright, allowing zero; returns `false` and a locale key for a
bad type, a non-finite amount, an illegal negative or a hook veto.

!!! warning "This overwrites rather than adjusts"

    Two plug-ins computing a new balance from a value each read a moment ago
    will silently clobber each other. Use [`OPX.AddMoney`](#addmoney) or
    [`OPX.RemoveMoney`](#removemoney) for anything that is really a delta; reach
    for this only when the new balance is the thing you actually know — an admin
    correction, or emptying an account.

```lua
local ok, why = OPX.SetMoney(identifier, moneyType, amount, reason)
```

- identifier: [`Player`](types.md#player)` | `[`Source`](types.md#source)` | `[`CitizenId`](types.md#citizenid)
- moneyType: [`MoneyType`](types.md#moneytype)
- amount: `number`
    - Rounded. **Zero is allowed here and nowhere else**: it is the only way to
      empty an account.
- reason?: `string`

**Returns** `boolean, string?`

**Errors**

| Code | Meaning |
|---|---|
| `error.notLoggedIn` | The identifier did not resolve to a Player. |
| `money.offline` | The Player is offline. |
| `money.badType` | Not a configured money type. Unlike the other two, this is **not** logged. |
| `money.badAmount` | Not a finite number. No security audit line is written. |
| `money.negative` | Below zero and this type is not in `MONEY.ALLOW_NEGATIVE`. |
| `money.vetoed` | A [`money:beforeSet`](hooks.md#money-beforeset) hook returned `false`. |

**Side** `server` — inside `opx77_core` only. Does not yield.

`payload.amount` on the `money:beforeSet` hook is the **resulting balance**, not
a delta. A single function registered at all three money points cannot tell them
apart from the payload alone.

### OPX.GetMoney {#getmoney}

Returns one balance, or the whole money table when no type is named; returns
`nil` when the identifier does not resolve.

```lua
local balance = OPX.GetMoney(identifier, moneyType)
```

- identifier: [`Player`](types.md#player)` | `[`Source`](types.md#source)` | `[`CitizenId`](types.md#citizenid)
- moneyType?: [`MoneyType`](types.md#moneytype)
    - Omitted returns the live `money` table itself, not a copy.

**Returns** `integer|table|nil`

**Side** `server` — inside `opx77_core` only. Does not yield.

!!! warning "The no-type form hands back the live table"

    Assigning into what it returns moves money with no hook, no audit line, no
    client update and no dirty flag. Read from it; write through the three
    mutators above.

A money type this server does not have answers `nil`, not `0` — which is the
right answer, because "no such currency" and "a balance of nothing" are
different facts.

## Metadata {#metadata}

`PlayerData.metadata` is one JSON column and it is free-form: a key a plug-in
invents survives every save and every core upgrade. It is the supported place
for per-character state.

!!! danger "Metadata is mirrored to the client that owns the character"

    The whole of `PlayerData` — metadata included — is sent to the owning client
    on login and on every change. Nothing secret may go in it. Key a private
    table on the [`CitizenId`](types.md#citizenid) instead.

### OPX.SetMetadata {#setmetadata}

Sets one metadata key on a character and announces the change; returns `false`
when the identifier does not resolve.

```lua
local ok = OPX.SetMetadata(identifier, key, value)
```

- identifier: [`Player`](types.md#player)` | `[`Source`](types.md#source)` | `[`CitizenId`](types.md#citizenid)
- key: `string`
- value: `any`
    - Anything JSON can carry.

**Returns** `boolean` — `true` when it was written.

**Errors** none. A missing character is `false`, with no code.

**Side** `server` — inside `opx77_core` only. Does not yield.

It writes through [`Functions.SetMetaData`](player.md#setmetadata), which bumps
`Revision` — which is what makes the autosave carry the change. Assigning into
`PlayerData.metadata` directly does not, and the change is lost at the next
restart.

Names the core itself reads are `health`, `armor`, `hunger`, `thirst`, `isDead`
and `inLastStand`. See [`PlayerMetadata`](types.md#playermetadata).

### OPX.GetMetadata {#getmetadata}

Returns one metadata value, or the whole metadata table when no key is named;
returns `nil` when the identifier does not resolve or nothing has written that
key.

```lua
local value = OPX.GetMetadata(identifier, key)
```

- identifier: [`Player`](types.md#player)` | `[`Source`](types.md#source)` | `[`CitizenId`](types.md#citizenid)
- key?: `string`
    - Omitted returns the live `metadata` table itself, not a copy.

**Returns** `any`

**Side** `server` — inside `opx77_core` only. Does not yield.

!!! warning "The no-key form hands back the live table"

    Mutating it changes the character's metadata without bumping `Revision` and
    without telling the client. Read from it; write through
    [`OPX.SetMetadata`](#setmetadata).

`nil` is ambiguous here: it means "no such character", "no such key", or "the
value is genuinely nil". Resolve the player first if you need to tell them
apart.

## Appearance {#appearance}

The character's face is `opx77_characters.appearance`, a nullable JSON column,
and `server/appearance.lua` is the only thing that writes it. It travels inside
`PlayerData` like any other field of the character, so it is in every event the
core already publishes.

The capture is not done here. [`opx77_appearance`](../opx77_appearance/index.md)
does it on the **client** — its one server file only hands looks between players
and never touches the face: it opens the native customization modal, captures
a snapshot, and sends it to the core on
[`opx77:server:saveAppearance`](events.md#saveappearance). The core takes the
character from the connection, validates the snapshot, writes it and broadcasts
it. Nothing else may write a face, and there is deliberately no export that
does: a caller that could hand the framework a snapshot could hand it somebody
else's.

### OPX.SaveAppearance {#saveappearance}

Validates a captured snapshot, writes it to `opx77_characters.appearance` and
puts it on `PlayerData.appearance`.

```lua
local saved = OPX.SaveAppearance(identifier, snapshot)
```

- identifier: [`Player`](types.md#player)`|`[`Source`](types.md#source)`|`[`CitizenId`](types.md#citizenid)
- snapshot: `any`
    - Straight off the wire. Nothing is assumed about it.

**Returns** [`Result`](types.md#result) — the `ok` value is the **canonical**
snapshot, which is not necessarily the table that was passed in.

**Errors**

| Code | Meaning |
|---|---|
| `error.notLoggedIn` | No character resolves from `identifier`. |
| `appearance.invalid` | The snapshot is not in canonical form. `detail` carries which check failed. |
| `appearance.tooLarge` | The encoded document is over `SHARED.APPEARANCE.MAX_JSON_BYTES`. `detail` carries the size. |
| — | Anything the storage layer answers, unchanged. |

**Side** `server` — inside `opx77_core` only. **Yields** — coroutine only.

A snapshot identical to the stored face returns `ok` and writes **nothing**: no
column is touched, and neither
[`opx77:client:onAppearanceUpdate`](events.md#onappearanceupdate) nor
[`opx77:player:appearanceChange`](events.md#internal-appearancechange) is
raised. A caller waiting on one of those for an unchanged confirm waits forever.

On a real change the column is written immediately rather than at the next
autosave, `PlayerData.appearance` is replaced, the owning client is sent the new
snapshot, the internal event is fired and one `appearance.saved` audit line is
written.

### OPX.GetAppearance {#server-getappearance}

Returns the stored face for a character, online or not.

```lua
local face = OPX.GetAppearance(identifier)
```

- identifier: [`Player`](types.md#player)`|`[`Source`](types.md#source)`|`[`CitizenId`](types.md#citizenid)

**Returns** [`Result`](types.md#result) — the `ok` value is an
[`AppearanceSnapshot`](types.md#appearancesnapshot), or `nil` for a character
that has never been captured, which is a success and not an error.

**Errors** `error.notLoggedIn` when the identifier is not a citizen id and no
Player resolves from it. Anything the storage layer answers is passed through
unchanged.

**Side** `server` — inside `opx77_core` only. **Yields when the character is
offline** — treat it as coroutine-only.

An online character is answered from the roster with no round trip. An offline
one is fetched with
[`OPX.Storage.Players.fetchOne`](#storageplayersfetchone).

### OPX.Appearance.canonical {#appearancecanonical}

Puts a snapshot into canonical form, or says what is wrong with it.

```lua
local canonical, reason = OPX.Appearance.canonical(value)
```

- value: `any`

**Returns** [`AppearanceSnapshot`](types.md#appearancesnapshot)`|nil`, and a
`string|nil` reason when it answered `nil`.

**Side** `server` — inside `opx77_core` only. Does not yield.

Canonical form means: `schemaVersion` is `OPX.Appearance.VERSION`, `gameBuild`
is a key of `SHARED.APPEARANCE.GAME_BUILDS`, `catalogDigest` is 64 lower-case
hex characters, `gender` is the engine's `"0x…"` body-family hash, and `options`
is a dense array of 1 to 256 entries with lower-cased names and no duplicate
`part:name` pair. Every reason is a diagnostic string for a log, never a locale
key: `invalid_snapshot`, `unsupported_schema`, `unsupported_game_build`,
`invalid_catalog_digest`, `invalid_gender`, `invalid_options`,
`invalid_option_count`, `invalid_option`, `invalid_option_part`,
`invalid_option_name`, `invalid_option_value`, `invalid_option_choices`,
`option_out_of_range`, `duplicate_option` and `sparse_options`.

The array is checked twice: `#value.options` stops at the first hole, so the
first pass only proves the *prefix* is well formed, and a second walk over
`pairs` is what catches a sparse array before it reaches the codec.

### OPX.Appearance.same {#appearancesame}

Returns whether two canonical snapshots are the same face.

```lua
if OPX.Appearance.same(left, right) then return end
```

- left: [`AppearanceSnapshot`](types.md#appearancesnapshot)`|nil`
- right: [`AppearanceSnapshot`](types.md#appearancesnapshot)`|nil`

**Returns** `boolean` — `false` whenever either side is not a table.

**Side** `server` — inside `opx77_core` only. Does not yield.

This is what makes a confirm that changed nothing free. It compares the build,
the catalogue digest, the body-family hash and every option's part, name and
value; `choices` is not compared, because it describes the catalogue rather than
the choice.

### OPX.Appearance.buildAccepted {#appearancebuildaccepted}

Returns whether a game build is one the core will read a stored face back into.

```lua
if not OPX.Appearance.buildAccepted(build) then return end
```

- build: `any`

**Returns** `boolean` — `true` only for a key of
`OPX.Config.SHARED.APPEARANCE.GAME_BUILDS`.

**Side** `server` — inside `opx77_core` only. Does not yield.

### OPX.Appearance.VERSION {#appearanceversion}

The schema version written into every stored snapshot.

```lua
OPX.Appearance.VERSION --> 1
```

**Type** `integer`

A snapshot declaring any other `schemaVersion` is refused with
`unsupported_schema`. There is no upgrade path between versions: a snapshot is a
list of positions in a catalogue, and there is nothing to migrate it against.

## Jobs and gangs {#groups}

A character has **memberships** — every job and gang they belong to, with a
grade, held in `opx77_character_groups` — and one **primary** job and gang, the
flattened [`PlayerJob`](types.md#playerjob) and
[`PlayerGang`](types.md#playergang) that live on `PlayerData` and get paid.

!!! warning "Everything in this section yields for an offline character"

    `server/groups.lua` accepts a character who is not in the world, by loading
    the row, building an [offline Player](player.md#offline), applying the change
    and writing the affected column back. That is up to three database round
    trips. Treat the whole section as coroutine-only and call it from inside a
    `CreateThread`, even when you know the character is online.

    Between those round trips the character may log in. Every one of these
    functions re-resolves afterwards and re-applies the change against the live
    Player when that happens, so a change is never silently applied to a stale
    copy.

### OPX.SetJob {#setjob}

Makes a job the character's primary job at a grade, joining it if they were not
already a member; returns a `Result` that fails for an unknown job, an unknown
grade or a failed write.

```lua
local outcome = OPX.SetJob(identifier, name, grade)
```

- identifier: [`Player`](types.md#player)` | `[`Source`](types.md#source)` | `[`CitizenId`](types.md#citizenid)
- name: `string`
    - A key of `OPX.Jobs`, from [`data/jobs.lua`](data.md).
- grade?: `integer`
    - `nil` and anything unparseable become `0`.
    - Default: `0`

**Returns** [`Result`](types.md#result) — ok value is the new
[`PlayerJob`](types.md#playerjob).

**Errors**

| Code | Meaning |
|---|---|
| `job.notFound` | No job of that name in `data/jobs.lua`. |
| `job.gradeNotFound` | The job exists; that grade does not. |
| `error.notLoggedIn` | The identifier is a `Source` or a `Player` and neither resolves. Only a [`CitizenId`](types.md#citizenid) can name an offline character. |
| `character.notFound` | The identifier is a citizen id and no living row carries it. |
| `query-failed` / `no-database` | The membership row or the column write failed. |

**Side** `server` — inside `opx77_core` only. **Yields.**

Duty comes from the job definition's `defaultDuty`, not from whatever the
character was on a moment ago: a promotion does not clock you in. The membership
row is written **before** `PlayerData` is touched, so a failed write leaves the
character on the job they had.

On success it fires `opx77:client:onJobUpdate` to the owning client (online
only), `opx77:player:jobUpdate` inside the core's VM, and writes a `job.set`
audit line.

#### Example {#setjob-example}

```lua
CreateThread(function()
  local outcome = OPX.SetJob(source, "ncpd", 2)
  if not outcome.ok then
    OPX.Refuse(source, outcome.error)
    return
  end
  OPX.NotifyLocale(source, "job.updated", {
    grade = outcome.value.grade.name, job = outcome.value.label,
  }, "success")
end)
```

### OPX.SetJobDuty {#setjobduty}

Clocks a character in or out of their primary job and tells them so; refuses a
job whose `defaultDuty` is true.

```lua
local outcome = OPX.SetJobDuty(identifier, onDuty)
```

- identifier: [`Player`](types.md#player)` | `[`Source`](types.md#source)` | `[`CitizenId`](types.md#citizenid)
- onDuty: `boolean`
    - Compared with `== true`, so any other value clocks them out.

**Returns** [`Result`](types.md#result) — ok value is the resulting boolean.

**Errors**

| Code | Meaning |
|---|---|
| `job.notFound` | Their primary job is no longer in `data/jobs.lua`. |
| `job.noDuty` | The job's `defaultDuty` is true — it has no shift to clock into, and clocking out of "unemployed" is a state nothing reasons about. |
| `error.notLoggedIn` | The identifier names nobody, and is not a citizen id. |
| `character.notFound` | The identifier is a citizen id and no living row carries it. |

**Side** `server` — inside `opx77_core` only. **Yields.**

An online character is also sent a `job.onDuty` / `job.offDuty` notification, so
a caller does not have to send one.

`onDuty` is not a durable membership: it lives on `PlayerData.job`, is written
to the `job` JSON column by the next save, and is reset from the definition's
`defaultDuty` the next time [`OPX.SetJob`](#setjob) runs.

### OPX.AddPlayerToJob {#addplayertojob}

Adds a job membership at a grade **without** changing which job is primary;
returns a `Result` that fails for an unknown job or grade.

```lua
local outcome = OPX.AddPlayerToJob(identifier, name, grade)
```

- identifier: [`Player`](types.md#player)` | `[`Source`](types.md#source)` | `[`CitizenId`](types.md#citizenid)
- name: `string`
- grade: `integer`

**Returns** [`Result`](types.md#result) — ok value is `true`.

**Errors**

| Code | Meaning |
|---|---|
| `job.notFound` | No job of that name. |
| `job.gradeNotFound` | The job exists; that grade does not. |
| `error.notLoggedIn` | The identifier names nobody, and is not a citizen id. |
| `character.notFound` | The identifier is a citizen id and no living row carries it. |
| `query-failed` / `no-database` | The membership row could not be written. |

**Side** `server` — inside `opx77_core` only. **Yields.**

Joining a group you are already in is a **promotion**, not a duplicate row —
enforced by the composite primary key on `opx77_character_groups` rather than by
whichever call site remembered to check.

No client event is fired for a membership change. `PlayerData.jobs` changes, and
`UpdatePlayerData` pushes the whole table, so the client sees it — but nothing
named `onJobUpdate` goes out, because the primary job did not change.

### OPX.RemovePlayerFromJob {#removeplayerfromjob}

Removes a job membership, falling the character back to the default job when the
one removed was their primary; returns a `Result` that fails on a failed write.

```lua
local outcome = OPX.RemovePlayerFromJob(identifier, name)
```

- identifier: [`Player`](types.md#player)` | `[`Source`](types.md#source)` | `[`CitizenId`](types.md#citizenid)
- name: `string`
    - A job they are not in is not an error: the `DELETE` simply matches nothing.

**Returns** [`Result`](types.md#result) — ok value is `true`.

**Errors**

| Code | Meaning |
|---|---|
| `error.notLoggedIn` | The identifier names nobody, and is not a citizen id. |
| `character.notFound` | The identifier is a citizen id and no living row carries it. |
| `query-failed` / `no-database` | The delete or the column write failed. |

**Side** `server` — inside `opx77_core` only. **Yields.**

The fallback is `OPX.Config.SERVER.PLAYER.DEFAULT_JOB` at grade `0`. Leaving
somebody employed by a job they have left is how a fired employee keeps drawing
a salary, so the primary is always replaced.

Writes a `job.removed` audit line.

### OPX.SetPlayerPrimaryJob {#setplayerprimaryjob}

Switches which of a character's **existing** jobs is primary; refuses a job they
are not a member of rather than joining it.

```lua
local outcome = OPX.SetPlayerPrimaryJob(identifier, name)
```

- identifier: [`Player`](types.md#player)` | `[`Source`](types.md#source)` | `[`CitizenId`](types.md#citizenid)
- name: `string`

**Returns** [`Result`](types.md#result) — ok value is the new
[`PlayerJob`](types.md#playerjob).

**Errors**

| Code | Meaning |
|---|---|
| `job.notMember` | They hold no membership of that job. Only one of "switch to my other job" and "give me a job" is a promotion. |
| `job.notFound` / `job.gradeNotFound` | Raised by the [`OPX.SetJob`](#setjob) it delegates to. |
| `error.notLoggedIn` | The identifier names nobody, and is not a citizen id. |
| `character.notFound` | The identifier is a citizen id and no living row carries it. |

**Side** `server` — inside `opx77_core` only. **Yields.**

The grade comes from the membership, so a switch never changes rank. Note that
a character created before the core wrote a default-job membership row will be
refused here with `job.notMember` for their own default job — the row is
written at creation now, precisely so that cannot happen.

### OPX.SetGang {#setgang}

Makes a gang the character's primary gang at a grade, joining it if needed;
returns a `Result` that fails for an unknown gang, an unknown grade or a failed
write.

```lua
local outcome = OPX.SetGang(identifier, name, grade)
```

- identifier: [`Player`](types.md#player)` | `[`Source`](types.md#source)` | `[`CitizenId`](types.md#citizenid)
- name: `string`
    - A key of `OPX.Gangs`, from [`data/gangs.lua`](data.md).
- grade?: `integer`
    - Default: `0`

**Returns** [`Result`](types.md#result) — ok value is the new
[`PlayerGang`](types.md#playergang).

**Errors**

| Code | Meaning |
|---|---|
| `gang.notFound` | No gang of that name in `data/gangs.lua`. |
| `gang.gradeNotFound` | The gang exists; that grade does not. |
| `error.notLoggedIn` | The identifier names nobody, and is not a citizen id. |
| `character.notFound` | The identifier is a citizen id and no living row carries it. |
| `query-failed` / `no-database` | The write failed. |

**Side** `server` — inside `opx77_core` only. **Yields.**

Fires `opx77:client:onGangUpdate` and `opx77:player:gangUpdate`, and writes a
`gang.set` audit line. A gang has no duty and no payment.

### OPX.AddPlayerToGang {#addplayertogang}

Adds a gang membership at a grade without changing which gang is primary;
returns a `Result` that fails for an unknown gang or grade.

```lua
local outcome = OPX.AddPlayerToGang(identifier, name, grade)
```

- identifier: [`Player`](types.md#player)` | `[`Source`](types.md#source)` | `[`CitizenId`](types.md#citizenid)
- name: `string`
- grade: `integer`

**Returns** [`Result`](types.md#result) — ok value is `true`.

**Errors**

| Code | Meaning |
|---|---|
| `gang.notFound` | No gang of that name. |
| `gang.gradeNotFound` | The gang exists; that grade does not. |
| `error.notLoggedIn` | The identifier names nobody, and is not a citizen id. |
| `character.notFound` | The identifier is a citizen id and no living row carries it. |
| `query-failed` / `no-database` | The membership row could not be written. |

**Side** `server` — inside `opx77_core` only. **Yields.**

### OPX.RemovePlayerFromGang {#removeplayerfromgang}

Removes a gang membership, falling the character back to the default gang when
the one removed was their primary; returns a `Result` that fails on a failed
write.

```lua
local outcome = OPX.RemovePlayerFromGang(identifier, name)
```

- identifier: [`Player`](types.md#player)` | `[`Source`](types.md#source)` | `[`CitizenId`](types.md#citizenid)
- name: `string`

**Returns** [`Result`](types.md#result) — ok value is `true`.

**Errors**

| Code | Meaning |
|---|---|
| `error.notLoggedIn` | The identifier names nobody, and is not a citizen id. |
| `character.notFound` | The identifier is a citizen id and no living row carries it. |
| `query-failed` / `no-database` | The delete or the column write failed. |

**Side** `server` — inside `opx77_core` only. **Yields.**

The fallback is `OPX.Config.SERVER.PLAYER.DEFAULT_GANG`, shipped as `"none"`.
Writes a `gang.removed` audit line.

### OPX.SetPlayerPrimaryGang {#setplayerprimarygang}

Switches which of a character's existing gangs is primary; refuses a gang they
are not a member of.

```lua
local outcome = OPX.SetPlayerPrimaryGang(identifier, name)
```

- identifier: [`Player`](types.md#player)` | `[`Source`](types.md#source)` | `[`CitizenId`](types.md#citizenid)
- name: `string`

**Returns** [`Result`](types.md#result) — ok value is the new
[`PlayerGang`](types.md#playergang).

**Errors**

| Code | Meaning |
|---|---|
| `gang.notMember` | They hold no membership of that gang. |
| `gang.notFound` / `gang.gradeNotFound` | Raised by the [`OPX.SetGang`](#setgang) it delegates to. |
| `error.notLoggedIn` | The identifier names nobody, and is not a citizen id. |
| `character.notFound` | The identifier is a citizen id and no living row carries it. |

**Side** `server` — inside `opx77_core` only. **Yields.**

### OPX.GetGroupMembers {#getgroupmembers}

Returns everyone in a job or gang, online or not, ordered by grade; returns a
`Result` that fails for an unknown group type.

```lua
local outcome = OPX.GetGroupMembers(groupType, name)
```

- groupType: [`GroupType`](types.md#grouptype)
    - `"job"` or `"gang"`. Anything else is refused.
- name: `string`

**Returns** [`Result`](types.md#result) — ok value is a list of
`{ citizenId, grade, name }`, where `name` is the character's first and last
name joined.

**Errors**

| Code | Meaning |
|---|---|
| `error.badRequest` | `groupType` was neither `"job"` nor `"gang"`. |
| `query-failed` / `no-database` | The read failed. |

**Side** `server` — inside `opx77_core` only. **Yields.**

!!! warning "Bounded at 200 rows, silently"

    The statement carries `LIMIT 200` and there is no paging and no total. An
    unbounded result set is a stall on the database worker, and 200 is the
    ceiling a boss menu or the `opx77.group` diagnostic was sized for. A group
    with more members than that returns the top 200 by grade with no indication
    that anything was left out.

Soft-deleted characters are excluded. `grade` is the stored membership level,
not the primary job's.

### OPX.GetPlayersByJob {#getplayersbyjob}

Returns every loaded character whose **primary** job is a given one, optionally
only those on duty.

```lua
local players = OPX.GetPlayersByJob(name, onDutyOnly)
```

- name: `string`
- onDutyOnly?: `boolean`
    - Default: `false`

**Returns** [`Player`](types.md#player)`[]`

**Side** `server` — inside `opx77_core` only. Does not yield — it walks memory.
This is what a dispatch or a radio calls, often.

It matches the primary job only. Somebody who holds an `ncpd` membership but is
currently primarily a taxi driver will not be returned, which is almost always
the behaviour a dispatch wants.

It calls [`OPX.GetPlayers`](#getplayers) internally, so it inherits that
function's eviction pass.

### OPX.GetPlayersByGang {#getplayersbygang}

Returns every loaded character whose primary gang is a given one.

```lua
local players = OPX.GetPlayersByGang(name)
```

- name: `string`

**Returns** [`Player`](types.md#player)`[]`

**Side** `server` — inside `opx77_core` only. Does not yield.

### OPX.Jobs {#jobs}

Every job definition, keyed by name.

```lua
OPX.Jobs["ncpd"] --> JobDefinition
```

**Side** `shared` — the same table exists in the client VM, because
`data/jobs.lua` is a `shared_script`.

Loaded from [`data/jobs.lua`](data.md). It is static data, not configuration:
renaming a key orphans every membership row already stored under the old name.

### OPX.Gangs {#gangs}

Every gang definition, keyed by name.

```lua
OPX.Gangs["valentinos"] --> GangDefinition
```

**Side** `shared`.

### OPX.Origins {#origins}

The three lifepaths, as a set, used to validate a character registration.

```lua
OPX.Origins --> { nomad = …, streetkid = …, corpo = … }
```

**Side** `shared`.

### OPX.GetJob {#getjob}

Returns a job definition by name, or `nil` when no such job is defined.

```lua
local definition = OPX.GetJob(name)
```

- name: `string`

**Returns** [`JobDefinition`](types.md#jobdefinition)`|nil`

**Side** `shared` — both runtimes. Does not yield.

### OPX.GetGang {#getgang}

Returns a gang definition by name, or `nil` when no such gang is defined.

```lua
local definition = OPX.GetGang(name)
```

- name: `string`

**Returns** [`GangDefinition`](types.md#gangdefinition)`|nil`

**Side** `shared` — both runtimes. Does not yield.

### OPX.ResolveJob {#resolvejob}

Flattens a job name and grade into the [`PlayerJob`](types.md#playerjob) shape
carried on `PlayerData`; returns a `Result` so the caller can tell "no such job"
from "no such grade in that job".

```lua
local outcome = OPX.ResolveJob(name, grade)
```

- name: `string`
- grade?: `integer|string`
    - Passed through `tonumber`; `nil` and anything unparseable become `0`.
    - Default: `0`

**Returns** [`Result`](types.md#result) — ok value is a
[`PlayerJob`](types.md#playerjob).

**Errors**

| Code | Meaning |
|---|---|
| `job.notFound` | No job of that name. `detail` carries the name asked for. |
| `job.gradeNotFound` | The job exists; that grade does not. `detail` is `"name:grade"`. |

**Side** `shared` — both runtimes. Does not yield.

`onDuty` on the result comes from the definition's `defaultDuty`, so resolving
is not the same as preserving: use it to build a job, not to copy one.

### OPX.ResolveGang {#resolvegang}

Flattens a gang name and grade into the [`PlayerGang`](types.md#playergang)
shape; returns a `Result` distinguishing an unknown gang from an unknown grade.

```lua
local outcome = OPX.ResolveGang(name, grade)
```

- name: `string`
- grade?: `integer|string`
    - Default: `0`

**Returns** [`Result`](types.md#result) — ok value is a
[`PlayerGang`](types.md#playergang).

**Errors**

| Code | Meaning |
|---|---|
| `gang.notFound` | No gang of that name. |
| `gang.gradeNotFound` | The gang exists; that grade does not. |

**Side** `shared` — both runtimes. Does not yield.

### OPX.TopGrade {#topgrade}

Returns the highest grade level defined for a group, so a caller can clamp
rather than fail.

```lua
local top = OPX.TopGrade(grades)
```

- grades: `table<integer, JobGrade|GangGrade>`
    - Expected to be contiguous from `0`.

**Returns** `integer`

**Side** `shared` — both runtimes. Does not yield.

!!! warning "It stops at the first hole"

    The walk starts at `0` and increments while the next key exists. A
    definition with grades `0, 1, 3` answers `1`, and grade `3` becomes
    unreachable through anything that clamps with this. Keep grade tables
    contiguous.

## Characters {#characters}

Creation, deletion, selection and placement. **Everything in this section
yields.**

!!! danger "These functions are the ownership boundary"

    `source` is the only value a client cannot forge, so the account is always
    taken from the [`Session`](types.md#session) and never from a payload. A
    refused ownership check answers `character.notFound` — the same code a
    genuinely missing character gets — because "that one is somebody else's" is
    an existence oracle: it tells an attacker which of their guesses named a
    real character. Do not "improve" those messages.

### OPX.SendCharacters {#sendcharacters}

Loads an account's roster and sends the character list to that client; returns a
`Result` that fails when called too often, when the identity is unverified, or
when the database will not answer.

```lua
local outcome = OPX.SendCharacters(source, pushed)
```

- source: [`Source`](types.md#source)
- pushed: `boolean` — optional
    - `true` only for the core's own send on connect, which is neither cooled
      nor cooling. Every other caller omits it.

**Returns** [`Result`](types.md#result) — ok value is a list of
[`CharacterSummary`](types.md#charactersummary).

**Errors**

| Code | Meaning |
|---|---|
| `error.tooFast` | A 2 000 ms per-source cooldown on the key `roster`. Never for a `pushed` send. |
| `entry.noIdentity` | The host would not vouch for that slot. |
| `error.unavailable` | The core booted with no usable schema. The client is also sent a refusal. |
| `query-failed` / `no-database` | The account upsert or the roster read failed. |

**Side** `server` — inside `opx77_core` only. **Yields.**

Safe to run twice: a resource reload empties this VM's roster and the client
re-announces itself. The cooldown lives here rather than at a doorway because
the same work is reachable from the unrestricted `/opx77.characters` command,
and a guard on one entry point is forgotten by the next one added.

The push on connect is the exception, and the reason is timing. It goes out from
[`OPX.Lifecycle.beginEntry`](#lifecyclebeginentry) before any of the client's
resources run, so it usually lands nowhere. Were it cooled, the `READY` the
core's client sends when it starts — a second or two later — would fall inside
the window and be dropped, and the roster would arrive only on a retry, after the
gameplay world had loaded. That is too late for
[`opx77_appearance`](../opx77_appearance/index.md), which picks the body the
world loads with from the roster and falls back to its default family without
it.

The summaries deliberately omit money, metadata and the stored position. Those
are nobody's business until a character is loaded — the account owner's
included, because the selection screen is reachable before any ownership
decision has been made.

### OPX.CreateCharacter {#createcharacter}

Creates a character on the caller's own account and writes its default job and
gang memberships; returns a `Result` that fails on invalid input, a full
account, a rate limit or a failed write.

```lua
local outcome = OPX.CreateCharacter(source, payload)
```

- source: [`Source`](types.md#source)
    - The account comes from this and from nothing in the payload.
- payload: `table`
    - `firstName`, `lastName`, `origin`, `gender`, `birthDate`. Every field is
      treated as attacker-controlled.

**Returns** [`Result`](types.md#result) — ok value is a
[`CharacterSummary`](types.md#charactersummary).

**Errors**

| Code | Meaning |
|---|---|
| `entry.noIdentity` | The host would not vouch for that slot. |
| `error.unavailable` | The core booted with no usable schema, **or** no free citizen id was drawn in five attempts, **or** the memberships failed and the half-created row was rolled back. |
| `error.badRequest` | The payload is not a table, or `gender` is neither `"female"` nor `"male"`. |
| `character.badName` | `firstName` or `lastName` failed [`OPX.ValidateName`](#validatename). `detail` says which. |
| `character.badOrigin` | `origin` is not a key of `OPX.Origins`. |
| `error.tooFast` | A 3 000 ms per-source cooldown on the key `create`. |
| `character.rowLimit` | The account has written as many rows to `opx77_characters` as `CHARACTER_ROWS` allows. |
| `character.limit` | Every configured character slot on the account is taken. |
| `query-failed` / `no-database` | A read or the insert failed. |

**Side** `server` — inside `opx77_core` only. **Yields.**

The cooldown is applied **after** validation, deliberately: it guards the write,
not a mistyped name, and a player fixing a typo should not be told to slow down.

`birthDate` is shape-checked against `YYYY-MM-DD` and never parsed — the server
sandbox removes `os`, so there is no clock to check it against — and an invalid
one silently becomes `2050-01-01` rather than refusing the whole registration.

The citizen id is drawn rather than searched for, and a collision is settled by
the unique key on the column, not by a `SELECT` beforehand: two players creating
in the same tick would both pass that check.

If the character row is inserted but its job or gang membership row is not, the
row is **hard-deleted** and the whole call fails. A half-created character is
worse than none: a character with no membership row is one
[`OPX.SetPlayerPrimaryJob`](#setplayerprimaryjob) refuses for ever.

### OPX.DeleteCharacter {#deletecharacter}

Soft-deletes one of the caller's own characters, logging them out first and
cascading the tables an operator has listed; returns a `Result` that fails on a
rate limit, an unparseable id, or a character that is not theirs.

!!! danger "It logs the character out of the world first"

    If the character being deleted is loaded, `OPX.Logout` runs before the
    delete. Without that the autosave writes the row back a minute later and the
    deletion undoes itself.

```lua
local outcome = OPX.DeleteCharacter(source, citizenId)
```

- source: [`Source`](types.md#source)
- citizenId: [`CitizenId`](types.md#citizenid)
    - Parsed and normalised here, so any case and separator form is accepted.

**Returns** [`Result`](types.md#result) — ok value is the citizen id.

**Errors**

| Code | Meaning |
|---|---|
| `error.tooFast` | A 3 000 ms per-source cooldown on the key `delete`. It guards the audit trail too: every refused delete writes a security line. |
| `entry.noIdentity` | The host would not vouch for that slot. |
| `character.notFound` | Unparseable id, no such character, **or it belongs to another account**. The three are deliberately indistinguishable. |
| `query-failed` / `no-database` | The read or the soft delete failed. |

**Side** `server` — inside `opx77_core` only. **Yields.**

The delete is **soft**: the row is marked rather than removed, so a mistake is
recoverable and a citizen id is never reissued to a stranger. The slot number is
freed, which is why `CHARACTER_ROWS` exists as a separate lifetime ceiling —
create-and-delete writes a new row every time.

Rows in `CHARACTERS.CASCADE_TABLES` are deleted for real, because they belong to
plug-ins that never agreed to the soft-delete convention. **Those deletes are
not checked**: a failure is not reported and does not abort the operation.

### OPX.SelectCharacter {#selectcharacter}

Runs the whole "I choose this one" sequence — log the old one out and wait, log
the new one in, place them, then release the readiness gate; returns a `Result`
carrying the loaded Player.

```lua
local outcome = OPX.SelectCharacter(source, citizenId)
```

- source: [`Source`](types.md#source)
- citizenId: [`CitizenId`](types.md#citizenid)
    - Parsed here.

**Returns** [`Result`](types.md#result) — ok value is the loaded
[`Player`](types.md#player).

**Errors**

| Code | Meaning |
|---|---|
| `error.tooFast` | A 1 000 ms per-source cooldown on the key `select`. |
| `character.notFound` | Unparseable id, no such character, or not theirs. |
| `character.inUse` | Loaded on another slot. |
| `error.unavailable` | The **outgoing** character could not be saved, so the switch is refused rather than made permanent. |
| every code from [`OPX.Login`](#login) | The login half. |

**Side** `server` — inside `opx77_core` only. **Yields.**

Order is the contract and every step of it is load-bearing:

1. **The target is checked before the current character is torn down.** Logging
   somebody out and only then discovering the id is not theirs left the player
   in the world with nothing loaded and nothing saving them — reachable by
   typing `/opx77.select` with any id that is not yours, no modified client
   required.
2. **The outgoing save is awaited**, not dispatched, or the read for the next
   character beats the write.
3. **A failed save refuses the switch.** Loading the next character over an
   unwritten row makes the loss permanent.
4. **The gate is released last**, and only after placement. Releasing first lets
   every other resource act on a player who is not yet where they belong, which
   is the race the gate exists to prevent.

Selecting the character that is already loaded is a no-op that returns the
current Player, checked early: on the same row the read would otherwise beat the
write and hand back pre-save values.

A placement failure does **not** fail the call. The character is logged in, the
gate is released, and the failure is logged — along with the fact that their
stored position is now frozen. See [`OPX.PlaceCharacter`](#placecharacter).

### OPX.PlaceCharacter {#placecharacter}

Puts a loaded character where they belong, by killing and respawning them;
returns `false` and a reason on every failure, leaving the stored position
frozen.

!!! danger "Placement is a kill, and it is the only correct way to move a player"

    A raw transform write skips the fade, the streaming preload and the grace
    window that the respawn transaction carries. Acting on a client that is not
    yet incarnated crashes that client, which is why this polls the life state
    five times over a second first, and why the gate is still held while it runs.

```lua
local placed, reason = OPX.PlaceCharacter(player)
```

- player: [`Player`](types.md#player)

**Returns** `boolean, string?` — `true` on success; `false` and a short
diagnostic string otherwise.

**Errors** — these are plain strings, not locale keys, and are for the log:

| Reason | Meaning |
|---|---|
| `offline` | The Player has no `source`. |
| `no-default-spawn` | No stored position and `DEFAULT_SPAWN.SET` is false. `MaySample` is turned **on** for this one failure: nothing was restored, so wherever they end up is the position. |
| `life-state-<phase>` | The platform never reported a settled life state. |
| *(a platform message)* | `Open77.players.kill` or `respawn` refused. |

**Side** `server` — inside `opx77_core` only. **Yields** — it waits up to a
second on the life state.

This is the only setter of [`MaySample`](player.md#maysample) to `true`. Every
failing exit but `no-default-spawn` leaves it `false`, which is what stops the
sampler writing "wherever the engine dropped them" over the position placement
was trying to restore. It is never turned off again: a character placed
correctly and then failing a second attempt is still standing where they belong.

If the respawn fails after the kill succeeded, a revive is attempted so the
player is not left dead. A revive leaves the body where it fell rather than
where the row says, so `MaySample` stays false and the stored position survives
for the next attempt.

Armour is applied after the transaction, because it is not a respawn option and
the body is about to be replaced. Health is scaled into `0.15`–`1.0`.

### OPX.CitizenId.parse {#citizenidparse}

Parses player input into a normalised citizen id; returns a `Result` that fails
for the wrong length, an unknown symbol or a failed checksum.

```lua
local outcome = OPX.CitizenId.parse(input)
```

- input: `any`
    - Forgiving about case, spaces, hyphens and underscores. Strict about
      content.

**Returns** [`Result`](types.md#result) — ok value is the grouped form,
`"H7K-M4X3"`.

**Errors**

| Code | Meaning |
|---|---|
| `type` | Not a string. |
| `length` | Not seven symbols after cleaning — checked before the copies, so a refusal has a fixed cost. |
| `alphabet` | A symbol outside the 23-symbol alphabet. Rejected, never dropped: dropping turns `"AO2C-D3F"` into somebody else's id. |
| `checksum` | The check symbol does not match. |

**Side** `shared` — both runtimes. Does not yield.

Use this on anything a player typed, so they learn why it was refused. See
[Identity](../../concepts/identity.md#parsing).

### OPX.CitizenId.isValid {#citizenidisvalid}

Returns whether a value is a well-formed citizen id.

```lua
if OPX.CitizenId.isValid(value) then end
```

- value: `any`

**Returns** `boolean`

**Side** `shared` — both runtimes. Does not yield.

For guarding an internal call site. On player input use
[`parse`](#citizenidparse) instead, which says which of the four things was
wrong.

Well-formed is not the same as existing: the checksum proves the id was typed
correctly, never that a character holds it.

### OPX.CitizenId.generate {#citizenidgenerate}

Draws a new citizen id.

```lua
local citizenId = OPX.CitizenId.generate(rng)
```

- rng?: `fun(low: integer, high: integer): integer`
    - Injectable so generation can be made deterministic in a test.
    - Default: `math.random`

**Returns** [`CitizenId`](types.md#citizenid)

**Side** `shared` — both runtimes. Does not yield.

!!! warning "Not unique, and not unguessable"

    It draws at random and checks nothing. Uniqueness is enforced by the primary
    key on `opx77_characters.citizen_id` — which is why
    [`OPX.CreateCharacter`](#createcharacter) retries on a duplicate rather than
    selecting first. And `math.random` is not a secure source, so an id must
    never be treated as a secret.

### OPX.CitizenId.build {#citizenidbuild}

Builds a citizen id from six payload values, appending the check symbol.

```lua
local citizenId = OPX.CitizenId.build(values)
```

- values: `integer[]`
    - Six of them; each is taken modulo the alphabet size, so any integer is
      accepted.

**Returns** [`CitizenId`](types.md#citizenid)

**Side** `shared` — both runtimes. Does not yield.

`OPX.CitizenId.ALPHABET` is the 23 symbols, in order. The modulus being prime is
what catches every single-symbol substitution and every neighbour transposition;
do not change the alphabet size or the weights.

### OPX.ValidateName {#validatename}

Validates one half of a character name against the configured bounds; returns a
`Result` that fails for the wrong type, the wrong length, malformed UTF-8 or a
disallowed character.

```lua
local outcome = OPX.ValidateName(value)
```

- value: `any`

**Returns** [`Result`](types.md#result) — ok value is the trimmed name.

**Errors**

| Code | Meaning |
|---|---|
| `type` | Not a string. |
| `too-short` | Fewer than `CHARACTERS.NAME.MIN` characters after trimming. |
| `too-long` | More than `CHARACTERS.NAME.MAX` characters — or past the byte ceiling, checked before the trim. |
| `not-utf8` | The bytes are not valid UTF-8. A client can put arbitrary bytes on the wire. |
| `format` | Did not match `OPX.NAME_PATTERN`. |

**Side** `shared` — both runtimes. Does not yield.

The pattern is a byte range rather than `%a`, which is ASCII-only and would
refuse "Éloïse". It accepts accented Latin, Greek, Cyrillic and CJK, plus a
literal space, an apostrophe and a hyphen after the first character. Four-byte
lead bytes are deliberately excluded, which is where emoji live.

Length is counted in **characters**, not bytes.

## Notifications and refusals {#notifications}

Two channels, and the distinction between them is a security decision.
[`OPX.Notify`](#notify) tells a player something. [`OPX.Refuse`](#refuse) tells
them a request was refused **and nothing else**, because a refusal that explains
itself tells an attacker which half of their guess was right.

Both are deduplicated per source: an identical message to the same player inside
2 000 ms is dropped, so a client looping a request costs one line rather than a
screenful. Two *different* refusals are two things the player has to be told, so
only exact repeats are suppressed. The window is cleared by
[`OPX.ForgetCooldowns`](#forgetcooldowns).

### OPX.Notify {#notify}

Sends a toast to one player through the server runtime's own
`Open77.notifications`; does nothing at all when nothing is installed to render
it.

```lua
OPX.Notify(source, message, kind, durationMs)
```

- source: [`Source`](types.md#source)
    - Anything `tonumber` accepts. Zero and negative are ignored.
- message: `string`
- kind?: `"info"|"success"|"warning"|"error"`
    - Default: `"info"`
- durationMs?: `integer`
    - Default: `5000`

**Returns** nothing.

**Errors** none — every failure is silent.

**Side** `server` — inside `opx77_core` only. Does not yield.

!!! warning "It degrades to nothing, on purpose"

    The core declares **no dependency** on any renderer, because a declared
    dependency is hard on this platform and the core must install on a bare
    server. If `Open77.notifications` is `nil`, this function returns having
    done nothing — no error, no log line. A flow whose only feedback is a toast
    will look broken and diagnose as silent.

    `Open77.notifications.send` itself only fires
    `open77:notifications:show` at the target. Whichever client resource
    registered that name draws the toast:
    [`opx77_notify`](../opx77_notify/index.md), the platform's own
    `open77_notifications`, or — if both are running — both of them, twice.

`title` is `OPX.Config.SHARED.SERVER_NAME` and `position` is
`SHARED.NOTIFY_POSITION` on every notification the core sends.

### OPX.NotifyLocale {#notifylocale}

Sends a toast built from a locale key, interpolating parameters into it.

```lua
OPX.NotifyLocale(source, key, params, kind)
```

- source: [`Source`](types.md#source)
- key: `string`
    - A key in the active catalogue. It is run through
      [`OPX.RefusalKey`](#refusalkey) first, so a code the catalogue does not
      carry is shown as `error.unavailable` rather than raw. A key the catalogue
      *does* carry but has not translated falls back to `en`, and then to the
      key itself, so the player sees `money.paycheck` rather than nothing.
- params?: `table<string, string|number>`
    - Substituted into `{name}` placeholders. An unknown name is left in place
      so a typo is visible.
- kind?: `"info"|"success"|"warning"|"error"`

**Returns** nothing.

**Side** `server` — inside `opx77_core` only. Does not yield.

Note that `durationMs` cannot be passed through this form — it always uses the
5 000 ms default.

### OPX.RefusalKey {#refusalkey}

Maps a code onto one the catalogue can actually render.

```lua
local key = OPX.RefusalKey(code)
```

- code: `any`

**Returns** `string` — `code` itself when
[`OPX.Locale.exists`](#localeexists) says the catalogue carries it, and
`error.unavailable` otherwise, with one warning line naming the code that was
replaced.

**Side** `server` — inside `opx77_core` only. Does not yield.

Not every code a `Result` carries is a locale key. The storage layer answers
`query-failed` and `no-database`, and a validator answers `too-short`: those are
for a log, not for a player. [`OPX.Refuse`](#refuse) and
[`OPX.NotifyLocale`](#notifylocale) both run their code through this first, so
neither channel can hand a client a key it cannot render. Call it yourself
before showing a code through any other path.

### OPX.Refuse {#refuse}

Tells a client a request was refused: which request, a stable code, and nothing
else.

```lua
OPX.Refuse(source, code, operation)
```

- source: [`Source`](types.md#source)
- code: `string`
    - A locale key. The **client** resolves it, so the server sends no text. A
      code the catalogue does not carry is replaced with `error.unavailable` by
      [`OPX.RefusalKey`](#refusalkey) before it goes out.
- operation?: `string`
    - Which request this refusal answers: a value of
      [`OPX.Operations`](#operations). Omitted, it is sent as `unknown`.

**Returns** nothing.

**Side** `server` — inside `opx77_core` only. Does not yield.

This is the right answer to almost every failed `Result`: the error code of a
`Result` is already a locale key, so
`OPX.Refuse(source, outcome.error, OPX.Operations.SELECT_CHARACTER)` is the
whole handler.

**Pass the operation.** Without it a client waiting on one request out of
several cannot tell which `error.tooFast` is its own — a refusal answering a
vehicle spawn is not the answer to a captured face still in flight. The
operation is also part of the dedupe key, so two different requests refused for
the same reason are two answers rather than one swallowed one.

It fires [`opx77:client:notify`](events.md#notify) with
`{ kind = "error", code = code, operation = operation }`. The reason is
deliberately not sent. A caller that "helpfully" replaces this with
`OPX.Notify(source, "that character belongs to someone else")` has built an
existence oracle.

### OPX.CommandNotice {#commandnotice}

Answers a chat command with what it did, or why it did not: a toast on the
player's screen, the chat line it used to be on a client without
`opx77_notify`; prints to the console when there is no source.

```lua
OPX.CommandNotice(source, raw, kind, message, toasted)
```

- source: [`Source`](types.md#source)`|nil`
    - `nil` or `0` prints to the server console instead.
- raw: `string|nil`
    - The command line as typed. Becomes `""` when `nil`.
- kind: `"success"|"warning"|"error"`
    - `warning` for what was typed wrong or run again too fast — the same
      command with the right words works — and `error` when it could not be
      done. Anything else is shown as `error`.
- message: `string`
    - Already rendered, in the configured locale. An empty one shows nothing.
- toasted?: `boolean`
    - `true` when the action already raised this same toast through
      [`OPX.Notify`](#notify): the client then raises nothing and writes the
      chat line only while `opx77_notify` is not running. Compared with
      `== true`.

**Returns** nothing.

**Side** `server` — inside `opx77_core` only. Does not yield.

Fires [`opx77:client:commandAnswer`](events.md#commandanswer) at the player,
and the core's client half raises it through `opx77_notify`'s `show`, titled
`SERVER_NAME`, at `NOTIFY_POSITION`, in one slot each answer replaces. Not on
`open77:command:result`: `opx77_chat` prints none of that event's accepted
answers, and a refusal there would be toasted under the chat's own *COMMAND*
title rather than the server's.

Unlike [`OPX.Notify`](#notify) it is not deduplicated — each command typed is
answered — and it does not depend on `Open77.notifications`, because the toast
is raised on the client. `opx77.duty` passes `toasted`, since
[`OPX.SetJobDuty`](#setjobduty) already tells the player they clocked in.

### OPX.CommandResult {#commandresult}

Answers a chat command with a report someone asked to read — a list, a dump, a
config block to copy — as a chat line; prints to the console when there is no
source.

```lua
OPX.CommandResult(source, raw, accepted, message)
```

- source: [`Source`](types.md#source)`|nil`
    - `nil` or `0` prints to the server console instead.
- raw: `string|nil`
    - The command line as typed. Kept for the signature; the chat line does not
      carry it.
- accepted: `boolean`
    - `true` draws the line as `info`, anything else as a red `error` line.
- message: `string`

**Returns** nothing.

**Side** `server` — inside `opx77_core` only. Does not yield.

Sends `chat:addMessage` to the player, authored `SERVER_NAME`, which
`opx77_chat` draws exactly as it arrives. It used to fire
`open77:command:result`; since `opx77_chat` 0.5.0 prints no accepted result on
that event, a report sent there would reach nobody. What a command *did* is
[`OPX.CommandNotice`](#commandnotice) instead — a toast is gone in five seconds,
which is right for an outcome and wrong for a list.

### OPX.IsNotifyPosition {#isnotifyposition}

Returns whether a value is one of the seven documented notification positions.

```lua
if OPX.IsNotifyPosition(position) then end
```

- position: `any`

**Returns** `boolean`

**Side** `shared` — both runtimes. Does not yield.

!!! warning "Advisory only — never drop a toast on a `false`"

    The server binary forwards `position` to `open77_notifications` without
    validating it, and that resource is not on disk, so the accepted set is known
    only from the website. A whitelist that guessed the set wrong would swallow
    every notification silently, which is far worse than an unknown position. Warn
    on `false` and send it anyway — which is what the core does.

The seven are `middle_left` (the service default), `top_left`, `top_center`,
`top_right`, `bottom_left`, `bottom_center` and `bottom_right`. The set is also
published as `OPX.NOTIFY_POSITIONS`.

## Cooldowns {#cooldowns}

Per-source rate limits, keyed by an operation name.

!!! warning "A cooldown belongs to the operation, not to a doorway onto it"

    Put it where the work is done, never at the net-event handler. Anything that
    can be driven in a loop is usually reachable from more than one place — a
    net event *and* a console command, say — and the next entry point added
    forgets the guard. `OPX.SendCharacters` cools itself for exactly this
    reason.

    They are also **not a security boundary**. They bound cost, not
    authorisation. The ownership checks in `server/character.lua` are the
    boundary.

### OPX.Cooling {#cooling}

Returns whether a source ran an operation less than a given interval ago, and
records the attempt when it did not.

```lua
if OPX.Cooling(source, key, everyMs) then return end
```

- source: [`Source`](types.md#source)
    - Zero and negative answer `false` — they are never rate-limited.
- key: `string`
    - The operation's name. Namespace your own: the table is shared across the
      whole core, so a plug-in using `"select"` fights the character switch.
- everyMs: `integer`

**Returns** `boolean` — `true` means *refuse now*.

**Side** `server` — inside `opx77_core` only. Does not yield.

The clock is [`OPX.Now()`](#now), process-monotonic milliseconds. A `true`
return does **not** record a fresh attempt, so a client hammering an operation
does not extend its own lockout indefinitely — the window still expires
`everyMs` after the last accepted call.

### OPX.ForgetCooldowns {#forgetcooldowns}

Drops every cooldown and every deduplication window held for a source.

```lua
OPX.ForgetCooldowns(source)
```

- source: [`Source`](types.md#source)

**Returns** nothing.

**Side** `server` — inside `opx77_core` only. Does not yield.

Called on departure, and it must be: a source is recycled, and a window left
behind would refuse the next player to hold that id — or swallow their first
refusal, which is the harder bug to find.

## Entry and the readiness gate {#lifecycle}

`OPX.Lifecycle` wraps the platform's `Open77.ready` gate. Read
[The entry gate](../../concepts/entry-gate.md) first: the gate is a barrier that
opens once per join, its interval is a watchdog on *this resource* rather than a
budget for the player, and on a stock OPX//77 install
[it never opens at all](../../concepts/entry-gate.md#never-opens).

### OPX.Lifecycle.hold {#lifecyclehold}

Takes the readiness-gate hold for one player and remembers the session handle;
does nothing on a host with no gate, or for a player with no session.

```lua
OPX.Lifecycle.hold(source, reason)
```

- source: [`Source`](types.md#source)
- reason?: `string`
    - Default: `"opx77_character_selection"`

**Returns** nothing.

**Side** `server` — inside `opx77_core` only. Does not yield.

The handle is stored on the [`Session`](types.md#session) as `gateSession`,
which is what keeps a release honest: releasing by a recycled
[`Source`](types.md#source) alone could clear somebody else's hold.

The core takes its hold once per join and **never refreshes it**, so the
declared liveness interval is in practice the deadline it has.

### OPX.Lifecycle.release {#lifecyclerelease}

Releases the gate for one player, asking the host for the handle when the
session does not have one; idempotent, and safe for a player who never held it.

!!! danger "A hold nobody releases stalls that player indefinitely"

    A hold is not on a clock. It is only ever broken by evidence the holder is
    gone — the resource died, was reloaded away, or stopped answering — which,
    on a core that is still running, is never. Every failure path in the entry
    sequence releases the gate rather than returning early.

```lua
OPX.Lifecycle.release(source, note)
```

- source: [`Source`](types.md#source)
- note?: `string`
    - Default: `"done"`. Prefixed with `opx77_core:` before it is sent.

**Returns** nothing.

**Side** `server` — inside `opx77_core` only. Does not yield.

The note becomes the `detail` of `onPlayerReady` in **every** running server VM,
which is the one channel this core has for telling another server resource what
happened. The notes the core itself sends are `character-placed`,
`character-loaded`, `no-identity`, `roster-failed` and `selection-timeout`. See
[the release note channel](../../concepts/integration-channels.md#release-note).

### OPX.Lifecycle.beginEntry {#lifecyclebeginentry}

Runs everything the core does for a player who has just connected: session,
hold, roster, watchdog.

```lua
OPX.Lifecycle.beginEntry(source)
```

- source: [`Source`](types.md#source)

**Returns** nothing.

**Side** `server` — inside `opx77_core` only. Does not yield — the database work
is moved onto its own thread.

Called from the platform's connection event. Every failure path releases the
gate rather than leaving the player held. The roster it sends is
`OPX.SendCharacters(source, true)`, the one send the `roster` cooldown neither
refuses nor starts — see [`OPX.SendCharacters`](#sendcharacters).

### OPX.Lifecycle.watch {#lifecyclewatch}

Starts the watchdog that gives up on a player who never chooses a character.

```lua
OPX.Lifecycle.watch(source)
```

- source: [`Source`](types.md#source)

**Returns** nothing.

**Side** `server` — inside `opx77_core` only. Does not yield; it starts a thread.

One thread per joining player, polling once a second against the `SELECTION_MS`
tunable, exiting the moment the gate is released, a character is chosen, or the
slot changes hands. On expiry it refuses with `entry.timedOut` and releases the
gate with the note `selection-timeout`.

`SELECTION_MS` is capped below the gate's liveness interval on purpose, so the
core always gives up first and can say why — rather than being declared dead by
the host with the player holding no puppet.

### OPX.Lifecycle.participate {#lifecycleparticipate}

Declares this resource a participant in the readiness gate; warns and does
nothing on a host that has no gate.

```lua
OPX.Lifecycle.participate()
```

**Returns** nothing.

**Side** `server` — inside `opx77_core` only. Does not yield.

Called once at load, from the bottom of `server/lifecycle.lua`. A plug-in has no
reason to call it again.

## Vehicles {#vehicles}

`OPX.Vehicles` owns what a character drives. The **plate** is the identity, not
the runtime id: `Open77.vehicles.create` issues a 64-bit id, and the documented
policy is that stopping or reloading a resource removes every vehicle it owns —
so the id is gone every reload while the car is not.

Configuration lives in `config/vehicles.lua` as `OPX.Config.VEHICLES`.

### OPX.Vehicles.Give {#vehiclesgive}

Gives a character a vehicle, drawing a plate and writing the row; returns a
`Result` that fails on a bad record, a full garage or an exhausted plate space.

```lua
local outcome = OPX.Vehicles.Give(citizenId, record, options)
```

- citizenId: [`CitizenId`](types.md#citizenid)
    - Not checked against a real character here — the foreign key is.
- record: `string`
    - A TweakDB record, e.g. `"Vehicle.v_standard2_archer_hella_player"`.
- options?: `{ garage?: string, appearance?: string, paint?: table, metadata?: table }`

**Returns** [`Result`](types.md#result) — ok value is the stored vehicle,
including its drawn `plate`.

**Errors**

| Code | Meaning |
|---|---|
| `error.badRequest` | `citizenId` or `record` missing or not a string. |
| `vehicle.badRecord` | The record is longer than the host's 256-character cap. |
| `vehicle.limit` | The character already owns `PER_CHARACTER` vehicles. `0` disables the ceiling. |
| `vehicle.plateExhausted` | Five draws all collided with an existing plate. |
| `query-failed` / `no-database` | The count or the insert failed. |

**Side** `server` — inside `opx77_core` only. **Yields.**

The vehicle is created **stored**, in `DEFAULT_GARAGE` — giving somebody a car
does not put it in the street.

### OPX.Vehicles.List {#vehicleslist}

Returns every vehicle a character owns.

```lua
local outcome = OPX.Vehicles.List(citizenId)
```

- citizenId: [`CitizenId`](types.md#citizenid)

**Returns** [`Result`](types.md#result) — ok value is a list of stored vehicles.

**Errors**

| Code | Meaning |
|---|---|
| `query-failed` / `no-database` | The read failed. |

**Side** `server` — inside `opx77_core` only. **Yields.**

### OPX.Vehicles.Get {#vehiclesget}

Returns one stored vehicle by plate, with whether it is out right now.

```lua
local outcome = OPX.Vehicles.Get(plateId)
```

- plateId: `string`

**Returns** [`Result`](types.md#result) — ok value is the stored vehicle with
`spawned` (`boolean`) and `id` (the runtime id, or `nil`) added.

**Errors**

| Code | Meaning |
|---|---|
| `vehicle.notFound` | No row carries that plate. |
| `query-failed` / `no-database` | The read failed. |

**Side** `server` — inside `opx77_core` only. **Yields.**

`id` is only meaningful until the next reload of `opx77_core`. Key nothing on
it.

### OPX.Vehicles.Spawn {#vehiclesspawn}

Puts a character's own vehicle into the world beside them, restoring its stored
damage; returns a `Result` that fails when the character is not loaded, the
plate is not theirs, or the host refuses the creation.

!!! danger "Ownership is proved here, against the loaded character"

    The row's `citizen_id` is compared against the character the **connection**
    has loaded — the row this VM read. There is no client claim in that
    comparison, and a mismatch answers `vehicle.notFound`, the same code a
    missing plate gets, because "somebody else's" is an existence oracle.

```lua
local outcome = OPX.Vehicles.Spawn(source, plateId)
```

- source: [`Source`](types.md#source)
- plateId: `string`

**Returns** [`Result`](types.md#result) — ok value is `{ plate, id }`.

**Errors**

| Code | Meaning |
|---|---|
| `error.notLoggedIn` | No character loaded on that connection — or the player switched character or left during the database read, in which case the vehicle that was just created is removed again. |
| `error.badRequest` | `plateId` is not a string. |
| `vehicle.notFound` | No such plate, or it belongs to another character. |
| `vehicle.noPosition` | The platform would not report where the player is. |
| `vehicle.spawnRefused` | `Open77.vehicles.create` refused; `detail` carries its reason. |
| `query-failed` / `no-database` | The read failed. |

**Side** `server` — inside `opx77_core` only. **Yields.**

Spawning a vehicle that is already out is a no-op that returns its existing id.

The stored damage is given **back** on spawn. Without that the row's damage
would be write-only, and a store-then-spawn cycle would be a free repair of
glass, lights, tyres, dents and the destroyed flag — the one thing the platform
deliberately refuses a client.

### OPX.Vehicles.Store {#vehiclesstore}

Takes a vehicle out of the world and writes back what happened to it; returns a
`Result` that fails when the vehicle is not out.

```lua
local outcome = OPX.Vehicles.Store(plateId, garage)
```

- plateId: `string`
- garage?: `string`
    - Where it belongs now. Omitted keeps the garage it had.

**Returns** [`Result`](types.md#result) — ok value is `{ plate }`.

**Errors**

| Code | Meaning |
|---|---|
| `vehicle.notSpawned` | That plate is not out right now. |

**Side** `server` — inside `opx77_core` only. **Yields.**

The snapshot is read **before** the removal, because it is gone the moment the
vehicle is. Health, damage and flags are written back; a snapshot the host will
not give up degrades to a state change only.

### OPX.Vehicles.StoreAll {#vehiclesstoreall}

Stores every vehicle a character has out and returns how many were put away.

```lua
local stored = OPX.Vehicles.StoreAll(citizenId)
```

- citizenId: [`CitizenId`](types.md#citizenid)

**Returns** `integer`

**Side** `server` — inside `opx77_core` only. **Yields.**

Called on logout and on a resource stop. A character leaving takes their cars
with them: without this they sit in the street with an owner who is not
connected, and the host removes them on the next reload anyway — with whatever
damage they took since the last save unwritten.

The plates are collected before anything yields, because a spawn landing
mid-walk would insert a key into the table being iterated, and a car skipped by
that rehash is left in the street with nobody connected.

## Storage {#storage}

`OPX.Storage` is the database. Read
[Persistence](../../concepts/persistence.md) first — the conventions below are
not stylistic, and every one of them is there because the alternative broke
something.

!!! warning "Every function in this section yields"

    Each one blocks on a database round trip. Call them from inside a
    `CreateThread`; calling one from a bare event handler raises *attempt to
    yield from outside a coroutine*, one frame away from the mistake.

Three rules for anything you write with them:

- **Named parameters, never positional `?`.** The bridge rewrites `?` by
  scanning the statement, which is also why **no SQL string in this resource
  carries a comment** — a `?` inside one is rewritten too.
- **`MySQL.<method>.await` raises rather than answering `value, reason`.** Every
  method here wraps it in `pcall` and turns it into a
  [`Result`](types.md#result), which is why none of them can take a thread down.
  Do not call the bridge directly.
- **A `nil` value is an empty result, not a failure.** `single` answers `nil` for
  "no such row", inside a `Result.ok`.

The shared error codes, which every entry below can return:

| Code | Meaning |
|---|---|
| `no-database` | The MySQL bridge is not installed, or that method is missing. |
| `query-failed` | The statement raised. `detail` carries the database exception verbatim — **staff only**, never put it on a player's screen. |

### OPX.Storage.query {#storagequery}

Runs a statement and returns every row.

```lua
local outcome = OPX.Storage.query(sql, params)
```

- sql: `string`
- params?: `table`
    - Named, matched to `@name` placeholders.

**Returns** [`Result`](types.md#result) — ok value is a list of rows, which may
be empty.

**Errors** the [shared codes](#storage).

**Side** `server` — inside `opx77_core` only. **Yields.**

### OPX.Storage.single {#storagesingle}

Runs a statement and returns the first row, or `nil` when nothing matched.

```lua
local outcome = OPX.Storage.single(sql, params)
```

- sql: `string`
- params?: `table`

**Returns** [`Result`](types.md#result) — ok value is one row, or `nil`.

**Errors** the [shared codes](#storage).

**Side** `server` — inside `opx77_core` only. **Yields.**

`outcome.ok` with `outcome.value` of `nil` means the query worked and matched
nothing. Check both.

### OPX.Storage.scalar {#storagescalar}

Runs a statement and returns one column of one row, or `nil`.

```lua
local outcome = OPX.Storage.scalar(sql, params)
```

- sql: `string`
- params?: `table`

**Returns** [`Result`](types.md#result) — ok value is the column, or `nil`.

**Errors** the [shared codes](#storage).

**Side** `server` — inside `opx77_core` only. **Yields.**

### OPX.Storage.insert {#storageinsert}

Runs an `INSERT` and returns the inserted id.

```lua
local outcome = OPX.Storage.insert(sql, params)
```

- sql: `string`
- params?: `table`

**Returns** [`Result`](types.md#result) — ok value is the inserted id.

**Errors** the [shared codes](#storage). A duplicate-key violation surfaces as
`query-failed` with the database's own message in `detail` — which is how
[`OPX.CreateCharacter`](#createcharacter) recognises a citizen-id collision and
draws again.

**Side** `server` — inside `opx77_core` only. **Yields.**

### OPX.Storage.update {#storageupdate}

Runs a statement and returns how many rows it affected; also the right method
for DDL.

```lua
local outcome = OPX.Storage.update(sql, params)
```

- sql: `string`
- params?: `table`

**Returns** [`Result`](types.md#result) — ok value is the affected row count.

**Errors** the [shared codes](#storage).

**Side** `server` — inside `opx77_core` only. **Yields.**

Zero rows affected is a **success**. An `UPDATE` whose `WHERE` matched nothing
did not fail, and if that distinction matters to you, you have to make it
yourself.

### OPX.Storage.execute {#storageexecute}

An alias for [`update`](#storageupdate), for statements whose return value
nobody reads.

```lua
local outcome = OPX.Storage.execute(sql, params)
```

- sql: `string`
- params?: `table`

**Returns** [`Result`](types.md#result)

**Errors** the [shared codes](#storage).

**Side** `server` — inside `opx77_core` only. **Yields.**

### OPX.Storage.transaction {#storagetransaction}

Runs several statements as one unit, committed or rolled back together.

```lua
local outcome = OPX.Storage.transaction(statements)
```

- statements: `({ query: string, values: table }|string)[]`

**Returns** [`Result`](types.md#result) — ok value is `true`.

**Errors**

| Code | Meaning |
|---|---|
| `no-database` | `MySQL.transaction.await` is unavailable. |
| `transaction-raised` | The call itself raised. |
| `transaction-failed` | It rolled back. `detail` carries the reason. |

**Side** `server` — inside `opx77_core` only. **Yields.**

This is the one bridge method that resolves `false, reason` instead of raising,
which is why it does not go through the same wrapper as everything else — a
generic wrapper would read a rollback as a win.

### OPX.Storage.ready {#storageready}

Returns whether the database answered, with the reason when it did not; probes
once and then caches for the life of the process.

```lua
local ready, reason = OPX.Storage.ready()
```

**Returns** `boolean, string` — `true, "ready"`, or `false` and the exception.

**Side** `server` — inside `opx77_core` only. **Yields** on the first call only.

A `false` sets `OPX.BootError`, and the core then boots but refuses to log
anybody in: running a roleplay server whose characters cannot be written back is
worse than not running one. See
[When there is no database](../../concepts/persistence.md#no-database).

### OPX.Storage.migrate {#storagemigrate}

Applies pending migrations in order and returns how many ran.

!!! danger "Never edit or rename a migration that has shipped"

    The runner keys on the migration's **name**, not its position, and it has
    already run on live databases. An edited statement never runs again there, so
    the two databases diverge silently. Append a new migration instead.

```lua
local outcome = OPX.Storage.migrate(migrations)
```

- migrations: [`Migration`](types.md#migration)`[]`
    - `OPX.Schema` is the core's own list.

**Returns** [`Result`](types.md#result) — ok value is the number applied.

**Errors**

| Code | Meaning |
|---|---|
| `migration-failed` | A statement failed. `detail` is the migration's name; the run **stops there**, because a half-applied schema is the one state neither rolling forward nor back is safe from. |
| `query-failed` / `no-database` | The migration table could not be created or read. |

**Side** `server` — inside `opx77_core` only. **Yields.**

### OPX.Schema {#schema}

The core's own migration list: `0001_users`, `0002_characters`,
`0003_character_groups`, `0004_vehicles`.

```lua
OPX.Schema --> Migration[]
```

**Side** `server` — inside `opx77_core` only.

Each entry carries a `file` naming the `sql/` copy of the same statements —
`sql/users.sql`, `sql/characters.sql`, `sql/character_groups.sql`,
`sql/vehicles.sql`. `server/storage/schema.lua` is what actually runs, because
the server runtime installs no file-reading API; `sql/` is what an operator
reads. The two are edited together, and
`python3 tools/check_sql_parity.py` exits non-zero when they drift.

Append-only. A plug-in that needs its own tables should keep its own list and
call [`OPX.Storage.migrate`](#storagemigrate) with it, rather than appending to
this one — the core's list is replaced wholesale by an upgrade.

!!! danger "A database from before the renames cannot be upgraded in place"
    `opx77_accounts`, `opx77_players` and `opx77_player_groups` were renamed
    **inside** migrations 0001–0003 rather than added as new ones, so a database
    created earlier keeps the old tables while the code queries the new names.
    The runner keys on the migration name and will not re-run one it has already
    recorded. Drop the database and let the runner recreate it: there is no
    automatic migration path and none is planned.

### OPX.Storage.Players.fetchAll {#storageplayersfetchall}

Returns every living character on an account, most recently played first.

```lua
local outcome = OPX.Storage.Players.fetchAll(userId)
```

- userId: [`UserId`](types.md#userid)

**Returns** [`Result`](types.md#result) — ok value is a list of character
entities.

**Errors** the [shared codes](#storage).

**Side** `server` — inside `opx77_core` only. **Yields.**

Never-played characters sort to the top, where the player is looking.
Soft-deleted rows are excluded.

### OPX.Storage.Players.fetchOne {#storageplayersfetchone}

Returns one character by citizen id, whoever owns it.

!!! danger "This performs no ownership check"

    It reads any character on the server. Ownership is the **caller's** job —
    compare the entity's `userId` against the session's, and answer
    `character.notFound` on a mismatch rather than anything more specific.

```lua
local outcome = OPX.Storage.Players.fetchOne(citizenId)
```

- citizenId: [`CitizenId`](types.md#citizenid)

**Returns** [`Result`](types.md#result) — ok value is the character entity.

**Errors**

| Code | Meaning |
|---|---|
| `character.notFound` | No row, or the row is soft-deleted. The statement filters `deleted_at`, so a deleted character is indistinguishable from one that never existed. |
| `query-failed` / `no-database` | The [shared codes](#storage). |

**Side** `server` — inside `opx77_core` only. **Yields.**

### OPX.Storage.Players.save {#storageplayerssave}

Writes a loaded character's entity back.

```lua
local outcome = OPX.Storage.Players.save(entity, loggedOut)
```

- entity: `table`
    - A [`PlayerData`](types.md#playerdata)-shaped table.
- loggedOut?: `boolean`
    - `true` stamps `last_logged_out`.

**Returns** [`Result`](types.md#result) — ok value is the affected row count.

**Errors** the [shared codes](#storage).

**Side** `server` — inside `opx77_core` only. **Yields.**

`citizen_id` and `user_id` are **not** in the `SET` list: an update that could
move a character to another account is how characters get stolen, so the
statement cannot express it. Neither are `jobs` and `gangs` — those live in
`opx77_character_groups`, which is their authority. `appearance` **is** written
here, so an autosave carries whatever the entity holds; the face is normally
written the moment it is committed, by
[`OPX.Storage.Players.saveAppearance`](#storageplayerssaveappearance).

Prefer [`OPX.Save`](#save), which samples the position first.

### OPX.Storage.Players.saveAppearance {#storageplayerssaveappearance}

Writes the `appearance` column, and only that column.

```lua
local written = OPX.Storage.Players.saveAppearance(citizenId, appearance)
```

- citizenId: [`CitizenId`](types.md#citizenid)
- appearance: `table|nil`
    - A canonical snapshot, already validated. `nil` clears the column, which is
      what "this character has no stored face" means.

**Returns** [`Result`](types.md#result)

**Side** `server` — inside `opx77_core` only. **Yields.**

Written the moment a face is committed rather than at the next autosave, and
scoped `WHERE citizen_id = @citizen AND deleted_at IS NULL`, so a soft-deleted
character cannot be dressed. Called only from
[`OPX.SaveAppearance`](#saveappearance), which is what validates the snapshot;
this function does not.

### OPX.Storage.Players.insert {#storageplayersinsert}

Creates a character row.

```lua
local outcome = OPX.Storage.Players.insert(entity)
```

- entity: `table`

**Returns** [`Result`](types.md#result)

**Errors** the [shared codes](#storage). A duplicate citizen id arrives as
`query-failed` with `duplicate` somewhere in `detail`.

**Side** `server` — inside `opx77_core` only. **Yields.**

Use [`OPX.CreateCharacter`](#createcharacter) instead unless you have a very
good reason: it draws the id, enforces both ceilings, writes the memberships and
rolls the row back if they fail.

### OPX.Storage.Players.softDelete {#storageplayerssoftdelete}

Marks a character row deleted without removing it.

```lua
local outcome = OPX.Storage.Players.softDelete(citizenId)
```

- citizenId: [`CitizenId`](types.md#citizenid)

**Returns** [`Result`](types.md#result)

**Errors** the [shared codes](#storage).

**Side** `server` — inside `opx77_core` only. **Yields.**

The row stays so a mistake is recoverable and so a citizen id is never reissued
to a stranger. It performs **no ownership check** and does not log the character
out — [`OPX.DeleteCharacter`](#deletecharacter) does both.

### OPX.Storage.Players.upsertAccount {#storageplayersupsertaccount}

Creates or refreshes the account row for a user id.

```lua
local outcome = OPX.Storage.Players.upsertAccount(userId, displayName)
```

- userId: [`UserId`](types.md#userid)
- displayName?: `string`

**Returns** [`Result`](types.md#result)

**Errors** the [shared codes](#storage).

**Side** `server` — inside `opx77_core` only. **Yields.**

One statement, so two connections racing cannot both insert. `display_name` is
assigned unconditionally because `ON UPDATE CURRENT_TIMESTAMP` only fires when a
column actually changes, and `last_seen_at` has to move on every login.

### OPX.Storage.Players.nextCid {#storageplayersnextcid}

Returns the lowest free character slot number on an account.

```lua
local outcome = OPX.Storage.Players.nextCid(userId, slots)
```

- userId: [`UserId`](types.md#userid)
- slots: `integer`
    - The account's ceiling.

**Returns** [`Result`](types.md#result) — ok value is the slot number, 1-based.

**Errors**

| Code | Meaning |
|---|---|
| `character.limit` | Every slot is taken. `detail` is the ceiling. |
| `query-failed` / `no-database` | The read failed. |

**Side** `server` — inside `opx77_core` only. **Yields.**

Lowest free rather than highest plus one, so a deleted slot is reused instead of
the numbers climbing past the configured limit.

### OPX.Storage.Players.countRows {#storageplayerscountrows}

Returns how many rows an account has **ever** owned, soft-deleted ones included.

```lua
local outcome = OPX.Storage.Players.countRows(userId)
```

- userId: [`UserId`](types.md#userid)

**Returns** [`Result`](types.md#result) — ok value is the count.

**Errors** the [shared codes](#storage).

**Side** `server` — inside `opx77_core` only. **Yields.**

The one read in the core that does not filter `deleted_at`. Create-delete-create
writes a new row every time, and this is what bounds it — which is why
`CHARACTER_ROWS` is a lifetime ceiling and must be kept well above
`CHARACTER_SLOTS`.

### OPX.Storage.Players.fetchGroups {#storageplayersfetchgroups}

Returns every job and gang a character belongs to, as two `name -> grade` maps.

```lua
local outcome = OPX.Storage.Players.fetchGroups(citizenId)
```

- citizenId: [`CitizenId`](types.md#citizenid)

**Returns** [`Result`](types.md#result) — ok value is
`{ jobs = table, gangs = table }`.

**Errors** the [shared codes](#storage).

**Side** `server` — inside `opx77_core` only. **Yields.**

Maps rather than lists, because every caller asks "is this character in X" and
never "what is the third one".

### OPX.Storage.Players.upsertGroup {#storageplayersupsertgroup}

Writes a membership row, promoting rather than duplicating when one already
exists.

```lua
local outcome = OPX.Storage.Players.upsertGroup(citizenId, groupType, groupName, grade)
```

- citizenId: [`CitizenId`](types.md#citizenid)
- groupType: [`GroupType`](types.md#grouptype)
- groupName: `string`
- grade: `integer`

**Returns** [`Result`](types.md#result)

**Errors** the [shared codes](#storage).

**Side** `server` — inside `opx77_core` only. **Yields.**

The composite primary key is what makes rejoining a promotion rather than a
duplicate row, rather than whichever call site remembered to check. It does not
touch `PlayerData` — prefer [`OPX.AddPlayerToJob`](#addplayertojob), which does.

### OPX.Storage.Players.removeGroup {#storageplayersremovegroup}

Deletes one membership row.

```lua
local outcome = OPX.Storage.Players.removeGroup(citizenId, groupType, groupName)
```

- citizenId: [`CitizenId`](types.md#citizenid)
- groupType: [`GroupType`](types.md#grouptype)
- groupName: `string`

**Returns** [`Result`](types.md#result)

**Errors** the [shared codes](#storage).

**Side** `server` — inside `opx77_core` only. **Yields.**

A membership that was not there is a success affecting zero rows.

### OPX.Storage.Players.membersOf {#storageplayersmembersof}

Returns everyone in a group, online or not, ordered by grade and then by name.

```lua
local outcome = OPX.Storage.Players.membersOf(groupType, groupName)
```

- groupType: [`GroupType`](types.md#grouptype)
- groupName: `string`

**Returns** [`Result`](types.md#result) — ok value is a list of
`{ citizenId, grade, name }`.

**Errors** the [shared codes](#storage).

**Side** `server` — inside `opx77_core` only. **Yields.**

!!! warning "Bounded at 200 rows, silently"

    `LIMIT 200`, with no paging and no total. An unbounded result set is a stall
    on the database worker. A larger group returns its top 200 by grade with no
    indication that anything was left out.

[`OPX.GetGroupMembers`](#getgroupmembers) wraps this and adds the group-type
check.

### OPX.Storage.Players.toEntity {#storageplayerstoentity}

Turns one raw database row into the entity shape the rest of the core passes
around.

```lua
local entity = OPX.Storage.Players.toEntity(row)
```

- row: `table|nil`
    - `nil` in, `nil` out.

**Returns** `table|nil`

**Side** `server` — inside `opx77_core` only. Does not yield.

Every JSON column gets a default, because a row written by an older core is a
shape this one has to survive. A column that fails to decode is treated as
absent rather than fatal: one corrupted character must not stop a server
booting. `appearance` defaults to `nil`, which means "never captured" rather
than "empty".

### OPX.Storage.Vehicles {#storagevehicles}

The reads and writes for `opx77_vehicles`. No policy lives here —
[`OPX.Vehicles`](#vehicles) decides.

Every function returns a [`Result`](types.md#result), can return the
[shared codes](#storage), and **yields**.

**Side** `server` — inside `opx77_core` only, every one of them. **Yields.**

| Function | Returns |
|---|---|
| `fetchByOwner(citizenId)` | Every vehicle a character owns, oldest first. |
| `fetchOne(plate)` | One vehicle, or `vehicle.notFound`. |
| `insert(entity)` | Creates a row; a duplicate plate surfaces as `query-failed`. |
| `save(entity)` | Writes health, damage, paint, garage, state and metadata back. |
| `setState(plate, state, garage)` | One column, so a state change does not carry a stale copy of everything else. `garage` is optional. |
| `delete(plate)` | Hard delete. There is no soft delete for a vehicle. |
| `countByOwner(citizenId)` | The count, for the per-character ceiling. |

`OPX.Storage.Vehicles.STATE` is `{ OUT = 0, STORED = 1, IMPOUNDED = 2 }` — a
number rather than a string, because the column is a `TINYINT` and a gamemode
can add its own states without a migration.

The `body` column is named for history and carries the **whole** damage view —
body, glass, lights, tyres, detached parts — because storing only the grid made
a store-and-respawn cycle a free repair of everything else.

## Logging {#logging}

Two systems, for two different questions.

- **`Open77.log`** is for *what the code is doing*: developer-facing, and the
  host's own logger. `Open77.log.debug`, `.info`, `.warn` and `.error` are
  called directly, everywhere, on both sides. The **host** owns the level; the
  framework has no setting for it.
- **`OPX.Logger`** is for *what an operator will be asked about later* — "who
  took 40 000 eddies out of the Valentinos account on Tuesday". Structured, one
  shape per line, greppable, and written under the prefix `[audit]`.

Both end up in the platform log and nowhere else. The runtime exposes no HTTP
client and the sandbox removes `io` and `os`, so there is no file and no
webhook. A Discord relay is not possible from inside the core.

!!! info "`OPX.Log` is gone, and so is `SHARED.LOG_LEVEL`"
    The core used to wrap `Open77.log` in a levelled `OPX.Log` with a
    `scope(name)` helper, configured by `LOG_LEVEL` in `config/shared.lua`.
    `shared/log.lua`, its manifest line, the config key and the `setLevel` calls
    are all deleted. A plug-in written against `OPX.Log.scope` calls a `nil`
    field; call `Open77.log.info` directly and put the scope in the message, the
    way the core's own files do:

    ```lua
    Open77.log.info(("[my-plugin] %s joined"):format(citizenId))
    ```

    `OPX.Logger` is unaffected. It is a different thing and it stays.

**Nothing player-facing goes through `Open77.log`.** A translated string in an
operator's log makes a support request harder to answer, not easier, so the log
stays English and the catalogue is for the player.

### OPX.Logger.log {#loggerlog}

Writes one structured audit line; ignores anything that is not a table with a
string `event`.

```lua
OPX.Logger.log(entry)
```

- entry: [`LogEntry`](types.md#logentry)

**Returns** nothing.

**Side** `server` — inside `opx77_core` only. Does not yield.

Identical entries inside a 10 000 ms window are collapsed, and the first entry
after the window reports how many it stood for — so a client looping a refusal
costs one line and a number instead of a screenful.

**Ledger entries are never collapsed.** An entry whose `event` begins `money.` or
`character.` and whose severity is `info` or `debug` is written out every time,
because six purchases in eight seconds are six answers an operator will be asked
for, not one.

### OPX.Logger.player {#loggerplayer}

Writes an audit line already carrying a character's source, citizen id and
account.

```lua
OPX.Logger.player(player, event, message, data)
```

- player: [`Player`](types.md#player)`|nil`
    - `nil` is accepted; the three identity fields are then absent.
- event: `string`
    - Stable and greppable. Prefix it with your own subsystem.
- message?: `string`
    - Truncated to 200 characters.
- data?: `table`
    - JSON-encoded into the line, truncated to 200 characters.

**Returns** nothing.

**Side** `server` — inside `opx77_core` only. Does not yield.

This is the one to use for anything an operator may later have to account for.

### OPX.Logger.security {#loggersecurity}

Writes an audit line at `warn` severity, for a refusal rather than an event.

```lua
OPX.Logger.security(event, message, data, source)
```

- event: `string`
- message?: `string`
- data?: `table`
- source?: [`Source`](types.md#source)
    - **Pass it.** Without a source the dedupe key is global per event, and one
      player looping a refusal swallows every other player's.

**Returns** nothing.

**Side** `server` — inside `opx77_core` only. Does not yield.

`Logger.security` is the only producer of `warn`, and it is the half a client
can drive — which is why it is always subject to the dedupe window, `money.` and
`character.` prefixes included.

### OPX.Logger.safe {#loggersafe}

Truncates a value and strips its control characters, returning a string safe to
put in a log line.

```lua
local text = OPX.Logger.safe(value, maximum)
```

- value: `any`
- maximum?: `integer`
    - Default: `64`

**Returns** `string`

**Side** `server` — inside `opx77_core` only. Does not yield.

!!! danger "Log injection is a real attack here"

    Anything a client chose reaches the platform log through a format string, and
    a newline inside it forges a whole log line attributed to whatever resource
    the attacker names. Put every client-supplied value through this before
    logging it.

### OPX.Logger.forget {#loggerforget}

Drops the dedupe windows held for a departing player.

```lua
OPX.Logger.forget(source, citizenId)
```

- source: [`Source`](types.md#source)
- citizenId?: [`CitizenId`](types.md#citizenid)
    - Pass it when you have it: a character logged without a source is keyed by
      its citizen id instead, which a departing source does not name.

**Returns** nothing.

**Side** `server` — inside `opx77_core` only. Does not yield.

Not what bounds the table — a periodic sweep is. This is the tidy-up for a
source that will not return.

## Tunables {#tunables}

Numbers an operator may change from the Warden panel while people are playing.
Every default comes from `config/server.lua`, and on a host with no tunables
support `OPX.Tune` silently becomes those defaults.

!!! warning "Read a tunable at the point of use, never into a file-scope local"

    `OPX.Tune` is a live proxy. A value captured in a local at load freezes for
    the life of the resource, and the operator's change appears to do nothing.
    The core's own loops re-read theirs on every interval for exactly this
    reason.

### OPX.Tune {#tune}

The live tunable values, by key.

```lua
OPX.Tune.AUTOSAVE_SECONDS
```

**Side** `server` — inside `opx77_core` only.

The six keys are `AUTOSAVE_SECONDS`, `PAYCHECK_MINUTES`,
`PAYCHECK_REQUIRES_DUTY`, `CHARACTER_SLOTS`, `CHARACTER_ROWS` and
`SELECTION_MS`. Each is documented, with its range and its shipped default, in
[Configuration](config.md).

### OPX.TuneNumber {#tunenumber}

Re-reads a numeric tunable with a floor, falling back to the shipped default
when the value is missing or not a number.

```lua
local value = OPX.TuneNumber(key, floor)
```

- key: `string`
- floor: `number`
    - Also the answer for a key with no declaration at all. Returning `nil`
      there would hand every caller a `nil` to compare against a number, which
      raises at the comparison rather than at the mistake. Every call site in
      the core passes one.

**Returns** `number`

**Side** `server` — inside `opx77_core` only. Does not yield.

The panel enforces each declaration's `min` and `max`, but a host without
tunables hands back whatever `config/server.lua` says — so the floor is not
redundant. The value is tested with
[`OPX.Math.isFinite`](#isfinite) rather than with a bare NaN check, because an
infinity passes a NaN test and freezes whichever interval it lands in.

`floor` is a **floor, not a default**: passing `5` does not mean "5 if unset", it
means "never less than 5".

## Locale {#locale}

Player-facing text. Server logs stay in English whatever the configured locale
is, deliberately: an operator reading a log and a player reading a toast are
different audiences.

### locale {#locale-fn}

Returns the text for a key in the active catalogue, with `{name}` placeholders
substituted; never returns `nil`.

```lua
local text = locale(key, params)
```

- key: `string`
- params?: `table<string, string|number>`

**Returns** `string`

**Side** `shared` — both runtimes. Does not yield.

A global shorthand for `OPX.Locale.t`, and the form every file in the core uses.
A missing translation falls back to the `en` catalogue and then to the key
itself, so a player sees `money.paycheck` rather than an empty toast — visible,
which is the point.

An unknown placeholder name is left in place, so a typo shows rather than
silently emptying.

### OPX.Locale.register {#localeregister}

Merges strings into the catalogue for a language code, so a plug-in can register
its own keys next to the code that uses them.

```lua
OPX.Locale.register(code, strings)
```

- code: `string`
    - `"en"`, `"fr"`, or whatever an operator has configured.
- strings: `table<string, string>`

**Returns** nothing.

**Side** `shared` — both runtimes. Does not yield.

Merged, not replaced, so registering does not disturb the core's own keys — but
a key you reuse **overwrites** the core's. Namespace yours.

Always register into `"en"` as well as your own language: `en` is the fallback
catalogue, and a key present only in `"fr"` shows as its raw key to everybody
else.

### OPX.Locale.set {#localeset}

Selects the catalogue player-facing text is read from; accepts a code with no
catalogue.

```lua
local applied = OPX.Locale.set(code)
```

- code: `string`

**Returns** `boolean` — `false` only for a non-string or an empty string.

**Side** `shared` — both runtimes. Does not yield.

An unknown code is accepted on purpose: catalogues register *after* this file
loads, and a code with no catalogue simply falls back to `en`.

Called once at load with `OPX.Config.SHARED.LOCALE`.

### OPX.Locale.current {#localecurrent}

Returns the active language code.

```lua
local code = OPX.Locale.current()
```

**Returns** `string`

**Side** `shared` — both runtimes. Does not yield.

### OPX.Locale.exists {#localeexists}

Returns whether a key resolves in the active catalogue or in the `en` fallback.

```lua
if OPX.Locale.exists(key) then end
```

- key: `string`

**Returns** `boolean`

**Side** `shared` — both runtimes. Does not yield.

Useful before handing a code to [`OPX.Refuse`](#refuse), which sends the key and
lets the client resolve it — a key nothing has registered reaches the player raw.

## Utility {#utility}

The shared helpers. All of these are `shared_script`s, so they exist in the
client VM too — which is why the **Side** on each says `shared`, and why none of
them touches a platform API at all.

### OPX.Result.ok {#resultok}

Wraps a value as a success.

```lua
return OPX.Result.ok(value)
```

- value: `any`
    - May be `nil`. An empty answer is still a success.

**Returns** [`Result`](types.md#result)

**Side** `shared` — both runtimes. Does not yield.

### OPX.Result.err {#resulterr}

Wraps a code as a failure.

```lua
return OPX.Result.err(code, detail)
```

- code: `string`
    - Stable, meant to be branched on, and doubling as a locale key wherever the
      failure is shown to a player. Namespace yours: `"heist.notEligible"`.
- detail?: `string`
    - **For logs and staff only.** It can carry a raw database exception.

**Returns** [`Result`](types.md#result)

**Side** `shared` — both runtimes. Does not yield.

A failure never unwinds the stack. There is nothing to `pcall`, and a caller
that ignores the return simply carries on with wrong data — which is why every
example on this site checks `.ok` first.

### OPX.Now {#now}

Returns process-monotonic milliseconds.

```lua
local now = OPX.Now()
```

**Returns** `integer`

**Side** `shared` — both runtimes. Does not yield.

!!! warning "This is not a wall clock, and there is no wall clock"

    The server sandbox removes `os`, so there is no `os.time` and no `os.date`.
    `OPX.Now()` counts from process start and resets on every restart. Never
    persist it, never compare one against a value stored before a restart, and
    never present it to a player as a date — the only real timestamps on this
    server are the database's own `TIMESTAMP` columns.

`Open77.time.monotonic()` is the same clock in **seconds**; this function
multiplies it back up in the fallback path, and prefers `GetGameTimer` where the
bootstrap installed one, which it does in every server VM.

### OPX.Table.deepCopy {#tabledeepcopy}

Returns a deep, cycle-safe copy of a value; returns non-tables unchanged.

```lua
local copy = OPX.Table.deepCopy(source)
```

- source: `any`
- seen?: `table`
    - Internal: already-copied table to its copy, so a self-referencing graph
      terminates. You do not pass this.

**Returns** `any`

**Side** `shared` — both runtimes. Does not yield.

Keys are copied too. Metatables are **not**, and neither are functions or
userdata — those are carried by reference.

This is what stops a table default in `STARTING_METADATA` becoming one table
that every character on the server shares.

### OPX.Table.count {#tablecount}

Returns the number of keys in a table, array part included.

```lua
local n = OPX.Table.count(source)
```

- source: `table`

**Returns** `integer`

**Side** `shared` — both runtimes. Does not yield.

`#` only answers for arrays. This walks, so it is O(n) — do not put it inside a
hot loop.

### OPX.Math.clamp {#clamp}

Returns a value confined to a range.

```lua
local value = OPX.Math.clamp(value, low, high)
```

- value: `number`
- low: `number`
- high: `number`

**Returns** `number`

**Side** `shared` — both runtimes. Does not yield.

It does not validate that `low <= high`; an inverted range returns `low`.

### OPX.Math.isFinite {#isfinite}

Returns whether a value is a real, finite number.

```lua
if not OPX.Math.isFinite(n) then return end
```

- value: `any`

**Returns** `boolean`

**Side** `shared` — both runtimes. Does not yield.

!!! danger "Use this on every number that came off the wire"

    `NaN` arrives through JSON from a client, `n ~= n` is the only test that
    catches it, and it passes **every** comparison — including the one that
    would stop a player spending a balance it has poisoned. Both infinities are
    refused for the same reason. The money mutators check this before anything
    else happens, and so should you.

### OPX.Math.distanceSquared {#distancesquared}

Returns the squared distance between two points.

```lua
local d2 = OPX.Math.distanceSquared(a, b)
```

- a: [`Vector3Like`](types.md#vector3like)
- b: [`Vector3Like`](types.md#vector3like)
    - A missing `z` on either is treated as `0`.

**Returns** `number`

**Side** `shared` — both runtimes. Does not yield.

Use this for every "is it within N" test and compare against `N * N`: the same
question, without the square root.

### OPX.Math.groupDigits {#groupdigits}

Returns a whole number with thousands separators.

```lua
local text = OPX.Math.groupDigits(value, separator)
```

- value: `number`
    - Truncated toward zero; the sign is preserved.
- separator?: `string`
    - Default: a space.

**Returns** `string`

**Side** `shared` — both runtimes. Does not yield.

### OPX.FormatMoney {#formatmoney}

Returns an amount formatted for display — `"12 500 €$"`.

```lua
local text = OPX.FormatMoney(amount, moneyType)
```

- amount: `number`
    - Rounded to the nearest whole unit.
- moneyType?: [`MoneyType`](types.md#moneytype)
    - `nil` and `"EDDIES"` both render with the eddies sign; any other type is
      shown with its own name appended.

**Returns** `string`

**Side** `shared` — both runtimes. Does not yield.

### OPX.IsMoneyType {#ismoneytype}

Returns whether a value names a currency this server actually has.

```lua
if not OPX.IsMoneyType(moneyType) then return end
```

- moneyType: `any`

**Returns** `boolean`

**Side** `shared` — both runtimes. Does not yield.

Resolved against `OPX.Config.SHARED.MONEY.TYPES` rather than a hard-coded list,
so a type an operator adds is accepted everywhere at once.

### OPX.String.length {#stringlength}

Returns a string's length in **characters**, or `nil` when the bytes are not
valid UTF-8.

```lua
local n = OPX.String.length(text)
```

- text: `string`

**Returns** `integer|nil`

**Side** `shared` — both runtimes. Does not yield.

The `nil` is the useful half: a client can put arbitrary bytes on the wire, and
"this is not text" is something you want to find out before you store it.

### OPX.String.trim {#stringtrim}

Returns a string with leading and trailing whitespace removed.

```lua
local text = OPX.String.trim(text)
```

- text: `string`

**Returns** `string`

**Side** `shared` — both runtimes. Does not yield.

Deliberately not `^%s*(.-)%s*$`: that backtracks once per trailing position,
which is quadratic on a long internal run of spaces. 48 KiB of them — one
envelope, one packet — is ten seconds of uninterruptible C-level matching, which
is a denial of service a client can send for free.

### OPX.String.interpolate {#stringinterpolate}

Substitutes `{name}` placeholders in a string, leaving an unknown name in place.

```lua
local text = OPX.String.interpolate(text, params)
```

- text: `string`
- params?: `table<string, any>`
    - `nil` returns the text unchanged.

**Returns** `string`

**Side** `shared` — both runtimes. Does not yield.

Leaving a typo visible is deliberate: a placeholder that silently emptied would
ship a broken sentence nobody notices.

### OPX.String.random {#stringrandom}

Builds a string from a template: `A` becomes a letter, `1` a digit, `.` either,
and anything else is copied through.

!!! danger "Not for anything a player must not guess"

    It draws from `math.random`, which is not a secure source. A phone number, a
    plate or a code produced by this is guessable. Never use it for a token, a
    password or anything that grants access.

```lua
local text = OPX.String.random(template)
```

- template: `string`
    - e.g. `"AA-1111"` → `"KP-8302"`.

**Returns** `string`

**Side** `shared` — both runtimes. Does not yield.

### OPX.Validate.text {#validatetext}

Trims a value and enforces length and an optional pattern; returns a `Result`
that fails for the wrong type, the wrong length, malformed UTF-8 or a pattern
miss.

```lua
local outcome = OPX.Validate.text(value, opts)
```

- value: `any`
- opts?: `{ min?: integer, max?: integer, pattern?: string }`
    - `min` defaults to `1`, `max` to `255`. Both are counted in **characters**.

**Returns** [`Result`](types.md#result) — ok value is the trimmed string.

**Errors**

| Code | Meaning |
|---|---|
| `type` | Not a string. `detail` names what it was. |
| `too-long` | Past the byte ceiling before the trim, or past `max` after it. |
| `too-short` | Below `min` after trimming. |
| `not-utf8` | The bytes are not valid UTF-8. |
| `format` | Did not match `pattern`. |

**Side** `shared` — both runtimes. Does not yield.

The byte ceiling is checked **first**, because trimming is the only work here
that scales with the input. It is `min(max * 4 + 16, 1024)`: a UTF-8 character
is up to four bytes, so four times `max` is the honest ceiling, and the 1 024
cap keeps a caller who passes no `max` from handing the trim a whole envelope.

Use this on everything that crosses a trust boundary — net events, command
arguments, WebUI payloads. The platform authenticates *who* sent a message,
never *what is inside it*.

### OPX.Validate.number {#validatenumber}

Coerces a value to a number and enforces finiteness, integrality and bounds;
returns a `Result` naming which check failed.

```lua
local outcome = OPX.Validate.number(value, opts)
```

- value: `any`
- opts?: `{ integer?: boolean, min?: number, max?: number }`

**Returns** [`Result`](types.md#result) — ok value is the number.

**Errors**

| Code | Meaning |
|---|---|
| `type` | `tonumber` refused it. |
| `not-finite` | `NaN` or an infinity. |
| `not-integer` | `opts.integer` was set and it has a fractional part. |
| `too-small` / `too-large` | Outside `min` / `max`. |

**Side** `shared` — both runtimes. Does not yield.

It accepts a numeric **string**, because `tonumber` does — which is usually what
you want from a command argument and rarely what you want from a JSON payload.

### OPX.Validate.oneOf {#validateoneof}

Returns a `Result` that succeeds only when a value is a key of an allowed set.

```lua
local outcome = OPX.Validate.oneOf(value, allowed)
```

- value: `any`
- allowed: `table<any, boolean>`
    - A **set**, so the check is one hash read. `{ female = true, male = true }`,
      not `{ "female", "male" }` — a list silently allows nothing.

**Returns** [`Result`](types.md#result) — ok value is the value.

**Errors**

| Code | Meaning |
|---|---|
| `not-allowed` | Not a truthy key of the set. `detail` is the value as a string. |

**Side** `shared` — both runtimes. Does not yield.

A table whose values are anything other than `true` — `OPX.Origins`, whose
values are description tables — works, because the test is truthiness.

## Namespace values {#namespace}

Not functions, but part of the surface.

### OPX.VERSION {#version}

The core's version string, `"0.3.0"`, matching `open77.lua`.

```lua
OPX.VERSION
```

**Side** `shared` — both runtimes.

### OPX.IsServer {#isserver}

`true` in the server VM. Read off `TriggerClientEvent`, a global only that
runtime has.

```lua
if OPX.IsServer then end
```

**Side** `shared` — both runtimes.

### OPX.IsClient {#isclient}

`true` in the client VM. Read off `TriggerServerEvent`.

```lua
if OPX.IsClient then end
```

**Side** `shared` — both runtimes.

Both are set from globals the bootstrap installs before any script runs — not
from `Open77.database`, which is only installed with `database.access` and would
therefore answer "not a server" on a server without it.

### OPX.Config {#config}

The merged configuration: `SHARED` everywhere, `SERVER` on the server, `CLIENT`
on the client.

```lua
OPX.Config.SHARED.MONEY.DEFAULT
OPX.Config.SERVER.PLAYER.DEFAULT_JOB
OPX.Config.VEHICLES.PLATE_FORMAT
```

**Side** `shared` — `SERVER`, `CLIENT` and `VEHICLES` each exist on one side
only, so a wrong-side read fails loudly rather than silently answering `nil`.
`config/vehicles.lua` used to fill a bare global `OPX_VEHICLES`; it fills
`OPX.Config.VEHICLES` now, and the old name is gone.

!!! danger "`SHARED` is shipped to every client in the signed resource set"

    Everything in `config/shared.lua` is public. Credentials, webhooks and admin
    identifiers belong in `config/server.lua`, which is a `server_script` and is
    never distributed.

Every key is documented in [Configuration](config.md).

### OPX.Events {#events}

Every event name the core uses, in five tables: `Platform`, `Client`, `Server`,
`Local` and `Internal`.

```lua
TriggerClientEvent(OPX.Events.Client.PLAYER_LOADED, source, playerData)
```

**Side** `shared` — both runtimes.

!!! danger "`Client` and `Local` are deliberately disjoint, and must stay so"

    On this platform a `TriggerEvent` also reaches `RegisterNetEvent` handlers of
    the same name — the dispatcher matches on the name and never looks at the
    network flag. A local re-emission that reused its own wire name would
    therefore re-enter the handler that fired it. It is tick-paced rather than
    recursive, which makes it a **silent permanent busy loop** instead of a stack
    overflow: nothing crashes and nothing is logged. Keeping the two vocabularies
    disjoint is the whole of what prevents it.

Use the constants rather than the literal strings, so a rename is one edit. Every
name, with its payload and which registration call it needs, is in
[Events](events.md).

### OPX.Operations {#operations}

The vocabulary of the `operation` argument to [`OPX.Refuse`](#refuse), and the
third argument of [`opx77:client:refused`](events.md#refused). Each value is
named after the `opx77:server:*` request that starts it.

```lua
OPX.Operations.SAVE_APPEARANCE --> "saveAppearance"
```

| Key | Value |
|---|---|
| `ENTRY` | `entry` |
| `ROSTER` | `ready` |
| `SELECT_CHARACTER` | `selectCharacter` |
| `CREATE_CHARACTER` | `createCharacter` |
| `DELETE_CHARACTER` | `deleteCharacter` |
| `SAVE_APPEARANCE` | `saveAppearance` |
| `SPAWN_VEHICLE` | `spawnVehicle` |
| `STORE_VEHICLE` | `storeVehicle` |

**Side** `shared` — both runtimes.

A **satellite cannot import this table**: it lives in the core's own Lua state,
and the runtime installs no cross-resource way to read it. A satellite that
branches on an operation compares the string literal, and the values above are
where it comes from.

### OPX.BootError {#booterror}

A string explaining why the core cannot load characters, or `nil` when it can.

```lua
if OPX.BootError then return end
```

**Side** `server` — inside `opx77_core` only.

Set at boot when there is no database, or when a migration failed. The core
still starts — refusing to boot would take the whole server down over a
recoverable problem — but every entry point checks this and answers
`error.unavailable`. A plug-in that touches the database should check it too.

### OPX.NAME_PATTERN {#namepattern}

The Lua pattern a character name must match.

```lua
OPX.NAME_PATTERN
```

**Side** `shared` — both runtimes.

A byte range rather than `%a`, which is ASCII-only and would refuse "Éloïse".
It requires a letter first, then letters, literal spaces, apostrophes and
hyphens. Four-byte lead bytes are excluded, which is where emoji live.

### OPX.NOTIFY_POSITIONS {#notifypositions}

The seven documented notification positions, as a set.

```lua
OPX.NOTIFY_POSITIONS.top_right --> true
```

**Side** `shared` — both runtimes.

A set rather than a list, because the only thing anyone asks is whether a value
is in it. See [`OPX.IsNotifyPosition`](#isnotifyposition) for why it is advisory
rather than enforced.

## Where to go next {#next}

- [Writing a server plugin](../../guides/writing-a-server-plugin.md) — the file
  every function here is called from, and how to keep it upgradeable.
- [Player](player.md) — the `Player` object and its bound `Functions`.
- [Hooks](hooks.md) — refusing an operation without editing the file that
  performs it.
- [Types](types.md) — the shape of every value on this page.
- [Events](events.md) — what the core emits when these functions succeed.
- [Configuration](config.md) — every key and tunable they read.
- [Integration channels](../../concepts/integration-channels.md) — what remains
  when you cannot add a file to the core.
