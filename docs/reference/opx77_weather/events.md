---
title: opx77_weather events
description: The wire protocol opx77_weather speaks — the one inbound sync request, the snapshot broadcast, the client-local update event other resources should listen to, and the in-VM event that is not reachable from outside.
---

# Events

The whole protocol is three names, and the asymmetry between them is the design: the server
broadcasts a whole snapshot, a client may only *ask* for one, and everything else on the
machine hears about the result locally.

!!! info "There is deliberately no mutation event"

    Nothing a client sends can move the authority. The only inbound name carries a request id
    and nothing else. Every mutation is an ACL-gated [command](commands.md), resolved by the
    host before this resource runs.

## Networked (client → server) {#networked-client-to-server}

Register these with `RegisterNetEvent` in a **server** script. Inside the handler, `source` is
the authenticated connection that sent it — never trust an id in the payload.

### opx77:weather:request {#opx77-weather-request}

Asks the authority for a snapshot. Answered with a targeted
[`opx77:weather:sync`](#opx77-weather-sync) carrying the same request id, or ignored entirely.

```lua
RegisterNetEvent("opx77:weather:request", function(requestId) end)
```

- requestId: `integer` — a counter the requesting client mints, `>= 1`. It comes back on the
  answer so the client can measure the round trip and halve it into a latency compensation.

Handled by `opx77_weather`'s own server half. It is ignored, with no answer at all, when the
id is not a positive whole number, or when that player asked less than `MIN_REQUEST_MS`
(1000 ms) ago. The timestamp is kept per session player id and cleared on
`onPlayerDisconnected`.

You do not normally send this. `opx77_weather`'s client half sends it at resource start and
every 15 s thereafter, and the authority broadcasts a heartbeat every 5 s regardless.

### chat:ready {#chat-ready}

The chat completion handshake, not part of the weather protocol. `opx77_weather`'s server half
answers it with its own command list.

```lua
-- handled in opx77_weather/server/commands.lua
RegisterNetEvent("chat:ready", function() end)
```

Carries no arguments. The answer is a `chat:addSuggestions` to that player, one entry per
registered command with its help line and parameter names, both rendered from the configured
[locale](index.md#locales) as the answer goes out. It is floored at one answer per player every
2 s, because `chat:ready` is a net event any client can send as fast as it likes.
See [publishing suggestions](../opx77_chat/events.md#publishing-suggestions).

## Networked (server → client) {#networked-server-to-client}

### opx77:weather:sync {#opx77-weather-sync}

The authority's snapshot. Sent to one player as the answer to a request, and to `-1` on every
mutation and every heartbeat.

```lua
RegisterNetEvent("opx77:weather:sync", function(snapshot, requestId) end)
```

- snapshot: `table` — a `WeatherSnapshot`, fields below.
- requestId?: `integer` — present only when this is the answer to that client's own request;
  absent on a broadcast, which is why a broadcast carries no latency compensation.

| Field | Type | Meaning |
|---|---|---|
| `protocol` | `integer` | Wire version. Must equal `OpxWeather.PROTOCOL`, currently `1`. |
| `authorityEpoch` | `number` | Which server incarnation this is. A higher one wins outright. |
| `revision` | `integer` | Bumped by every mutation, within one epoch. |
| `weatherRevision` | `integer` | Bumped only when the preset changes. |
| `secondsOfDay` | `number` | `0..86399.999` at the instant the snapshot was built. |
| `rate` | `number` | Game seconds per real second. |
| `timeFrozen` | `boolean` | The clock is held. |
| `weather` | `string` | The configured `NAME`. |
| `weatherPreset` | `string` | The REDengine preset behind it. |
| `weatherPriority` | `integer` | The priority `setWeather` is submitted at. |
| `weatherFrozen` | `boolean` | The roll **schedule** is held. Not the engine's weather lock. |
| `transitionSeconds` | `number` | The full crossfade length that was chosen. |
| `weatherTransitionRemainingMs` | `number` | How much of it is left — remaining, not elapsed, because the two machines share no clock. |
| `nextRollInMs` | `number \| nil` | Absent entirely while the schedule is frozen. |
| `reason` | `string` | Why it was published. Diagnostic only. |

`reason` is one of `sync`, `request`, `heartbeat`, `weather_scheduled`, `weather_rolled`,
`weather_set`, `weather_frozen`, `weather_resumed`, `time_set`, `time_frozen`, `time_resumed`,
`day_length_changed`, or one of the six `command_*` values a staff command passes in.

!!! warning "It is diagnostic, and a new value is not a protocol change"

    Do not branch on `reason`. It is there so a log line can say what happened; the fields
    beside it are the contract, and a future version may add a value without bumping
    `protocol`.

!!! warning "Any resource on the player's machine can raise this name locally"

    On the client — unlike the server — a plain `TriggerEvent` also reaches `RegisterNetEvent`
    handlers, and the local bus is host-wide. A forged snapshot cannot change the weather for
    anyone *else*, since the server tells every client directly, but it **can latch one client
    off the real authority** by claiming a higher epoch, after which genuine snapshots are
    refused as stale. The handler is floored at one apply every 100 ms and the epoch is bounded
    at 2⁵³, so a forgery has to win a race against the server's own message rather than run in
    a loop nobody outruns. Treat what a player's machine reports accordingly, and decide
    anything that matters on the server.

!!! warning "Never re-emit a wire name from inside its own handler"

    A `TriggerEvent("opx77:weather:sync", …)` inside an `opx77:weather:sync` handler reaches
    that same handler again. There is no re-entry guard on this platform — it is tick-paced, so
    it does not blow the stack, it becomes a silent permanent busy loop instead.

If you want to know what the weather is, do not register this name at all. Listen for
[`opx77:weather:updated`](#opx77-weather-updated), which fires only for snapshots that were
actually accepted, or call [`state`](exports.md#state).

### open77:command:result {#open77-command-result}

The dispatcher's answer to a command that player typed. `opx77_weather`'s **client** half also
registers this name, and logs the ones whose `raw` names one of its own commands — accepted at
info level, refused at warn. It matches against the names in
[`config.lua`](config.md#commands), so a rename carries; matching on the word `weather` would
not.

```lua
RegisterNetEvent("open77:command:result", function(raw, accepted, message) end)
```

- raw: `string` — the command name as typed.
- accepted: `boolean`
- message: `string`

It is a shared channel, not a private one: [`opx77_chat`](../opx77_chat/events.md#open77-command-result)
renders it in the box, and this resource only mirrors its own into the client log. The server
side of it is what every command handler here calls to answer the player.

`message` is the player's [localised](index.md#locales) text, so the mirror does not log it. It
logs the fact instead, in English:

```text
command answered: opx77.weather.set (accepted)
```

## Non-networked, client {#non-networked-client}

Register this with `AddEventHandler` in a **client** script. The client's local event bus is
host-wide, so a name raised in any resource on the player's machine reaches handlers in all of
them.

### opx77:weather:updated {#opx77-weather-updated}

Fires on the player's own machine after every **accepted** snapshot — never for one that failed
validation or was refused as stale. Carries the whole projection, already re-based onto this
client's monotonic clock.

```lua
AddEventHandler("opx77:weather:updated", function(projection) end)
```

- projection: `table` — a `WeatherProjection`: every field of the snapshot above except
  `protocol`, plus three the client adds.

| Added field | Type | Meaning |
|---|---|---|
| `anchorLocalMs` | `number` | The local monotonic millisecond the snapshot was accepted at. `secondsOfDay` is the time *at that instant*, not now. |
| `weatherTransitionEndLocalMs` | `number` | When the crossfade finishes, on this client's clock. |
| `latencyCompensationMs` | `number` | Half the round trip that was folded in; `0` for a broadcast. |

**This is the supported channel for another resource.** It is the only push notification of a
weather change on this platform, it costs nothing to listen to, and it fires perhaps a dozen
times an hour plus one per heartbeat.

!!! warning "`secondsOfDay` on this payload is not the current time"

    It is the time at `anchorLocalMs`, and the clock keeps running afterwards. Reading it
    directly gives you a value that is correct for one instant and then drifts by `rate`
    seconds for every real second that passes. Use it to detect *that* something changed, and
    call [`state`](exports.md#state) when you need the time *now*.

### Example {#opx77-weather-updated-example}

```lua
-- client/main.lua of your own resource
local lastWeather

AddEventHandler("opx77:weather:updated", function(projection)
  if projection.weather == lastWeather then return end
  lastWeather = projection.weather
  Open77.log.info("the sky is now " .. tostring(projection.weather))
end)
```

## Non-networked, server {#non-networked-server}

### opx77:weather:state {#opx77-weather-state}

Raised on the server with `TriggerEvent` every time a snapshot is published, carrying the same
`WeatherSnapshot` that went on the wire.

```lua
-- only inside opx77_weather itself; TriggerEvent walks one VM on the server
AddEventHandler("opx77:weather:state", function(snapshot) end)
```

- snapshot: `table` — a `WeatherSnapshot`, exactly as sent.

**Side** `in-resource server` — reachable only from a file inside `opx77_weather`.

!!! warning "This is not an integration point, and it will look like one"

    A server-side `TriggerEvent` walks only its own VM. There is no cross-resource event bus on
    the server, no `exports`, and no `GetInvokingResource` — a handler you register in your own
    server script will never fire, and nothing will tell you why. It exists so that one file in
    this resource can notify another.

    A server resource that needs to know the weather has to be told over the wire by a client
    that heard it, or read it from a database the authority writes; see
    [Integration channels](../../concepts/integration-channels.md) for the three server-side
    channels that do exist. On the client, use
    [`opx77:weather:updated`](#opx77-weather-updated) instead — that one does cross resources.

## See also {#see-also}

- [Exports](exports.md) — `state`, for sampling rather than reacting.
- [Overview](index.md#authority-model) — how a snapshot is ordered, validated and projected.
- [Integration channels](../../concepts/integration-channels.md) — why the client and server
  buses behave differently.
