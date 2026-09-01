# opx77_weather

`opx77_weather` is a synchronized clock and weather authority. The server
decides what time it is and what the sky is doing; every client is told, and
applies it.

Without a single authority each client runs its own weather, and two players
standing together see different skies. One holds noon and rain, the other
holds dusk and fog, and nothing in the game reconciles them.

| At a glance | |
|---|---|
| Version | `0.1.0` |
| Reload policy | `local` |
| Permissions | `network.events`, `world.environment` |
| Depends on | nothing else in the set |

The resource is split the way the platform forces it: one server half that
owns the state and decides, one client half that projects and applies. See
[the client export contract](../index.md#the-client-export-contract) for why every shared service in OPX//77 is
shaped like this.

!!! warning "Early development"

    Open77 and `opx77_weather` are both pre-1.0. Command names, config keys and
    the export shape can change between versions.

## The authority model

The server holds one state: a second-of-day, an anchor on the host's monotonic
clock, a rate, a preset name and two freeze flags. Nothing on a client
contributes to it. There is exactly one inbound event — a request for a
snapshot — and there is deliberately no mutation event: a client can ask, and
cannot tell.

The authority publishes a `WeatherSnapshot` on every mutation, and a heartbeat
every 5 s when nothing has changed. A client answers a snapshot with nothing;
it either adopts it or drops it.

### Epoch first, then revision

Two counters order the stream:

- **`authorityEpoch`** — which incarnation of the authority this is. It is
  stamped once, when the server anchors its clock on the first real tick, from
  the host's monotonic clock in microseconds. A restart produces a new one; a
  reload carries the old one across.
- **`revision`** — bumped by every mutation, within one epoch.

A third counter, `weatherRevision`, is bumped only when the preset actually
changes, so a client can skip a `setWeather` that would repeat what the sky is
already doing.

A client orders snapshots with those two, in that order:

```lua
-- client/main.lua, Projection.apply
if value.authorityEpoch < held.authorityEpoch then return { ok = false, error = "stale" } end
if value.authorityEpoch == held.authorityEpoch and value.revision < held.revision then
  return { ok = false, error = "stale" }
end
```

A **higher epoch wins outright** — a new server generation is adopted whatever
its revision, because its revision counter started again at 1 and comparing it
against the previous generation's would refuse every genuine snapshot. Within
one epoch, a lower revision is refused as `stale`. Before any of that the
snapshot is validated whole: wrong `protocol`, a non-integer or out-of-range
epoch or revision, a `secondsOfDay` outside `0..86399`, a NaN or a rate past
`Clock.MAX_RATE`, an empty preset string or a transition outside `0..300`
seconds is rejected as `invalid_snapshot` and nothing is applied.

### Latency compensation

A snapshot describes the world as it was when the server sent it. A client
that asked for it knows how long the round trip took, and adds **half** of it:

```lua
compensationMs = math.min(SYNC.MAX_LATENCY_MS, math.max(0, receivedAt - sentAt) / 2)
```

The compensation is added to the time of day (`rate * compensationMs / 1000`,
and not at all while the clock is frozen) and subtracted from the remaining
transition, so a player joining mid-crossfade picks the fade up where everyone
else is. It is bounded at `MAX_LATENCY_MS` (2000 ms), and it is `0` for a
broadcast — a heartbeat carries no request id, so there is no round trip to
halve.

Each client then re-bases the snapshot onto its **own** monotonic clock:
`anchorLocalMs` is the instant it was accepted, and the time of day is derived
from there every 500 ms. The two machines never compare clocks; they compare
elapsed milliseconds.

!!! note "Why the client re-derives instead of being told"

    Telling a client the time once every heartbeat would step the sky five
    seconds at a time. The client is told the time *and the rate*, and runs the
    clock itself between snapshots. It only writes to the game when the live
    time has drifted more than `DRIFT_TOLERANCE_SECONDS` (120 game seconds)
    from where the projection says it should be — the engine's own clock is
    left to run the seconds in between.

### The weather lock

REDengine runs its own weather cycle. On every accepted snapshot the client
takes `Open77.environment.setWeatherFrozen(true)`, which stops that cycle from
running underneath the projection, and a thread re-checks the lock **every
5 s** (`ENFORCE_MS`). A lock found false is evidence something else took the
sky: the client re-takes it, and re-submits the preset if no transition is
still running.

## Fails open

The resource is built so that a failure gives the world *back*, never a frozen
sky nothing drives.

- **A client that cannot reach the authority keeps the last sky it was given.**
  The projection keeps running on its own monotonic clock; sync requests keep
  going out every 15 s. Nothing is reset and nothing is blanked.
- **On stop, the world is handed back.** `onClientResourceStop` releases both
  locks — `setTimeFrozen(false)` and `setWeatherFrozen(false)` — so a player
  left after the resource goes away is under the engine's own cycle rather
  than under a held sky with no authority behind it.
- **On start, the time lock is released before anything else**, so a client
  reconnecting into a lock an older generation left behind always thaws.
- **Without the environment natives, the client loads nothing.** It logs
  `environment natives unavailable; restart Cyberpunk to activate them` and
  returns; `getState` then answers `environment_unavailable` rather than
  raising.
- **With no usable preset row**, the authority reports `ready = false`, every
  weather mutation answers `no_presets`, and the status line carries a
  `DEGRADED` marker. The clock still runs.

## Commands

Every mutation is registered **restricted**, so the host resolves
`command.<name>` against the caller's ACL **before this resource runs at all**.
There is no permission check anywhere in `server/commands.lua`, and there must
not be one.

| Command | Arguments | Does | Gated |
|---|---|---|---|
| `opx77.weather` | — | The current time, day length, preset, freezes and next roll | open |
| `opx77.weather.presets` | — | Lists the configured presets: name, engine preset, weight, duration band, transition | open |
| `opx77.weather.set` | `<preset> [seconds]` | Crosses to a preset by `NAME` or engine `PRESET`, case-insensitive; the optional transition overrides the preset's own | ACL |
| `opx77.weather.next` | — | Rolls the weighted table now, even while the schedule is frozen | ACL |
| `opx77.weather.freeze` | `<on\|off>` | Holds or releases the roll **schedule** | ACL |
| `opx77.weather.time` | `<HH:MM[:SS]>` | Sets the authoritative clock, 24-hour | ACL |
| `opx77.weather.time.freeze` | `<on\|off>` | Holds or releases the clock | ACL |
| `opx77.weather.daylength` | `<realMinutes>` | Sets how many real minutes a day takes | ACL |

`on`, `true` and `1` all mean on; `off`, `false` and `0` all mean off. A bare
toggle is deliberately not accepted — it would have to be run twice to be read.

Grant the desk in `acl.jsonc`, which `server.jsonc` names under
`accessControl`. A trailing wildcard covers all of it at once:

```text
command.opx77.weather.*
```

Console helpers: `acl.reload`, `acl.list`, `acl.check <playerId> <permission>`.
Commands typed at the server console run as `source = 0`, are never rate
limited, and answer into the platform log instead of into chat. A player's
answer goes back over `open77:command:result` and is picked up by
[`opx77_chat`](opx77_chat.md).

!!! note "A command set to `false` is not registered"

    `COMMANDS.<KEY>.NAME = false` — or an empty string — registers nothing at
    all: the name does not exist, and the ACL key for it is never consulted
    because there is no command behind it. The boot log says so once, per key.

    Two entries sharing one `NAME` would bind a single ACL key, and the loser's
    `RESTRICTED` flag with it. The second one is refused and logged at error
    level.

!!! danger "`RESTRICTED = false` on a mutation opens it to every player"

    For the six mutations the flag is read as `RESTRICTED ~= false`, so a
    missing, misspelled or quoted flag still gates the command. Only an
    explicit `RESTRICTED = false` opens one, and the boot log then warns
    `command <name> is OPEN to every player`. For the two read-only commands
    the test is the other way round (`RESTRICTED == true`): they are open
    unless you say otherwise.

Registered names, with `[acl]` or `[open]` beside each, are printed at boot and
sent as chat suggestions: the resource answers `chat:ready` with
`chat:addSuggestions`, carrying each registered command's help line and its
parameter names, so staff see the usage while typing.

The two open commands are floored at one run per player every 2 s, as is the
suggestion handshake. The mutations are not — they are already behind the ACL.

## Exports

Client-side, read-only. There is no export that moves the authority: an
authority another resource can move is not one.

| Export | Answers |
|---|---|
| `getState` | The time, the preset, the freezes, the revisions, and whether the authority has been heard from |

`getState` projects to the instant of the call — it does not answer the last
snapshot's timestamp, it answers what the clock reads now.

```lua
--- ok = true
{
  ok = true,
  hour = 21, minute = 30, second = 4,
  secondsOfDay = 77404.2,
  weather = "rain",                  -- the configured NAME
  weatherPreset = "24h_weather_rain", -- the REDengine preset
  timeFrozen = false,
  weatherFrozen = false,
  revision = 42,
  weatherRevision = 7,
  latencyCompensationMs = 31,
}

--- ok = false
{ ok = false, error = "not_synchronized" }        -- no snapshot accepted yet
{ ok = false, error = "environment_unavailable" } -- no environment natives in this client
```

Both failure levels of the export contract still apply on top of that:

```lua
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_weather", "getState")
  if not promise then return print(reason) end        -- dispatch failure

  local result, callError = promise:await()           -- resolution failure
  if callError then return print(callError) end

  if not result.ok then
    -- "not_synchronized" or "environment_unavailable"
    return print(result.error)
  end

  print(("%02d:%02d — %s"):format(result.hour, result.minute, result.weather))
end)
```

!!! warning "Treat `not_synchronized` as a normal state, not an error"

    It is what every client answers between resource start and the first
    accepted snapshot, and what one answers again if it is asked during a
    server restart. Poll, or listen for the local `opx77:weather:updated`
    event, which the client raises with the whole projection after every
    accepted snapshot and which crosses resources on the client.

## Presets and the roll

Each row of `OPX_WEATHER_CONFIG.WEATHER` is a name staff can type, the
REDengine preset behind it, a weight, a duration band and a crossfade.

| `NAME` | `PRESET` | `WEIGHT` | `MIN_SECONDS` | `MAX_SECONDS` | `TRANSITION_SECONDS` |
|---|---|---:|---:|---:|---:|
| `sunny` | `24h_weather_sunny` | 28 | 480 | 900 | 18 |
| `lightclouds` | `24h_weather_light_clouds` | 24 | 360 | 720 | 20 |
| `cloudy` | `24h_weather_cloudy` | 18 | 300 | 600 | 24 |
| `rain` | `24h_weather_rain` | 12 | 180 | 420 | 30 |
| `heavyclouds` | `24h_weather_heavy_clouds` | 8 | 240 | 480 | 26 |
| `fog` | `24h_weather_fog` | 5 | 180 | 360 | 28 |
| `pollution` | `24h_weather_pollution` | 3 | 180 | 360 | 28 |
| `sandstorm` | `24h_weather_sandstorm` | 2 | 120 | 300 | 35 |

- **`WEIGHT` is relative**, and only against the other rows — the shipped
  weights happen to total 100, which is convenient to read but not required. A
  weight of `0` means the row can be `set` by hand but **never rolls**.
- **`MIN_SECONDS` / `MAX_SECONDS`** are real seconds. The duration is drawn
  once, with `math.random(MIN_SECONDS, MAX_SECONDS)`, at the moment the preset
  starts — not when the previous one ends, and not re-drawn while it runs.
- **`TRANSITION_SECONDS`** is how long the sky takes to cross into the preset.
  It is the default for a roll and for a bare `set`; `set` with a second
  argument overrides it, bounded to `0..300` seconds. A snapshot carries the
  *remaining* transition rather than its start, because the two machines share
  no clock, so a client that arrives mid-fade joins it where it is.

### It never rolls the sky already up

`Authority.chooseNext` builds its candidate list from every row whose `NAME`
differs from the current one **and** whose weight is above zero, accumulates
their weights, and picks a point in that total. A repeat is structurally
impossible: the current preset is not a candidate.

The degenerate case is handled rather than looped: if nothing is left to roll —
a one-row table, or every other row weighted `0` — the current preset is
returned and the sky stays put.

`opx77.weather.next` calls the same roll, so a manual roll obeys the same rules
as a scheduled one, and re-draws the duration on the way in.

Timing around the roll:

- The scheduler looks at whether a roll is due once a second.
- The boot preset holds for **180 s** before the first roll, whatever the row's
  own band says.
- Freezing the schedule suspends the countdown, and `nextRollInMs` is absent
  from the snapshot while it is frozen. Releasing it **re-arms** the countdown
  from a fresh draw — otherwise an expired timer would make "resume" mean
  "next".

## The clock

The clock is a second-of-day plus a rate, anchored to the host's monotonic
clock. It is never read from the operating system's wall time.

```lua
Clock.at(baseSeconds, anchorMs, rate, frozen, nowMs)
-- frozen does not advance; the anchor is rewritten on the freeze
```

**Day length and rate.** `DAY_LENGTH_MINUTES` is real minutes per whole day.
The rate is `86400 / (minutes * 60)`, in game seconds per real second. At the
shipped 180 minutes the rate is exactly `8.0`, which is the only value that
matches the engine's own rate.

**Bounds.** A day length is accepted from **1 minute to 10080 minutes (7
days)**; outside that the answer is `invalid_day_length`. On top of that the
rate is capped at `Clock.MAX_RATE = 120.0` game seconds per real second, which
refuses anything under **12 real minutes a day** with `day_too_short`. The cap
exists because a client past the drift tolerance at that speed would be jumping
the world continuously instead of running it.

**Freezing.** `timeFrozen` holds the clock where it is; the anchor is rewritten
at the moment of the freeze so releasing it resumes rather than jumps.
`weatherFrozen` is a different thing entirely: it holds **the roll schedule**,
not the engine's weather lock, which the client keeps taken regardless.

**Normalisation.** `Clock.normalize` folds any second-of-day onto `0..86399`,
negatives included, so arithmetic across midnight needs no special case.
`Clock.toHms` floors to whole seconds first, then splits — `Clock.fromHms`
refuses an hour that does not exist (`25:00` is a mistake, not a wrap), and
`Clock.parse` accepts `HH:MM` or `HH:MM:SS` and nothing else, so `12:30pm` is
refused rather than half-read.

!!! note "Rewinds are guarded"

    `setTime` in the engine picks the *next* occurrence of a time, so a stale
    packet one second behind would be applied as a full-day jump forward. The
    client refuses a backwards step of more than twelve hours unless a mutation
    or a new epoch actually moved the authority.

## Configuration

Everything below lives in `config.lua`, which is a **shared** script: a client
downloads it. Put no secrets and no ACL grants in it.

| Key | Meaning | Shipped default |
|---|---|---|
| `DAY_LENGTH_MINUTES` | Real minutes per whole day. Only 180 matches the engine's own rate. | `180` |
| `START_TIME.HOUR` | Boot hour. A reload keeps the live time instead. | `12` |
| `START_TIME.MINUTE` | Boot minute. | `0` |
| `START_TIME.SECOND` | Boot second. | `0` |
| `TIME_FROZEN` | Start with the clock held at `START_TIME`. | `false` |
| `WEATHER_FROZEN` | Start with the roll **schedule** held. Not the engine's weather lock. | `false` |
| `INITIAL_WEATHER` | A `NAME` or a `PRESET` from `WEATHER`. Unknown falls back to the first row, with a warning. | `"sunny"` |
| `WEATHER` | The preset table: `NAME`, `PRESET`, `WEIGHT`, `MIN_SECONDS`, `MAX_SECONDS`, `TRANSITION_SECONDS`. | 8 rows |
| `COMMANDS.STATUS` | `{ NAME, RESTRICTED }` — time, preset, freezes, roll. | `"opx77.weather"`, `false` |
| `COMMANDS.PRESETS` | What `.set` accepts. | `"opx77.weather.presets"`, `false` |
| `COMMANDS.SET` | `<name\|preset> [seconds]`. | `"opx77.weather.set"`, `true` |
| `COMMANDS.NEXT` | Roll now, even if frozen. | `"opx77.weather.next"`, `true` |
| `COMMANDS.FREEZE` | `<on\|off>`, the schedule. | `"opx77.weather.freeze"`, `true` |
| `COMMANDS.TIME` | `<HH:MM[:SS]>`. | `"opx77.weather.time"`, `true` |
| `COMMANDS.TIME_FREEZE` | `<on\|off>`. | `"opx77.weather.time.freeze"`, `true` |
| `COMMANDS.DAY_LENGTH` | `<realMinutes>`. | `"opx77.weather.daylength"`, `true` |

A malformed row is dropped with a warning rather than taken: `NAME` and
`PRESET` must both be strings, a missing `MIN_SECONDS` falls back to 300, a
`MAX_SECONDS` below the minimum is raised to it, a missing weight is `0` and a
missing transition is 20 seconds. An unparsable `START_TIME` falls back to
12:00:00 and an unusable `DAY_LENGTH_MINUTES` to a rate of `8.0`.

### What is not in `config.lua`

The cadence — how often each side talks, the drift tolerance, the latency
ceiling and the wire protocol version — lives in `shared/clock.lua` instead,
because none of it is an operator decision and the two halves must not be able
to disagree about it.

| Constant | Value | Meaning |
|---|---:|---|
| `PROTOCOL` | `1` | Wire version; both halves must agree |
| `HEARTBEAT_MS` | `5000` | How often the authority republishes unchanged |
| `CLIENT_SYNC_MS` | `15000` | How often a client asks for a fresh timestamp |
| `APPLY_MS` | `500` | How often the client re-derives the time of day |
| `ENFORCE_MS` | `5000` | How often the client re-checks the weather lock |
| `SCHEDULER_MS` | `1000` | How often the authority looks at whether a roll is due |
| `DRIFT_TOLERANCE_SECONDS` | `120` | Game seconds of drift before the client corrects |
| `MAX_LATENCY_MS` | `2000` | Ceiling on the half-round-trip compensation |
| `MIN_REQUEST_MS` | `1000` | Floor between two sync requests from one player |
| `INITIAL_WEATHER_SECONDS` | `180` | How long the boot preset holds before the first roll |
| `WEATHER_PRIORITY` | `5` | Priority `setWeather` is submitted at |

### Reload keeps the sky, restart returns it to config

```lua
reload_policy "local"
```

On a reload the authority hands its live state to the host — epoch, both
revisions, the base second and anchor, the rate, the preset and both freeze
flags — and the next generation adopts it, keeping the same epoch and carrying
on the same revision counter. The boot log then reads *authority resumed across
a reload*. On a **restart** nothing is carried and the state returns to
`config.lua`, with a fresh epoch that every client adopts outright.

The carried bag is untrusted input and is refused **whole** rather than
partly: a `PROTOCOL` that is not the current one, a preset that is no longer
configured, any carried number that is not finite, a negative epoch, a revision
below 1, or a rate outside `0 < rate <= MAX_RATE`. Any of those and the
resource boots from configuration instead, with a warning naming what was
wrong.

State is also saved the moment the authority anchors, before any mutation —
otherwise a reload in the first minutes would still send the day back to noon.

## Permissions

```lua
permissions {
  "network.events",     -- snapshots out, sync requests in
  "world.environment",  -- Open77.environment.*; client-side only, and only this resource
}
```

`network.events` carries the whole protocol: snapshots out to clients, sync
requests in from them. `world.environment` is what the client half needs to
write the sky and the clock — `setWeather`, `setTime`, `setWeatherFrozen`,
`setTimeFrozen`, `getTime`, `isWeatherFrozen`.

**`world.environment` is client-side only.** `Open77.environment.*` does not
exist in the server runtime; the authority never touches the sky, it only
describes it. The client half checks the natives are actually present before
loading anything else, because every function below that point would otherwise
be a call into `nil`.

**And only this resource.** The environment is a single global the last writer
wins. Two resources holding `world.environment` and writing the weather fight
each other at whatever cadence they each run, and the visible result is a sky
that flickers between two presets. Everything else in OPX//77 reads the sky
through `getState` or the `opx77:weather:updated` event instead of writing it.

!!! warning "The client event bus crosses resources"

    On the client — unlike the server — any resource on the player's machine
    can raise `opx77:weather:sync`. It cannot forge the weather for anyone
    *else*, since the server tells every client directly, but it can latch one
    client off the real authority by claiming a higher epoch, after which
    genuine snapshots are refused as stale. The handler is floored at one apply
    every 100 ms and the epoch is bounded at 2^53, so a forgery has to win a
    race against the server's own message rather than run in a loop nobody
    outruns. Treat what a player's machine can reach accordingly.

## See also

- [Getting started](../getting-started.md) — `acl.jsonc`, and the
  `startup.commands` list in `server.jsonc` for pinning the clock at boot.
- [`opx77_core`](opx77_core.md) — the framework and the server state.
- [`opx77_chat`](opx77_chat.md) — where a command's answer is shown.
