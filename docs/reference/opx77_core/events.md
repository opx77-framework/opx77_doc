---
title: opx77_core events
description: Every event name opx77_core sends, fires or listens for — the networked server-to-client wire, the permission-free client-local channel, the client-to-server doorways, the resource-internal names and the platform events the core handles — with payloads and the registration call each one needs.
---

# Events

Event names live in one place, `shared/main.lua`'s `OPX.Events`, and are named
`opx77:<side>:<subject>`. There are five vocabularies, and which one you use
decides both the registration call you write and the permission your manifest
needs.

| Table | Names | Registration | Permission |
|---|---|---|---|
| [`Client`](#networked-server-to-client) — networked, server → client | 10 | `RegisterNetEvent` | `network.events` |
| [`Local`](#client-local) — client-local, fired by the core's own client half | 9 | `AddEventHandler` | none |
| [`Server`](#networked-client-to-server) — networked, client → server | 8 | `TriggerServerEvent` from a client | `network.events` |
| [`Internal`](#resource-internal) — inside the core's server VM only | 7 | `AddEventHandler`, in a file inside the core | none |
| [`Platform`](#platform) — raised by the host, handled by the core | 8 | — | — |

## Which channel a satellite should use {#choosing}

**Prefer `Local`.** It is fired by the core's client half immediately *after*
the mirrored state has been updated, so a handler woken by one can read
`GetPlayerData` and see the change that woke it rather than the value it
replaced. It needs no permission at all, because the client's local event bus is
**host-wide** — the platform's own resources rely on exactly this, with
`open77_zones` firing a caller-supplied name and `pursuit` receiving it with a
bare `AddEventHandler`.

Take `Client` instead when you want the payload before the core's mirror has
been updated, or when you are not running the core's client half at all. It
costs `network.events` in your manifest and is otherwise identical in content.

!!! warning "The two vocabularies are deliberately disjoint, and must stay that way"
    No name appears in both tables. On this platform a `TriggerEvent` also
    reaches `RegisterNetEvent` handlers of the same name — the dispatcher
    matches on the name and never looks at the network flag — so re-emitting a
    wire name from inside its own handler re-enters the handler that fired it.
    It is tick-paced rather than recursive, which makes it a **silent permanent
    busy loop** instead of a stack overflow: nothing crashes and nothing is
    logged. `playerLoaded` and `playerUnloaded` used to do exactly that.
    If you republish one of these, republish under a name of your own.

---

## Networked (server → client) {#networked-server-to-client}

The wire. Sent by the core's server half with `TriggerClientEvent`, to the one
client the change belongs to. A listener declares `network.events` and
registers with `RegisterNetEvent`.

| Event | Payload |
|---|---|
| [`opx77:client:characters`](#characters) | the selection roster |
| [`opx77:client:playerLoaded`](#playerloaded) | the whole `PlayerData` |
| [`opx77:client:playerUnloaded`](#playerunloaded) | nothing |
| [`opx77:client:setPlayerData`](#setplayerdata) | the whole `PlayerData` |
| [`opx77:client:onMoneyChange`](#onmoneychange) | type, amount, action, balance |
| [`opx77:client:onJobUpdate`](#onjobupdate) | the new `PlayerJob` |
| [`opx77:client:onGangUpdate`](#ongangupdate) | the new `PlayerGang` |
| [`opx77:client:onAppearanceUpdate`](#onappearanceupdate) | the stored `AppearanceSnapshot` |
| [`opx77:client:notify`](#notify) | a refusal code, and the request it answers |
| [`opx77:client:commandAnswer`](#commandanswer) | a command's outcome, already worded |

### opx77:client:characters {#characters}

Carries the selection roster, sent on join, on a client re-announcing itself,
and after any change to the character list.

```lua
RegisterNetEvent("opx77:client:characters", function(payload) end)
```

- payload: `table`
    - characters: [`CharacterSummary[]`](types.md#charactersummary)
    - slots: `integer` — how many characters this account may hold.
    - origins: `table` — the lifepath definitions.

**Side** `client` — any resource holding `network.events`. The core's own client
half also handles it, validates it and re-fires
[`opx77:client:charactersReady`](#charactersready).

### opx77:client:playerLoaded {#playerloaded}

Fires when a character has been loaded onto this connection, carrying the whole
`PlayerData`.

!!! warning
    It is sent at the end of the **login**, which is before the character has
    been placed and before the readiness gate is released. Do not read a
    position from it and do not act on the world in its handler: the player is
    about to be killed and respawned where the core says they belong.

```lua
RegisterNetEvent("opx77:client:playerLoaded", function(playerData) end)
```

- playerData: [`PlayerData`](types.md#playerdata)

It is also re-sent, alone, to a client that re-announces itself while a
character is already loaded — a core reload, most often — because re-opening the
selection screen over a live character would be wrong.

!!! warning
    Everything in this payload is the server's belief at the moment it was sent.
    Once it is in the client VM it is a hint, not proof.

**Side** `client` — any resource holding `network.events`.

### opx77:client:playerUnloaded {#playerunloaded}

Fires when the character leaves the world — a logout, a character switch or a
disconnect. Carries nothing: there is nothing left to describe.

```lua
RegisterNetEvent("opx77:client:playerUnloaded", function() end)
```

Takes no arguments.

**Side** `client` — any resource holding `network.events`.

### opx77:client:setPlayerData {#setplayerdata}

Fires whenever any field of the loaded character changes. Carries the **whole**
`PlayerData`, not a patch.

```lua
RegisterNetEvent("opx77:client:setPlayerData", function(playerData) end)
```

- playerData: [`PlayerData`](types.md#playerdata)

Whole rather than a patch because a merge protocol is a class of bug where the
two copies drift and neither can tell. It is sent by every mutator in the core —
money, job, gang, metadata, charinfo — so a resource that only needs to know
"something changed" should listen to this one and nothing else.

!!! warning
    This is the noisiest event in the framework. It fires on every money
    movement and every metadata write, so do not do expensive work in the
    handler without comparing what you care about first.

**Side** `client` — any resource holding `network.events`. The permission-free
equivalent is [`opx77:client:playerDataChanged`](#playerdatachanged).

### opx77:client:onMoneyChange {#onmoneychange}

Fires when a balance moves, carrying the delta and the balance it landed on.

```lua
RegisterNetEvent("opx77:client:onMoneyChange", function(moneyType, amount, action, balance) end)
```

- moneyType: `string`
- amount: `integer` — always positive; `action` says which way it went.
- action: `string` — `add`, `remove` or `set`.
- balance: `integer` — the balance after the change.

A `set` carries the value it was set to as `amount`, which is the one case where
`amount` and `balance` are the same number.

**Side** `client` — any resource holding `network.events`. Not sent for an
offline character: there is no client to send it to.

### opx77:client:onJobUpdate {#onjobupdate}

Fires when the primary job or the duty flag changes.

```lua
RegisterNetEvent("opx77:client:onJobUpdate", function(job) end)
```

- job: [`PlayerJob`](types.md#playerjob) — the resolved job, including `grade.level` and `onDuty`.

**Side** `client` — any resource holding `network.events`.

### opx77:client:onGangUpdate {#ongangupdate}

Fires when the primary gang changes.

```lua
RegisterNetEvent("opx77:client:onGangUpdate", function(gang) end)
```

- gang: [`PlayerGang`](types.md#playergang)

**Side** `client` — any resource holding `network.events`.

### opx77:client:onAppearanceUpdate {#onappearanceupdate}

Fires when the core has stored a new face for the live character.

```lua
RegisterNetEvent("opx77:client:onAppearanceUpdate", function(snapshot) end)
```

- snapshot: [`AppearanceSnapshot`](types.md#appearancesnapshot) — the canonical
  form the core wrote, not the one the client sent.

Sent only to the character's own client, and only when the write actually
happened: a capture identical to the stored face is skipped, so a confirm that
changed nothing raises nothing. The core's client half mirrors it onto
`PlayerData.appearance` and re-fires it as
[`opx77:client:appearanceSaved`](#appearancesaved).

**Side** `client` — any resource holding `network.events`.

### opx77:client:notify {#notify}

Carries a refusal: which request it answers, a stable code, and nothing else.

```lua
RegisterNetEvent("opx77:client:notify", function(payload) end)
```

- payload: `table`
    - code: `string` — a locale key, so `locale(code)` renders it in the
      player's language. A code the catalogue does not carry is replaced with
      `error.unavailable` before it is sent, so this channel never hands a
      client something it cannot render.
    - kind: `string` — `error` in every case the core currently sends.
    - operation: `string` — a value of `OPX.Operations`, naming the request this
      refusal answers: `entry`, `ready`, `selectCharacter`, `createCharacter`,
      `deleteCharacter`, `saveAppearance`, `spawnVehicle` or `storeVehicle`.
      `unknown` when the refusal names none.

The reason behind the code is deliberately not sent: a refusal that explains
itself tells an attacker which half of the guess was right. Repeats of the same
code to the same player inside a short window are suppressed at the source — the
operation is part of that dedupe key, so two different requests refused for the
same reason are still two answers.

**Side** `client` — any resource holding `network.events`. The permission-free
equivalent is [`opx77:client:refused`](#refused).

### opx77:client:commandAnswer {#commandanswer}

Carries what a command this player typed did, or why it did not, for the core's
client half to show. Sent by
[`OPX.CommandNotice`](server-api.md#commandnotice).

```lua
RegisterNetEvent("opx77:client:commandAnswer", function(raw, kind, message, toasted) end)
```

- raw: `string` — the command line as typed; `""` when the server had none.
- kind: `string` — `success`, `warning` or `error`. Anything else is shown as
  `error`.
- message: `string` — already in the configured locale. An empty one is
  dropped.
- toasted: `boolean` — `true` when the action already raised the same toast
  itself, through [`OPX.Notify`](server-api.md#notify).

The core's client half raises it as a toast through `opx77_notify`'s `show`,
titled `SERVER_NAME`, at `NOTIFY_POSITION`, in the one slot
`opx77_core.command` that each answer replaces — a player retrying a command
sees one answer, not a stack. While `opx77_notify` is not running, or when it
refuses the toast, the same text is a `chat:addMessage` line authored
`SERVER_NAME`, and the client log says so once. With `toasted` set, nothing is
raised and the chat line is written only while `opx77_notify` is not running:
`opx77.duty` is answered this way, because `OPX.SetJobDuty` already toasts.

A report — a list, a dump — never comes on this event: it is a chat line sent
from the server with [`OPX.CommandResult`](server-api.md#commandresult).

**Side** `client` — the core's own client half. No `Local` equivalent is fired.

---

## Non-networked: the client-local channel {#client-local}

Fired by the core's **client** half with `TriggerEvent`, after the mirror has
been updated. Register with a plain `AddEventHandler`, from any resource, with
**no permission at all**: the client's local event bus is host-wide.

| Event | Payload |
|---|---|
| [`opx77:client:charactersReady`](#charactersready) | the mirrored roster |
| [`opx77:client:onPlayerLoaded`](#onplayerloaded) | the whole `PlayerData` |
| [`opx77:client:onPlayerUnloaded`](#onplayerunloaded) | nothing |
| [`opx77:client:playerDataChanged`](#playerdatachanged) | the whole `PlayerData` |
| [`opx77:client:moneyChanged`](#moneychanged) | type, amount, action, balance |
| [`opx77:client:jobChanged`](#jobchanged) | the new `PlayerJob` |
| [`opx77:client:gangChanged`](#gangchanged) | the new `PlayerGang` |
| [`opx77:client:appearanceSaved`](#appearancesaved) | the stored `AppearanceSnapshot` |
| [`opx77:client:refused`](#refused) | a refusal code, its kind and its operation |

### opx77:client:charactersReady {#charactersready}

Fires when a fresh selection roster has been stored in the client mirror.

```lua
AddEventHandler("opx77:client:charactersReady", function(characters) end)
```

- characters: `table`
    - list: [`CharacterSummary[]`](types.md#charactersummary)
    - slots: `integer`
    - origins: `table`

The argument is the core's own `OPX.Characters` table, the same one
[`GetCharacters`](exports/client.md#getcharacters) reads. Treat it as read-only;
the core replaces its fields, never the table.

**Side** `client` — any resource, no permission. Fires only in a session that is
running the core's client half.

### opx77:client:onPlayerLoaded {#onplayerloaded}

Fires when a character has been loaded, after the mirror has been filled in —
which is at the end of the login, before placement has run.

```lua
AddEventHandler("opx77:client:onPlayerLoaded", function(playerData) end)
```

- playerData: [`PlayerData`](types.md#playerdata)

This is the release note for a selection UI: it is what tells you
[`SelectCharacter`](exports/client.md#selectcharacter) succeeded.

!!! warning
    The payload is a copy of the server's belief, living in the player's own
    process. It is a hint, not proof.

**Side** `client` — any resource, no permission.

### opx77:client:onPlayerUnloaded {#onplayerunloaded}

Fires when the character has left the world and the mirror has been emptied.

```lua
AddEventHandler("opx77:client:onPlayerUnloaded", function() end)
```

Takes no arguments. `OPX.IsLoggedIn` is already `false` and `PlayerData` is
already `{}` when it fires, so a handler that clears a UI can do so
unconditionally.

**Side** `client` — any resource, no permission.

### opx77:client:playerDataChanged {#playerdatachanged}

Fires whenever any field of the loaded character changes, carrying the whole
`PlayerData` — the most-used event in the framework, and the one most satellites
should be built on.

```lua
AddEventHandler("opx77:client:playerDataChanged", function(playerData) end)
```

- playerData: [`PlayerData`](types.md#playerdata)

The mirror has already been updated when this fires, so a handler may equally
call [`GetPlayerData`](exports/client.md#getplayerdata) and get the same value.
Both `opx77_hud` and `opx77_elevators` adopt the argument directly and redraw.

!!! warning
    Whole, not a patch, and noisy: every money movement and every metadata write
    produces one. Compare the field you care about before doing expensive work
    in the handler.

**Side** `client` — any resource, no permission. The networked equivalent is
[`opx77:client:setPlayerData`](#setplayerdata).

### opx77:client:moneyChanged {#moneychanged}

Fires when a balance moves, after the mirrored balance has been updated.

```lua
AddEventHandler("opx77:client:moneyChanged", function(moneyType, amount, action, balance) end)
```

- moneyType: `string`
- amount: `integer` — always positive.
- action: `string` — `add`, `remove` or `set`.
- balance: `integer` — the balance after the change.

**Side** `client` — any resource, no permission.

### opx77:client:jobChanged {#jobchanged}

Fires when the primary job or the duty flag changes, after the mirrored job has
been replaced.

```lua
AddEventHandler("opx77:client:jobChanged", function(job) end)
```

- job: [`PlayerJob`](types.md#playerjob)

!!! warning
    A job read on the client is a hint. Gate a menu on it; re-derive anything
    that must be unforgeable inside the core.

**Side** `client` — any resource, no permission.

### opx77:client:gangChanged {#gangchanged}

Fires when the primary gang changes, after the mirrored gang has been replaced.

```lua
AddEventHandler("opx77:client:gangChanged", function(gang) end)
```

- gang: [`PlayerGang`](types.md#playergang)

!!! warning
    A gang read on the client is a hint, not proof.

**Side** `client` — any resource, no permission.

### opx77:client:appearanceSaved {#appearancesaved}

Fires when the core has stored a new face and the mirror carries it, so a
handler can read `GetAppearance` and see it.

```lua
AddEventHandler("opx77:client:appearanceSaved", function(snapshot) end)
```

- snapshot: [`AppearanceSnapshot`](types.md#appearancesnapshot)

The local re-emission of
[`opx77:client:onAppearanceUpdate`](#onappearanceupdate). Nothing is raised for
a capture identical to the stored face, because the core writes nothing for one.

**Side** `client` — any resource, no permission.

### opx77:client:refused {#refused}

Fires when the server refused something this client asked for.

```lua
AddEventHandler("opx77:client:refused", function(code, kind, operation) end)
```

- code: `string` — a locale key. Render it with
  [`Locale`](exports/client.md#locale), or with `locale(code)` inside the core.
  A code the catalogue does not carry never reaches here: the core maps it to
  `error.unavailable` first.
- kind: `string` — `error` in every case the core currently sends.
- operation: `string` — which request this refusal answers, from
  `OPX.Operations`: `entry`, `ready`, `selectCharacter`, `createCharacter`,
  `deleteCharacter`, `saveAppearance`, `spawnVehicle` or `storeVehicle`, and
  `unknown` when the refusal names none.

This is the failure half of every character-screen request: the export said the
request was sent, and this says the server would not do it. Common codes are
`character.notFound`, `character.inUse`, `character.badName`, `error.tooFast`,
`entry.timedOut` and `entry.failed`.

**Branch on `operation`, not on the code.** A client waiting on one request out
of several cannot otherwise tell whose `error.tooFast` it is holding — an
`error.tooFast` raised by a vehicle spawn is not the answer to a captured face
still in flight. `OPX.Operations` lives in the core's own VM and a satellite
cannot import it, so a satellite compares the string; the values are the eight
above and they are named after the `opx77:server:*` request that starts them.

**Side** `client` — any resource, no permission.

---

## Networked (client → server) {#networked-client-to-server}

The doorways. A client sends these with `TriggerServerEvent`; the core's server
half validates every one of them.

!!! danger "Every payload here is attacker-controlled"
    Only `source` cannot be forged. The core takes the account from the session
    keyed on `source` and never from the payload, re-checks ownership against
    the database, and re-derives every position it stores. If you copy one of
    these handlers, copy that habit with it.

| Event | Payload | Cooldown |
|---|---|---|
| [`opx77:server:ready`](#server-ready) | none | 2 s |
| [`opx77:server:selectCharacter`](#selectcharacter) | `{ citizenId }` | 1 s |
| [`opx77:server:createCharacter`](#createcharacter) | the registration | 1 s |
| [`opx77:server:deleteCharacter`](#deletecharacter) | `{ citizenId }` | 1 s |
| [`opx77:server:reportPosition`](#reportposition) | `{ heading }` | 1 s |
| [`opx77:server:saveAppearance`](#saveappearance) | `{ snapshot }` | 2 s |
| [`opx77:server:spawnVehicle`](#spawnvehicle) | `{ plate }` | 3 s |
| [`opx77:server:storeVehicle`](#storevehicle) | `{ plate }` | 3 s |

Every doorway checks its cooldown **before** spawning a thread. A modified
client can send one of these thirty-two times a second, and a thread spawned per
message spends the host's 1 024-task budget — shared with the autosave and with
every login — before any of the validation inside the thread gets a say.

### opx77:server:ready {#server-ready}

The client announcing itself, which is what refills the roster after a reload:
`onPlayerConnected` does not re-fire for players who are already here.

```lua
TriggerServerEvent("opx77:server:ready")
```

Takes no arguments. Answered with [`opx77:client:characters`](#characters), or
with [`opx77:client:playerLoaded`](#playerloaded) if a character is already
loaded.

**Side** `net event` — sent from a client resource holding `network.events`.
[`RequestCharacters`](exports/client.md#requestcharacters) is the export that
sends it for you.

### opx77:server:selectCharacter {#selectcharacter}

Asks to enter the world as one of the caller's own characters.

```lua
TriggerServerEvent("opx77:server:selectCharacter", { citizenId = citizenId })
```

- payload: `table`
    - citizenId: `string` — ownership is re-checked against the database.

Answered with [`opx77:client:playerLoaded`](#playerloaded), or refused with
[`opx77:client:notify`](#notify).

**Side** `net event` — `network.events`. Prefer
[`SelectCharacter`](exports/client.md#selectcharacter).

### opx77:server:createCharacter {#createcharacter}

Asks to create a character on the caller's own account.

```lua
TriggerServerEvent("opx77:server:createCharacter", registration)
```

- registration: `table` — `firstName`, `lastName`, `origin`, `gender`, `birthDate`.
  Every field is validated server-side against the same rules the client half
  applies.

Answered with a fresh [`opx77:client:characters`](#characters), or refused with
[`opx77:client:notify`](#notify).

**Side** `net event` — `network.events`. Prefer
[`CreateCharacter`](exports/client.md#createcharacter).

### opx77:server:deleteCharacter {#deletecharacter}

Asks to delete one of the caller's own characters.

```lua
TriggerServerEvent("opx77:server:deleteCharacter", { citizenId = citizenId })
```

- payload: `table`
    - citizenId: `string`

!!! danger
    A refused delete is audited, and an accepted one takes every row in
    `CASCADE_TABLES` with it for real. Do not wire this to anything a stray
    keypress reaches.

**Side** `net event` — `network.events`. Prefer
[`DeleteCharacter`](exports/client.md#deletecharacter).

### opx77:server:reportPosition {#reportposition}

Reports the caller's heading. Sent by the core's own client loop; nothing else
should send it.

```lua
TriggerServerEvent("opx77:server:reportPosition", { heading = yaw })
```

- payload: `table`
    - heading: `number` — accepted between −360 and 360, and ignored otherwise.

Only the heading is kept, because the server's own position snapshot carries
none. `x`, `y` and `z` are re-derived at save time, so a client that lies about
them lies to nobody.

**Side** `net event` — `network.events`.

### opx77:server:saveAppearance {#saveappearance}

Commits a captured face for the live character. Sent by
[`opx77_appearance`](../opx77_appearance/index.md) once the player has confirmed
the mirror; nothing else should send it.

```lua
TriggerServerEvent("opx77:server:saveAppearance", { snapshot = snapshot })
```

- payload: `table`
    - snapshot: [`AppearanceSnapshot`](types.md#appearancesnapshot) — the
      capture. A bare snapshot with no `snapshot` key is accepted too.

The character comes from the connection and never from the payload, and the
snapshot is put into canonical form before anything is written: an unknown
schema version, a game build outside
`OPX.Config.SHARED.APPEARANCE.GAME_BUILDS`, a bad catalogue digest, a sparse or
oversized option array, a duplicate option or an out-of-range index are each
refused. An encoded document over `APPEARANCE.MAX_JSON_BYTES` is refused with
`appearance.tooLarge`.

A snapshot identical to the stored one is accepted and **written nowhere**: no
column is touched, and neither
[`opx77:client:onAppearanceUpdate`](#onappearanceupdate) nor
[`opx77:player:appearanceChange`](#internal-appearancechange) is raised. A
caller waiting for one of those on an unchanged confirm waits forever, which is
why `opx77_appearance` completes that case on the client.

Refusals arrive as [`opx77:client:notify`](#notify) with `operation` set to
`saveAppearance`, so the six codes that path answers with —
`appearance.invalid`, `appearance.tooLarge`, `error.badRequest`,
`error.notLoggedIn`, `error.tooFast` and `error.unavailable` — can be told apart
from a refusal answering some other request.

**Side** `net event` — `network.events`.

### opx77:server:spawnVehicle {#spawnvehicle}

Asks for one of the caller's own vehicles to be spawned.

```lua
TriggerServerEvent("opx77:server:spawnVehicle", { plate = plateId })
```

- payload: `table`
    - plate: `string` — the durable identity of the vehicle. The runtime id is
      not durable: a reload removes every vehicle this resource owns.

Ownership comes from the row, and the character from the connection. Refusals
arrive on [`opx77:client:notify`](#notify) with codes such as
`vehicle.notFound`, `vehicle.limit` or `vehicle.spawnRefused`.

**Side** `net event` — `network.events`.

### opx77:server:storeVehicle {#storevehicle}

Asks for one of the caller's own vehicles to be put away, writing its condition
back.

```lua
TriggerServerEvent("opx77:server:storeVehicle", { plate = plateId })
```

- payload: `table`
    - plate: `string`

Ownership is checked before anything is taken off the world: `live` is keyed by
plate, and a player could otherwise store somebody else's car by naming its
plate.

**Side** `net event` — `network.events`.

---

## Non-networked: resource-internal {#resource-internal}

Fired with `TriggerEvent` inside the core's **server** VM, and heard there only.
A server `TriggerEvent` walks its own VM and no further, so these are reachable
from a file added to `opx77_core/server/` and from nowhere else — which is the
point of them.

| Event | Payload |
|---|---|
| [`opx77:player:loaded`](#internal-playerloaded) | `source`, `playerData` |
| [`opx77:player:unloaded`](#internal-playerunloaded) | `source`, `playerData` |
| [`opx77:player:moneyChange`](#internal-moneychange) | seven values, below |
| [`opx77:player:jobUpdate`](#internal-jobupdate) | `source`, `job` |
| [`opx77:player:gangUpdate`](#internal-gangupdate) | `source`, `gang` |
| [`opx77:player:appearanceChange`](#internal-appearancechange) | `source`, `citizenId`, `snapshot` |
| [`opx77:player:paycheck`](#internal-paycheck) | `source`, `amount`, `jobName` |

### opx77:player:loaded {#internal-playerloaded}

Fires inside the core's server VM at the end of a login, before the character
has been placed.

```lua
AddEventHandler("opx77:player:loaded", function(source, playerData) end)
```

- source: `integer`
- playerData: [`PlayerData`](types.md#playerdata)

**Side** `server` — inside `opx77_core` only. Not reachable from another
resource, in either direction.

### opx77:player:unloaded {#internal-playerunloaded}

Fires inside the core's server VM when a character has been logged out — a
switch, a disconnect or a shutdown.

```lua
AddEventHandler("opx77:player:unloaded", function(source, playerData) end)
```

- source: `integer`
- playerData: [`PlayerData`](types.md#playerdata) — the character as it was, so
  a handler can still read its citizen id.

The core's own vehicle file listens on this one to put a departing character's
cars away.

**Side** `server` — inside `opx77_core` only.

### opx77:player:moneyChange {#internal-moneychange}

Fires inside the core's server VM whenever a balance moves, online or offline.

```lua
AddEventHandler("opx77:player:moneyChange",
  function(source, citizenId, moneyType, amount, action, reason, balance) end)
```

- source: `integer|nil` — **nil for an offline character**, honestly so.
- citizenId: `string` — the field to key on, for that reason.
- moneyType: `string`
- amount: `integer` — always positive.
- action: `string` — `add`, `remove` or `set`.
- reason: `string|nil` — whatever the caller passed, as written to the audit log.
- balance: `integer` — the balance after the change.

**Side** `server` — inside `opx77_core` only.

### opx77:player:jobUpdate {#internal-jobupdate}

Fires inside the core's server VM when a primary job or duty flag changes.

```lua
AddEventHandler("opx77:player:jobUpdate", function(source, job) end)
```

- source: `integer|nil` — nil for an offline character.
- job: [`PlayerJob`](types.md#playerjob)

**Side** `server` — inside `opx77_core` only.

### opx77:player:gangUpdate {#internal-gangupdate}

Fires inside the core's server VM when a primary gang changes.

```lua
AddEventHandler("opx77:player:gangUpdate", function(source, gang) end)
```

- source: `integer|nil` — nil for an offline character.
- gang: [`PlayerGang`](types.md#playergang)

**Side** `server` — inside `opx77_core` only.

### opx77:player:appearanceChange {#internal-appearancechange}

Fires inside the core's server VM after a face has been written to the character
row.

```lua
AddEventHandler("opx77:player:appearanceChange", function(source, citizenId, snapshot) end)
```

- source: `integer|nil` — nil for an offline character.
- citizenId: [`CitizenId`](types.md#citizenid)
- snapshot: [`AppearanceSnapshot`](types.md#appearancesnapshot) — canonical form.

Raised only when the column actually changed; a capture identical to the stored
face is written nowhere and announced nowhere.

**Side** `server` — inside `opx77_core` only.

### opx77:player:paycheck {#internal-paycheck}

Fires inside the core's server VM after a paycheck has been paid — after the
money landed, so it is a record rather than a decision.

```lua
AddEventHandler("opx77:player:paycheck", function(source, amount, jobName) end)
```

- source: `integer`
- amount: `integer` — what was actually paid, into the money type
  `SERVER.MONEY.PAYCHECK_TYPE` names (`BANK` as shipped; a name that is not a
  money type falls back to `SHARED.MONEY.DEFAULT`, with one warning at boot).
- jobName: `string`

To *veto* a paycheck rather than observe one, use the `paycheck:before`
[hook](hooks.md): this event has already spent the money.

**Side** `server` — inside `opx77_core` only.

---

## Platform events the core handles {#platform}

Raised by the host, not by OPX//77. The set of names a host fans into a VM is
closed and hard-coded: a framework cannot add one. Listed here so there is one
place to look when the platform moves them.

| Event | Side | What the core does with it |
|---|---|---|
| `onPlayerConnected` | server | Begins entry: makes the session, takes the readiness hold, sends the roster. Arguments arrive as `(rawPlayerId, playerName)` and the id is a **string**, because the bare `source` global is populated only for network events. |
| `onPlayerDisconnected` | server | Logs the character out, forgets the session and clears the per-source cooldowns. The only departure event this platform raises. |
| `onPlayerReady` | server | The readiness gate opened. Read for its `detail` note. |
| `onClientResourceStart` | client | The core's client half announces itself and re-requests the roster. This is what makes a core reload survivable. |
| `open77:worldReady` | client | Announces again, because a client can start before the world is up. |
| `onResourceStop` | server | Dispatches a best-effort save for every loaded character, and stores every vehicle this resource owns. |
| `onVehicleRemoved` | server | Forgets a vehicle the host removed rather than trying to write through its id. |
| `chat:ready` | server | Sends the five unrestricted commands to the chat autocomplete. Cooled at one per ten seconds per player: anybody can raise it. |

### onPlayerReady {#onplayerready}

The gate opened for a player. The `detail` string is the one channel a server
resource on this platform has for telling every other server VM something.

```lua
AddEventHandler("onPlayerReady", function(rawPlayerId, detail) end)
```

- rawPlayerId: `string` — convert it with `tonumber`.
- detail: `string` — the release note.

`detail` is one of `cleared`, `incarnated`, `resource_stopped`,
`resource_reloaded`, `liveness_lost:<res>[,<res>…]`, or the sanitised note a
resource passed to `release`. The core passes
`opx77_core:character-placed`, `opx77_core:character-loaded`,
`opx77_core:selection-timeout`, `opx77_core:roster-failed` or
`opx77_core:no-identity`.

!!! warning "One resource has to be running for the gate to open at all"
    Every joiner also carries a `__platform` hold that no Lua may take or
    release and which has **no deadline**. It clears on one thing only: a client
    announcing `open77:session:gameplayReady`. In this resource set
    [`opx77_appearance`](../opx77_appearance/index.md) is what sends it. Without
    it `Open77.ready.isReady` stays false forever and this handler can never
    fire. The core's boot check also accepts the official `open77_appearance`,
    which sends it too, but that package is not a drop-in for this set, and
    running both conflicts — see
    [The entry gate](../../concepts/entry-gate.md#platform-hold). The core is unaffected, because it reads neither, and says so
    with one warning at boot. See
    [The entry gate](../../concepts/entry-gate.md).

A `detail` beginning `liveness_lost:` means a hold passed its liveness deadline
and the platform concluded the holder was gone. If the list names `opx77_core`,
a player is in the world without the core having decided where they belong; the
core logs a warning saying exactly that.

**Side** `server` — any server resource. Handled inside the core in
`server/events.lua`.

## Where to go next {#next}

- [Client exports](exports/client.md) — asking, rather than being told.
- [Hooks](hooks.md) — the four points where a file inside the core can veto rather than observe.
- [Integration channels](../../concepts/integration-channels.md) — the whole picture, with what each channel cannot do.
- [Types](types.md) — `PlayerData`, `PlayerJob`, `PlayerGang`, `CharacterSummary`.
