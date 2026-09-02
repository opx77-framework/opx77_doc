---
title: opx77_weather
description: opx77_weather is a server-authoritative clock and sky for OPX//77 — one authority decides the time of day and the weather preset, every client is told, and the state survives a reload.
---

# opx77_weather

A server-authoritative clock and sky. The server decides what time it is and what the weather
is doing; every client is told, and applies it.

| At a glance | |
|---|---|
| **Version** | `0.2.0` |
| **Requires** | `open77_version ">=0.0.1"`. Nothing else in OPX//77 |
| **Auto start** | yes |
| **Reload policy** | `local` — the live authority is carried across a reload. See [below](#carried-state) |
| **Permissions** | `network.events`, `world.environment` |
| **Sides** | server, which owns the state and decides, and client, which projects and applies it |
| **Exports** | one, client-side and read-only — see [Exports](exports.md) |
| **Commands** | eight — six ACL-gated, two open. See [Commands](commands.md) |
| **Events** | one snapshot outward, one request inward, and **no mutation event** — see [Events](events.md) |
| **Locales** | `en` and `fr`; [`LOCALE`](config.md#locale) picks one. Logs stay English — see [below](#locales) |
| **Conflicts with** | `open77_weather`, the official package it replaces. See [below](#official-package-conflict) |

## What it is {#what-it-is}

Without a single authority each client runs its own weather, and two players standing together
see different skies. One holds noon and rain, the other dusk and fog, and nothing in the game
reconciles them.

`opx77_weather` is split the way the platform forces every shared service to be split: one
server half that owns the state and decides, one client half that projects and applies. The
server holds one state — a second-of-day, an anchor on the host's monotonic clock, a rate, a
preset name and two freeze flags — and nothing on a client contributes to it. There is exactly
one inbound event, a request for a snapshot, and there is deliberately **no mutation event**: a
client can ask, and cannot tell.

The authority publishes a snapshot on every mutation and a heartbeat every 5 s when nothing
has changed. A client answers a snapshot with nothing; it either adopts it or drops it.

## The pages {#pages}

- **[Exports](exports.md)** — `getState`, the one read-only client export.
- **[Commands](commands.md)** — the eight staff commands and the ACL keys that gate them.
- **[Events](events.md)** — the two wire events, the local one every other resource should
  listen to, and the in-VM one that is not reachable from outside.
- **[Configuration](config.md)** — `config.lua`, and the cadence constants that deliberately
  are not in it.

## The authority model {#authority-model}

### Epoch first, then revision {#ordering}

Two counters order the stream:

- **`authorityEpoch`** — which incarnation of the authority this is. It is stamped once, when
  the server anchors its clock on the first real tick, from the host's monotonic clock in
  microseconds. A restart produces a new one; a reload carries the old one across.
- **`revision`** — bumped by every mutation, within one epoch.

A third counter, `weatherRevision`, is bumped only when the preset actually changes, so a
client can skip a `setWeather` that would repeat what the sky is already doing.

A client orders snapshots with those two, in that order:

```lua
-- client/main.lua, Projection.apply
if value.authorityEpoch < held.authorityEpoch then return { ok = false, error = "stale" } end
if value.authorityEpoch == held.authorityEpoch and value.revision < held.revision then
  return { ok = false, error = "stale" }
end
```

A **higher epoch wins outright** — a new server generation is adopted whatever its revision,
because its revision counter started again at 1 and comparing it against the previous
generation's would refuse every genuine snapshot. Within one epoch, a lower revision is
refused as `stale`.

Before any of that the snapshot is validated whole, field by field: a wrong `protocol`, a
non-integer or out-of-range epoch or revision, a `secondsOfDay` outside `0..86399`, a rate
outside `0 < rate <= Clock.MAX_RATE`, a freeze flag that is not a boolean, an empty `weather` or
`weatherPreset`, a non-integer `weatherPriority`, a transition outside `0..300` seconds, a
remaining transition outside `0..300000` ms, a `nextRollInMs` that is present and negative, or a
`reason` that is not a string. Any one of them and the **whole** snapshot is rejected as
`invalid_snapshot`, with nothing applied.

Every number there is tested with `Clock.finite`, which is one test standing in for three
mistakes: a NaN sits *inside* every bound written above, an infinity sits outside all of them,
and `% 1 ~= 0` cannot see a non-integer past 2⁵³. A NaN through that gate would hold the clock
silently; an infinity would raise out of the first `%d` that reached it.

### Latency compensation {#latency}

A snapshot describes the world as it was when the server sent it. A client that *asked* for it
knows how long the round trip took, and adds **half** of it:

```lua
compensationMs = math.min(SYNC.MAX_LATENCY_MS, math.max(0, receivedAt - sentAt) / 2)
```

The compensation is added to the time of day (`rate * compensationMs / 1000`, and not at all
while the clock is frozen) and subtracted from the remaining transition, so a player joining
mid-crossfade picks the fade up where everyone else is. It is bounded at `MAX_LATENCY_MS`
(2000 ms), and it is `0` for a broadcast — a heartbeat carries no request id, so there is no
round trip to halve.

Each client then re-bases the snapshot onto its **own** monotonic clock: `anchorLocalMs` is the
instant it was accepted, and the time of day is derived from there every 500 ms. The two
machines never compare clocks; they compare elapsed milliseconds.

Telling a client the time once every heartbeat would step the sky five seconds at a time. The
client is told the time *and the rate*, and runs the clock itself in between. It only writes to
the game when the live time has drifted more than `DRIFT_TOLERANCE_SECONDS` (120 game seconds)
from where the projection says it should be — the engine's own clock runs the seconds between.

!!! warning "Rewinds are guarded, because `setTime` picks the next occurrence"

    The engine's `setTime` moves *forward* to the next occurrence of a time, so a stale packet
    one second behind would be applied as a full-day jump. The client refuses a backwards step
    of more than twelve hours unless a mutation or a new epoch actually moved the authority.

### The weather lock {#weather-lock}

REDengine runs its own weather cycle. On every accepted snapshot the client takes
`Open77.environment.setWeatherFrozen(true)`, which stops that cycle running underneath the
projection, and a thread re-checks the lock every 5 s (`ENFORCE_MS`). A lock found false is
evidence something else took the sky: the client re-takes it, and re-submits the preset if no
transition is still running.

The re-submission is deliberately conditional. An unconditional forced re-apply on every pass
is not a native no-op — each submission re-evaluates world state, and the platform's own
package documents removing exactly that because it resurrected destroyed props.

## Fails open {#fails-open}

The resource is built so that a failure gives the world *back*, never a frozen sky nothing
drives.

- **A client that cannot reach the authority keeps the last sky it was given.** The projection
  keeps running on its own monotonic clock; sync requests keep going out every 15 s. Nothing is
  reset and nothing is blanked.
- **On stop, the world is handed back.** `onClientResourceStop` releases both locks —
  `setTimeFrozen(false)` and `setWeatherFrozen(false)` — so a player left after the resource
  goes away is under the engine's own cycle rather than a held sky with no authority behind it.
- **On start, the time lock is released before anything else**, so a client reconnecting into a
  lock an older generation left behind always thaws.
- **Without the environment natives, the client loads nothing.** It logs
  `environment natives unavailable; restart Cyberpunk to activate them` and returns;
  [`getState`](exports.md#getstate) then answers `environment_unavailable` rather than raising.
- **With no usable preset row**, the authority reports `ready = false`, every weather mutation
  answers `no_presets`, and the status line carries a `DEGRADED` marker. The clock still runs.
- **A loop slice that raises does not end its loop.** Every slice runs inside
  `OpxWeather.guarded`, which `pcall`s it and logs `<label> slice failed: …` at warn level. A
  raise from a host call inside a bare `CreateThread` ends that loop for the rest of the
  session, which is the failure this exists to prevent.

## Reload keeps the sky {#carried-state}

```lua
reload_policy "local"
```

A reload replaces the Lua VM wholesale. Everything a resource keeps in an upvalue is gone and
it re-initialises from its config defaults — which for a resource that merely reacts to events
is correct, and for one that *holds* world state is data loss dressed up as a fresh start.
Worse than losing it: every connected client is then told to follow the reverted value. Reload
`opx77_weather` at 21:40 and, without this, every player's sky snaps back to noon and sunny.

So the authority hands its live state to the **host** instead, with a pair of server-side
functions:

```lua
Open77.state.save(carried)   -- true; nil clears
local carried = Open77.state.load()  -- the last stored value, or nil on a fresh start
```

`Open77.state` is a small bag the host keeps per resource, outside the VM. It survives a
reload and is deliberately dropped by `stop`, `restart` and `refresh`, so an operator keeps a
way to say "come up as you would at boot" — and the server re-asserts its `startup.commands`
for a resource that starts with nothing carried.

!!! info "This API is not on the platform's API reference"

    `Open77.state.save` / `.load` / `.clear` are absent from the page that claims to be the
    complete server inventory, and the host's own bootstrap names the weather clock as the
    motivating example. What is written here comes from the shipped bootstrap and the host
    binaries, not from the website — see [Persistence](../../concepts/persistence.md) for the
    full contract and for how it differs from the database.

What `opx77_weather` carries: the protocol version, the authority epoch, both revision
counters, the base second and its anchor, the rate, the weather name, when the preset last
changed, the transition length, when the next roll is due, and both freeze flags. The boot log
then reads *authority resumed across a reload*, the epoch is unchanged, and the revision
counter carries on, so **no client sees a mutation at all** — the reload is invisible from the
outside.

It is saved on every mutation, and once more the moment the authority anchors, before any
mutation has happened: without that, a reload in the first minutes would still send the day
back to noon.

!!! warning "A carried value is untrusted input from a previous version of your own code"

    That is the whole point of a reload — the code may have changed shape between the save and
    the load. The bag is also round-tripped through JSON by the host, so it holds plain data
    only: functions, coroutines and metatables do not survive, and cycles are rejected.
    Validate everything you read, and refuse the bag **whole** rather than in parts, or you
    boot half in one world and half in another.

`opx77_weather` refuses the whole bag on any of:

| Refused when | Why |
|---|---|
| It is not a table | Nothing decoded, or something else wrote it. |
| `PROTOCOL` is not the current one | The wire shape changed across the reload. |
| The carried preset is no longer configured | Somebody edited `config.lua` between the generations. |
| Any carried number is not a finite number | A NaN anchor would freeze the clock silently. |
| `authorityEpoch` is missing, negative or not a whole number | It orders every snapshot; a bad one latches clients off. |
| `revision` or `weatherRevision` is below 1, or not a whole number | Both start at 1, climb by one, and reach a `%d`. |
| `rate` is `<= 0`, or above `Clock.MAX_RATE` | The same ceiling the wire enforces — a bag can outlive the build whose bound was wider. |
| `transitionSeconds` is outside `0..300` | Also the wire's own bound: a wider carried crossfade would have every snapshot refused. |

Any of those and it boots from `config.lua` instead. The protocol mismatch, the preset that is
no longer configured and the field that is not a finite number each name themselves in a
warning; the bounds below them refuse silently. The carried anchor is kept as-is rather than
rebased, because
`anchorMs` comes from the host's monotonic clock, which is process-wide and does not restart
with the VM.

!!! warning "Save when state changes, never from a stop handler"

    A reload prepares the successor VM *before* stopping the old one, so a `Open77.state.save`
    from inside `onResourceStop` is refused and returns a bare `false`. There is also a 64 KiB
    ceiling on the encoded value, and exceeding it **raises** rather than returning false. This
    is a handful of authoritative fields that must survive a reload, not a database — for
    anything that must outlive the process, see [Persistence](../../concepts/persistence.md).

A **restart** carries nothing: the state returns to `config.lua` with a fresh epoch, which
every client adopts outright.

## Player-facing text {#locales}

Every sentence a player is shown comes from a catalogue in `locales/`, and
[`LOCALE`](config.md#locale) in `config.lua` picks which one. `en` and `fr` ship.
`shared/locale.lua` is the catalogue itself and publishes one global, `locale(key, params)`,
which every file listed below it in `open77.lua` uses. A key missing from the chosen catalogue
falls back to `en`, and then to the key itself.

The surface is the whole of what a **player** gets back: the status line and the preset list a
[command](commands.md) answers with, the refusal sentences, the `usage:` lines and the chat
completion help. Nothing else moves. Server logs, the answer the server console gets, the
`reason` on a snapshot and the `error` codes on [`getState`](exports.md#getstate) are English,
because a code is what integrating code branches on rather than something a player reads.

The two nearly meet in one place, and deliberately do not. The client half mirrors this
resource's own [`open77:command:result`](events.md#open77-command-result) answers into the
operator log, and the `message` on that event is the player's translated text — so the mirror
logs the fact instead, in English:

```text
command answered: opx77.weather.set (accepted)
```

## Permissions {#permissions}

```lua
permissions {
  "network.events",     -- snapshots out, sync requests in
  "world.environment",  -- Open77.environment.*; client-side only, and only this resource
}
```

`network.events` carries the whole protocol: snapshots out to clients, sync requests in from
them. `world.environment` is what the client half needs to write the sky and the clock —
`setWeather`, `setTime`, `setWeatherFrozen`, `setTimeFrozen`, `getTime`, `isWeatherFrozen`.

**`world.environment` is client-side only.** `Open77.environment.*` does not exist in the
server runtime; the authority never touches the sky, it only describes it. The client half
checks all six are actually present before loading anything else, because every function below
that point would otherwise be a call into `nil`.

**And only this resource should hold it.** The environment is a single global and the last
writer wins. Two resources holding `world.environment` and writing the weather fight each
other at whatever cadence they each run. Everything else in OPX//77 reads the sky through
[`getState`](exports.md#getstate) or the
[`opx77:weather:updated`](events.md#opx77-weather-updated) event instead of writing it.

## Running alongside the official `open77_weather` {#official-package-conflict}

`opx77_weather` replaces the platform's own `open77_weather` package. It is not an addition to
it, and the two cannot both be loaded.

If both are running, the server half warns once at boot:

```text
open77_weather is running and is the package this one replaces
  two authorities both hold world.environment: the clock is corrected twice
  a second toward two different times, and the sky is whichever authority
  rolled last. Drop one from resources.load in server.jsonc.
```

What actually goes wrong:

- **The clock is corrected twice a second, toward two different times.** Both client halves run
  a 500 ms apply loop, each calling `Open77.environment.setTime` toward its own authority
  whenever drift exceeds the tolerance. Nothing enforces exclusivity on `world.environment` —
  the platform's own reference calls single ownership a convention, and no lock exists in the
  shipped host.
- **The sky is whichever authority rolled last.** Each schedule rolls on its own timer, two to
  fifteen minutes apart, and each roll re-submits a preset over the other's.
- **The weather lock hides the fight rather than resolving it.** Both take
  `setWeatherFrozen(true)` on every apply, so neither one's 5 s enforce loop ever sees the lock
  cleared and neither forces a re-apply. That is why this is a slow flip between presets and
  not a five-second flicker — and why it is easy to misdiagnose.

There is no export or command collision: `Open77.exports.call` is resource-scoped, so a caller
naming `open77_weather` can never reach `opx77_weather`; the commands here are all
`opx77.weather.*`, and the wire events are all `opx77:weather:*`.

The check is a `GetResourceState("open77_weather")` from a deferred thread rather than at file
scope — a conflicting resource listed after this one in `resources.load` is still `discovered`
at load time, and the warning would silently depend on load order. Server resources cannot call
each other on this platform, so asking the host is the only way to ask at all; see
[Integration channels](../../concepts/integration-channels.md).

## See also {#see-also}

- [Getting started](../../guides/getting-started.md) — `acl.jsonc`, and the `startup.commands`
  list in `server.jsonc` for pinning the clock at boot.
- [`opx77_chat`](../opx77_chat/index.md) — where a command's answer is shown.
- [Persistence](../../concepts/persistence.md) — the carried-state bag and the database, and
  which one a given fact belongs in.
