---
title: Configuration
description: Every key in the four files under opx77_core/config/, with its shipped default, its type, which side it lives on, and which of them an operator can retune from the Warden panel while people are playing.
---

# Configuration

`opx77_core/config/` holds the settings an operator tunes. It is four files, and
they are the only files in the resource a server owner is expected to edit.

**Every value shown on this page is the shipped default.** If you have never
touched `config/`, this page describes your server.

Settings are not definitions. The jobs, gangs and origins in
[`data/`](data.md) are a separate thing with a separate rule: changing a
setting changes behaviour, changing a definition renames something players
already hold. That distinction is spelled out at the top of
[Jobs, gangs and origins](data.md).

## The four files {#files}

| File | Loaded as | Reaches a client | Global it fills |
|---|---|---|---|
| `config/shared.lua` | `shared_script` | **yes — every byte** | `OPX.Config.SHARED` |
| `config/server.lua` | `server_script` | no | `OPX.Config.SERVER` |
| `config/vehicles.lua` | `server_script` | no | `OPX.Config.VEHICLES` |
| `config/client.lua` | `client_script` | yes | `OPX.Config.CLIENT` |

!!! danger "`config/shared.lua` goes out in the signed resource set"
    Everything in it is public and readable by anyone who joins. A licence
    key, a webhook URL, a Discord token or an admin identifier put in this
    file is published to every player who connects. Those belong in
    `config/server.lua`, which the server VM alone ever loads.

Each global exists on one side only. `OPX.Config.SERVER` is `nil` on a client
and `OPX.Config.CLIENT` is `nil` on the server, by construction: a wrong-side
read fails loudly at the point of the mistake instead of silently returning a
stale default.

Each file opens with an annotation block carrying one `@field` line per key, the
short form of what this page says about it.

---

## SERVER_NAME {#shared-server-name}

Names the server in the launcher and in player-facing text; the core also uses
it as the title of every notification it sends.

```lua
SERVER_NAME = 'OPX//77',
```

**Type** `string`

**File** `config/shared.lua` — shipped to every client

