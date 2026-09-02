---
title: opx77_weather configuration
description: The keys of OPX_WEATHER_CONFIG in opx77_weather/config.lua — day length, start time, the freeze flags, the weighted weather table and the eight command entries — plus the cadence constants that deliberately are not operator settings.
---

# Configuration

Everything below lives in `opx77_weather/config.lua`. **The value shown in each fence is the
shipped default**, so a key you never touch behaves exactly as written here.

!!! warning "`config.lua` is a shared script, so a client downloads it"

    It is listed as `shared_script`, which means every connecting player receives the file.
    Put no secrets in it and no ACL grants — a command's `RESTRICTED` flag says *whether* the
    host checks a permission, never *who* holds it. Grants live in `acl.jsonc`, which is
    server-side.

A **reload** re-reads this file, but it also carries the live authority state across on purpose
and adopts it in preference to the config — see [the carried state](index.md#carried-state) —
so which of these takes effect depends on the key:

| Key | Takes effect on a reload? |
|---|---|
| [`WEATHER`](#weather) | Yes — the table is rebuilt from the file. The live *preset* is still the carried one, and a bag naming a row you deleted is refused whole, which sends everything back to this file. |
| [`COMMANDS`](#commands) | Yes — the new VM registers the names in the file. |
| [`DAY_LENGTH_MINUTES`](#day-length-minutes), [`START_TIME`](#start-time), [`TIME_FROZEN`](#time-frozen), [`WEATHER_FROZEN`](#weather-frozen), [`INITIAL_WEATHER`](#initial-weather) | No — these describe how the authority *boots*, and a reload does not boot it. Restart for these. |

## DAY_LENGTH_MINUTES {#day-length-minutes}

How many real minutes one whole in-game day takes.

```lua
DAY_LENGTH_MINUTES = 180,
```

**Type** `number` — real minutes, `1..10080`

The rate is `86400 / (minutes * 60)`, in game seconds per real second — exactly `8.0` at 180
minutes, which is the only value that matches the engine's own rate. On top of the range, the
rate is capped at `120.0`, which refuses anything under **12 real minutes a day**: a client
past the drift tolerance at that speed would be jumping the world continuously instead of
running it.

An unusable value here falls back to a rate of `8.0` at boot without stopping the resource. The
same value set at runtime with [`/opx77.weather.daylength`](commands.md#day-length) is refused
instead, with `invalid_day_length` or `day_too_short`.

## START_TIME {#start-time}

The time of day the clock starts at, on a **boot**.

```lua
START_TIME = { HOUR = 12, MINUTE = 0, SECOND = 0 },
```

**Type** `{ HOUR: integer, MINUTE: integer, SECOND: integer }` — 24-hour

An hour that does not exist is a mistake rather than a wrap, so the whole table falls back to
`12:00:00` if any of the three is out of range. There is no wall-clock option: the authority is
a second-of-day plus a rate anchored to the host's monotonic clock, and never reads the
operating system's time.

This applies at boot and after a restart. **A reload keeps the live time instead** — that is
the point of the carried state, and it is why reloading the resource at 21:40 does not send
every player's sky back to noon.

## TIME_FROZEN {#time-frozen}

Whether the clock starts held at [`START_TIME`](#start-time).

```lua
TIME_FROZEN = false,
```

**Type** `boolean`

Only a literal `true` freezes. Release it at runtime with
[`/opx77.weather.time.freeze off`](commands.md#time-freeze); the anchor is rewritten at the
moment of the freeze, so releasing resumes from where the clock stood rather than jumping.

## WEATHER_FROZEN {#weather-frozen}

Whether the roll **schedule** starts held.

```lua
WEATHER_FROZEN = false,
```

**Type** `boolean`

!!! warning "This is not the engine's weather lock"

    It holds the automatic countdown between rolls. The client keeps
    `Open77.environment.setWeatherFrozen(true)` taken on every accepted snapshot regardless, so
    REDengine's own cycle never runs underneath the projection whether this is `true` or
    `false`. [`/opx77.weather.next`](commands.md#next) still rolls while it is on, and
    [`/opx77.weather.set`](commands.md#set) still crosses.

## INITIAL_WEATHER {#initial-weather}

The preset the sky starts on, on a boot.

```lua
INITIAL_WEATHER = "sunny",
```

**Type** `string` — a `NAME` or an engine `PRESET` from [`WEATHER`](#weather), matched without
case

A value that is not in the table falls back to the **first row** and warns once:

```text
INITIAL_WEATHER 'blizzard' is not in the table; starting on 'sunny'
```

The boot preset holds for 180 s before the first roll, whatever the row's own duration band
says. That number is not an operator setting; it is
[`INITIAL_WEATHER_SECONDS`](#not-in-config) in `shared/clock.lua`.

## WEATHER {#weather}

The weighted preset table: what the sky may be, how likely each is, how long it lasts and how
long it takes to get there.

```lua
WEATHER = {
  -- name / engine preset / weight, relative and 0 never rolls / min..max seconds / crossfade
  { NAME = "sunny", PRESET = "24h_weather_sunny", WEIGHT = 28,
    MIN_SECONDS = 480, MAX_SECONDS = 900, TRANSITION_SECONDS = 18 },
  { NAME = "lightclouds", PRESET = "24h_weather_light_clouds", WEIGHT = 24,
    MIN_SECONDS = 360, MAX_SECONDS = 720, TRANSITION_SECONDS = 20 },
  { NAME = "cloudy", PRESET = "24h_weather_cloudy", WEIGHT = 18,
    MIN_SECONDS = 300, MAX_SECONDS = 600, TRANSITION_SECONDS = 24 },
  { NAME = "rain", PRESET = "24h_weather_rain", WEIGHT = 12,
    MIN_SECONDS = 180, MAX_SECONDS = 420, TRANSITION_SECONDS = 30 },
  { NAME = "heavyclouds", PRESET = "24h_weather_heavy_clouds", WEIGHT = 8,
    MIN_SECONDS = 240, MAX_SECONDS = 480, TRANSITION_SECONDS = 26 },
  { NAME = "fog", PRESET = "24h_weather_fog", WEIGHT = 5,
    MIN_SECONDS = 180, MAX_SECONDS = 360, TRANSITION_SECONDS = 28 },
  { NAME = "pollution", PRESET = "24h_weather_pollution", WEIGHT = 3,
    MIN_SECONDS = 180, MAX_SECONDS = 360, TRANSITION_SECONDS = 28 },
  { NAME = "sandstorm", PRESET = "24h_weather_sandstorm", WEIGHT = 2,
    MIN_SECONDS = 120, MAX_SECONDS = 300, TRANSITION_SECONDS = 35 },
},
```

**Type** a list of rows

| Field | Type | Meaning |
|---|---|---|
| `NAME` | `string` | The stable name staff type and the authority stores. Required. |
| `PRESET` | `string` | The REDengine preset handed to `setWeather`. Required. |
| `WEIGHT` | `number` | Relative, and only against the other rows. `0` means the row can be `set` by hand but **never rolls**. |
| `MIN_SECONDS` | `integer` | Real seconds. The duration is drawn once, at the moment the preset starts. |
| `MAX_SECONDS` | `integer` | Raised to `MIN_SECONDS` if it is below it. |
| `TRANSITION_SECONDS` | `number` | How long the sky takes to cross into it. `0..300`. |

Both `NAME` and `PRESET` are matched without case, and both resolve to the same row, so
`/opx77.weather.set 24h_weather_fog` and `/opx77.weather.set FOG` are the same command.

The shipped weights total 100, which is convenient to read but is not required — a weight is
only meaningful against the others in the table.

A malformed row is **dropped with a warning** rather than taken, and the rest of the table
still loads:

| Wrong | What happens |
|---|---|
| `NAME` or `PRESET` is not a string | The row is dropped: `weather row 4 ignored: NAME and PRESET must be strings` |
| `MIN_SECONDS` missing or unusable | Falls back to `300`, floored at `1` |
| `MAX_SECONDS` below `MIN_SECONDS` | Raised to `MIN_SECONDS` |
| `WEIGHT` missing or unusable | Falls back to `0` — the row can be set, never rolled |
| `TRANSITION_SECONDS` missing | Falls back to `20` |

!!! warning "An empty table leaves the resource running and degraded"

    With no usable row the authority reports `ready = false`: every weather mutation answers
    `no_presets`, nothing rolls, and the status line carries
    `DEGRADED: no usable preset in OPX_WEATHER_CONFIG.WEATHER`. The **clock still runs** — the
    two halves of the authority fail independently on purpose.

The roll never repeats the sky already up: candidates are every row whose `NAME` differs from
the current one *and* whose weight is above zero. If nothing is left — a one-row table, or every
other row weighted `0` — the current preset is returned and the sky stays put rather than
looping.

## COMMANDS {#commands}

The eight command entries: what each is called, and whether the host checks a permission before
running it.

```lua
COMMANDS = { -- RESTRICTED gates on command.<NAME> in acl.jsonc; NAME = false registers none
  STATUS = { NAME = "opx77.weather", RESTRICTED = false }, -- time, preset, freezes, roll
  PRESETS = { NAME = "opx77.weather.presets", RESTRICTED = false }, -- what .set accepts
  SET = { NAME = "opx77.weather.set", RESTRICTED = true }, -- <name|preset> [seconds]
  NEXT = { NAME = "opx77.weather.next", RESTRICTED = true }, -- roll now, even if frozen
  FREEZE = { NAME = "opx77.weather.freeze", RESTRICTED = true }, -- <on|off>, the SCHEDULE
  TIME = { NAME = "opx77.weather.time", RESTRICTED = true }, -- <HH:MM[:SS]>
  TIME_FREEZE = { NAME = "opx77.weather.time.freeze", RESTRICTED = true }, -- <on|off>
  DAY_LENGTH = { NAME = "opx77.weather.daylength", RESTRICTED = true }, -- <realMinutes>
},
```

**Type** `{ [KEY]: { NAME: string | false, RESTRICTED: boolean } }`

The ACL key follows the name: rename `SET` to `sky.set` and the permission becomes
`command.sky.set`. Full descriptions of each are on [Commands](commands.md).

**`NAME = false`, or an empty string, registers nothing at all.** The command does not exist,
and its ACL key is never consulted because there is no command behind it. The boot log says so
once, per key:

```text
command SET is off (COMMANDS.SET.NAME)
```

!!! danger "`RESTRICTED = false` on a mutation hands the world clock to every player"

    For the six mutations the flag is read as `RESTRICTED ~= false`, so a missing, misspelled
    or quoted flag still gates the command — only an explicit boolean `false` opens one, and
    the boot log then warns `command <name> is OPEN to every player`. Opening
    `TIME` or `DAY_LENGTH` lets any connected player move the world clock for everybody on the
    server, and there is no undo beyond setting it back.

    For the two read-only commands the test is the other way round (`RESTRICTED == true`):
    they are open unless you say otherwise.

!!! warning "Two entries sharing one `NAME` bind one ACL key"

    The loader refuses the second one and logs it at error level rather than letting an open
    command's `RESTRICTED` flag leak onto a mutation. See
    [Two names, one ACL key](commands.md#duplicate-names).

## What is not in `config.lua` {#not-in-config}

The cadence — how often each side talks, the drift tolerance, the latency ceiling and the wire
protocol version — lives in `shared/clock.lua` instead. None of it is an operator decision, and
the two halves must not be able to disagree about it: they are in a shared script for exactly
that reason.

| Constant | Value | Meaning |
|---|---:|---|
| `PROTOCOL` | `1` | Wire version; a snapshot carrying any other is rejected outright |
| `HEARTBEAT_MS` | `5000` | How often the authority republishes when nothing has changed |
| `CLIENT_SYNC_MS` | `15000` | How often a client asks for a fresh timestamp |
| `APPLY_MS` | `500` | How often the client re-derives the time of day it should be showing |
| `ENFORCE_MS` | `5000` | How often the client checks that nothing local stole the weather |
| `SCHEDULER_MS` | `1000` | How often the authority looks at whether a roll is due |
| `DRIFT_TOLERANCE_SECONDS` | `120` | Game seconds of drift before the client writes to the engine |
| `MAX_LATENCY_MS` | `2000` | Ceiling on the half-round-trip added to a received timestamp |
| `MIN_REQUEST_MS` | `1000` | Floor between two sync requests from the same player |
| `INITIAL_WEATHER_SECONDS` | `180` | How long the boot preset holds before the first roll |
| `WEATHER_PRIORITY` | `5` | The priority `setWeather` is submitted at |
| `Clock.MAX_RATE` | `120.0` | The fastest clock a client can be asked to follow |

!!! warning "Editing these changes the wire, not a setting"

    `PROTOCOL` in particular: both halves ship together, so bumping it is how you say "the old
    snapshots are not valid any more" — a carried state bag from before the bump is refused
    whole and the authority boots from `config.lua`. The rest are traded against each other,
    and lowering one without the others mostly buys bandwidth for no visible change.

## See also {#see-also}

- [Commands](commands.md) — every command these entries register.
- [Overview](index.md#carried-state) — why a reload ignores most of this file, on purpose.
- [Getting started](../../guides/getting-started.md) — `acl.jsonc` and `server.jsonc`.
