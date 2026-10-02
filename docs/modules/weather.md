---
title: weather module
description: The single server authority for the time of day and the weather, published to every client, with staff commands to set, roll and freeze both.
---

# weather

The weather module keeps one clock and one sky for the whole server. The server runs the time of day at a configured day length, rolls the next weather from a weighted table when the current one has run its course, and sends a snapshot to every client; each client applies it with the environment natives and corrects drift. Every player therefore sees the same hour and the same weather. Staff can set the time, change or roll the weather, freeze either, and change the day length. The state survives a resource reload but not a server restart.

| | |
|---|---|
| Side | both |
| Requires | none |
| Optional | none |
| Configuration | `config/weather.lua` (shared script) |
| Contract | `weather` v1 — server, client |
| Data | none (reload carry-over only) |

## Commands {#commands}

| Command | Access | Arguments | What it does |
|---|---|---|---|
| <a id="opx-weather"></a>`/opx.weather` | everyone | — | Shows the time, day length, weather, next roll and revision. |
| <a id="opx-weather-presets"></a>`/opx.weather.presets` | everyone | — | Lists the weather table: name, engine preset, weight, duration range, transition. |
| <a id="opx-weather-set"></a>`/opx.weather.set` | ACL `command.opx.weather.set` | `<preset> [transitionSeconds]` | Crosses to a preset (by `NAME` or `PRESET`). Transition 0..300 s; default the row's `TRANSITION_SECONDS`. |
| <a id="opx-weather-next"></a>`/opx.weather.next` | ACL `command.opx.weather.next` | — | Rolls the weighted table now. |
| <a id="opx-weather-freeze"></a>`/opx.weather.freeze` | ACL `command.opx.weather.freeze` | `on\|off` | Holds or releases the roll schedule. |
| <a id="opx-time"></a>`/opx.time` | ACL `command.opx.time` | `HH:MM[:SS]` | Sets the clock. |
| <a id="opx-time-freeze"></a>`/opx.time.freeze` | ACL `command.opx.time.freeze` | `on\|off` | Holds or releases the clock. |
| <a id="opx-time-length"></a>`/opx.time.length` | ACL `command.opx.time.length` | `<minutes>` | Real minutes per game day, 1..10080; under 12 is refused (`day_too_short`). |

