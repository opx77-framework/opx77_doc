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
| `config/vehicles.lua` | `server_script` | no | `OPX_VEHICLES` |
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

`config/vehicles.lua` is the odd one out — it fills a bare global,
`OPX_VEHICLES`, rather than a field of `OPX.Config`.

---

## SERVER_NAME {#shared-server-name}

Names the server in the launcher and in player-facing text; the core also uses
it as the title of every notification it sends.

```lua
SERVER_NAME = "OPX//77",
```

**Type** `string`

**File** `config/shared.lua` — shipped to every client

**Read by** `server/functions.lua` (notification title), and republished to any
resource through [`GetSharedConfig`](exports/client.md) as `serverName`.

---

## LOCALE {#shared-locale}

Chooses the language of player-facing text, applied at load; server logs stay
in English whatever it is set to.

```lua
LOCALE = "fr",
```

**Type** `string` — a catalogue registered in `locales/`. `"en"` and `"fr"`
ship.

**File** `config/shared.lua` — shipped to every client

**Read by** `shared/locale.lua`, which calls `Locale.set` with it at load on
both sides. Without that call this key would be inert and an operator shipping
`"fr"` would read English everywhere.

An unknown code is **accepted**, not rejected: catalogues register after this
file loads, so there is nothing to check it against yet. Every lookup then
falls back to `en`, and then to the key itself — so a gameplay file that adds a
string without translating it shows the player its raw key rather than nothing,
which is the failure you want, because it is visible.

[`GetSharedConfig`](exports/client.md) republishes `locale` as the code *in
force*, which after an unknown code is not the same thing as the catalogue
being read.

---

## LOG_LEVEL {#shared-log-level}

Sets the floor below which the core's own log lines are dropped, on both sides.

```lua
LOG_LEVEL = "info",
```

**Type** `string` — `"debug"`, `"info"`, `"warn"`, `"error"` or `"silent"`

**File** `config/shared.lua` — shipped to every client

**Read by** `server/main.lua` and `client/main.lua`, each calling
`OPX.Log.setLevel` at boot.

---

## MONEY.TYPES {#shared-money-types}

Declares every money type this server has, mapped to the balance a brand new
character starts with.

```lua
MONEY = {
  TYPES = {
    EDDIES = 500,   -- carried on the person, losable
    BANK = 5000,    -- held by a bank, not losable
  },
},
```

**Type** `table<string, integer>`

**File** `config/shared.lua` — shipped to every client

!!! danger "The names are durable"
    A type name becomes a key in the `money` JSON column of `opx77_players`.
    **Adding a type is free. Renaming one orphans every balance already stored
    under the old name** — the money is still in the row, under a key nothing
    reads any more, and the character now starts that type from its configured
    opening balance. There is no migration in the core that will find it for
    you.

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

Names the money type a UI should offer when the player has not chosen one.

```lua
MONEY = {
  DEFAULT = "EDDIES",
},
```

