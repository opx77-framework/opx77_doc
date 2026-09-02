---
title: opx77_core client exports
description: The sixteen client exports opx77_core publishes — twelve reads over the mirrored character state and the static definitions, four character-screen requests that answer by event — each with its parameters, answer shape and error codes, plus the in-core OPX client API those exports wrap.
---

# Client exports

`opx77_core`'s client half publishes sixteen exports. Twelve are **reads**: they
answer from the mirror of the character the server last sent, or from the static
definitions shipped into the client VM. Four are **requests**: they fire an
`opx77:server:*` net event, the server validates it, and the return value only
says the request was sent — the answer arrives as an event.

| Export | Kind | Answers with |
|---|---|---|
| [`GetPlayerData`](#getplayerdata) | read | the whole mirrored `PlayerData` |
| [`IsLoggedIn`](#isloggedin) | read | a boolean |
| [`HasJob`](#hasjob) | read | a boolean |
| [`HasGang`](#hasgang) | read | a boolean |
| [`GetAppearance`](#getappearance) | read | the stored face, or `nil` |
| [`GetCharacters`](#getcharacters) | read | the selection roster |
| [`RequestCharacters`](#requestcharacters) | request | `opx77:client:charactersReady` |
| [`SelectCharacter`](#selectcharacter) | request | `opx77:client:onPlayerLoaded` or `opx77:client:refused` |
| [`CreateCharacter`](#createcharacter) | request | `opx77:client:charactersReady` or `opx77:client:refused` |
| [`DeleteCharacter`](#deletecharacter) | request | `opx77:client:charactersReady` or `opx77:client:refused` |
| [`GetSharedConfig`](#getsharedconfig) | read | the six config values a UI legitimately needs |
| [`Locale`](#locale) | read | one translated string |
| [`GetJobs`](#getjobs) | read | every job definition |
| [`GetGangs`](#getgangs) | read | every gang definition |
| [`GetOrigins`](#getorigins) | read | every lifepath |
| [`GetVersion`](#getversion) | read | the core's version string |

Below them, [the in-core client API](#in-core-client) is the synchronous `OPX`
surface these exports wrap. It is reachable only from a file inside
`opx77_core/client/`, and no other resource can see it.

## How to call one {#how-to-call}

!!! info
    Read [The export contract](../../../concepts/export-contract.md) first. There
    is no `exports.opx77_core:GetPlayerData()` proxy on this platform, the call
    is always asynchronous, and failure has three levels — checking only the
    first turns a remote error into a silent `nil`.

```lua
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_core", "GetPlayerData")
  if not promise then return print(reason) end   -- level 1: never dispatched
  local result, callError = promise:await()
  if callError then return print(callError) end  -- level 2: resolution failed
  if not result.ok then return end               -- level 3: the core refused
  print(result.data.citizenId)
end)
```

Every export answers a plain `{ ok = boolean, … }` table rather than an
`OPX.Result`, because the value crosses a codec and lands in code that does not
have `OPX.Result` loaded. `ok = false` is used rather than an empty answer so a
caller cannot mistake "not logged in yet" for "logged in with nothing".

---

## GetPlayerData {#getplayerdata}

Returns the whole mirrored character, or `ok = false` with `error.notLoggedIn`
when no character is loaded.

```lua
Open77.exports.call("opx77_core", "GetPlayerData")
```

Takes no parameters.

**Returns** `{ ok: boolean, data?: `[`PlayerData`](../types.md#playerdata)`, error?: string }`

**Errors**

| Code | Meaning |
|---|---|
| `error.notLoggedIn` | No character is loaded on this client. |

!!! warning
    This is a mirror of the character that lives in the player's own process. It
    is a hint, not proof. Draw a UI from it; re-derive on the server anything
    that must be unforgeable.

**Side** `client` export — callable from any client resource. Asynchronous, and
the answer crosses the value codec. Not reachable from a server resource.

### Example {#getplayerdata-example}

```lua
CreateThread(function()
  local promise = Open77.exports.call("opx77_core", "GetPlayerData")
  if not promise then return end
  local result, callError = promise:await()
  if callError or not result.ok then return end
  local data = result.data
  print(("%s %s — %s"):format(data.charInfo.firstName, data.charInfo.lastName, data.job.label))
end)
```

---

## IsLoggedIn {#isloggedin}

Returns whether a character is loaded on this client. Never refuses: `ok` is
always `true`, and the answer is in `loggedIn`.

```lua
Open77.exports.call("opx77_core", "IsLoggedIn")
```

Takes no parameters.

**Returns** `{ ok: true, loggedIn: boolean }`

**Errors** none.

!!! warning
    This is read from the client's own mirror, and is a hint rather than proof.
    It is true between `opx77:client:playerLoaded` and
    `opx77:client:playerUnloaded` and says nothing about what the server
    currently believes.

**Side** `client` export — callable from any client resource. Asynchronous. Not
reachable from a server resource.

---

## HasJob {#hasjob}

Returns whether the loaded character holds this job, optionally only while on
duty and optionally at or above a grade; `false` when no character is loaded.

```lua
Open77.exports.call("opx77_core", "HasJob", name, onDutyOnly, minGrade)
```

- name: `string`
    - The job key, as in `data/jobs.lua` — not the label.
- onDutyOnly?: `boolean`
    - When `true`, an off-duty holder answers `false`.
    - Default: `false`
- minGrade?: `integer`
    - When given, the held `grade.level` must be greater than or equal to this.
    - Read with `tonumber`, so a value that is not a number is treated as absent
      rather than as grade 0.
    - Default: absent — any grade matches

**Returns** `{ ok: true, result: boolean }`

**Errors** none. A wrong job name is not an error; it is `result = false`.

!!! warning
    A duty check and a grade comparison on a client-side mirror. It is a hint,
    not proof — a job gate that matters must be re-derived inside the core.

`minGrade` is the **third** parameter rather than the second so every call
written against the older two-argument form keeps the meaning it had.

**Side** `client` export — callable from any client resource. Asynchronous. Not
reachable from a server resource.

### Example {#hasjob-example}

```lua
CreateThread(function()
  local promise = Open77.exports.call("opx77_core", "HasJob", "ncpd", true, 2)
  if not promise then return end
  local result, callError = promise:await()
  if callError or not result.ok then return end
  if result.result then
    -- on duty as NCPD, grade 2 or above
  end
end)
```

---

## HasGang {#hasgang}

Returns whether the loaded character belongs to this gang, optionally at or
above a grade; `false` when no character is loaded.

```lua
Open77.exports.call("opx77_core", "HasGang", name, minGrade)
```

- name: `string`
    - The gang key, as in `data/gangs.lua` — not the label.
- minGrade?: `integer`
    - When given, the held `grade.level` must be greater than or equal to this.
    - Read with `tonumber`, so a non-numeric value is treated as absent.
    - Default: absent — any grade matches

**Returns** `{ ok: true, result: boolean }`

**Errors** none. A wrong gang name is `result = false`, not a refusal.

There is no duty flag here, because a gang has no shifts — which is why
`minGrade` is the **second** parameter on this export and the **third** on
[`HasJob`](#hasjob).

!!! warning
    Read from the client's mirror. It is a hint, not proof.

**Side** `client` export — callable from any client resource. Asynchronous. Not
reachable from a server resource.

---

## GetAppearance {#getappearance}

Returns the stored face for the live character, as the mirror carries it.

```lua
Open77.exports.call("opx77_core", "GetAppearance")
```

Takes no parameters.

**Returns** `{ ok: true, appearance: `[`AppearanceSnapshot`](../types.md#appearancesnapshot)`|nil }`

- `appearance` — `nil` for a character that has never been to the mirror, which
  is not an error.

**Errors** `error.notLoggedIn` when no character is loaded, as
`{ ok = false, error = "error.notLoggedIn" }`.

The snapshot is read from `PlayerData.appearance`, so it is already on the
client before this is called — it arrives with `opx77:client:playerLoaded` like
every other field of the character, and is replaced by
[`opx77:client:onAppearanceUpdate`](../events.md#onappearanceupdate) whenever the
core stores a new one. There is deliberately no export that *writes* a face: a
caller that could hand the framework a snapshot could hand it somebody else's.
The one write path is the net event
[`opx77:server:saveAppearance`](../events.md#saveappearance), and
[`opx77_appearance`](../../opx77_appearance/index.md) is what sends it.

!!! warning
    Read from the client's mirror. It is a hint, not proof.

**Side** `client` export — callable from any client resource. Asynchronous. Not
reachable from a server resource.

---

## GetCharacters {#getcharacters}

Returns the selection roster the server last sent — the character list, the slot
allowance and the lifepath definitions. Empty, never `nil`, before the first
roster arrives.

```lua
Open77.exports.call("opx77_core", "GetCharacters")
```

Takes no parameters.

**Returns** `{ ok: true, characters: `[`CharacterSummary[]`](../types.md#charactersummary)`, slots: integer, origins: table }`

- `characters` — one entry per character on this account.
- `slots` — how many that account may hold.
- `origins` — the same table [`GetOrigins`](#getorigins) answers with.

**Errors** none. A client that has not been sent a roster yet gets
`characters = {}` and `slots = 0`.

To be told when a fresh roster lands rather than polling this, listen for
`opx77:client:charactersReady` — see [Events](../events.md#charactersready).

**Side** `client` export — callable from any client resource. Asynchronous. Not
reachable from a server resource.

---

## RequestCharacters {#requestcharacters}

Asks the server to send the roster again, for a selection UI that started after
the first one was sent; returns as soon as the request is on the wire.

```lua
Open77.exports.call("opx77_core", "RequestCharacters")
```

Takes no parameters.

**Returns** `{ ok: true }` — the request was sent, nothing more.

**Errors** none from this call. The server may still refuse it: it cools
`opx77:server:ready` at one per two seconds per player and answers nothing when
it does.

The answer arrives as `opx77:client:charactersReady` on the core's local
channel, or as `opx77:client:characters` on the wire. A client that already has
a character loaded is re-sent `opx77:client:playerLoaded` instead, because
re-opening the selection screen over a live character would be wrong.

**Side** `client` export — callable from any client resource. Asynchronous, and
the value it returns is not the answer. Not reachable from a server resource.

---

## SelectCharacter {#selectcharacter}

Asks the server to enter the world as this character; returns whether the
request was sent, never whether it succeeded.

!!! warning
    A successful selection kills and respawns the player to place them. Do not
    call it from a UI that a player can trigger while already in the world
    unless that is what you mean.

```lua
Open77.exports.call("opx77_core", "SelectCharacter", citizenId)
```

- citizenId: [`CitizenId`](../types.md#citizenid)
    - The character to enter as, as printed on the roster.

**Returns** `{ ok: boolean, error?: string }`

**Errors**

| Code | Meaning |
|---|---|
| `bad-citizen-id` | The argument was not a string. Nothing was sent. |

The server's own refusals do not come back through this call. They arrive as
[`opx77:client:refused`](../events.md#refused) (local) or
[`opx77:client:notify`](../events.md#notify) (wire), carrying a locale key such
as `character.notFound`, `error.tooFast` or `entry.failed` **and the operation
they answer** — `selectCharacter` here. Branch on the operation: a caller with
more than one request in flight cannot otherwise tell whose `error.tooFast` it
is holding. Success arrives as `opx77:client:onPlayerLoaded` (local) or
`opx77:client:playerLoaded` (wire).

**Side** `client` export — callable from any client resource. Asynchronous, and
the value it returns is not the answer. Not reachable from a server resource.

### Example {#selectcharacter-example}

```lua
AddEventHandler("opx77:client:onPlayerLoaded", function(playerData)
  -- the selection landed
end)

AddEventHandler("opx77:client:refused", function(code, kind, operation)
  if operation ~= "selectCharacter" then return end
  -- render locale(code); it is a catalogue key
end)

CreateThread(function()
  local promise = Open77.exports.call("opx77_core", "SelectCharacter", "NC-4B2K-7Q")
  if not promise then return end
  local result, callError = promise:await()
  if callError or not result.ok then return end
  -- sent; now wait for one of the two handlers above
end)
```

---

## CreateCharacter {#createcharacter}

Asks the server to create a character, after checking the names and the lifepath
locally; returns whether the request was sent.

```lua
Open77.exports.call("opx77_core", "CreateCharacter", registration)
```

- registration: `table`
    - firstName: `string` — 2 to 32 characters, counted in characters, not bytes.
    - lastName: `string` — same bounds.
    - origin: `string` — a key of [`GetOrigins`](#getorigins): `nomad`, `streetkid` or `corpo`.
    - gender: `string` — `female` or `male`. Required: it is the body family
      `open77_appearance` understands, and its column constraint accepts those
      two. The client-side pre-check does not look at it, so a wrong value is
      refused by the server with `error.badRequest`.
    - birthDate?: `string` — shape-checked against `YYYY-MM-DD` and never
      parsed; anything else is replaced with `2050-01-01` rather than refused.

**Returns** `{ ok: boolean, error?: string }`

**Errors**

| Code | Meaning |
|---|---|
| `bad-request` | `registration` was not a table. Nothing was sent. |
| `character.badName` | A name failed the local length check. Nothing was sent. |
| `character.badOrigin` | The origin is not one of the shipped lifepaths. Nothing was sent. |

Every field is checked again server-side against the same rules. Checking here
only spares a round trip and gives the UI something to mark. A server-side
refusal arrives as `opx77:client:refused` with a code such as
`character.slotsFull`; success is followed by a fresh roster on
`opx77:client:charactersReady`.

**Side** `client` export — callable from any client resource. Asynchronous, and
the value it returns is not the answer. Not reachable from a server resource.

---

## DeleteCharacter {#deletecharacter}

Asks the server to delete a character; returns whether the request was sent.

!!! danger
    The character disappears from the account immediately and nothing in this
    framework puts it back. The row itself is only **marked** deleted, so the
    citizen id is never reissued and an operator can recover it in the database
    — but every row in `CASCADE_TABLES` is deleted for real. There is no
    confirmation step anywhere below this call: build one into your UI.

```lua
Open77.exports.call("opx77_core", "DeleteCharacter", citizenId)
```

- citizenId: [`CitizenId`](../types.md#citizenid)
    - The character to delete. Ownership is re-checked server-side.

**Returns** `{ ok: boolean, error?: string }`

**Errors**

| Code | Meaning |
|---|---|
| `bad-citizen-id` | The argument was not a string. Nothing was sent. |

A server-side refusal arrives as `opx77:client:refused`; success is followed by
a fresh roster on `opx77:client:charactersReady`.

**Side** `client` export — callable from any client resource. Asynchronous, and
the value it returns is not the answer. Not reachable from a server resource.

---

## GetSharedConfig {#getsharedconfig}

Returns the six configuration values a UI legitimately needs — and only those,
not `OPX.Config` wholesale.

```lua
Open77.exports.call("opx77_core", "GetSharedConfig")
```

Takes no parameters.

**Returns** `{ ok: true, config: table }`

- serverName: `string` — `SHARED.SERVER_NAME`.
- locale: `string` — the locale **in force**, not the one configured: the two differ after a `Locale.set`.
- moneyTypes: `string[]` — the money types this server runs.
- defaultMoneyType: `string`
- nameBounds: `{ MIN: integer, MAX: integer }` — character-name length, counted in characters.
- notifyPosition: `string` — the notification position the core sends with, in the platform's underscored vocabulary.

**Errors** none.

The static definitions are **not** here. They are large, they never change, and
a UI that wants them wants them once: use [`GetJobs`](#getjobs),
[`GetGangs`](#getgangs) and [`GetOrigins`](#getorigins).

**Side** `client` export — callable from any client resource. Asynchronous. Not
reachable from a server resource.

---

## Locale {#locale}

Translates one catalogue key with the player's language, so a refusal code
renders identically wherever it is shown; refuses a key that is not a string.

```lua
Open77.exports.call("opx77_core", "Locale", key, params)
```

- key: `string`
    - A catalogue key, such as `character.badName`. Every code the core sends on
      `opx77:client:refused` is one.
- params?: `table<string, string|number>`
    - Placeholder substitutions. A spare parameter is ignored, so one table can
      cover several codes.

**Returns** `{ ok: boolean, text?: string, error?: string }`

**Errors**

| Code | Meaning |
|---|---|
| `error.badRequest` | `key` was not a string. |

A key that is not in the catalogue is not an error: the catalogue answers with
the key itself, which is legible enough to report.

**Side** `client` export — callable from any client resource. Asynchronous. Not
reachable from a server resource.

---

## GetJobs {#getjobs}

Returns every job definition shipped in `data/jobs.lua`, keyed by job name.

```lua
Open77.exports.call("opx77_core", "GetJobs")
```

Takes no parameters.

**Returns** `{ ok: true, jobs: table<string, table> }`, each entry carrying:

- label: `string`
- type?: `string`
- defaultDuty: `boolean`
- offDutyPay: `boolean`
- grades: `array` of `{ level: integer, name: string, payment: number, isBoss: boolean, bankAuth: boolean }`

**Errors** none.

!!! warning
    `grades` is a **1-based array carrying an explicit `level`**, not the
    0-keyed source table. Read `grade.level`, never the array index: grade 0 is
    a real and common grade, and it is the first array entry. The rebuild exists
    because the value codec documents "string or integer keys" and no table with
    a `0` key has ever crossed it in this framework.

**Side** `client` export — callable from any client resource. Asynchronous. Not
reachable from a server resource.

### Example {#getjobs-example}

```lua
CreateThread(function()
  local promise = Open77.exports.call("opx77_core", "GetJobs")
  if not promise then return end
  local result, callError = promise:await()
  if callError or not result.ok then return end
  for name, job in pairs(result.jobs) do
    for i = 1, #job.grades do
      local grade = job.grades[i]
      print(("%s %d %s %d"):format(name, grade.level, grade.name, grade.payment or 0))
    end
  end
end)
```

---

## GetGangs {#getgangs}

Returns every gang definition shipped in `data/gangs.lua`, keyed by gang name.

```lua
Open77.exports.call("opx77_core", "GetGangs")
```

Takes no parameters.

**Returns** `{ ok: true, gangs: table<string, table> }`, each entry carrying:

- label: `string`
- grades: `array` of `{ level: integer, name: string, isBoss: boolean, bankAuth: boolean }`

Gangs carry no `payment` and no duty flags: a gang is not an employer.

**Errors** none.

!!! warning
    `grades` is a 1-based array carrying an explicit `level`, not the 0-keyed
    source table. Read `grade.level`, never the array index.

**Side** `client` export — callable from any client resource. Asynchronous. Not
reachable from a server resource.

---

## GetOrigins {#getorigins}

Returns the lifepath definitions offered at character creation, keyed by origin
name.

```lua
Open77.exports.call("opx77_core", "GetOrigins")
```

Takes no parameters.

**Returns** `{ ok: true, origins: table<string, { label: string, description: string }> }`

**Errors** none.

This table is flat and string-keyed, so it is returned exactly as it stands —
this same table already crosses the codec on the roster, as
[`GetCharacters`](#getcharacters)`().origins`. It is published separately anyway,
because reading it off a roster is not a place a resource should have to look.

**Side** `client` export — callable from any client resource. Asynchronous. Not
reachable from a server resource.

---

## GetVersion {#getversion}

Returns the running core's version string, so a satellite can refuse to run
against a core it does not know.

```lua
Open77.exports.call("opx77_core", "GetVersion")
```

Takes no parameters.

**Returns** `{ ok: true, version: string }` — `"0.3.0"` on this release.

**Errors** none.

**Side** `client` export — callable from any client resource. Asynchronous. Not
reachable from a server resource.

## The in-core client API {#in-core-client}

Everything above is the surface **other resources** call. Inside `opx77_core`'s
own client VM there is a second, synchronous surface: the `OPX` global, which the
exports above are thin wrappers over. It is reachable from one place only — a
Lua file added to `opx77_core/client/` and listed as a `client_script` in
`opx77_core/open77.lua`. There is no `require`, and the file must be listed
individually: a script glob is fatal on this platform, and
[Architecture](../../../concepts/architecture.md#load-order) explains why.

!!! info "A fourth answer to \"can I call this from here\""
    The three sides the rest of this reference uses — *client export*, *in-core
    server*, *net event* — do not cover this one. These functions are **in-core
    client**: same machine, same Lua state as `client/exports.lua`, synchronous,
    no codec, and invisible to every other resource. A satellite that calls
    `OPX.HasJob` calls a `nil` global.

Three fields carry the state they all read, and a plug-in file may read them
directly:

| Field | Is |
|---|---|
| `OPX.PlayerData` | the server's last copy of the live character, mirrored. `{}` before login, replaced wholesale on it — never captured into a local. |
| `OPX.IsLoggedIn` | `true` between `playerLoaded` and `playerUnloaded`. |
| `OPX.Characters` | the selection roster the server last sent: `list`, `slots`, `origins`. |

!!! warning "None of this is authoritative, on any entry below"
    Every value here is a mirror of what the server last sent, and a modified
    client can make it say anything. Read it to *present* — draw a gauge, gate a
    menu, skip a prompt — and let the server decide anything that must hold. See
    [Integration channels](../../../concepts/integration-channels.md).

### OPX.GetPlayerData {#opx-getplayerdata}

Returns the mirrored `PlayerData` table; never `nil`, so it can be indexed
without guarding — it is `{}` when no character is loaded.

```lua
local data = OPX.GetPlayerData()
```

**Returns** [`PlayerData`](../types.md#playerdata) `| table` — the empty table
before login. The honest question is the `OPX.IsLoggedIn` field, not the
emptiness of this one.

**Side** `in-core client` — a file inside `opx77_core/client/` only. Does not
yield.

### OPX.GetCitizenId {#getcitizenid}

Returns the live character's citizen id, or `nil` when no character is loaded.

```lua
local citizenId = OPX.GetCitizenId()
```

**Returns** [`CitizenId`](../types.md#citizenid) `| nil`

**Side** `in-core client` — a file inside `opx77_core/client/` only. Does not
yield.

### OPX.GetJobData {#getjobdata}

Returns the live character's job, or `nil` when no character is loaded.

```lua
local job = OPX.GetJobData()
```

**Returns** [`PlayerJob`](../types.md#playerjob) `| nil`

**Side** `in-core client` — a file inside `opx77_core/client/` only. Does not
yield.

### OPX.GetGangData {#getgangdata}

Returns the live character's gang, or `nil` when no character is loaded.

```lua
local gang = OPX.GetGangData()
```

**Returns** [`PlayerGang`](../types.md#playergang) `| nil`

**Side** `in-core client` — a file inside `opx77_core/client/` only. Does not
yield.

### OPX.HasJob {#opx-hasjob}

Answers whether the live character holds this job, returning `false` when no
character is loaded, when the name differs, when `onDutyOnly` is set and they are
off duty, or when their grade is below `minGrade`.

```lua
OPX.HasJob(name, onDutyOnly, minGrade)
```

- name: `string`
    - The job key, as spelled in `data/jobs.lua`.
- onDutyOnly?: `boolean`
    - When `true`, an off-duty holder answers `false`.
    - Default: `nil`
- minGrade?: `integer`
    - When given, the held grade level must be greater than or equal to this.
    - Default: `nil` — any grade passes.

**Returns** `boolean`

!!! warning "`minGrade` is the third parameter, not the second"
    It was appended rather than inserted precisely so that every call written
    against the two-argument form keeps the meaning it had. A caller who passes a
    grade where `onDutyOnly` lives gets a silent duty check, not a grade check.

**Side** `in-core client` — a file inside `opx77_core/client/` only. Does not
yield. The exported [`HasJob`](#hasjob) is this function with `tonumber` applied
to `minGrade`.

### OPX.HasGang {#opx-hasgang}

Answers whether the live character holds this gang, returning `false` when no
character is loaded, when the name differs, or when their grade is below
`minGrade`.

```lua
OPX.HasGang(name, minGrade)
```

- name: `string`
    - The gang key, as spelled in `data/gangs.lua`.
- minGrade?: `integer`
    - When given, the held grade level must be greater than or equal to this.
    - Default: `nil`

**Returns** `boolean`

There is no duty parameter, because a gang has no shifts: duty is a property of
the primary job only. That is why `minGrade` is the **second** parameter here and
the third on [`OPX.HasJob`](#opx-hasjob).

**Side** `in-core client` — a file inside `opx77_core/client/` only. Does not
yield.

### OPX.GetJobGrade {#getjobgrade}

Returns the grade level of the live character's job, or `-1` when they hold no
job or hold a different one.

```lua
OPX.GetJobGrade(name)
```

- name?: `string`
    - When given, `-1` is returned unless the held job has this name.
    - Default: `nil` — the grade of whatever job is held.

**Returns** `integer` — `-1` for absence.

Minus one rather than `nil` because grade `0` is a real and common grade, and
`if OPX.GetJobGrade("police") then` would be true for both.

**Side** `in-core client` — a file inside `opx77_core/client/` only. Does not
yield.

### OPX.GetMoney {#client-getmoney}

Returns the mirrored balance of one money type, or `0` when no character is
loaded or the type is not one the character carries.

```lua
OPX.GetMoney(moneyType)
```

- moneyType: [`MoneyType`](../types.md#moneytype)

**Returns** `integer` — `0` for both absence and an empty purse, which this
function does not distinguish.

**Side** `in-core client` — a file inside `opx77_core/client/` only. Does not
yield. It is a mirror: the writer is
[`Player.Functions.AddMoney`](../player.md#addmoney) and friends, on the server.

### OPX.GetMetadata {#client-getmetadata}

Returns one metadata value, the whole metadata table when `key` is omitted, or
`nil` when no character is loaded.

```lua
OPX.GetMetadata(key)
```

- key?: `string`
    - Omit it for the whole table.
    - Default: `nil`

**Returns** `any | nil`

**Side** `in-core client` — a file inside `opx77_core/client/` only. Does not
yield.

### OPX.GetAppearance {#client-getappearance}

Returns the stored face for the live character, or `nil` for one that has never
been captured.

```lua
local snapshot = OPX.GetAppearance()
```

**Returns** [`AppearanceSnapshot`](../types.md#appearancesnapshot)` | nil`

**Side** `in-core client` — a file inside `opx77_core/client/` only. Does not
yield. It is a mirror: the writer is
[`OPX.SaveAppearance`](../server-api.md#saveappearance), on the server.

### OPX.GetPosition {#getposition}

Returns the local player's position as a flat `{ x, y, z }` table, or `nil` when
the platform did not answer three numbers — which is the normal state before the
world is up.

```lua
local position = OPX.GetPosition()
```

**Returns** `{ x: number, y: number, z: number } | nil`

`Open77.character.position()` returns **three numbers**, not a vector and not a
table, so this flattens them into the one shape the wire format and the shared
maths helpers both take. Indexing its first return value indexes a number, which
answers `nil` for every axis.

**Side** `in-core client` — a file inside `opx77_core/client/` only. Does not
yield.

### OPX.Announce {#announce}

Tells the server this client is present, by firing
[`opx77:server:ready`](../events.md#server-ready); it returns nothing and reports
nothing.

```lua
OPX.Announce()
```

**Returns** nothing.

This is what makes a core reload survivable. After a reload the server's roster
is empty and the host does **not** re-fire `onPlayerConnected`, so nothing would
ever tell the server the client is there. The core calls it itself on resource
start and again on world-ready, and the server throttles the repeat.

**Side** `in-core client` — a file inside `opx77_core/client/` only. Does not
yield.

### OPX.RequestCharacters {#opx-requestcharacters}

Asks the server to send the selection roster again, for a UI that started after
it was first sent; it returns nothing, and the roster arrives as an event.

```lua
OPX.RequestCharacters()
```

**Returns** nothing. The answer is
[`opx77:client:charactersReady`](../events.md#charactersready).

It fires the same `opx77:server:ready` event as
[`OPX.Announce`](#announce) — asking to be re-announced *is* asking for the
roster.

**Side** `in-core client` — a file inside `opx77_core/client/` only. Does not
yield.

### OPX.SelectCharacter {#opx-selectcharacter}

Asks the server to enter the world as one character, returning whether the
request was sent and never whether it succeeded.

```lua
local sent, reason = OPX.SelectCharacter(citizenId)
```

- citizenId: [`CitizenId`](../types.md#citizenid)

**Returns** `boolean sent, string? reason`

**Errors**

| Code | Meaning |
|---|---|
| `bad-citizen-id` | The argument was not a string. Nothing was sent. |

The server's own refusal never comes back here. It arrives on the wire as
`opx77:client:notify` and is re-emitted locally as
[`opx77:client:refused`](../events.md#refused).

**Side** `in-core client` — a file inside `opx77_core/client/` only. Does not
yield.

### OPX.CreateCharacter {#opx-createcharacter}

Asks the server to create a character, returning `false` and a code when the
registration fails the client's own check, and otherwise only that the request
was sent.

```lua
local sent, reason = OPX.CreateCharacter(registration)
```

- registration: `{ firstName: string, lastName: string, origin: Origin, gender: Gender, birthDate: string }`

**Returns** `boolean sent, string? reason`

**Errors**

| Code | Meaning |
|---|---|
| `bad-request` | The argument was not a table. |
| `character.badName` | `firstName` or `lastName` failed [`OPX.ValidateName`](../server-api.md#validatename). |
| `character.badOrigin` | `origin` is not a key of `data/origins.lua`. |

The client's check exists to spare a round trip and give a UI something to mark.
The server applies the same rules again, and its answer is the one that counts.

**Side** `in-core client` — a file inside `opx77_core/client/` only. Does not
yield.

### OPX.DeleteCharacter {#opx-deletecharacter}

Asks the server to delete a character, returning whether the request was sent and
never whether it succeeded.

```lua
local sent, reason = OPX.DeleteCharacter(citizenId)
```

- citizenId: [`CitizenId`](../types.md#citizenid)

**Returns** `boolean sent, string? reason`

**Errors**

| Code | Meaning |
|---|---|
| `bad-citizen-id` | The argument was not a string. Nothing was sent. |

!!! danger "Deletion is permanent and the client cannot confirm it"
    The row, the character's money, its job history and its vehicles go with it.
    This call answers before the server has decided anything; the outcome arrives
    as [`opx77:client:charactersReady`](../events.md#charactersready) with one
    fewer entry, or as a refusal.

**Side** `in-core client` — a file inside `opx77_core/client/` only. Does not
yield.

## Where to go next {#next}

- [The in-core client API](#in-core-client) — the same reads, synchronously, for
  a file added to `opx77_core/client/`.
- [Server exports](server.md) — why there are none.
- [Events](../events.md) — how to be told about a change instead of asking.
- [Types](../types.md) — `PlayerData`, `CharacterSummary` and the rest.
- [The export contract](../../../concepts/export-contract.md) — the three levels of failure, in full.