Names and restriction come from [`COMMANDS`](#config-weather-commands). A player may run each command once per 2 seconds. On the console the answer is printed; a player gets it as [`opx:net:weather:notice`](#opx-net-weather-notice).

!!! warning "Player answers may not be shown"
    The client shows a notice through the old `opx77_notify` resource, and falls back to the legacy `chat:addMessage` event. Nothing in opx_infinity listens to either, so a player running these commands may see no answer unless the platform's `open77_chat` is loaded. The command itself still runs. Not verified in game. These commands are registered with plain `RegisterCommand`, so the chat box does not offer them as completions.

## Server contract {#server-contract}

`local weather = OPX.Api.Get('weather')` on the server, from code inside opx_infinity. Nothing yields. Every change is published to all clients at once.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="server-weather-ready"></a>`Ready` | — | boolean | `false` when the weather table has no usable row. |
| <a id="server-weather-status"></a>`Status` | — | `{ hour, minute, second, dayLengthMinutes, timeFrozen, weather, weatherFrozen, nextRollInSeconds, revision }` | Plain table, not a Result. `nextRollInSeconds` is nil while frozen. |
| <a id="server-weather-statustext"></a>`StatusText` | — | string | One-line summary, as the console sees it. |
| <a id="server-weather-presets"></a>`Presets` | — | list of `{ NAME, PRESET, WEIGHT, MIN_SECONDS, MAX_SECONDS, TRANSITION_SECONDS }` | The live table. Do not modify it. |
| <a id="server-weather-settime"></a>`SetTime` | `seconds, reason?` | nothing | Seconds since midnight. Not validated: pass 0..86399. |
| <a id="server-weather-settimefrozen"></a>`SetTimeFrozen` | `frozen, reason?` | nothing | |
| <a id="server-weather-setdaylength"></a>`SetDayLength` | `minutes, reason?` | Result | `invalid_day_length`, `day_too_short`. |
| <a id="server-weather-setweather"></a>`SetWeather` | `name, transitionSeconds?, reason?` | Result | `no_presets`, `unknown_preset`, `invalid_transition`. Also reschedules the next roll. |
| <a id="server-weather-setweatherfrozen"></a>`SetWeatherFrozen` | `frozen, reason?` | nothing | Unfreezing schedules a new roll. |
| <a id="server-weather-roll"></a>`Roll` | `reason?` | Result | Picks a different row by weight and applies it. |

`reason` is a free string carried in the snapshot for diagnostics.

## Client contract {#client-contract}

`OPX.Api.Get('weather')` on the client.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="client-weather-state"></a>`State` | — | `{ ok = true, hour, minute, second, secondsOfDay, weather, weatherPreset, timeFrozen, weatherFrozen, revision, weatherRevision, latencyCompensationMs }` or `{ ok = false, error }` | Flat table, not `{ ok, value }`. Errors: `not_synchronized` (no snapshot yet), `environment_unavailable` (no environment natives on this client). Time is projected to now. |

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-net-weather-request"></a>`opx:net:weather:request` | client → server | `requestId` | Asks for a fresh snapshot. Sent at start and every 15 s; at most one per player per second is answered. |
| <a id="opx-net-weather-sync"></a>`opx:net:weather:sync` | server → client | `snapshot, requestId?` | The authority's state: `protocol, authorityEpoch, revision, weatherRevision, secondsOfDay, rate, timeFrozen, weather, weatherPreset, weatherPriority, weatherFrozen, transitionSeconds, weatherTransitionRemainingMs, nextRollInMs, reason`. Sent on every change, on join, on request and as a 5 s heartbeat. |
| <a id="opx-net-weather-notice"></a>`opx:net:weather:notice` | server → client | `raw, kind, message` | A command's answer. `kind` is `report`, `success`, `warning` or `error`. |
| <a id="opx-on-weather-updated"></a>`opx:on:weather:updated` | client local | the accepted projection | A snapshot was applied. Only reaches code inside opx_infinity's client VM. |
| <a id="chat-ready"></a>`chat:ready` | client → server | none | Legacy chat event. The server answers with `chat:addSuggestions` listing its commands (once per 2 s per player). opx_infinity's own chat does not send it; the platform's `open77_chat` may. |

## Configuration {#configuration}

`config/weather.lua` sets `OPX.Config.MODULES.weather`. Shared script.

| Key | Default | What it does |
|---|---|---|
| <a id="config-weather-enabled"></a>`enabled` | `true` | `false` switches the module off; the engine then runs its own clock and sky on each client. |
| <a id="config-weather-day-length-minutes"></a>`DAY_LENGTH_MINUTES` | `180` | Real minutes per game day. 180 matches the engine. |
| <a id="config-weather-start-time"></a>`START_TIME` | `{ HOUR = 12, MINUTE = 0, SECOND = 0 }` | Clock at server start. |
| <a id="config-weather-time-frozen"></a>`TIME_FROZEN` | `false` | Start with the clock held. |
| <a id="config-weather-weather-frozen"></a>`WEATHER_FROZEN` | `false` | Start with the roll schedule held. |
| <a id="config-weather-initial-weather"></a>`INITIAL_WEATHER` | `'sunny'` | Weather at start; held for 180 s before the first roll. Unknown names fall back to the first row. |
| <a id="config-weather-weather"></a>`WEATHER` | 8 rows: `sunny`, `lightclouds`, `cloudy`, `rain`, `heavyclouds`, `fog`, `pollution`, `sandstorm` | The roll table. See below. |
| <a id="config-weather-commands"></a>`COMMANDS` | see [Commands](#commands) | `{ KEY = { NAME, RESTRICTED } }` for `STATUS`, `PRESETS`, `SET`, `NEXT`, `FREEZE`, `TIME`, `TIME_FREEZE`, `DAY_LENGTH`. An empty `NAME` turns the command off. `SET` to `DAY_LENGTH` stay restricted unless `RESTRICTED = false`. |

### WEATHER rows

| Field | Meaning |
|---|---|
| `NAME` | What staff type and what the state stores. Add rows freely; do not rename. |
| `PRESET` | The engine weather preset, e.g. `24h_weather_rain`. |
| `WEIGHT` | Relative chance of being rolled; `0` never rolls. |
| `MIN_SECONDS`, `MAX_SECONDS` | Real seconds the weather lasts before the next roll. |
| `TRANSITION_SECONDS` | Crossfade length, 0..300. |

## Refusal codes {#codes}

| Code | Meaning | Locale key |
|---|---|---|
| `invalid_time` | Not `HH:MM[:SS]`, or out of range. | `weather.error.invalidTime` |
| `invalid_day_length` | Not a number, or outside 1..10080. | `weather.error.invalidDayLength` |
| `day_too_short` | Faster than 120 game seconds per real second (under 12 minutes a day). | `weather.error.dayTooShort` |
| `unknown_preset` | Not a `NAME` or `PRESET` in the table. | `weather.error.presetHint` |
| `invalid_transition` | Not a number in 0..300. | `weather.error.invalidTransition` |
| `no_presets` | The table has no usable row. | `weather.error.noPresets` |
