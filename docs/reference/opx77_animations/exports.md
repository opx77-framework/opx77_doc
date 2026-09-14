---
title: opx77_animations exports
description: The eight client exports of opx77_animations — play, stop, state, list, categories, get, openPicker and closePicker — with their parameters, answers, error codes, and which of them answer only that the work was asked for.
---

# Exports

Eight exports, all **client-side**, because that is the only side exports exist
on: the OPEN//77 server runtime installs none. A server resource that wants a
player to play an animation sends a net event to its own client half, and that
half calls these. [The client export contract](../../concepts/export-contract.md)
covers the call shape and its three levels of failure.

Every call answers a table carrying `ok` and never raises. `error` is a stable
`snake_case` code meant for branching; every code is listed under
[`AnimationError`](types.md#animationerror).

!!! info "Called from another resource, always"

    Every export reads the caller from `GetInvokingResource()` and
    `GetInvokingResourceGeneration()`, never from an argument, and refuses
    `export_call_required` when there is none — or when the name is longer than
    64 bytes or carries anything but letters, digits, `_`, `-` and `.`. A raise
    inside an export is caught, logged as
    `export <name> raised for <resource>: <error>`, and answered as
    `internal_error`.

!!! warning "`play` and `stop` answer *asked*, not *done*"

    `ok = true` with a `requestId` means the request went to this resource's
    server half. The verdict arrives later, on the local event
    [`opx77:animations:result`](events.md#result), carrying the same
    `requestId`. A refused export request raises **no toast**: the caller
    decides what, if anything, the player is shown.

## play {#play}

Asks for an animation to be played on the local player, answering that it was
asked, or `ok = false` with the reason it was not sent.

```lua
Open77.exports.call("opx77_animations", "play", name, options)
```

- name: `string`
    - A catalogue name, without case: `"dance"`, `"smoke"`. See
      [The catalogue](index.md#catalogue).
- options?: [`AnimationOptions`](types.md#animationoptions)
    - `variant` (1-based) or `clip` — `variant` wins when both are given, and
      both default to the first offered variant.
    - `loop` — `true` or `false`. Absent takes
      [`LOOP_BY_DEFAULT`](config.md#loop-by-default).
    - `durationMs` — an integer from 1000 to
      [`MAX_DURATION_MS`](config.md#max-duration-ms). A playback that does not
      loop and names none plays [`ONE_SHOT_MS`](config.md#one-shot-ms).

**Returns** an [`AnimationRequest`](types.md#animationrequest) — on `ok = true`,
`queued = true`, the `requestId` to match on
[`opx77:animations:result`](events.md#result), the resolved `animation` name, and
`variant` when one was named. The server picks the first offered variant when
none was.

The client checks what it can before anything leaves it: the name against the
offer the server last sent — or the catalogue less `DISABLED` until it has sent
one — the variant against the offered set, and the options against the same
bounds the server applies. Everything else is decided by the server and the
service, and arrives on the event.

**Errors, answered here**
| Code | Meaning |
|---|---|
| `export_call_required` | No invoking resource. |
| `internal_error` | The export raised; the log names it. |
| `unknown_animation` | Not in the catalogue, disabled, or not offered on this build. |
| `invalid_variant` | No such variant, the `clip` is none of this animation's, or the variant is not offered on this build. |
| `invalid_options` | `options` is not a table, `loop` is not a boolean, or `durationMs` is outside 1000 to `MAX_DURATION_MS`. |
| `not_sent` | The net event was not accepted. The log says `play request not sent: <reason>`. |

**Errors, on the event** — `service_unavailable`, `rate_limited`,
`player_not_ready`, `play_raised`, `play_refused`, `request_timeout`, and the
service's own `player_not_alive`, `player_in_vehicle`, `animation_owned`. See
[`AnimationError`](types.md#animationerror).

An animation started here is **owned** by the calling resource: when it stops,
the animation is stopped with it. See [Ownership](index.md#ownership).

**Side** `client export` — callable from any resource on the player's machine,
asynchronous, arguments and answer pass through the runtime's codec.

### Example {#play-example}

```lua
-- in a client script of your own resource
local pending = {}

AddEventHandler("opx77:animations:result", function(result)
  if type(result) ~= "table" or not pending[result.requestId] then return end
  pending[result.requestId] = nil
  if not result.ok then
    Open77.log.info("animation refused: " .. tostring(result.error))
  end
end)

CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_animations", "play", "handsup",
    { variant = 2 })
  if not promise then return Open77.log.warn("not dispatched: " .. tostring(reason)) end
  local answer, callError = promise:await()
  if callError then return Open77.log.warn("call failed: " .. tostring(callError)) end
  if not answer.ok then return Open77.log.info("refused: " .. tostring(answer.error)) end
  pending[answer.requestId] = true
end)
```

`requestId` is a per-client serial, not a global one, and the verdict event is
host-wide: check it is a request **you** made before acting on it.

## stop {#stop}

Asks for the local player's animation to end, whichever resource — or command, or
picker row — started it.

```lua
Open77.exports.call("opx77_animations", "stop")
```

**Returns** an [`AnimationRequest`](types.md#animationrequest) — `queued = true`
and a `requestId` when the request went to the server.

Two things happen. A playback a client resource started is released at once over
the service's own wire and stops being posed on this client; and a stop request
goes to this resource's server half, which calls `Open77.animations.stop` on the
player. Nothing playing is not a failure: the verdict is `ok = true`.

If the net event is refused but a playback was released locally, the answer is
`ok = true, queued = false` with no `requestId`, and no verdict event follows.

**Errors, answered here**
| Code | Meaning |
|---|---|
| `export_call_required` | No invoking resource. |
| `internal_error` | The export raised. |
| `not_sent` | The net event was not accepted and there was nothing to release locally. |

**Errors, on the event** — `service_unavailable`, `rate_limited` (stop requests
get twice [`RATE_LIMIT.REQUESTS`](config.md#rate-limit)), `stop_raised`,
`request_timeout`, or a code the service refused with explicitly.

**Side** `client export`.

## state {#state}

Answers what a player is playing, as the service last replicated it to this
client: the local player by default, or any player in this client's bucket.

```lua
Open77.exports.call("opx77_animations", "state", playerId)
```

- playerId?: `integer`
    - Default: the local player

**Returns** an [`AnimationStateResponse`](types.md#animationstateresponse) —
`active`, and while active the `playbackId`, the `animation` profile, the `clip`,
the `variant` when the clip is one of this catalogue's, `known`, `step`, `steps`
and `cycle` — plus `presenting`, whether this client is the one posing bodies.

A player the mirror holds nothing for is answered `active = false`, and so is the
local player before this client is in a ready world, when there is no local id
to answer with. `animation` can be a profile this catalogue does not carry —
another resource may have asked the service for it — in which case `known` is
`false` and `variant` is `nil`.

**Errors**
| Code | Meaning |
|---|---|
| `export_call_required` | No invoking resource. |
| `internal_error` | The export raised. |
| `invalid_player` | `playerId` is not a whole number from 1 upward. |
| `presentation_unavailable` | This client has no presentation natives, so there is no mirror to read. |

**Side** `client export`.

## list {#list}

Answers every animation this player may ask for, in picker order, optionally in
one category.

```lua
Open77.exports.call("opx77_animations", "list", category)
```

- category?: `string`
    - One of `gestures`, `social`, `emotions`, `relaxation`, `consumables`,
      `interactions`, without case.
    - Default: every category

**Returns** an [`AnimationListResponse`](types.md#animationlistresponse) —
`animations`, an array of [`AnimationListing`](types.md#animationlisting): the
`name`, its `label` and `categoryLabel` in the configured locale, `prop`,
`placement`, and only the **offered** `variants`, each with its number, engine
clip and the words the picker shows beside it.

**Errors**
| Code | Meaning |
|---|---|
| `export_call_required` | No invoking resource. |
| `internal_error` | The export raised. |
| `unknown_category` | Not one of the six categories. |

**Side** `client export`.

## categories {#categories}

Answers the six categories in picker order, each with its label and how many
animations it offers.

```lua
Open77.exports.call("opx77_animations", "categories")
```

**Returns** an
[`AnimationCategoriesResponse`](types.md#animationcategoriesresponse) —
`categories`, an array of `{ name, label, count }`. A category with nothing
offered is still listed, with `count = 0`; the picker is what leaves it out.

**Errors** — `export_call_required`, `internal_error`.

**Side** `client export`.

## get {#get}

Answers one animation and its offered variants.

```lua
Open77.exports.call("opx77_animations", "get", name)
```

- name: `string`
    - A catalogue name, without case.

**Returns** an [`AnimationGetResponse`](types.md#animationgetresponse) —
`animation`, one [`AnimationListing`](types.md#animationlisting).

**Errors**
| Code | Meaning |
|---|---|
| `export_call_required` | No invoking resource. |
| `internal_error` | The export raised. |
| `unknown_animation` | Not in the catalogue, disabled, or not offered on this build. |

**Side** `client export`.

## openPicker {#openpicker}

Asks [`opx77_menu`](../opx77_menu/index.md) to put the picker up, standing on one
category's row when one is named.

```lua
Open77.exports.call("opx77_animations", "openPicker", category)
```

- category?: `string`
    - Where the cursor starts. Advisory: a category with nothing offered is not
      drawn, and the menu falls back to the first selectable row.

**Returns** an [`AnimationRequest`](types.md#animationrequest) — `ok = true,
queued = true`. The menu is called on a thread, so the picker appears a moment
later. A refusal from the menu after that is logged as
`picker did not open: <reason>`, and `menu_busy` additionally shows the player
*Another menu is open. Close it first.*

The picker is the whole tree, built from what is offered at the moment of the
call: a **Stop** row, then one submenu per non-empty category, then one row per
animation. An animation with one variant is a row that plays it; one with more is
a submenu of **Variant n** rows. It is well under `opx77_menu`'s 400-node
ceiling.

**Errors**
| Code | Meaning |
|---|---|
| `export_call_required` | No invoking resource. |
| `internal_error` | The export raised. |
| `menu_not_running` | `opx77_menu` is not running. Said once per session in the log: `opx77_menu is not running: no picker, the commands and exports still work`. |
| `unknown_category` | Not one of the six categories. |

**Side** `client export`.

## closePicker {#closepicker}

Closes the picker, when this resource has one open.

```lua
Open77.exports.call("opx77_animations", "closePicker")
```

**Returns** an [`AnimationRequest`](types.md#animationrequest) — `ok = true,
queued = true`. It closes only the picker this resource opened, by the handle
`opx77_menu` gave it; a caller cannot close another resource's menu through it.

**Errors**
| Code | Meaning |
|---|---|
| `export_call_required` | No invoking resource. |
| `internal_error` | The export raised. |
| `picker_not_open` | No picker of this resource's is on screen. |

**Side** `client export`.

## See also {#see-also}

- [Events](events.md#result) — where the verdict on `play` and `stop` arrives.
- [Types](types.md) — every shape above, and every error code.
- [Commands](commands.md) — the same requests, typed by a player.
