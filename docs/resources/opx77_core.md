# opx77_core

The foundation of the OPX//77 framework. Every other resource in the set —
[opx77_menu](opx77_menu.md), [opx77_hud](opx77_hud.md),
[opx77_chat](opx77_chat.md), [opx77_status](opx77_status.md) — reads its player
state from here.

| | |
|---|---|
| Resource | `opx77_core` |
| Version | `0.2.0` |
| Requires | `open77_version ">=0.0.1"` |
| Auto start | yes |
| Reload policy | `local` — a reload is a script reload, not a reconnect: both halves rebuild |
| Declared dependencies | none, deliberately: the core must install on a bare server |

!!! warning "Early development"
    The API, the architecture and the internal systems are subject to change
    without notice. Do not build production resources against this surface yet.

## What it is

`opx77_core` owns everything a roleplay server needs before any gameplay can
exist:

- **Characters** — creation, selection and deletion, with a per-account slot
  limit and a lifetime row ceiling.
- **Money** — named money types, stored as a JSON column, with per-type rules
  about going negative.
- **Jobs and gangs** — multi-membership with grades, a primary job and a
  primary gang, a duty state, and paychecks.
- **Persistence** — character rows, group memberships and owned vehicles in
  MySQL, autosaved on a timer and written again on departure.
- **The readiness gate** — the core holds the join-time gate for every
  connecting player, so nothing places anybody before the core has decided
  where they belong.
- **Live tunables** — the numbers an operator changes mid-session, editable
  from the Warden panel without a restart.
- **Locales** — every refusal is answered as a stable key that a satellite
  resource renders.