**Read by** `server/functions.lua` (the title of every toast, and the author of
every command report line), `client/events.lua` (the title of a command answer's
toast, and the author of its chat fallback), and republished to any resource
through [`GetSharedConfig`](exports/client.md#getsharedconfig) as `serverName`.

---

## LOCALE {#shared-locale}

Chooses the language of player-facing text, applied at load; server logs stay
in English whatever it is set to.

```lua
LOCALE = 'en',
```

**Type** `string` — a catalogue registered in `locales/`. `'en'` and `'fr'`
ship.

**File** `config/shared.lua` — shipped to every client

**Read by** `shared/locale.lua`, which calls `OPX.Locale.set` with it at load on
both sides.

This key covers `opx77_core`'s own catalogue and nothing else. Every satellite
that renders text of its own carries a second `LOCALE`, in its own `config.lua`
— see [Locales](#satellite-locales) below.

An unknown code is **accepted**, not rejected: catalogues register after this
file loads, so there is nothing to check it against yet. Every lookup then
falls back to `en`, and then to the key itself — so a gameplay file that adds a
string without translating it shows the player its raw key rather than nothing,
which is the failure you want, because it is visible.

[`GetSharedConfig`](exports/client.md#getsharedconfig) republishes `locale` as
the code *in force*, which after an unknown code is not the same thing as the
catalogue being read.

---

## APPEARANCE {#shared-appearance}

Bounds what the core will accept as a stored face.

```lua
APPEARANCE = {
	GAME_BUILDS = { ['2.31'] = true },

	MAX_JSON_BYTES = 49152,
},
```

**Type** `table` — `GAME_BUILDS` is a set of build strings; `MAX_JSON_BYTES` is
an integer, measured on the encoded JSON

**File** `config/shared.lua` — shipped to every client

**Read by** `server/appearance.lua`, which refuses a snapshot captured on a
build outside `GAME_BUILDS` with `appearance.invalid` (logging
`unsupported_game_build` as the reason), and one whose encoded document is
larger than `MAX_JSON_BYTES` with `appearance.tooLarge`.

A snapshot is a list of positions in the customization catalogue, so it only
means anything against the catalogue it was captured on. Widening `GAME_BUILDS`
does not make an old snapshot fit — it only stops the framework saying so. A
canonical snapshot of the maximum 256 options is far below the byte ceiling.

---

## MONEY.TYPES {#shared-money-types}

Declares every money type this server has, mapped to the balance a brand new
character starts with.

```lua
MONEY = {
	TYPES = {
		EDDIES = 500,
		BANK = 5000,
	},
},
```

**Type** `table<string, integer>` — `EDDIES` is carried on the person and
losable, `BANK` is held by a bank

**File** `config/shared.lua` — shipped to every client

!!! danger "The names are durable"
    A type name becomes a key in the `money` JSON column of `opx77_characters`.
    **Adding a type is free. Renaming one orphans every balance already stored
    under the old name** — the money is still in the row, under a key nothing
    reads any more, and the character now starts that type at zero. Nothing in
    the core will find it for you.

This table is the whole authority on what a money type is:
`OPX.IsMoneyType` resolves against it, so an operator who adds `CRYPTO = 0`
here has it accepted by `AddMoney`, `RemoveMoney`, `SetMoney` and `GetMoney`
everywhere with no further change. A type not in this table is refused with
`money.badType`.

The number is a **new-character grant, not a floor.** A type added to an
already-running server loads at zero for every character that existed before
it, because `server/player.lua` fills a missing balance with `0` rather than
with the value here. Only `OPX.CreateCharacter` reads these amounts.

---

## MONEY.DEFAULT {#shared-money-default}

Names the money type a UI should offer when the player has not chosen one, and
the type a paycheck lands in when `PAYCHECK_TYPE` is not a money type.

```lua
MONEY = {
	DEFAULT = 'EDDIES',
},
```

**Type** `string` — must be a key of [`MONEY.TYPES`](#shared-money-types)

**File** `config/shared.lua` — shipped to every client

**Read by** `server/loops.lua`, once at load, as the fallback for
[`PAYCHECK_TYPE`](#server-paycheck-type), and
[`GetSharedConfig`](exports/client.md#getsharedconfig), which publishes it as
`defaultMoneyType`.

!!! warning "The money mutators do not fall back to it"
    The key's annotation calls it *"Type a payment falls back to when none is
    named"*, and no mutator does that. `OPX.AddMoney`, `OPX.RemoveMoney` and
    `OPX.SetMoney` all refuse a `nil` or unknown `moneyType` with
    `money.badType` rather than substituting this value. Treat it as advice to
    a UI, and always name the type explicitly when you call a money mutator.

---

## CHARACTERS.NAME {#shared-characters-name}

Bounds how long each half of a character's name may be, counted in characters
rather than bytes.

```lua
CHARACTERS = {
	NAME = { MIN = 2, MAX = 32 },
},
```

**Type** `{ MIN: integer, MAX: integer }`

**File** `config/shared.lua` — shipped to every client

**Read by** `OPX.ValidateName` in `shared/functions.lua`, which runs on both
sides against the same bounds and the same pattern. The client check spares a
round trip and gives a form something to mark; the server checks again and is
the one that decides. The two bounds also fill the help line the chat
autocomplete shows for `/opx77.create`.

Characters, not bytes: the length comes from `OPX.String.length`, which uses
`utf8.len` and returns `nil` for bytes that are not valid UTF-8. `"Éloïse"` is
six characters and eight bytes, and the eight is never what is measured. The
accepted alphabet covers accented Latin, Greek, Cyrillic and CJK, plus the
space, apostrophe and hyphen; four-byte sequences are excluded, which is where
emoji live.

---

## DEFAULT_SPAWN {#shared-default-spawn}

Places a character who has no stored position — a brand new one, or one whose
row has never been written — and does nothing at all while `SET` is `false`.

```lua
DEFAULT_SPAWN = {
	SET = false,
	X = 0.0,
	Y = 0.0,
	Z = 0.0,
	HEADING = 0.0,
},
```

**Type** `{ SET: boolean, X: number, Y: number, Z: number, HEADING: number }`

**File** `config/shared.lua` — shipped to every client

The zeros are not a real Night City coordinate and are not meant to be one.
Run [`opx77.here`](commands.md#opx77-here) in game to print your own position in
exactly this shape, paste it in, and set `SET = true`.

While `SET` is `false` the core logs one warning at boot and then leaves every
unplaced character wherever the game happened to put them:

```text
[core] DEFAULT_SPAWN.SET is false in config/shared.lua: characters with no stored position are left where the game put them. Run `opx77.here` in game to print a coordinate in the right shape.
```

---

## NOTIFY_POSITION {#shared-notify-position}

Chooses where the toasts the core sends are drawn. It is passed through
`Open77.notifications.send` for the server's toasts, and to `opx77_notify`'s
`show` for the command answers the core's client half raises —
[`opx77_notify`](../opx77_notify/index.md) defaults to this same corner, so the
two agree without either being configured.

```lua
NOTIFY_POSITION = 'top_right',
```

**Type** `string` — one of `middle_left` (the notification service's own
default), `top_left`, `top_center`, `top_right`, `bottom_left`,
`bottom_center`, `bottom_right`

**File** `config/shared.lua` — shipped to every client

!!! warning "Underscores, not hyphens"
    The platform's vocabulary is `top_right`, never `top-right`. A hyphenated
    value is not one of the seven, and every toast the core sent would carry it.

The core **warns about an unrecognised value and sends it anyway**. That is
deliberate rather than lax: the accepted set is known only from the platform's
website, the server binary does not validate `position` at all, and the
resource that renders the toast is a *client* resource the server cannot read —
so a whitelist that guessed the set wrong would silently swallow every
notification the core sends. The check runs once, at load, in
`client/exports.lua`; you get one warning line, not one per toast.

`OPX.IsNotifyPosition(position)` is published on both sides if you want to make
the same check yourself.

---

## AUTOSAVE_SECONDS {#server-autosave-seconds}

Sets how often every loaded character is written back to the database, which is
what bounds how much a crash, a power cut or a `kill -9` costs.

```lua
AUTOSAVE_SECONDS = 300,
```

**Type** `integer` — seconds

**File** `config/server.lua` — server only, never sent to a client

**Tunable** `AUTOSAVE_SECONDS`, 30–3600 step 30, applied live. See
[Tunables](#tunables) — and read it with `OPX.TuneNumber('AUTOSAVE_SECONDS', 30)`
at the point of use, never into a file-scope local.

Saving only on logout is lossy in exactly the cases people care about most.
Lower costs more database writes. The autosave writes only characters whose
revision has moved, or who have moved a metre or more, since their last write,
so an idle server writes nothing.

---

## MONEY.ALLOW_NEGATIVE {#server-money-allow-negative}

Lists the money types that may go below zero; for a type not listed, a removal
that would go below zero is refused whole rather than truncated.

```lua
MONEY = {
	ALLOW_NEGATIVE = { BANK = true },
},
```

**Type** `table<string, boolean>` — keys are [`MONEY.TYPES`](#shared-money-types)
names

**File** `config/server.lua` — server only, never sent to a client

**Read by** `OPX.RemoveMoney` and `OPX.SetMoney` in `server/player.lua`. A
removal is refused with `money.insufficient`, and a negative `SetMoney` with
`money.negative` — the balance is untouched, and the caller is told which rule
it broke rather than being handed a partial debit.

`BANK` only, and that asymmetry is the point: an overdraft is a feature of a
bank account, and carried cash going negative never is.

---

## MONEY.PAYCHECK_MINUTES {#server-paycheck-minutes}

Sets the minutes between paychecks; zero turns paychecks off entirely without
touching a single job definition.

```lua
MONEY = {
	PAYCHECK_MINUTES = 10,
},
```

**Type** `integer` — minutes, `0` to disable

**File** `config/server.lua` — server only, never sent to a client

**Tunable** `PAYCHECK_MINUTES`, 0–240 step 1, applied live. See
[Tunables](#tunables) — and read it with
`OPX.TuneNumber('PAYCHECK_MINUTES', 0)` at the point of use, never into a
file-scope local.

Switching it back on resumes the same salaries, because the amounts live in
[`data/jobs.lua`](data.md) and this key only decides how often they are paid.
Which money type they land in is [`PAYCHECK_TYPE`](#server-paycheck-type).

---

## MONEY.PAYCHECK_REQUIRES_DUTY {#server-paycheck-requires-duty}

Restricts paychecks to players who are clocked in.

```lua
MONEY = {
	PAYCHECK_REQUIRES_DUTY = true,
},
```

**Type** `boolean`

**File** `config/server.lua` — server only, never sent to a client

**Tunable** `PAYCHECK_REQUIRES_DUTY`, applied live — the only tunable declared
with no `type` field. See [Tunables](#tunables), and read it as
`OPX.Tune.PAYCHECK_REQUIRES_DUTY` at the point of use, never into a file-scope
local.

A job's own [`offDutyPay`](data.md#job-shape) overrules this: the
server-wide switch cannot stop a job that pays off duty from paying off duty.
Turning it off is what a low-population server usually wants, because a job
nobody can clock into on an empty server otherwise pays nothing at all.

---

## MONEY.PAYCHECK_TYPE {#server-paycheck-type}

Names the money type a salary lands in, and the type its toast names.

```lua
MONEY = {
	PAYCHECK_TYPE = 'BANK',
},
```

**Type** `string` — a key of [`SHARED.MONEY.TYPES`](#shared-money-types)

**File** `config/server.lua` — server only, never sent to a client

**Read by** `server/loops.lua`, once at load: a name that is not a money type on
this server is warned about at boot and the paycheck falls back to
[`SHARED.MONEY.DEFAULT`](#shared-money-default), rather than being re-checked on
every cycle.

`BANK` rather than carried cash, because a salary that lands as `EDDIES` can be
taken off the body of whoever logged in at the wrong moment. The type is
substituted into the `money.paycheck` locale line, so the toast names whatever
this key actually pays into.

---

## CHARACTERS.DEFAULT_SLOTS {#server-characters-default-slots}

Sets how many characters one account may hold.

```lua
CHARACTERS = {
	DEFAULT_SLOTS = 3,
},
```

**Type** `integer`

**File** `config/server.lua` — server only, never sent to a client

**Tunable** `CHARACTER_SLOTS`, 1–20 step 1, applied live. See
[Tunables](#tunables) — and read it with
`OPX.TuneNumber('CHARACTER_SLOTS', 1)` at the point of use, never into a
file-scope local.

Lowering it never deletes anything: an account already over the limit keeps
every character it has and simply cannot make another. A creation past the
limit is refused with `character.limit`, which names the account's own slot
count — this value, or its override.
[`SLOTS_BY_USER`](#server-characters-slots-by-user) overrides it per account,
and an override is taken as written — the tunable does not apply to it.

---

## CHARACTERS.SLOTS_BY_USER {#server-characters-slots-by-user}

Overrides the slot count for named accounts, keyed by durable `userId`.

```lua
CHARACTERS = {
	SLOTS_BY_USER = {},
},
```

**Type** `table<string, integer>`

**File** `config/server.lua` — server only, never sent to a client

Run [`opx77.whois`](commands.md#opx77-whois) in game to print a player's
`userId`. It is the platform identity behind every character on the account and
it does not change; see [Identity](../../concepts/identity.md) for what it is and
what it is not.

An entry here bypasses the `CHARACTER_SLOTS` tunable entirely, so a value set
from the Warden panel will not move it. The roster the client is sent carries
the account's own count as `slots`.

---

## CHARACTERS.ROW_CEILING {#server-characters-row-ceiling}

Caps the number of rows one account may ever write to `opx77_characters` over its
whole lifetime.

```lua
CHARACTERS = {
	ROW_CEILING = 60,
},
```

**Type** `integer`

**File** `config/server.lua` — server only, never sent to a client

**Tunable** `CHARACTER_ROWS`, 5–500 step 5, applied live. See
[Tunables](#tunables) — and read it with
`OPX.TuneNumber('CHARACTER_ROWS', 5)` at the point of use, never into a
file-scope local.

!!! warning "A lifetime ceiling, not a roster size"
    Deleting a character is a **soft delete**: the slot is freed but the row
    stays, so the deletion can be undone and so a citizen id is never
    reissued. Create-and-delete therefore writes a new row every single time,
    and this key is the only thing that stops that being unbounded. Keep it
    well above [`DEFAULT_SLOTS`](#server-characters-default-slots) — the
    shipped 60 against 3 is twenty create-and-delete cycles, not twenty
    characters. An account at the ceiling is refused with `character.rowLimit`.

---

## CHARACTERS.CASCADE_TABLES {#server-characters-cascade-tables}

Lists the tables whose rows are deleted along with a character, as
`{ TABLE, COLUMN }` pairs matched against the citizen id.

```lua
CHARACTERS = {
	CASCADE_TABLES = {},
},
```

**Type** `{ [1]: string, [2]: string }[]`

**File** `config/server.lua` — server only, never sent to a client

**Read by** `OPX.DeleteCharacter` in `server/character.lua`, which deletes the
matching rows for real when it soft-deletes the character.

This is for gameplay files you add to `opx77_core` that keep their own tables.
The core's own tables are not listed: a character's memberships, clothing,
vehicles and bag stay with its soft-deleted row, and their foreign keys, declared
`ON DELETE CASCADE` in `server/storage/schema.lua`, take them only when the row
is really deleted.

---

## ENTRY.GATE_MS {#server-entry-gate-ms}

Declares the liveness interval the host watches `opx77_core` on while it holds
the join-time readiness gate.

```lua
ENTRY = {
	GATE_MS = 300000,
},
```

**Type** `integer` — milliseconds; the host clamps it to `[1000, 600000]`

**File** `config/server.lua` — server only, never sent to a client

!!! warning "Not a budget for the player"
    This is **not** how long a joining player is given. It is how long the host
    will wait for a sign of life from *this resource* before deciding the
    holder is gone and opening the gate anyway, with the detail
    `liveness_lost:opx77_core`. A hold is refreshed by taking it again; the
    core takes one hold per join and never refreshes it, so in practice this
    doubles as the deadline it has.

It is passed to `Open77.ready.participate` in `server/lifecycle.lua`.
Deliberately **not** a tunable: it is a contract with the host declared once at
load, and the number that an operator would actually want to move is
[`PIPELINE_MS`](#server-entry-pipeline-ms). [The entry
gate](../../concepts/entry-gate.md) explains what the gate is and what opens it.

---

## ENTRY.PIPELINE_MS {#server-entry-pipeline-ms}

Sets the core's own deadline for choosing a character, held below `GATE_MS` so
the core gives up first and can say why.

```lua
ENTRY = {
	PIPELINE_MS = 240000,
},
```

**Type** `integer` — milliseconds

**File** `config/server.lua` — server only, never sent to a client

**Tunable** `SELECTION_MS`, 30000–240000 step 15000, applied live. See
[Tunables](#tunables) — and read it with
`OPX.TuneNumber('SELECTION_MS', 30000)` at the point of use, never into a
file-scope local.

The tunable's maximum is this value rather than a round 900000, and that is
load-bearing: a selection the panel could stretch past
[`GATE_MS`](#server-entry-gate-ms) would have the host declare this resource
dead mid-screen and open the gate with `liveness_lost:opx77_core`. If you raise
`GATE_MS`, raise this too — and if you lower `GATE_MS`, lower this first.

At the deadline the core releases its hold with the note
`opx77_core:selection-timeout` and sends `entry.timedOut` on the `entry`
operation. It does not disconnect the player, and `SelectCharacter` still works
afterwards.

---

## ENTRY.BUCKET {#server-entry-bucket}

Sets the routing bucket a player waits in while no character is loaded: one per
player, so nobody choosing a character sees anybody else or is seen.

```lua
ENTRY = {
	BUCKET = {
		ISOLATE = true,

		BASE = 77000,

		WORLD = 0,

		POPULATION = false,
		LOCKDOWN = 'relaxed',
	},
},
```

**Type** `table`

**File** `config/server.lua` — server only, never sent to a client

**Read by** `server/buckets.lua`, once at load. A value of the wrong type is said
once and the shipped one is used.

| Key | Does | Shipped |
|---|---|---|
| `ISOLATE` | `false` moves nobody: every player stays in `WORLD` | `true` |
| `BASE` | a player's own bucket is `BASE` plus their player id, up to `BASE + 65535`. Keep that range clear of every other resource's buckets: the platform's Deathmatch uses 4100–4287 and its Race 6500 | `77000` |
| `WORLD` | where a character is placed when its stored position names no bucket, or one in the selection range. A `WORLD` inside the selection range turns isolation off, with an error | `0` |
| `POPULATION` | ambient population in a selection bucket | `false` |
| `LOCKDOWN` | the selection bucket's entity lockdown: `inactive`, `relaxed`, `strict` or `full`; `false` leaves it alone | `'relaxed'` |

Population off and a `relaxed` lockdown are how the platform prepares its own
isolated rounds. The routing bucket API needs **no manifest permission**.

### The lifecycle {#server-entry-bucket-lifecycle}

| When | The player's bucket |
|---|---|
| they connect | their own, at once, under the closed readiness gate. Taken again at their client's `READY` if the host refused it |
| a character is selected | the placement bucket — the stored one, or `WORLD` — set just before the kill → respawn, which names the same bucket |
| the character could not be placed | `WORLD` all the same: it is loaded, and plays where it stands |
| the character is unloaded — a logout, or the deletion of the loaded one | their own again. The position is sampled **before** the move, so the row keeps the world bucket |
| a switch from one character to another | no move, unless the switch fails after the first character was torn down |
| they disconnect | nothing: the host drops the player, and their bucket with them |
| `opx77_core` stops | everybody in a selection bucket goes to `WORLD` |
| `opx77_core` starts again | a player still behind the readiness gate is isolated again at their `READY`; one past it has been in the world this session and stays in `WORLD` |

Every move is one debug line:

```text
[bucket] 3 moved from 0 to 77003 (joined)
[bucket] 3 moved from 77003 to 0 (placement)
```

and a refusal a warning:

```text
[bucket] 3 could not be moved from 0 to 77003 (joined): <reason>
```

A stored position in the selection range is never placed into: that bucket
belongs to whoever holds the player id now. It is what a staff member who went
to a player on the roster, and saved there, would otherwise come back to.

### Under the closed gate {#server-entry-bucket-gate}

[The gate's rule](../../concepts/entry-gate.md) is never to teleport, spawn, kill
or force a respawn on a player whose gate is closed, because acting on the body of
a client that is not incarnated crashes it. A bucket move is none of those. The
host's `setPlayer` "moves authoritative visibility scope" — which bodies,
vehicles and props are replicated to and from the player — and writes no
transform, life state or puppet. The platform's own `open77_appearance` handles
`onPlayerBucketChange` with no life or gate check, and none of the host's bucket
refusals names readiness. So the core moves the player at connect, which is also
the only moment nothing from the shared world has been replicated to them yet.

### Other resources {#server-entry-bucket-others}

- **`opx77_admin`** — `goto`, `bring` and `observe` place through kill → respawn
  into a bucket, and refuse a target whose readiness gate is closed, which is
  every player on the roster for the first time. A player back on the roster
  after an unload has an open gate: `goto` then lands the staff member in that
  player's selection bucket, and `bring` takes the player into the staff
  member's. The core undoes neither; the next selection places the character in
  the world as usual.
- **`opx77_elevators`** answers `wrong_bucket` outside its lift's bucket, and
  **`opx77_animations`** plays within a bucket: neither is reachable from the
  roster.
- **The face editor** of a character with no stored face opens after the
  character is placed, so it opens in `WORLD`.

---

## PLAYER.STARTING_METADATA {#server-player-starting-metadata}

Sets what a brand new character starts with; it becomes the initial
`PlayerData.metadata`.

```lua
PLAYER = {
	STARTING_METADATA = {
		health = 100,
		armor = 0,
		isDead = false,
		inLastStand = false,
	},
},
```

**Type** `table<string, any>` — see [`PlayerMetadata`](types.md)

**File** `config/server.lua` — server only, never sent to a client

**Read by** `server/character.lua`, which deep-copies it into the new row, and
`server/player.lua`, which fills in any key an older row is missing on load.

Metadata is free-form: a gameplay file that adds its own key has it merged on
top and it survives every save. The four keys shipped are the four the core
itself reads: [`OPX.PlaceCharacter`](server-api.md#placecharacter) clamps the
respawn transaction with the stored `health` and applies `armor` after it, and
`isDead` and `inLastStand` are stored, published and never written by anything
in the core.

The gameplay needs are **not** here. Hunger, thirst, stamina and street cred
belong to [`opx77_status`](../opx77_status/index.md), in its own table, and the
core neither seeds nor writes them.

---

## PLAYER.DEFAULT_JOB {#server-player-default-job}

Names the job a new character is employed in, and the job a character falls
back to when they are removed from their primary one.

```lua
PLAYER = {
	DEFAULT_JOB = 'unemployed',
},
```

**Type** `string` — must be a key of [`OPX.Jobs`](data.md#jobs)

**File** `config/server.lua` — server only, never sent to a client

**Read by** `server/groups.lua` (the fallback on
`OPX.RemovePlayerFromJob`), `server/character.lua` (a new character) and
`server/player.lua` (a stored job that no longer resolves).

A name with no entry in [`data/jobs.lua`](data.md#jobs) makes character
creation fail with `job.notFound`. If you rename the shipped `unemployed` job,
change this key in the same commit.

---

## PLAYER.DEFAULT_GANG {#server-player-default-gang}

Names the gang a new character belongs to, and the gang a character falls back
to when they are removed from their primary one.

```lua
PLAYER = {
	DEFAULT_GANG = 'none',
},
```

**Type** `string` — must be a key of [`OPX.Gangs`](data.md#gangs)

**File** `config/server.lua` — server only, never sent to a client

**Read by** `server/groups.lua`, `server/character.lua` and `server/player.lua`,
exactly as [`DEFAULT_JOB`](#server-player-default-job) is.

The shipped `none` gang exists precisely so this key can point somewhere: it is
the absence of a gang, kept as a real entry so no call site has to handle
`nil`.

---

## CONFLICTING_PLACERS {#server-conflicting-placers}

Names the resources that would fight the core over where a player stands, so it
can warn about them at boot.

```lua
CONFLICTING_PLACERS = { 'open77_playerstate', 'freeroam', 'pursuit', 'race' },
```

**Type** `string[]`

**File** `config/server.lua` — server only, never sent to a client

The core **disables nothing.** It checks `GetResourceState` for each name at
boot and prints one warning, once, per name that is `running` or `starting`:

```text
[core] freeroam is running and also places players; see CONFLICTING_PLACERS in config/server.lua
```

`starting` counts, because a resource coming up will be placing players a moment
from now.

What to do about each of the shipped four:

| Resource | What to do |
|---|---|
| `open77_playerstate` | Stop it, or add `opx77_core` to its `spawnOwners` tunable. |
| `freeroam` | Turn its `forceOnJoin` off. |
| `pursuit`, `race` | Round-based gamemodes. Two gamemodes on the same players is a bug in the resource set, not something to configure around. |

Two resources moving the same player means the last one wins, with no rule
saying which will be last.

---

## EXPORTS.READ {#server-exports-read}

Names the server resources that may call the four read
[server exports](exports/server.md) — `GetVersion`, `GetIdentity`, `GetChanges`
and `GetVehiclePlate`.

```lua
EXPORTS = {
	READ = '*',
},
```

**Type** `string|table<string, boolean>` — `'*'` for every server resource, or a
set of resource names such as `{ opx77_inventory = true, opx77_status = true }`

**File** `config/server.lua` — server only, never sent to a client

**Read by** `server/exports.lua`, on every call. The caller's name is read from
the host with `GetInvokingResource()`, never from an argument; a caller not
admitted is answered `export.callerDenied` and written to the audit log as an
`export.denied` security line.

!!! warning "Keep `opx77_inventory` and `opx77_status` in a narrowed set"
    Both call [`GetIdentity`](exports/server.md#getidentity):
    `opx77_inventory` to key a bag on the loaded character, and `opx77_status`
    to admit a pull of stored needs only for the character the core has loaded
    on that player. A set that leaves either out stops that resource loading
    anything. Any other value than `'*'` or a table admits nobody.

---

## EXPORTS.CALLERS {#server-exports-callers}

Grants resources the scopes the write exports need. The seven `Inventory*`
exports need the `inventory` scope.

```lua
EXPORTS = {
	CALLERS = {
		opx77_inventory = { scopes = { inventory = true } },
	},
},
```

**Type** `table<string, { scopes: table<string, boolean> }>`

**File** `config/server.lua` — server only, never sent to a client

**Read by** `server/exports.lua`, on every inventory call, and by
[`GetVersion`](exports/server.md#getversion), which answers the scopes its
caller holds. A caller without the scope is refused with `export.callerDenied`
and an `export.denied` security line.

`opx77_inventory` is the one caller shipped, and the one that needs it. A
resource listed here is not admitted to the reads by this entry; those follow
[`EXPORTS.READ`](#server-exports-read).

!!! danger
    A resource granted `inventory` can empty or rewrite any container on the
    server. Grant it to the inventory and to nothing else.

---

## EXPORTS.MAX_RESULT_BYTES {#server-exports-max-result-bytes}

Caps how heavy one server export answer may be, measured on its encoded JSON.

```lua
EXPORTS = {
	MAX_RESULT_BYTES = 32768,
},
```

**Type** `integer` — bytes

**File** `config/server.lua` — server only, never sent to a client

**Read by** `server/exports.lua`, once at load. An answer over it is refused
with `export.tooLarge` rather than reaching the caller as the platform's own
codec refusal, and [`InventoryRead`](exports/server.md#inventoryread) trims its
page to half of it.

The host's transfer budget is 48 KiB per answer, and that budget counts its own
node overhead; 32 KiB leaves the margin. Do not raise it towards 48 KiB.

---

## INVENTORY {#server-inventory}

Bounds what the inventory storage [server exports](exports/server.md#inventory-storage)
accept. These guard the tables, not the gameplay: sizes and weights are
`opx77_inventory`'s decision.

```lua
INVENTORY = {
	MAX_SLOTS = 1000,
	MAX_WEIGHT = 4000000000,
	MAX_METADATA_BYTES = 4096,
	PAGE_ROWS = 64,

	LINKED_KINDS = { character = 'citizen', trunk = 'plate', glovebox = 'plate' },
},
```

**Type** `table`

**File** `config/server.lua` — server only, never sent to a client

**Read by** `server/exports.lua`.

| Key | Bounds | Shipped |
|---|---|---|
| `MAX_SLOTS` | the slots one container may have, a stack's slot number, and the stacks one `InventoryStage` call and one container under a token may carry. The column is `SMALLINT UNSIGNED` | `1000` |
| `MAX_WEIGHT` | a container's weight limit, in grams. The column is `INT UNSIGNED` | `4000000000` |
| `MAX_METADATA_BYTES` | one stack's metadata, encoded | `4096` |
| `PAGE_ROWS` | the stacks one `InventoryRead` answers at most, before the size trim | `64` |
| `LINKED_KINDS` | the kinds whose owner is another row: `citizen`, a living character's citizen id, or `plate`, an owned vehicle's plate. `InventoryEnsure` refuses an owner that does not exist with `inventory.noOwner`, and the container goes with that row when it is really deleted. Any other kind stands alone | `{ character = 'citizen', trunk = 'plate', glovebox = 'plate' }` |

---

## PER_CHARACTER {#vehicles-per-character}

Caps how many vehicles one character may own; `0` removes the ceiling.

```lua
PER_CHARACTER = 8,
```

**Type** `integer`

**File** `config/vehicles.lua` — server only, never sent to a client. Fills
`OPX.Config.VEHICLES`.

Exceeding it refuses the creation with `vehicle.limit`, carrying the configured
number as its detail so a UI can say what the limit was.

---

## PLATE_FORMAT {#vehicles-plate-format}

Describes the shape of a generated number plate: `1` becomes a digit, `A` a
letter, `.` either, and anything else is copied through as written. It is handed
straight to [`OPX.String.random`](server-api.md#stringrandom), so the tokens are
that helper's.

```lua
PLATE_FORMAT = '11AAA111',
```

**Type** `string`

**File** `config/vehicles.lua` — server only, never sent to a client

Plates are generated as uppercase ASCII only: the column is `ascii_bin`, and a
plate is compared for equality far more often than it is read. Widen the format
before a busy server exhausts the space — the shipped shape is
10<sup>5</sup> × 26<sup>3</sup> combinations, and generation gives up with
`vehicle.plateExhausted` rather than looping forever.

---

## DEFAULT_GARAGE {#vehicles-default-garage}

Names the garage a vehicle created without one belongs to.

```lua
DEFAULT_GARAGE = 'impound',
```

**Type** `string`

**File** `config/vehicles.lua` — server only, never sent to a client

The core attaches no meaning to the string beyond storing it; garages are a
gameplay concept and there is no garage resource in the framework. Pick a name
your own resource will recognise.

---

## SPAWN_OFFSET {#vehicles-spawn-offset}

Sets how many metres to the side of the player a spawned vehicle appears.

```lua
SPAWN_OFFSET = 3.0,
```

**Type** `number` — metres

**File** `config/vehicles.lua` — server only, never sent to a client

Applied on the X axis, with a fixed 0.25 m lift on Z so the car is not spawned
inside the road surface. It is not rotated to face the player's heading, so a
player standing against a wall can put a car into it.

---

## SAVE_SECONDS {#vehicles-save-seconds}

Sets how often the condition of every vehicle that is currently out is written
back.

```lua
SAVE_SECONDS = 120,
```

**Type** `integer` — seconds

**File** `config/vehicles.lua` — server only, never sent to a client

A separate loop from the character autosave, and separately configured: a
vehicle's fuel and body damage change far faster than a character's money does.
Unlike [`AUTOSAVE_SECONDS`](#server-autosave-seconds) this one is not a
tunable, so changing it needs a restart.

---

## POSITION_REPORT_MS {#client-position-report-ms}

Sets how often the client checks its heading and reports it to the server, in
milliseconds.

```lua
POSITION_REPORT_MS = 5000,
```

**Type** `integer` — milliseconds

**File** `config/client.lua` — client only; `OPX.Config.CLIENT` is `nil` on the
server

!!! warning "Nothing here is authoritative"
    A modified client can change any value in this file, and the server
    re-derives anything that matters. The server reads the position itself
    before it writes, and keeps only the heading from the client, which its own
    position snapshot does not carry — so this key only decides how fresh that
    *hint* is. A client that never reports costs itself nothing.

A report goes out only while a character is loaded and only when the heading has
moved by 2 degrees or more since the last one. The server's rate limit on the
reporting event is a literal, not this value: that VM never loads
`config/client.lua`, and a rate limit derived from a number the client controls
would not be one.

---

## Locales, and why there is more than one {#satellite-locales}

[`SHARED.LOCALE`](#shared-locale) chooses the catalogue for `opx77_core`'s own
player-facing text, and for nothing else. Every satellite in this set that
renders text of its own carries its own catalogue — `locales/en.lua` and
`locales/fr.lua` — and its own `LOCALE` key, in its own `config.lua`:

| Resource | Key |
|---|---|
| `opx77_core` | `SHARED.LOCALE` in `config/shared.lua` |
| [`opx77_admin`](../opx77_admin/config.md) | `OPX_ADMIN_CONFIG.LOCALE` |
| [`opx77_animations`](../opx77_animations/config.md) | `OPX_ANIMATIONS_CONFIG.LOCALE` |
| [`opx77_appearance`](../opx77_appearance/config.md) | `OPX_APPEARANCE_CONFIG.LOCALE` |
| [`opx77_charcreator`](../opx77_charcreator/config.md) | `OPX_CHARCREATOR_CONFIG.LOCALE` |
| [`opx77_charselector`](../opx77_charselector/config.md) | `OPX_CHARSELECTOR_CONFIG.LOCALE` |
| [`opx77_chat`](../opx77_chat/config.md) | `OPX_CHAT_CONFIG.LOCALE` |
| [`opx77_elevators`](../opx77_elevators/config.md) | `OPX_ELEVATORS_CONFIG.LOCALE` |
| [`opx77_hud`](../opx77_hud/config.md) | `OPX_HUD_CONFIG.LOCALE` |
| [`opx77_input`](../opx77_input/config.md) | `OPX_INPUT_CONFIG.LOCALE` |
| [`opx77_inventory`](../opx77_inventory/config.md) | `OPX_INVENTORY_CONFIG.LOCALE` |
| [`opx77_menu`](../opx77_menu/config.md) | `OPX_MENU_CONFIG.LOCALE` |
| `opx77_prompts` | `OPX_PROMPTS_CONFIG.LOCALE` |
| [`opx77_weather`](../opx77_weather/config.md) | `OPX_WEATHER_CONFIG.LOCALE` |

Every one of them ships `'en'`.

That is a second place to set a language on a server that has already set one,
and it is deliberate: the core's [`Locale`](exports/client.md#locale) export is
**client-only and asynchronous**, so a satellite's server half can never call
it, and a satellite that renders a string at load cannot wait on it either. Each
resource therefore resolves its own keys, with the same fallback to English and
then to the key itself.

`opx77_notify` and `opx77_status` ship **no** catalogue and no `LOCALE` key.
They render nothing of their own: every string they draw was handed to them by
the resource that called them, in whatever language that resource chose.

Error **codes** that are not catalogue keys are not translated anywhere.
`not_owner`, `rate_limited`, `invalid_status` and the rest are a branching
surface for a caller, not text; a resource that wants to show one renders it
through its own catalogue. The core's own refusal codes are the exception: every
one is a key of its catalogue. `Open77.log` lines, console output and the
ACL-gated diagnostic reports stay English, because they are for the operator
reading a server log.

---

## Tunables {#tunables}

Tunables are the numbers an operator may change **from the Warden panel while
people are playing**. The core declares six, in `server/tunables.lua`. Every
default comes from `config/server.lua`, which stays the source of truth.

| Panel key | Backed by | Type | Default | Range | Panel label / group |
|---|---|---|---|---|---|
| `AUTOSAVE_SECONDS` | [`AUTOSAVE_SECONDS`](#server-autosave-seconds) | integer, s | `300` | 30–3600, step 30 | Autosave interval / Persistence |
| `PAYCHECK_MINUTES` | [`MONEY.PAYCHECK_MINUTES`](#server-paycheck-minutes) | integer, min | `10` | 0–240, step 1 | Paycheck interval / Economy |
| `PAYCHECK_REQUIRES_DUTY` | [`MONEY.PAYCHECK_REQUIRES_DUTY`](#server-paycheck-requires-duty) | boolean | `true` | — | Only pay players on duty / Economy |
| `CHARACTER_SLOTS` | [`CHARACTERS.DEFAULT_SLOTS`](#server-characters-default-slots) | integer | `3` | 1–20, step 1 | Characters per account / Characters |
| `CHARACTER_ROWS` | [`CHARACTERS.ROW_CEILING`](#server-characters-row-ceiling) | integer | `60` | 5–500, step 5 | Character rows per account / Characters |
| `SELECTION_MS` | [`ENTRY.PIPELINE_MS`](#server-entry-pipeline-ms) | integer, ms | `240000` | 30000–240000, step 15000 | Character selection deadline / Characters |

All six are declared `apply = 'live'`, so an accepted write takes effect
immediately rather than waiting for a boundary. `PAYCHECK_REQUIRES_DUTY` is the
only one declared with no explicit `type` field; its default is a boolean and
the panel infers the rest. Within each group the panel order is declared: the
selection deadline comes third among the Characters.

The panel key is not always the config path. `CHARACTER_SLOTS` is
`CHARACTERS.DEFAULT_SLOTS`, `CHARACTER_ROWS` is `CHARACTERS.ROW_CEILING`, and
`SELECTION_MS` is `ENTRY.PIPELINE_MS`. [`ENTRY.GATE_MS`](#server-entry-gate-ms)
is deliberately not tunable at all.

The core calls `Open77.tunables.declare` directly, at load. The platform
installs it for every server resource; a host without it stops the core at load.

### The trap: `OPX.Tune.KEY` is a live read {#tune-live-read}

!!! danger "A tunable hoisted into a file-scope local is frozen forever"
    `Open77.tunables.declare` returns a **proxy**, not a table. `OPX.Tune.KEY`
    is a function call behind a metatable that asks the host for the current
    value on every single access. The moment you write

    ```lua
    -- WRONG: captured at load, never updates again
    local interval = OPX.Tune.AUTOSAVE_SECONDS
    ```

    at file scope, you have captured the value at load time and every later
    change from the panel does nothing. The panel will still report the new
    number, so the bug presents as *"live tuning is a lie"* rather than as
    anything you can find. Read it at the point of use:

    ```lua
    -- right: re-read each time it is needed
    local interval = OPX.TuneNumber('AUTOSAVE_SECONDS', 30)
    ```

    A local inside a function is fine — it lives one call.

A misspelled key **raises** rather than returning `nil`, because a silent `nil`
is indistinguishable from "not changed yet". That is the host's behaviour, and
`OPX.TuneNumber` does not hide it.

### `OPX.TuneNumber(key, floor)` {#tune-number}

Re-reads a tunable as a number, never below a floor.

```lua
OPX.TuneNumber(key, floor)
```

- key: `string`
- floor?: `number`
    - The lowest value the caller can work with. Answered in place of a value
      that is not a finite number, and in place of one below it.

**Returns** `number` — or `nil` when there is no `floor` and the value is not a
finite number.

**Side** `server` — inside `opx77_core` only. Not reachable from another
resource.

## Where to go next {#next}

- [Jobs, gangs and origins](data.md) — the definitions in `data/`, and why
  they are not settings.
- [Commands](commands.md) — `opx77.here` and `opx77.whois`, which print the
  values two of these keys want.
- [Client exports](exports/client.md) — `GetSharedConfig`, which republishes
  six of these keys to any resource that asks.
- [Server exports](exports/server.md) — what `EXPORTS` and `INVENTORY` admit
  and bound.
- [The entry gate](../../concepts/entry-gate.md) — what `ENTRY.GATE_MS` is
  actually holding.
