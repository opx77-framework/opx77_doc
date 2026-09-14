---
title: opx77_admin configuration
description: Every key of OPX_ADMIN_CONFIG with its shipped default — rates, the audit ring, placement, noclip, announcements, ban durations, vehicles, weapons, the linked commands, the sky lists and the destinations — plus the two catalogues and the locale catalogue.
---

# Configuration

Everything lives in `config.lua`, in the global table `OPX_ADMIN_CONFIG`.
**Every value shown on this page is the shipped default**, exactly as the file
declares it.

!!! danger "Nothing in this file authorises anybody"

    `config.lua` is a `shared_script`, so every connecting player downloads it.
    It holds no secrets and no grants. Who may run what lives in `acl.jsonc`
    and nowhere else — see [Commands](commands.md#granting).

A number the code cannot do arithmetic on — a string, a NaN, an infinity — is
read as the shipped value rather than raised on.

## LOCALE {#locale}

Which `locales/<code>.lua` catalogue player-facing text is read from.

```lua
LOCALE = "en",
```

**Type** `string` — `"en"` or `"fr"` as shipped.

Applied at load by `shared/locale.lua`, on both sides. An unknown code is
accepted, and every key then falls back to `en`, then to the key itself. See
[Player-facing text](#locales).

## RATE {#rate}

Floors between two runs of the same thing by the same operator, in
milliseconds.

```lua
RATE = {
  ACTION_MS = 400,
  READ_MS = 1000,
  REFRESH_MS = 750,
},
```

| Key | Floor between |
|---|---|
| `ACTION_MS` | two runs of one mutating command |
| `READ_MS` | two runs of one command that only reads — the opener, `self.pos`, `weapon.read` and the four `read.*` |
| `REFRESH_MS` | two [`opx77_admin:refresh`](events.md#refresh) requests on one topic |

A command run inside its floor answers `too_fast`. The floor is per operator
**per command**, so running `heal` and then `revive` is not cooled. The console
is never cooled, and a disconnect forgets the player's history.

The chat-suggestion request is cooled at a literal 2000 ms and is not a key.

## AUDIT_ENTRIES {#audit-entries}

How many actions [`opx77.admin.read.audit`](commands.md#audit) can look back
over, this uptime.

```lua
AUDIT_ENTRIES = 200,
```

**Type** `integer` — never fewer than `10`.

The ring is in memory and dies with the process. The platform log line written
beside each entry is the record — see [The audit](index.md#audit).

## TOAST_MS {#toast-ms}

How long a target's "a staff member did this" toast stays up, in milliseconds.

```lua
TOAST_MS = 6000,
```

**Type** `integer`

Announcements have their own lifetime, [`ANNOUNCE.DURATION_MS`](#announce).

## PLACEMENT {#placement}

How a player is put down after a move. Every move is a
[kill and a respawn](index.md#placement).

```lua
PLACEMENT = {
  HEALTH = 1.0,
  GRACE_MS = 5000,
  BESIDE = { X = 1.5, Y = 0.0, Z = 0.0 },
  OBSERVE_HEIGHT = 2.0,
},
```

| Key | Does |
|---|---|
| `HEALTH` | the fraction of full health a respawn or a revive stands the player up with, clamped to `0.01`–`1.0` |
| `GRACE_MS` | respawn protection after a move or a revive, in ms; never negative |
| `BESIDE` | the offset from the other player on [`goto`](commands.md#player-goto) and [`bring`](commands.md#player-bring), in metres on the world axes |
| `OBSERVE_HEIGHT` | metres above the target an [observer](commands.md#player-observe) lands, noclip on |

!!! info "A fraction here, points elsewhere"

    `Open77.players.getHealth` answers absolute points and `revive` and
    `respawn` take a fraction. `HEALTH` is the fraction;
    [`opx77.admin.player.health`](commands.md#player-health) takes points. The
    code never mixes the two.

## NOCLIP {#noclip}

```lua
NOCLIP = {
  SPEED = 40.0,
},
```

`SPEED` is the noclip speed in m/s applied the first time noclip goes on for a
player, unless they chose one with
[`opx77.admin.self.speed`](commands.md#self-speed). The native accepts `0.1` to
`500`; the client drops a value outside that range.

## ANNOUNCE {#announce}

```lua
ANNOUNCE = {
  DURATION_MS = 12000,
  CHAT = true,
  MAX_CHARACTERS = 240,
},
```

| Key | Does |
|---|---|
| `DURATION_MS` | the announcement toast's lifetime on every client, in ms |
| `CHAT` | also write the announcement into the chat box, on `chat:addMessage`; only `false` turns it off |
| `MAX_CHARACTERS` | the announcement is cut to this many characters |

## BAN_DURATIONS {#ban-durations}

The ban durations the menu's ban form offers.

```lua
BAN_DURATIONS = { "1h", "1d", "7d", "30d", "perm" },
```

**Type** `string[]`

A typed ban is not limited to these: it takes any `<n>s`, `<n>m`, `<n>h` or
`<n>d` up to `3650d`, or `perm` — see
[`opx77.admin.moderate.ban`](commands.md#moderate-ban).

## VEHICLES {#vehicles}

```lua
VEHICLES = {
  SPAWN_OFFSET = { X = 3.0, Y = 0.0, Z = 0.25 },
  PER_OWNER = 8,
  NEAR_RADIUS = 30.0,
  OCCUPIED_REPAIRS = { glass = true, body = true, lights = true, tires = true, visual = true },
  FLAGS = { "locked", "engineOn", "lightsOn", "invulnerable" },
},
```

| Key | Does |
|---|---|
| `SPAWN_OFFSET` | where a vehicle appears, on the world axes, from whoever it is spawned for |
| `PER_OWNER` | vehicles this resource keeps out per player at once; never fewer than `1`. Past it `vehicle_cap` |
| `NEAR_RADIUS` | how far `near` looks when the operator is not in a vehicle, in metres, within their bucket |
| `OCCUPIED_REPAIRS` | the repair scopes allowed with somebody aboard. `full` and `mechanical` are left out because they may respawn the vehicle; a scope missing here answers `unsafe_repair` |
| `FLAGS` | the `Open77.vehicles.flags` names [`opx77.admin.vehicle.flag`](commands.md#vehicle-flag) may toggle. A name the host has no mask for is refused like one not listed |

A vehicle removed by somebody else is forgotten the next time the list is
consulted, so it stops counting against `PER_OWNER`.

## WEAPONS {#weapons}

```lua
WEAPONS = {
  MAX_RESERVE = 2000,
  FILL_MAGAZINE = true,
},
```

| Key | Does |
|---|---|
| `MAX_RESERVE` | the ceiling on a reserve, typed or from a class. The engine caps each ammunition type lower still |
| `FILL_MAGAZINE` | after the spare rounds, fill the magazine to the capacity the engine reports. Only `false` turns it off |

## LINKS {#links}

Commands of other OPX//77 resources the menu drives instead of doing the same
thing twice.

```lua
LINKS = {
  CHARACTERS = "opx77",
  WHERE = "opx77.where",
  JOB = "opx77.job",
  GANG = "opx77.gang",
  MONEY = "opx77.money",
  SAVE = "opx77.save",
  WEATHER_SET = "opx77.weather.set",
  WEATHER_NEXT = "opx77.weather.next",
  WEATHER_FREEZE = "opx77.weather.freeze",
  TIME = "opx77.weather.time",
  TIME_FREEZE = "opx77.weather.time.freeze",
},
```

**Type** `table<string, string|false>`

Match any rename made in [`opx77_core`](../opx77_core/commands.md) or in
[`opx77_weather`'s `COMMANDS`](../opx77_weather/config.md#commands).
`false` removes the row. Every name here is also put in the access map, so the
menu greys it by the operator's ACL like one of this resource's own.

## WEATHER_PRESETS and TIMES {#sky}

What the World screen's weather and time rows offer.

```lua
WEATHER_PRESETS = { "sunny", "lightclouds", "cloudy", "rain", "heavyclouds", "fog",
                    "pollution", "sandstorm" },
TIMES = { "06:00", "09:00", "12:00", "17:30", "20:30", "23:00", "03:00" },
```

Preset names come from [`opx77_weather`'s `WEATHER` table](../opx77_weather/config.md#weather),
and are sent to its commands as written.

## LOCATIONS {#locations}

Saved destinations, for [`send`](commands.md#player-send) and the menu.

```lua
LOCATIONS = {
  { NAME = "watson", LABEL = "Watson, west", X = -667.14, Y = -382.61, Z = 9.16, HEADING = 0.0 },
  { NAME = "heights", LABEL = "Northwest heights", X = -1441.0, Y = 1269.0, Z = 123.0,
    HEADING = 180.0 },
  { NAME = "coast", LABEL = "Southwest coast", X = -1716.38, Y = -2421.28, Z = 62.59,
    HEADING = 0.0 },
},
```

Starter points; replace them. `NAME` is what staff type: 1 to 32 letters,
digits, `_` and `-`, lower-cased. `LABEL` is cut to 48 characters and defaults
to the name. A row whose `NAME` is not such a name, or whose `X`, `Y` or `Z` is
not a number, is skipped at boot:

```text
LOCATIONS #2 ignored: NAME must be a slug and X, Y, Z numbers
```

Stand where you want one and run
[`opx77.admin.self.pos`](commands.md#self-pos): it copies a row in this shape
to the clipboard. Destinations added in game with
[`loc.add`](commands.md#loc-add) last until the next restart.

## Catalogues {#catalogues}

The vehicles staff may spawn and the weapons they may hand out are definitions,
not settings, and live in `data/vehicles.lua` (`OPX_ADMIN_VEHICLES`) and
`data/weapons.lua` (`OPX_ADMIN_WEAPONS`).

!!! danger "They are allowlists, not suggestions"

    A record that is not a row of one of these files never reaches
    `Open77.vehicles.create` or `Open77.weapons.assign`, whatever a client
    types.

The platform has no server-side call that enumerates vehicle or item records,
so both lists are hand-picked starters: fourteen vehicles in three classes and
seventeen weapons in nine. To extend one, add a row:

```lua
{ NAME = "outlaw", LABEL = "Herrera Outlaw", CLASS = "sport",
  RECORD = "Vehicle.v_sport1_herrera_outlaw_player" },
```

| Field | Rule |
|---|---|
| `NAME` | what staff type: 1 to 32 letters, digits, `_` or `-`, lower-cased |
| `LABEL` | what the menu shows, up to 48 characters; defaults to the name |
| `CLASS` | a `KEY` from the file's `CLASSES`, which also sets the menu order |
| `RECORD` | the exact TweakDB record: letters, digits, `_` and `.` |

A command accepts the `NAME` or the exact `RECORD`, without case. A malformed
row — a bad name or record, an unknown class, or a name or record declared
twice — is dropped and named in a boot warning rather than raised on:

```text
data/vehicles.lua: row #3: CLASS is not a KEY in CLASSES
```

A record the engine does not know passes the allowlist and is refused when it
is spawned, with the host's own reason in the answer.

**A weapon class** carries two more fields. `AMMO` says whether the class takes
ammunition at all — `false` for melee, and no spare rounds are asked for — and
`RESERVE` is how many spare rounds a give loads. The ammunition **type** is
never chosen: the engine reads it off the weapon record, and precision rifles
draw rifle ammunition. The engine caps what a character carries per ammunition
type, on the spare rounds plus the magazine, and a request above the cap is
partly applied and then reported as refused — keep `RESERVE` modest.

Only the three ordinary weapon slots are supported by the platform, so grenades,
heavy weapons and arm cyberware do not belong in `data/weapons.lua`.

## Player-facing text {#locales}

`locales/en.lua` and `locales/fr.lua`, keyed `admin.<thing>`, registered
through `shared/locale.lua`, which publishes the global `locale(key, params)`.

Every answer a player reads is translated, a staff member's included. The answer
the console gets, `Open77.log` lines, the audit and the refusal codes stay
English. Catalogue labels, destination labels, vehicle flag names and weather
preset names are data, not text, and are shown as written.

A key present in one catalogue and missing from the other is a defect, not a
fallback, and is named at boot:

```text
locales/fr.lua is missing admin.error.tooFast
```

To add a language: copy `locales/en.lua` to `locales/<code>.lua`, change the
code in the `register` call, translate the values, add
`shared_script "locales/<code>.lua"` to `open77.lua` beside the others, and set
[`LOCALE`](#locale) to it. The boot check compares `en` and `fr` only.

## Constants that are not configurable {#constants}

| Constant | Value | What it is |
|---|---|---|
| Kick reason | 127 bytes | the platform refuses a longer disconnect reason outright |
| Longest ban | `3650d` | a longer duration answers `bad_duration` |
| Coordinates | ±1,000,000 | a point past it on any axis answers `bad_coordinates` |
| Armour | `0`–`10000` points | the range [`player.armor`](commands.md#player-armor) accepts |
| Audit read | `1`–`40`, default `15` | what [`read.audit`](commands.md#audit) shows at once |
| Roster chunk | 20 rows | per [`opx77_admin:roster`](events.md#roster) event: the host drops an event past 1024 value nodes without a word |
| Travel sweep | 2000 ms | how often a revoked grant is looked for |
| Weapon request | 30,000 ms | how long an unanswered weapon relay is remembered |
| Menu answer | 15,000 ms | how long a command the menu sent may take to have its answer put under the list |
| Menu rows | 190 | per roster, catalogue class or destination list, under `opx77_menu`'s 200 a level |

## See also {#see-also}

- [Commands](commands.md) — what each key changes, command by command.
- [Overview](index.md) — the gate, placement and the audit these keys tune.