**Type** `string` — must be a key of [`MONEY.TYPES`](#shared-money-types)

**File** `config/shared.lua` — shipped to every client

!!! warning "The core does not fall back to it"
    The shipped comment calls this *"the type a payment falls back to when a
    caller does not name one"*, and no call site in the core does that.
    `OPX.AddMoney`, `OPX.RemoveMoney` and `OPX.SetMoney` all refuse a `nil`
    or unknown `moneyType` with `money.badType` rather than substituting this
    value. Its only reader is
    [`GetSharedConfig`](exports/client.md), which publishes it as
    `defaultMoneyType` — so treat it as advice to a UI, and always name the
    type explicitly when you call a money mutator.

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
the one that decides.

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
Run [`opx77.here`](commands.md) in game to print your own position in exactly
this shape, paste it in, and set `SET = true`.

While `SET` is `false` the core logs three warning lines at boot and then
leaves every unplaced character wherever the game happened to put them.

---

## NOTIFY_POSITION {#shared-notify-position}

Chooses where `open77_notifications` draws the toasts the core sends.

```lua
NOTIFY_POSITION = "top_right",
```

**Type** `string` — one of `middle_left` (the notification service's own
default), `top_left`, `top_center`, `top_right`, `bottom_left`,
`bottom_center`, `bottom_right`

**File** `config/shared.lua` — shipped to every client

!!! warning "Underscores, not hyphens"
    The platform's vocabulary is `top_right`, never `top-right`. Earlier
    releases of the core shipped the hyphenated form, which meant every toast
    it sent carried an invalid position and `GetSharedConfig` republished the
    bad value to every UI that asked.

The core **warns about an unrecognised value and sends it anyway**. That is
deliberate rather than lax: the accepted set is known only from the platform's
website, the server binary does not validate `position` at all, and
`open77_notifications` is a client resource whose source is not on disk here —
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
[Tunables](#tunables) — and read it with `OPX.TuneNumber("AUTOSAVE_SECONDS", 30)`
at the point of use, never into a file-scope local.

Saving only on logout is lossy in exactly the cases people care about most.
Lower costs more database writes. The autosave writes only characters whose
revision has moved since the last pass, so an idle server writes nothing.

---

## MONEY.ALLOW_NEGATIVE {#server-money-allow-negative}

Lists the money types that may go below zero; a type not listed is clamped at
zero and the removal is refused whole rather than truncated.

```lua
MONEY = {
  ALLOW_NEGATIVE = { BANK = true },
},
```

**Type** `table<string, boolean>` — keys are [`MONEY.TYPES`](#shared-money-types)
names

**File** `config/server.lua` — server only, never sent to a client

**Read by** `OPX.RemoveMoney` and `OPX.SetMoney` in `server/player.lua`. A
refusal is `false, "money.negative"` — the balance is untouched, and the caller
is told which rule it broke rather than being handed a partial debit.

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
`OPX.TuneNumber("PAYCHECK_MINUTES", 0)` at the point of use, never into a
file-scope local.

Switching it back on resumes the same salaries, because the amounts live in
[`data/jobs.lua`](data.md) and this key only decides how often they are paid.
A paycheck is credited to `BANK`, not `EDDIES` — a salary that landed as
carried cash could be taken off the body of whoever logged in at the wrong
moment.

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

## NEEDS.TICK_SECONDS {#server-needs-tick-seconds}

Sets how often hunger and thirst fall.

```lua
NEEDS = {
  TICK_SECONDS = 300,
},
```

**Type** `integer` — seconds

**File** `config/server.lua` — server only, never sent to a client

**Read by** `server/needs.lua`. The tick is wrapped in a `pcall`: one character
with a malformed metadata row must not stop the decay for everybody else, and
the loop gets no second chance if it raises.

Hunger and thirst are `PlayerData.metadata`, which only the core's server VM
holds. That is why they live here and not in `opx77_status` — a decay loop
written in a satellite would call a `nil` `OPX` and its own `pcall` would
swallow the raise. `opx77_status` still owns the effect strip; these two are
character state.

---

## NEEDS.DAMAGE_AT_ZERO {#server-needs-damage-at-zero}

Sets the health lost per tick for each need that is empty; `0` makes needs
purely cosmetic.

```lua
NEEDS = {
  DAMAGE_AT_ZERO = 2,
},
```

**Type** `integer` — health points per tick per empty need

**File** `config/server.lua` — server only, never sent to a client

Both needs empty costs twice this per tick. A need at zero stays at zero — this
is what running out *costs*, not a further drop — and health is never taken
below zero by it. The core writes it through `SetMetaData`, so the change marks
the character and the next autosave carries it.

---

## NEEDS.hunger.PER_TICK / NEEDS.thirst.PER_TICK {#server-needs-per-tick}

Sets how far each need falls on every tick.

```lua
NEEDS = {
  hunger = { PER_TICK = 1.0 },
  thirst = { PER_TICK = 1.4 }, -- thirst outruns hunger, as in every survival system
},
```

**Type** `number` — points per tick, out of the 100 a new character starts with

**File** `config/server.lua` — server only, never sent to a client

The two need names are fixed in `server/needs.lua`; adding a third key here
adds nothing, because the decay loop iterates its own list. Health is
deliberately not one of them: the engine owns health, and a need that emptied
it directly would fight whatever else is writing to it.

At the shipped numbers a full character reaches empty hunger in about eight and
a third hours of server uptime, and empty thirst in about six.

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
`OPX.TuneNumber("CHARACTER_SLOTS", 1)` at the point of use, never into a
file-scope local.

Lowering it never deletes anything: an account already over the limit keeps
every character it has and simply cannot make another.
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

Run [`opx77.whois`](commands.md) in game to print a player's `userId`. It is the
platform identity behind every character on the account and it does not change;
see [Identity](../../concepts/identity.md) for what it is and what it is not.

An entry here bypasses the `CHARACTER_SLOTS` tunable entirely, so a value set
from the Warden panel will not move it.

---

## CHARACTERS.ROW_CEILING {#server-characters-row-ceiling}

Caps the number of rows one account may ever write to `opx77_players` over its
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
`OPX.TuneNumber("CHARACTER_ROWS", 5)` at the point of use, never into a
file-scope local.

!!! warning "A lifetime ceiling, not a roster size"
    Deleting a character is a **soft delete**: the slot is freed but the row
    stays, so the deletion can be undone and so a citizen id is never
    reissued. Create-and-delete therefore writes a new row every single time,
    and this key is the only thing that stops that being unbounded. Keep it
    well above [`DEFAULT_SLOTS`](#server-characters-default-slots) — the
    shipped 60 against 3 is twenty create-and-delete cycles, not twenty
    characters.

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

**Read by** `OPX.DeleteCharacter` in `server/character.lua`.

This is for gameplay files you add to `opx77_core` that keep their own tables.
The core's own tables do not need an entry: they carry
`ON DELETE CASCADE` in `server/storage/schema.lua` and the database handles it.

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

Sets the core's own deadline for the whole join sequence, held below
`GATE_MS` so the core gives up first and can say why.

```lua
ENTRY = {
  PIPELINE_MS = 240000,
},
```

**Type** `integer` — milliseconds

**File** `config/server.lua` — server only, never sent to a client

**Tunable** `SELECTION_MS`, 30000–240000 step 15000, applied live. See
[Tunables](#tunables) — and read it with
`OPX.TuneNumber("SELECTION_MS", 30000)` at the point of use, never into a
file-scope local.

The tunable's maximum is this value rather than a round 900000, and that is
load-bearing: a selection the panel could stretch past
[`GATE_MS`](#server-entry-gate-ms) would have the host declare this resource
dead mid-screen and open the gate with `liveness_lost:opx77_core`. If you raise
`GATE_MS`, raise this too — and if you lower `GATE_MS`, lower this first.

---

## PLAYER.STARTING_METADATA {#server-player-starting-metadata}

Sets what a brand new character starts with; it becomes the initial
`PlayerData.metadata`.

```lua
PLAYER = {
  STARTING_METADATA = {
    health = 100,
    armor = 0,
    stamina = 100,
    hunger = 100,
    thirst = 100,
    streetCred = 0,
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
top and it survives every save. Of the keys shipped, `health` and `hunger` and
`thirst` are written by the core; `armor`, `stamina`, `streetCred`, `isDead`
and `inLastStand` are stored, published and never written by anything in the
core — they are agreed names for gameplay files, not features.

---

## PLAYER.DEFAULT_JOB {#server-player-default-job}

Names the job a new character is employed in, and the job a character falls
back to when they are removed from their primary one.

```lua
PLAYER = {
  DEFAULT_JOB = "unemployed",
},
```

**Type** `string` — must be a key of [`OPX.Jobs`](data.md#jobs)

**File** `config/server.lua` — server only, never sent to a client

**Read by** `server/groups.lua` (the fallback on
`OPX.RemovePlayerFromJob`) and `server/character.lua` (a new character).

A name with no entry in [`data/jobs.lua`](data.md#jobs) makes character
creation fail with `job.notFound`. If you rename the shipped `unemployed` job,
change this key in the same commit.

---

## PLAYER.DEFAULT_GANG {#server-player-default-gang}

Names the gang a new character belongs to, and the gang a character falls back
to when they are removed from their primary one.

```lua
PLAYER = {
  DEFAULT_GANG = "none",
},
```

**Type** `string` — must be a key of [`OPX.Gangs`](data.md#gangs)

**File** `config/server.lua` — server only, never sent to a client

**Read by** `server/groups.lua` and `server/character.lua`, exactly as
[`DEFAULT_JOB`](#server-player-default-job) is.

The shipped `none` gang exists precisely so this key can point somewhere: it is
the absence of a gang, kept as a real entry so no call site has to handle
`nil`.

---

## CONFLICTING_PLACERS {#server-conflicting-placers}

Names the resources that would fight the core over where a player stands, so it
can warn about them at boot.

```lua
CONFLICTING_PLACERS = { "open77_playerstate", "freeroam", "pursuit", "race" },
```

**Type** `string[]`

**File** `config/server.lua` — server only, never sent to a client

The core **disables nothing.** It checks `GetResourceState` for each name at
boot — server resources cannot call each other, so asking the host is the only
way — and prints three warning lines, once, per name that is `running` or
`starting`. `starting` counts, because a resource coming up will be placing
players a moment from now.

What to do about each of the shipped four:

| Resource | What to do |
|---|---|
| `open77_playerstate` | Stop it, or add `opx77_core` to its `spawnOwners` tunable. |
| `freeroam` | Turn its `forceOnJoin` off. |
| `pursuit`, `race` | Round-based gamemodes. Two gamemodes on the same players is a bug in the resource set, not something to configure around. |

Two resources moving the same player means the last one wins, with no rule
saying which will be last.

---

## PER_CHARACTER {#vehicles-per-character}

Caps how many vehicles one character may own; `0` removes the ceiling.

```lua
PER_CHARACTER = 8,
```

**Type** `integer`

**File** `config/vehicles.lua` — server only, never sent to a client. Fills the
bare global `OPX_VEHICLES`, not `OPX.Config`.

Exceeding it refuses the creation with `vehicle.limit`, carrying the configured
number as its detail so a UI can say what the limit was.

---

## PLATE_FORMAT {#vehicles-plate-format}

Describes the shape of a generated number plate: `1` becomes a digit, `A` a
letter, and anything else is copied through as written.

```lua
PLATE_FORMAT = "11AAA111",
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
DEFAULT_GARAGE = "impound",
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

## DESPAWN_RADIUS {#vehicles-despawn-radius}

Sets the distance past which an unoccupied vehicle is stored again; `0` never
stores one.

```lua
DESPAWN_RADIUS = 0.0,
```

**Type** `number` — metres, `0` to disable

**File** `config/vehicles.lua` — server only, never sent to a client

!!! warning "Nothing reads this key"
    Grep the resource and this key has exactly one occurrence: its own
    definition. No despawn sweep exists in `server/vehicles.lua` as shipped, so
    setting it to a non-zero value changes nothing. It is a reserved name for
    the sweep, not a switch.

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

Sets how often the client reports its position to the server, in milliseconds.

```lua
POSITION_REPORT_MS = 5000,
```

**Type** `integer` — milliseconds

**File** `config/client.lua` — client only; `OPX.Config.CLIENT` is `nil` on the
server

!!! warning "Nothing here is authoritative"
    A modified client can change any value in this file, and the server
    re-derives anything that matters. In this case the server re-reads the
    authoritative position before it writes, so this key only decides how fresh
    the *hint* is — a client that never reports costs itself nothing.

The server's rate limit on the reporting event is a literal, not this value:
that VM never loads `config/client.lua`, and a rate limit derived from a number
the client controls would not be one.

---

## CHARACTER.BOOTSTRAP_POLL_MS {#client-bootstrap-poll-ms}

Sets how often the bootstrap phase is polled while the character selection
screen is up.

```lua
CHARACTER = {
  BOOTSTRAP_POLL_MS = 250,
},
```

**Type** `integer` — milliseconds

**File** `config/client.lua` — client only

!!! warning "Nothing reads this key"
    `client/character.lua` does not open the character creator and does not
    poll a bootstrap: `open77_appearance` owns that transaction and it can only
    be resolved once. This key, `CREATOR_TIMEOUT_MS` and `USE_NATIVE_CREATOR`
    are reserved names for a selection UI that the framework does not ship —
    changing them has no effect today. The character flow you have is
    [`opx77.create`](commands.md) and the core's client exports.

---

## CHARACTER.CREATOR_TIMEOUT_MS {#client-creator-timeout-ms}

Sets how long to wait for the native character creator to hand back a result.

```lua
CHARACTER = {
  CREATOR_TIMEOUT_MS = 300000,
},
```

**Type** `integer` — milliseconds

**File** `config/client.lua` — client only

!!! warning "Nothing reads this key"
    As with [`BOOTSTRAP_POLL_MS`](#client-bootstrap-poll-ms), no file in the
    core reads it. `open77_appearance` owns the creator bootstrap; the core
    only decides which character is live.

---

## CHARACTER.USE_NATIVE_CREATOR {#client-use-native-creator}

Opens Cyberpunk's own character creator for a new character.

```lua
CHARACTER = {
  USE_NATIVE_CREATOR = true,
},
```

**Type** `boolean`

**File** `config/client.lua` — client only

Opening the native creator needs the `player.appearance.edit` permission in the
manifest of whichever resource does it. `false` would mean the default body and
a step of your own.

!!! warning "Nothing reads this key"
    As with [`BOOTSTRAP_POLL_MS`](#client-bootstrap-poll-ms), no file in the
    core reads it. The creator belongs to `open77_appearance`, which is also
    the resource that emits `open77:session:gameplayReady` — see [The entry
    gate](../../concepts/entry-gate.md) for why a stock install needs it for
    an unrelated and more urgent reason.

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

All six are declared `apply = "live"`, so an accepted write takes effect
immediately rather than waiting for a boundary. `PAYCHECK_REQUIRES_DUTY` is the
only one declared with no explicit `type` field; its default is a boolean and
the panel infers the rest.

The panel key is not always the config path. `CHARACTER_SLOTS` is
`CHARACTERS.DEFAULT_SLOTS`, `CHARACTER_ROWS` is `CHARACTERS.ROW_CEILING`, and
`SELECTION_MS` is `ENTRY.PIPELINE_MS`. [`ENTRY.GATE_MS`](#server-entry-gate-ms)
is deliberately not tunable at all.

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
    local interval = OPX.TuneNumber("AUTOSAVE_SECONDS", 30)
    ```

    A local inside a function is fine — it lives one call.

A misspelled key **raises** rather than returning `nil`, because a silent `nil`
is indistinguishable from "not changed yet". That is the host's behaviour, and
`OPX.TuneNumber` does not hide it.

### `OPX.TuneNumber(key, floor)` {#tune-number}

Re-reads a tunable as a number, substituting the `config/server.lua` default
for anything that is not one, and then `floor` if it is still not one.

```lua
OPX.TuneNumber(key, floor)
```

- key: `string`
- floor?: `number`
    - The lowest value the caller can work with. Also what is returned for a
      key with no declaration — returning `nil` there would hand the caller a
      `nil` to compare against a number, which raises at the comparison rather
      than here, where the mistake is.

**Returns** `number`

**Side** `server` — inside `opx77_core` only. Not reachable from another
resource.

### Servers with no tunables support {#no-tunables}

A binary predating tunables has no `Open77.tunables` at all. The core detects
that once, at load, falls back to a plain defaults table **built from the same
declaration** — so a key cannot exist in one and not the other — and logs:

```
[opx77_core] this server has no Open77.tunables; using config/server.lua values as fixed
```

Everything then works, with `config/server.lua` as the fixed source of truth
and the panel out of the picture.

## Where to go next {#next}

- [Jobs, gangs and origins](data.md) — the definitions in `data/`, and why
  they are not settings.
- [Commands](commands.md) — `opx77.here` and `opx77.whois`, which print the
  values two of these keys want.
- [Client exports](exports/client.md) — `GetSharedConfig`, which republishes
  six of these keys to any resource that asks.
- [The entry gate](../../concepts/entry-gate.md) — what `ENTRY.GATE_MS` is
  actually holding.
