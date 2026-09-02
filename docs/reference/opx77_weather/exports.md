---
title: opx77_weather exports
description: getState, the one read-only client export opx77_weather publishes — the synchronised time and weather projected to the instant of the call — with its fields and refusal codes.
---

# Exports

`opx77_weather` publishes one client export, and it is read-only.

!!! info "Read the export contract first"

    The call is asynchronous, resource-scoped and can fail at three different levels.
    [The export contract](../../concepts/export-contract.md) explains the shape; this page
    assumes it.

There is deliberately no export that moves the authority. An authority another resource can
move is not one — every mutation goes through an ACL-gated [command](commands.md), and the
only inbound wire event is a request for a snapshot. There is no server export either, here or
anywhere in OPX//77: the server runtime installs no export machinery at all.

## getState {#getstate}

Answers the synchronised time and weather, projected to the instant of the call, or
`{ ok = false, error = … }` when this client has no environment natives or has not accepted a
snapshot yet.

```lua
Open77.exports.call("opx77_weather", "getState")
```

Takes no arguments.

**Returns** `table` — a `WeatherStateResponse`

| Field | Type | Meaning |
|---|---|---|
| `ok` | `boolean` | `true` when the rest of the table is present. |
| `hour` | `integer` | `0..23`, projected to now. |
| `minute` | `integer` | `0..59` |
| `second` | `integer` | `0..59` |
| `secondsOfDay` | `number` | The same instant unrounded, `0..86399.999`. |
| `weather` | `string` | The configured `NAME`, for example `"rain"`. |
| `weatherPreset` | `string` | The REDengine preset behind it, for example `"24h_weather_rain"`. |
| `timeFrozen` | `boolean` | The clock is held. |
| `weatherFrozen` | `boolean` | The roll **schedule** is held. Not the engine's weather lock, which the client keeps taken regardless. |
| `revision` | `integer` | The authority's mutation counter, as of the last accepted snapshot. |
| `weatherRevision` | `integer` | Bumped only when the preset changes. |
| `latencyCompensationMs` | `number` | Half the round trip that was added to the last accepted snapshot; `0` for one that arrived as a broadcast. |

**Errors**

| Code | Meaning |
|---|---|
| `not_synchronized` | No snapshot has been accepted yet on this client. |
| `environment_unavailable` | This client has no environment natives, so the projection never loaded. |

**Side** `client export` — callable from any client resource through `Open77.exports.call`.
Local only: it reads this machine's projection, not the server's state.

It projects to the instant of the call. It does not answer the last snapshot's timestamp; it
answers what the clock reads *now*, derived from the accepted snapshot, the rate and the local
monotonic clock.

!!! warning "Treat `not_synchronized` as a normal state, not an error"

    It is what every client answers between resource start and the first accepted snapshot,
    and what one answers again during a server restart. Do not log it as a fault and do not
    retry it in a tight loop — poll on a sensible interval, or listen for
    [`opx77:weather:updated`](events.md#opx77-weather-updated), which the client raises with
    the whole projection after every accepted snapshot and which crosses resources on the
    client.

!!! warning "This is a hint about the sky, not proof of anything"

    The value is read on the player's machine, from a projection that resource on that machine
    can influence — the client event bus is host-wide, so another resource can raise
    `opx77:weather:sync` locally. If your rule needs to be enforced (a job that only pays in
    the rain, a vehicle that handles differently in fog), decide it on the server against the
    authority's own state, and use `getState` only to draw what the player sees.

### Example {#getstate-example}

```lua
-- client/main.lua of your own resource
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_weather", "getState")
  if not promise then return Open77.log.warn("not dispatched: " .. tostring(reason)) end

  local state, callError = promise:await()
  if callError then return Open77.log.warn("call failed: " .. tostring(callError)) end

  if not state.ok then
    -- "not_synchronized" before the first snapshot, "environment_unavailable" with no natives
    return Open77.log.info("weather unavailable: " .. tostring(state.error))
  end

  Open77.log.info(("%02d:%02d — %s"):format(state.hour, state.minute, state.weather))
end)
```

Prefer the event when you want to react to a change rather than sample one:

```lua
AddEventHandler("opx77:weather:updated", function(projection)
  if projection.weather == "rain" then raiseTheUmbrella() end
end)
```

## What the official package publishes that this one does not {#official-differences}

The platform's own `open77_weather` package publishes three exports: `isReady`, `requestSync`
and `getState`. `opx77_weather` publishes only the last of them, and the shape of its answer is
this resource's own — the two are not interchangeable, and `Open77.exports.call` is
resource-scoped, so no caller can reach one while naming the other.

| Official export | Here |
|---|---|
| `isReady()` | Read `ok` on `getState`. `ok == false` with `not_synchronized` is exactly "not ready yet". |
| `requestSync()` | Not published. The client already requests a snapshot at start and every 15 s, and the authority broadcasts a heartbeat every 5 s; a resource that forced an extra request could only add load to a channel that is already floored at one request per player per second. |
| `getState()` | [`getState`](#getstate), with the fields above. |

## See also {#see-also}

- [Events](events.md) — `opx77:weather:updated`, and the two wire events behind the projection.
- [Commands](commands.md) — the only way to move the authority.
- [Overview](index.md#authority-model) — how a snapshot becomes the value this export answers.