See [the client export contract](../index.md#the-client-export-contract) for how
a caller reaches this resource.

## Why the API is client-side

!!! warning "A server resource cannot call the core"
    The Open77 **server** runtime installs no `exports`, no
    `GetInvokingResource` and no cross-resource event bus. This is a platform
    fact, not a gap waiting to be filled. A server resource therefore has no
    way to reach `opx77_core` at all.

    The consequence shapes the whole framework: **the core is one server
    resource split by file, and its public API lives on the client.** What
    would be a plugin resource on another framework is here a file added to
    `server/`, where the `OPX` namespace is simply in scope.

    A server resource that needs core data sends a net event to **its own
    client half**, which calls the exports below and answers back.

The client runtime *does* have `exports` and `GetInvokingResource`, which is
what makes satellite client resources possible in the first place. The core's
entire public surface is `client/exports.lua`, published last in the load order
because publishing it claims everything it reads.

!!! danger "Three traps if you are coming from FiveM"
    - **There is no `exports.<resource>:<name>()` proxy.** Indexing the
      exports function raises *attempt to index a function value*.
    - **The call is always asynchronous.** `await` is only usable inside a
      `CreateThread`.
    - **Failure has two levels.** Checking only the first turns a remote error
      into a silent `nil`.

Every export answers a plain `{ ok = boolean, ... }` table rather than the
core's internal `OPX.Result`, because the value crosses a codec and lands in
code that does not have `OPX.Result` loaded.

## Exports

All exports are **client-side**. All of them are reads: writes go over
`opx77:server:*` net events, where the server validates them.

| Export | Parameters | Returns |
|---|---|---|
| `GetPlayerData` | — | `{ ok, data?, error? }` |
| `IsLoggedIn` | — | `{ ok = true, loggedIn }` |
| `HasJob` | `name: string`, `onDutyOnly?: boolean` | `{ ok = true, result }` |
| `HasGang` | `name: string` | `{ ok = true, result }` |
| `GetCharacters` | — | `{ ok = true, characters, slots, origins }` |
| `RequestCharacters` | — | `{ ok = true }` |
| `SelectCharacter` | `citizenId: string` | `{ ok, error? }` |
| `CreateCharacter` | `registration: table` | `{ ok, error? }` |
| `DeleteCharacter` | `citizenId: string` | `{ ok, error? }` |
| `GetSharedConfig` | — | `{ ok = true, config }` |
| `Locale` | `key: string`, `params?: table` | `{ ok, text?, error? }` |

### The calling pattern

```lua
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_core", "GetPlayerData")
  if not promise then
    -- level 1: dispatch failed, and `reason` says why. `export_not_found` is
    -- the documented example; arguments the value codec rejects fail here too.
    return print("dispatch failed: " .. tostring(reason))
  end

  local result, callError = promise:await()
  if callError then
    -- level 2: the call was dispatched but did not resolve.
    return print("call failed: " .. tostring(callError))
  end

  if not result.ok then
    -- the export ran and refused. `result.error` is a locale key.
    return print("refused: " .. tostring(result.error))
  end

  print(result.data.citizenId)
end)
```

Skipping either check is the classic bug: `promise:await()` on a `nil` promise
raises, and reading `result.data` after a `callError` reads a field of `nil`.

### `GetPlayerData`

Returns the whole mirrored character. `ok = false` rather than an empty table,
so a caller cannot mistake "not logged in yet" for "logged in with nothing".

```lua
-- logged in
{ ok = true, data = <PlayerData> }
-- not logged in
{ ok = false, error = "error.notLoggedIn" }
```

`PlayerData` is the server's copy, mirrored whole on every change:

| Field | Type | Meaning |
|---|---|---|
| `source` | integer or nil | the session-scoped, recycled player id; nil for an offline Player |
| `userId` | string | the Master-signed durable account id (a GUID) |
| `citizenId` | string | e.g. `"H7K-M4X3"`; also the `open77_appearance` character key |
| `cid` | integer | slot number within the account, 1-based |
| `name` | string | the account display name at last login |
| `charInfo` | table | `firstName`, `lastName`, `birthDate`, `origin`, `gender`, `phone` |
| `money` | table | money type name to integer balance |
| `job` | table | the primary job |
| `gang` | table | the primary gang |
| `jobs` | table | every job membership, name to grade |
| `gangs` | table | every gang membership, name to grade |
| `position` | table or nil | `x`, `y`, `z`, `heading`, `bucket`; nil until the character has been somewhere |
| `metadata` | table | free-form character state, see below |
| `lastLoggedOut` | string or nil | |
| `reportedHeading` | number or nil | the client's hint, never authoritative |

`job` carries `name`, `label`, `type`, `payment`, `onDuty`, `isBoss`,
`bankAuth` and `grade` (`{ name, level }`). `gang` carries `name`, `label`,
`isBoss`, `bankAuth` and `grade`.

`metadata` is free-form — a gameplay file adds its own keys and they survive
every save. The annotated keys are `health`, `armor`, `stamina`, `ram`,
`thirst`, `streetCred`, `isDead` and `inLastStand`; what a **new** character
actually starts with is `PLAYER.STARTING_METADATA` in `config/server.lua`,
which ships `health`, `armor`, `stamina`, `hunger`, `thirst`, `streetCred`,
`isDead` and `inLastStand`. Only `health` and `armor` are read by the core
itself, on the respawn transaction.

!!! note "Nothing secret belongs in `PlayerData`"
    The client mirrors this whole table. Do not put a server-side secret in it.

### `IsLoggedIn`

```lua
{ ok = true, loggedIn = false }
```

### `HasJob`

A grade comparison, which is why it is an export and not a plain field read.

```lua
-- HasJob("ripperdoc", true)
{ ok = true, result = false }
```

`onDutyOnly` defaults to false. It is compared strictly against `true`, so any
other value behaves as false. When it is true, the character must additionally
be clocked in.

### `HasGang`

```lua
-- HasGang("maelstrom")
{ ok = true, result = true }
```

### `GetCharacters`

The selection roster last sent to this client.

```lua
{
  ok = true,
  characters = { <CharacterSummary>, ... },
  slots = 3,
  origins = { ... },
}
```

A `CharacterSummary` is the trimmed shape sent for the selection screen:
`citizenId`, `cid`, `firstName`, `lastName`, `origin`, `gender`, `job`,
`gang`, `lastLoggedOut`. Money, metadata and the stored position are
deliberately absent.

### `RequestCharacters`

Asks the server for the roster again, for a selection UI that started after it
was first sent. Always `{ ok = true }` — it only says the request was sent.

### `SelectCharacter`, `CreateCharacter`, `DeleteCharacter`

!!! note "These are requests, not answers"
    The return value only says the request was sent. The real answer arrives on
    `opx77:client:playerLoaded`, or as a refusal on `opx77:client:notify`. A
    caller watches those events rather than the return value.

```lua
{ ok = true }
{ ok = false, error = "character.badName" }
```

`CreateCharacter` takes a registration table of `firstName`, `lastName`,
`origin`, `gender` and `birthDate`. The client checks the names and the origin
before sending, purely to spare a round trip and give the UI something to mark;
the server checks the same rules again.

Client-side refusal codes: `bad-request`, `bad-citizen-id`,
`character.badName`, `character.badOrigin`.

### `GetSharedConfig`

The configuration a UI legitimately needs, and only that — not `OPX.Config`
wholesale.

```lua
{
  ok = true,
  config = {
    serverName       = "OPX//77",
    locale           = "fr",       -- the locale in force, not the one configured
    moneyTypes       = { EDDIES = 500, BANK = 5000 },
    defaultMoneyType = "EDDIES",
    nameBounds       = { MIN = 2, MAX = 32 },
    notifyPosition   = "top-right",
  },
}
```

`locale` is the locale currently in force, which differs from the configured
one after a `Locale.set`.

### `Locale`

Renders one catalogue key, so a refusal code reads identically wherever it is
shown.

```lua
{ ok = true, text = "..." }
{ ok = false, error = "error.badRequest" }  -- key was not a string
```

`error.badRequest` is a real catalogue key rather than a marker string, because
`error` doubles as a locale key wherever it is displayed.

## Configuration

The files an operator edits, split by who may read them. Anything an operator
might want to change *mid-session* is a [tunable](#tunables) instead.

### `config/shared.lua`

!!! danger "Shipped to every client"
    This file goes out in the signed resource set. Everything in it is public.
    Credentials, webhooks and admin identifiers belong in `config/server.lua`.

| Key | Shipped default | Meaning |
|---|---|---|
| `SERVER_NAME` | `"OPX//77"` | shown in the launcher and in player-facing text |
| `LOCALE` | `"fr"` | language for player-facing text; server logs stay in English |
| `LOG_LEVEL` | `"info"` | `debug`, `info`, `warn`, `error` or `silent` |
| `MONEY.TYPES` | `{ EDDIES = 500, BANK = 5000 }` | money type name to starting balance |
| `MONEY.DEFAULT` | `"EDDIES"` | the type a payment falls back to when a caller does not name one |
| `CHARACTERS.NAME` | `{ MIN = 2, MAX = 32 }` | name length, counted in characters not bytes |
| `DEFAULT_SPAWN` | `{ SET = false, X = 0.0, Y = 0.0, Z = 0.0, HEADING = 0.0 }` | where a character with no stored position goes; nobody is placed until `SET` is true |
| `NOTIFY_POSITION` | `"top-right"` | `top`, `top-right`, `top-left`, `bottom`, `bottom-right`, `bottom-left` |

Money type names are durable: they become keys in the `money` JSON column.
Adding one is free; renaming one orphans every balance already stored under the
old name.

The shipped `DEFAULT_SPAWN` zeros are not a real Night City coordinate — run
`opx77.here` in game to print your own in exactly that shape.

### `config/server.lua`

Server-only; nothing here is ever distributed to a client.

| Key | Shipped default | Meaning |
|---|---|---|
| `AUTOSAVE_SECONDS` | `300` | how often a loaded player is written back; bounds what a crash costs |
| `MONEY.ALLOW_NEGATIVE` | `{ BANK = true }` | types that may go below zero; a type not listed is clamped at zero and the removal refused rather than truncated |
| `MONEY.PAYCHECK_MINUTES` | `10` | minutes between paychecks; zero disables them entirely |
| `MONEY.PAYCHECK_REQUIRES_DUTY` | `true` | only pay a player who is on duty |
| `NEEDS.TICK_SECONDS` | `300` | how often needs fall |
| `NEEDS.DAMAGE_AT_ZERO` | `2` | health lost per tick per empty need; `0` makes needs cosmetic |
| `NEEDS.hunger.PER_TICK` | `1.0` | |
| `NEEDS.thirst.PER_TICK` | `1.4` | |
| `CHARACTERS.DEFAULT_SLOTS` | `3` | how many characters one account may hold |
| `CHARACTERS.SLOTS_BY_USER` | `{}` | per-account overrides keyed by durable `userId`; `opx77.whois` prints a player's |
| `CHARACTERS.ROW_CEILING` | `60` | the most rows one account may ever write to `opx77_players` — a lifetime ceiling, not a roster size |
| `CHARACTERS.CASCADE_TABLES` | `{}` | `{ TABLE, COLUMN }` pairs whose rows are deleted with a character, matched against the citizen id; the core's own tables use `ON DELETE CASCADE` instead |
| `ENTRY.GATE_MS` | `300000` | how long the core holds the readiness gate per join; this is what is declared to the host |
| `ENTRY.PIPELINE_MS` | `240000` | the core's own deadline for the whole join sequence; below `GATE_MS` so the core gives up first |
| `PLAYER.STARTING_METADATA` | see below | initial `PlayerData.metadata` for a brand new character |
| `PLAYER.DEFAULT_JOB` | `"unemployed"` | must exist in `data/jobs.lua` |
| `PLAYER.DEFAULT_GANG` | `"none"` | must exist in `data/gangs.lua` |
| `CONFLICTING_PLACERS` | `{ "open77_playerstate", "freeroam", "pursuit", "race" }` | resources that would fight the core over where a player stands |

Shipped `STARTING_METADATA`: `health = 100`, `armor = 0`, `stamina = 100`,
`hunger = 100`, `thirst = 100`, `streetCred = 0`, `isDead = false`,
`inLastStand = false`. Anything a gameplay file adds later is merged on top and
survives every save. Nothing in the core spends `streetCred`; it is an agreed
name for gameplay files.

The core **disables nothing** in `CONFLICTING_PLACERS`. It checks
`GetResourceState` at boot and prints, once, what to do about each: stop
`open77_playerstate` or add `opx77_core` to its `spawnOwners` tunable, turn
`freeroam`'s `forceOnJoin` off, and treat `pursuit` and `race` as gamemodes
that should not share players with another gamemode.

Deleting a character is a *soft delete*: the slot is freed but the row stays,
so a citizen id is never reissued and the deletion can be undone. That is why
create-and-delete writes a new row every time, and why `ROW_CEILING` exists.

### `config/vehicles.lua`

Also server-only, and loaded by the manifest as a server script. It populates
the global `OPX_VEHICLES`, not `OPX.Config`.

| Key | Shipped default | Meaning |
|---|---|---|
| `PER_CHARACTER` | `8` | the most vehicles one character may own; `0` for no ceiling |
| `PLATE_FORMAT` | `"11AAA111"` | `1` becomes a digit, `A` a letter, anything else stays as written |
| `DEFAULT_GARAGE` | `"impound"` | where a vehicle created with no garage belongs |
| `SPAWN_OFFSET` | `3.0` | metres to the side of the player a vehicle appears |
| `DESPAWN_RADIUS` | `0.0` | metres past which an unoccupied vehicle is stored; `0` never does |
| `SAVE_SECONDS` | `120` | how often the condition of every vehicle that is out is written |

### `config/client.lua`

!!! warning "Never loaded by the server VM"
    `config/client.lua` is declared as a `client_script`. `OPX.Config.CLIENT`
    is `nil` on the server, exactly as `OPX.Config.SERVER` is `nil` on a
    client — a wrong-side read fails loudly instead of silently reading a
    stale default.

    Nothing here is authoritative. A modified client can change any of it, and
    the server re-derives anything that matters.

| Key | Shipped default | Meaning |
|---|---|---|
| `POSITION_REPORT_MS` | `5000` | how often the client reports its position for the autosave; the server re-reads the authoritative position before writing, so this only decides how fresh the hint is |
| `CHARACTER.BOOTSTRAP_POLL_MS` | `250` | how often the bootstrap phase is polled while the selection screen is up |
| `CHARACTER.CREATOR_TIMEOUT_MS` | `300000` | how long to wait for the native character creator to hand back a result |
| `CHARACTER.USE_NATIVE_CREATOR` | `true` | open Cyberpunk's own character creator for a new character; needs the `player.appearance.edit` permission, and `false` means the default body plus your own step |

## Tunables

Tunables are the numbers an operator may change **from the Warden panel while
people are playing**. Every default comes from `config/server.lua`, which stays
the source of truth for a host with no tunables support.

!!! note "Read a tunable at the point of use"
    `OPX.Tune.KEY` is a live read through a proxy. Capturing it into a
    file-scope local freezes the value for the life of the resource.

    ```lua
    -- wrong: frozen at load
    local interval = OPX.Tune.AUTOSAVE_SECONDS

    -- right: re-read each time
    local interval = OPX.TuneNumber("AUTOSAVE_SECONDS", 30)
    ```

A binary predating tunables has no `Open77.tunables` at all. The core detects
this once, falls back to a defaults table built from the same declaration — so
a key cannot exist in one and not the other — and logs a warning.

`OPX.TuneNumber(key, floor)` re-reads a value, substituting the default for a
non-number or NaN, then returning `floor` if the value is still unusable, and
raising the value to `floor` if it is below it.

| Key | Type | Default | Range | Panel label / group |
|---|---|---|---|---|
| `AUTOSAVE_SECONDS` | integer (s) | `300` | 30–3600, step 30 | Autosave interval / Persistence |
| `PAYCHECK_MINUTES` | integer (min) | `10` | 0–240, step 1 | Paycheck interval / Economy |
| `PAYCHECK_REQUIRES_DUTY` | boolean | `true` | — | Only pay players on duty / Economy |
| `CHARACTER_SLOTS` | integer | `3` | 1–20, step 1 | Characters per account / Characters |
| `CHARACTER_ROWS` | integer | `60` | 5–500, step 5 | Character rows per account / Characters |
| `SELECTION_MS` | integer (ms) | `240000` | 30000–900000, step 15000 | Character selection deadline / Characters |

Every one of them applies live. `PAYCHECK_REQUIRES_DUTY` is the only entry
declared without an explicit `type` field; its default is a boolean.

Note the mapping onto `config/server.lua`: `CHARACTER_SLOTS` is
`CHARACTERS.DEFAULT_SLOTS`, `CHARACTER_ROWS` is `CHARACTERS.ROW_CEILING`, and
`SELECTION_MS` is `ENTRY.PIPELINE_MS`. `ENTRY.GATE_MS` is deliberately **not** a
tunable — keep `SELECTION_MS` below it so the core gives up first and can say
why.

Lowering `CHARACTER_SLOTS` never deletes anything: an account already over the
limit keeps every character and simply cannot make another one.

## Data definitions

`data/jobs.lua`, `data/gangs.lua` and `data/origins.lua` hold definitions, not
settings.

!!! danger "Add freely, rename never"
    The key is stored on the character row. Renaming a job or a gang orphans
    every character holding it.

### Jobs

Grades are keyed from `0` and must be contiguous — a promotion is `grade + 1`.

```lua
OPX.Jobs = {
  fixer = {
    label = "Fixer",
    type = "fixer",       -- optional free-form category
    defaultDuty = true,   -- true for a job with no shift to clock into
    offDutyPay = false,   -- pays whether or not its holder is clocked in
    grades = {
      [0] = { name = "Runner", payment = 100 },
      [1] = { name = "Broker", payment = 260 },
      [2] = { name = "Fixer",  payment = 500, isBoss = true, bankAuth = true },
    },
  },
}
```

`isBoss` is published on `PlayerData.job.isBoss`; what a boss may *do* is up to
the gameplay file that asks. `unemployed` is the shipped default job — nothing
to clock into, so its small paycheck needs no shift.

### Gangs

Same rules, without `type`, `defaultDuty`, `offDutyPay` and `payment`.

```lua
OPX.Gangs = {
  maelstrom = {
    label = "Maelstrom",
    grades = {
      [0] = { name = "Chromehead" },
      [1] = { name = "Enforcer" },
      [2] = { name = "Cyberpsycho" },
      [3] = { name = "Warlord", isBoss = true, bankAuth = true },
    },
  },
}
```

`none` is the absence of a gang, kept as a real entry so no call site has to
handle `nil`.

### Origins

The lifepaths offered at character creation. Validated against this list,
stored on `PlayerData.charInfo.origin`, and never read again by the core.

```lua
OPX.Origins = {
  nomad = {
    label = "Nomad",
    description = "Raised in the Badlands, loyal to a clan and to nobody in the city.",
  },
}
```

Shipped: `nomad`, `streetkid`, `corpo`.

## The citizen id

A citizen id looks like `H7K-M4X3`: six payload symbols plus one check symbol,
rendered with a hyphen after the third.

Players type these codes from memory, out loud — transfers, reports, admin
lookups. The format is built to survive an approximate reading.

**The alphabet is 23 symbols with no ambiguous glyph:**

```
34679ACDEFGHJKMNPRTWXYZ
```

No `0` against `O`, no `1` against `I` or `L`, no `5` against `S`.

**The check symbol is a weighted sum modulo 23.** The six payload positions
carry weights `2, 3, 4, 5, 6, 7`, and the check symbol is the one that brings
the weighted sum to zero modulo 23. Because 23 is prime, this catches **every**
single-symbol substitution and **every** transposition of two adjacent symbols.

!!! warning "Do not change the alphabet size or the weights"
    The guarantee comes from the modulus being prime and from the weights being
    distinct. Change either and the check silently stops catching the errors it
    exists for.

Why it exists: without a check symbol, a typo can produce a *valid* code
belonging to somebody else. The money goes to a stranger and nothing on screen
reports an error.

Parsing is forgiving about case and separators, strict about content. Input is
upper-cased with whitespace, hyphens and underscores stripped. An unknown
symbol is **rejected, never dropped** — dropping turns `AO2C-D3F` into somebody
else's id.

```lua
local parsed = OPX.CitizenId.parse(input)
if not parsed.ok then
  -- parsed.error is one of: "type", "length", "alphabet", "checksum"
  return
end
local citizenId = parsed.value  -- normalized, grouped: "H7K-M4X3"
```

`OPX.CitizenId.isValid(value)` is the boolean form, for guarding an internal
call site. Use `parse` on player input, so the caller learns *why*.

`OPX.CitizenId.generate(rng)` accepts an optional
`fun(low, high): integer`, so generation can be made deterministic in a test.

This code is also the `character_key` for `open77_appearance` — one identity
instead of two, so there is no case where a character's face and their money
disagree about who they are. That validator accepts only `^[%w_.:%-]+$`, which
the grouped form satisfies.

## Sessions vs players

!!! note "They are not the same thing"
    A **session** is a connected machine. It exists from `onPlayerConnected`
    and carries the Master-signed `userId`.

    A **player** is a loaded character. It exists only between the moment
    somebody chooses one and the moment they disconnect.

    Somebody sitting in the character selection screen has a session and **no
    player**.

Confusing the two ends one of two ways: refusing a legitimate connection, or
trusting a character that was never loaded.

| | Session | Player |
|---|---|---|
| Exists from | `onPlayerConnected` | character selection |
| Server table | `OPX.Sessions[source]` | `OPX.Players[source]` |
| Fields | `source`, `userId`, `displayName`, `connectedAt`, `gateSession`, `citizenId`, `charactersSent`, `released` | `PlayerData`, `Functions`, `Offline` |

`playerId` (the `source`) is **recycled**; `userId` is **durable and signed**.
The `playerId` is therefore only a lookup key: every read re-checks the `userId`
behind the slot. `OPX.EnsureSession` refuses a slot with no verified identity
and evicts a session whose slot now belongs to a different account, which turns
a missed departure into a non-event instead of a security hole.

A `Player` also exists in an **offline** form — `Offline = true` and
`PlayerData.source = nil` — so a staff command can act on a character who is
not connected.

## The readiness gate

!!! danger "Never place a player before their gate opens"
    Do not teleport, spawn, kill or force a respawn on a player until their
    readiness gate has opened. Acting server-side on a client that is not
    incarnated crashes that client.

The core declares its participation **once, at boot**. That puts a hold on
every player who connects afterwards — the core is not racing to grab a hold
before something else moves the player, it already has one before the player
exists.

There are two deadlines, and the core's is the shorter one:

| Deadline | Where | Shipped | What happens |
|---|---|---|---|
| Host gate timeout | `ENTRY.GATE_MS` | `300000` ms | the host opens the gate itself and emits `timeout:opx77_core` |
| Core join pipeline | `ENTRY.PIPELINE_MS`, tunable `SELECTION_MS` | `240000` ms | the core gives up, releases deliberately, and says why |

If the host wins that race, the gate opens with the player possibly still in the
selection screen and holding **no puppet at all**. That is why the core's
deadline sits below it.

Release is idempotent and safe for a player who never had a hold. If the
session has lost track of its gate session, the core asks the host for the
status rather than skipping — an unreleased hold stalls that player until
`GATE_MS`.

The note passed on release reaches every running resource as the `detail` of
`onPlayerReady`. It is the one channel the core has for telling another
resource what happened. Notes the core sends include `opx77_core:no-identity`,
`opx77_core:roster-failed`, `opx77_core:selection-timeout` and
`opx77_core:done`.

On a server whose binary has no `Open77.ready` gate at all, the core logs a
warning and carries on: characters still load, but nothing stops another
resource from placing a player before the core has chosen where they belong.

### Placement is kill → respawn

!!! warning "Never a raw transform"
    The respawn transaction carries the fade, the streaming preload and the
    grace window that a direct teleport skips.

The sequence the core runs to place a loaded character:

1. Poll the life state up to five times over a second — the gate has just
   opened and the player may still be settling.
2. `Open77.players.kill` with `cause = "script"` and
   `weapon = "opx77_core:placement"`.
3. `Open77.players.respawn` with the target position, heading, bucket, the
   character's stored health (clamped to 0.15–1.0 of full) and a 5000 ms grace
   window.
4. Apply armour **after** the transaction — armour is not a respawn option, and
   the body is about to be replaced.

Order matters at the level above too: log in, place, *then* release the gate.
Releasing first lets every other resource act on a player who is not yet where
they belong, which is the exact race the gate exists to prevent.

If there is no stored position and `DEFAULT_SPAWN.SET` is false, placement
declines and lets the position sampler record wherever the engine dropped the
player — nothing was restored, so there is nothing to overwrite. Every *other*
failure path leaves the sampler switched off, so a failed placement never
writes "wherever the engine dropped them" over the position it could not
restore.

## Database

Every table the core owns is prefixed `opx77_`.

!!! danger "The database is common ground"
    Every resource holding `database.access` talks to the same database, with
    the same credential. There is no per-resource schema, table prefix or
    statement filter. **A resource can read and write another resource's
    tables.**

    That is an integration path as much as an attack surface. Never treat the
    contents of the database as un-forgeable by another installed resource.

| Table | Primary key | Holds |
|---|---|---|
| `opx77_accounts` | `user_id` CHAR(36) | one row per platform account: `display_name`, `created_at`, `last_seen_at`. No password and no email — the platform proved who this is before the session existed |
| `opx77_players` | `citizen_id` VARCHAR(16) | one row per character: `user_id`, `cid`, `name`, the JSON columns `char_info`, `money`, `job`, `gang`, `position` and `metadata`, plus `last_logged_out`, `created_at`, `updated_at` and `deleted_at` |
| `opx77_player_groups` | `(citizen_id, group_type, group_name)` | every job and gang membership, with its `grade` and `joined_at` |
| `opx77_vehicles` | `plate` VARCHAR(12) | owned vehicles: `citizen_id`, `record`, `appearance`, `garage`, `state`, `health`, and the JSON columns `body`, `paint` and `metadata` |
| `opx77_migrations` | `name` VARCHAR(190) | the applied-migration ledger. Created by the migration runner itself, not declared in `schema.lua` |

Design notes worth knowing before writing against these tables:

- `user_id` is `ascii_bin` because a case-insensitive collation would make two
  Master-issued GUIDs compare equal.
- `citizen_id` is the primary key of `opx77_players` because it is also the
  `character_key`.
- The JSON columns are never queried by their contents.
- `cid` is a slot number, not an identity: deleting character 2 of 3 leaves the
  third as `cid` 3.
- The composite primary key on `opx77_player_groups` makes rejoining a group a
  promotion rather than a duplicate row.
- `opx77_vehicles` is keyed on the plate, not the runtime id: the Open77 vehicle
  id is issued at spawn and is gone the moment the owning resource reloads.
- `opx77_player_groups` and `opx77_vehicles` cascade from `opx77_players`, which
  itself cascades from `opx77_accounts`.

### Migrations

`server/storage/schema.lua` is **append-only**. The runner keys on the migration
`name`, never on position — an index renumbers the moment one is inserted in the
middle.

!!! warning "Never edit a migration that has shipped"
    It has already run on live databases, and the runner will not run it again.
    Add a new one.

Migrations apply in order and stop at the first failure: a half-applied schema
is the one state that neither rolling forward nor rolling back is safe from.
Shipped migrations: `0001_accounts`, `0002_players`, `0003_player_groups`,
`0004_vehicles`.

On a server with no database, `OPX.Storage` degrades to one logged line and a
refusal to log anybody in.

## Permissions

The manifest's `permissions {}` block, with the reason each is requested.

| Permission | Why |
|---|---|
| `network.events` | `RegisterNetEvent` and `TriggerClientEvent`. `local.events` is not needed |
| `database.access` | persistence. Safe on a server with no database: storage degrades to one logged line and a refusal to log anybody in |
| `players.life.read` | acting server-side on a client that is not incarnated crashes that client, and the gate can open on a timeout with the player holding no puppet |
| `players.life.kill` | placement is kill → respawn, never a transform write |
| `players.life.respawn` | the respawn carries the fade and the streaming preload that a teleport skips |
| `players.damage.apply` | armour is re-applied after respawn; nothing here reads it back |
| `world.vehicles` | spawning a character's own car, and writing back what happened to it. The runtime id is not durable — a reload removes every vehicle this resource owns — so the plate is |

### Deliberately not requested

`world.props`, `world.elevators`, `combat.config`, `players.damage.read`,
`players.disconnect`.

If you need one of these, it belongs in a satellite resource that requests it
for itself — not in a patch to the core's manifest.

## Load order is the contract

The manifest lists one file per line, and order inside each block is dependency
order. A file publishes into `OPX`, and every file below it may read what was
published.

Two rules, each of which has cost somebody something:

!!! warning "No `require` on the resource's own files"
    A file both listed in the manifest and loaded by `require` executes
    **twice** — the manifest loader does not populate the `require` cache. And
    `require` is confined to the resource anyway, so it could never have reached
    a library living elsewhere.

!!! warning "No globs"
    `server/**/*.lua` matches nothing against flat files, and an empty glob
    stops the whole resource from starting. It is a failure mode that only shows
    up after a rename.

The layers:

| Directory | Contents |
|---|---|
| `config/` | the only files an operator edits. `UPPER_SNAKE` keys |
| `data/` | jobs, gangs, lifepaths. Definitions, not settings |
| `shared/` | `OPX` itself: result, table, string, math, log, validate, hooks, locales, citizen ids |
| `server/storage/` | every SQL statement, and the migrations |
| `server/` | roster, player, groups, characters, gate, events |
| `client/` | the state mirror and the exports surface |

`client/exports.lua` is loaded last, because publishing the surface claims
everything it reads.

## Hooks

The core triggers four veto points. Returning `false` from a hook vetoes the
operation; returning nothing allows it.

`money:beforeAdd`, `money:beforeRemove`, `money:beforeSet`, `paycheck:before`.

The payload carries `player`, and where relevant `moneyType`, `amount` and
`reason`.

## Events

Event names live in one place, `OPX.Events`, named `opx77:<side>:<subject>`.

**Server to client** — `opx77:client:characters`, `opx77:client:playerLoaded`,
`opx77:client:playerUnloaded`, `opx77:client:setPlayerData`,
`opx77:client:onMoneyChange`, `opx77:client:onJobUpdate`,
`opx77:client:onGangUpdate`, `opx77:client:notify`.

**Client to server** — `opx77:server:ready`, `opx77:server:selectCharacter`,
`opx77:server:createCharacter`, `opx77:server:deleteCharacter`,
`opx77:server:reportPosition`, `opx77:server:spawnVehicle`,
`opx77:server:storeVehicle`.

!!! danger "Every client-to-server payload is attacker-controlled"
    Only `source` cannot be forged. The server re-validates everything else.

The core also re-emits two `open77_appearance` events under its own names, so a
selection UI can step out of the way first:
`opx77:client:appearanceRequired` (`characterKey`, `nonce`) and
`opx77:client:appearanceChanged` (`characterKey`).

## Commands

Server commands are gated by the ACL permission `command.<name>`, except the
handful a player runs on their own character.

**Unrestricted** — `opx77.characters`, `opx77.select`, `opx77.create`,
`opx77.delete`, `opx77.duty`. These five are also pushed to the chat resource as
suggestions when it announces itself.

**Restricted** — `opx77`, `opx77.where`, `opx77.here`, `opx77.whois`,
`opx77.money`, `opx77.job`, `opx77.gang`, `opx77.group`, `opx77.save`.

`opx77.here` prints your current position in exactly the shape `DEFAULT_SPAWN`
expects. `opx77.whois` prints a player's durable `userId`, which is what
`SLOTS_BY_USER` is keyed on. `opx77.money`, `opx77.job` and `opx77.gang` accept
either a player id or a citizen id.

## Where to go next

- [Getting started](../getting-started.md) — installing the resource set.
- [Resources overview](index.md) — the rest of the set.
