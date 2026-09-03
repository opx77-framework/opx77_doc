---
title: opx77_status events
description: Every event opx77_status sends and receives — the two local events raised back to an effect's owner, the opx77:status:effects and opx77:status:needs payloads opx77_hud draws, and the four net events that carry a character's needs between the two halves.
---

# Events

There are two kinds here, and the split matters.

The **local** events are the resource's public output: an effect being removed or
expiring, the strip to draw, the needs to draw. They are raised with
`TriggerEvent` on the client's host-wide bus, received with a bare
`AddEventHandler`, and none of them needs a permission. If you are integrating
with `opx77_status`, these are the names you want.

The **networked** events are its two halves talking to each other about where a
character's needs are stored. They are listed here because a name on the wire is
part of a resource's surface whether it is meant to be called or not, but you
should have no reason to raise one.

## The path a character's needs take {#needs-path}

```text
opx77:client:onPlayerLoaded              (or, on a start mid-session,
      │                                   opx77_core's GetPlayerData export)
      ▼
client takes citizenId, values sit at the config defaults, ready = false
      │
      │──TriggerServerEvent("opx77_status:pull", citizenId)──►  server half
      │                                                              │
      │                                                     SELECT needs FROM
      │                                                  opx77_character_status
      │                                                    (or the defaults)
      │  ◄──TriggerClientEvent("opx77_status:values", id, values)────┘
      ▼
ready = true, and opx77:status:needs fires with source = "loaded"
      │
      │  from here the CLIENT owns the values:
      │    · hunger and thirst decay every DECAY_MS          → source "decay"
      │    · setNeeds / addNeeds move them                   → source "set"/"add"
      ▼
      │──TriggerServerEvent("opx77_status:push", id, values)──►  server half
      │    every PUSH_MS, or at once when a need moved                │
      │    PUSH_DELTA                                          held in memory,
      │                                                        marked dirty
      │  ◄──TriggerClientEvent("opx77_status:pushed", id)────────────┘
      ▼
the drift the push carried is settled; until this arrives it is still counted,
so a push the server dropped is simply sent again

server writes the held row on onPlayerDisconnected, every AUTOSAVE_MS, on its
own onResourceStop, and when a second character takes the same player slot —
never on the push itself
```

The last of those is there because **nothing announces a character being put
down**: on a character swap the server writes the outgoing character's last push
before the record holding it is replaced, or that push would be dropped with the
record.

`opx77:client:onPlayerUnloaded` ends it: the client forgets everything and fires
[`opx77:status:needs`](#status-needs) once with `source = "unloaded"`.

!!! warning "The disconnect is the one moment the client cannot speak"
    Nothing is sent from the client at disconnect, so what gets saved is the last
    push it managed during play. That is the whole reason
    [`PUSH_DELTA`](config.md#push-delta) exists: it makes a large move — a meal, a
    payout — reach the server immediately rather than waiting out
    [`PUSH_MS`](config.md#push-ms).

## Networked {#networked}

Four, all of them internal to this resource, and all of them the reason its
manifest declares `network.events`. Two travel client to server, two travel back.

| Event | Direction | Carries |
|---|---|---|
| [`opx77_status:pull`](#net-pull) | client → server | `citizenId` |
| [`opx77_status:values`](#net-values) | server → client | `citizenId`, `values` |
| [`opx77_status:push`](#net-push) | client → server | `citizenId`, `values` |
| [`opx77_status:pushed`](#net-pushed) | server → client | `citizenId` |

!!! danger "The citizen id and the values are taken at face value"
    The server half checks the *shape* of an id — one to sixteen characters of
    upper-case letters, digits and `-` — and clamps every value into the bounds in
    [`config.lua`](config.md#needs) before it reaches a column. It does **not**
    check that the connection sending the id owns that character, and it does not
    re-derive the values from anything. A client that lies is believed. This is
    the project owner's ruling, stated in the resource's README in the same terms,
    and not a gap to be worked around by a third-party resource raising these
    names itself.

### opx77_status:pull {#net-pull}

The client naming the character it wants values for. Raised once when a character
loads, and again every 10 seconds for as long as the server has not answered.

```lua
TriggerServerEvent("opx77_status:pull", citizenId)
```

The server answers [`opx77_status:values`](#net-values), or **says nothing at
all**. It stays silent when the id is not shaped like one, when the `CREATE TABLE`
at boot did not succeed, when the read failed, or when this player has already
sent four pulls in the last ten seconds. There is no refusal payload; the client's
retry is what covers every one of those cases.

### opx77_status:values {#net-values}

The stored row, or the [configured defaults](config.md#needs) when the character
has none yet.

```lua
-- server → this resource's client half
TriggerClientEvent("opx77_status:values", player, citizenId, values)
```

An answer whose `citizenId` is not the one the client is currently waiting on is
dropped, which is what makes a late reply for a character that has already been
swapped out harmless. Anything the payload leaves out, or gets wrong, falls back
to that need's `DEFAULT`.

### opx77_status:push {#net-push}

The client handing its values back. Sent every [`PUSH_MS`](config.md#push-ms), at
once when any need has moved [`PUSH_DELTA`](config.md#push-delta) since the last
acknowledged push, and forced when this resource stops.

```lua
TriggerServerEvent("opx77_status:push", citizenId, values)
```

**Nothing is written to the database here.** The server bounds the values, holds
them in memory as this player's last push, marks them dirty, and answers
[`opx77_status:pushed`](#net-pushed). The writes happen elsewhere — see
[the path above](#needs-path).

A push is dropped in silence when the id is malformed, when the payload is not a
table, when **not one** of the configured needs came through as a usable number,
or when this player has already sent twelve pushes in the last ten seconds.

### opx77_status:pushed {#net-pushed}

The acknowledgement, and the only thing that settles a push.

```lua
-- server → this resource's client half
TriggerClientEvent("opx77_status:pushed", player, citizenId)
```

Until it arrives the client still counts the drift that push carried, so a push
the server dropped for any of the reasons above is sent again on the next tick
rather than being lost. `TriggerServerEvent` answering `true` only says the event
left the client.

!!! info "The acknowledgement names no push, so the client counts them"
    The payload carries the citizen id and nothing that identifies *which* push
    it answers. The client therefore indexes every push it sends and settles the
    **nth** acknowledgement against the **nth** push, never against a later one.
    Two pushes in flight at once is easy to produce —
    [`addNeeds`](exports.md#addneeds) re-pushes while the drift is still measured
    against the value before it — and without the counting the first ack would
    promote the second push's snapshot. If that second push were then dropped by
    the rate limit, which sends no acknowledgement and logs nothing, the client
    would believe a value was stored that never was.

    A push held too long for an acknowledgement that never comes is forgotten
    without moving the settled snapshot, so the drift it carried is sent again.
    The failure mode is a redundant push, never a lost value.

## Non-networked (the client local bus) {#non-networked}

The client's local event bus is **host-wide**: a `TriggerEvent` in one client
resource reaches a plain `AddEventHandler` in another. See
[The client export contract](../../concepts/export-contract.md#local-bus).

Three fixed names, plus whichever one you choose per effect:

| Event | Raised when |
|---|---|
| [`opx77:status`](#opx77-status) | one effect was removed or expired |
| [your own `spec.event`](#spec-event) | the same, for one effect only |
| [`opx77:status:effects`](#status-effects) | the strip changed |
| [`opx77:status:needs`](#status-needs) | a need moved |

!!! warning "Do not name your per-effect event after a wire name"
    A `TriggerEvent` also reaches every `RegisterNetEvent` handler of the same
    name — the dispatcher matches on the name and ignores the network flag. Giving
    an effect an `event` that collides with a networked name you already handle
    will fire that handler with a status payload it does not expect. This resource
    now has [four wire names](#networked) of its own, so that is no longer a purely
    hypothetical collision.

### opx77:status {#opx77-status}

Fires whenever an effect is removed or expires, for **every** owner on the strip,
so one listener can watch them all; it carries the effect's bare id, not a chip
id.

```lua
AddEventHandler("opx77:status", function(payload) end)
```

- payload: `table`
    - `status`: `string` — the effect id you passed to
      [`addEffect`](exports.md#addeffect), **unprefixed**.
    - `owner`: `string` — the resource that added it.
    - `action`: `string` — `"removed"` or `"expired"`.
    - `label`: `string` — the cleaned label it had.
    - `tone`: `string | nil` — the tone it had.
    - `data`: `table | nil` — your opaque table, echoed back.

| `action` | Raised when |
|---|---|
| `removed` | The owner called [`removeEffect`](exports.md#removeeffect) for it. |
| `expired` | Its `durationMs` elapsed and the 250 ms sweep took it down. |

**Nothing else raises.** [`addEffect`](exports.md#addeffect), [`updateEffect`](exports.md#updateeffect),
[`clearEffects`](exports.md#cleareffects), a stopped owner and a reloaded owner are all silent
— see [the sweep](exports.md#sweep).

!!! warning "This fires for other resources' effects too"
    `opx77:status` is global. The payload carries `owner` precisely so you can
    tell yours apart, and a listener that does not filter on it will act on
    somebody else's chip. Giving each effect its own
    [`event`](#spec-event) avoids the question entirely.

#### Example {#opx77-status-example}

```lua
-- a client script in your own resource
AddEventHandler("opx77:status", function(payload)
  if payload.owner ~= GetCurrentResourceName() then return end
  if payload.action == "expired" and payload.status == "bleeding" then
    -- the timer ran out on its own; stop the bleed
  end
end)
```

### Your own `spec.event` {#spec-event}

Fires for one effect only, with exactly the same payload as
[`opx77:status`](#opx77-status), when you gave that effect an `event` name; it
fires once, not twice, when the name you chose is `opx77:status` itself.

```lua
AddEventHandler("myresource:status", function(payload) end)
```

- payload: `table` — identical to [`opx77:status`](#opx77-status)'s, including
  `owner` and `action`.

The name is validated on the way in: same character rules as an id, up to 96
characters, or the [`addEffect`](exports.md#addeffect) call is refused with `invalid_event`.

The reason this channel exists at all is that **an export cannot answer a
callback** on this platform. When an effect goes away for a reason its owner did
not ask for, an event is the only way to say so. See
[Integration channels](../../concepts/integration-channels.md#local-events).

#### Example {#spec-event-example}

```lua
-- a client script in your own resource
CreateThread(function()
  Open77.exports.call("opx77_status", "addEffect", {
    id = "overdose",
    label = "Overdose",
    tone = "chem",
    durationMs = 20000,
    event = "myresource:status",
    data = { drug = "maxdoc" },
  })
end)

AddEventHandler("myresource:status", function(payload)
  if payload.action ~= "expired" then return end
  -- payload.data.drug is the table you handed to add
end)
```

### opx77:status:effects {#status-effects}

Published by this resource whenever the picture changes, carrying the whole strip
and where it should sit; [`opx77_hud`](../opx77_hud/index.md) is its intended
consumer, and it is republished only when something that is not a countdown moves.

```lua
AddEventHandler("opx77:status:effects", function(payload) end)
```

- payload: `table`
    - `anchor`: `string` — [`OPX_STATUS_CONFIG.ANCHOR`](config.md#anchor), passed
      straight through so the consumer never reads this resource's config.
    - `offset`: `integer` — [`OPX_STATUS_CONFIG.OFFSET`](config.md#offset).
    - `chips`: `table[]` — already ordered and already cut to
      [`MAX_VISIBLE`](config.md#max-visible). Each entry is a
      [published chip](effect-spec.md#published-chip).
    - `hidden`: `integer` — how many effects were left out of the cut.

The change signature covers the chips' ids, labels, icons, tones, `progress` and
`totalMs`, plus `hidden`. `remainingMs` is deliberately **not** in it: a countdown
ticking down is not a new picture, and the page animates it on its own clock.

!!! warning "A consumer must treat this as untrusted"
    The local bus is host-wide, so any client resource on the machine can raise
    this name. `opx77_hud` keeps at most 12 chips from one payload, drops any chip
    without an `id`, and coerces `hidden` to a number. Write the same defences if
    you consume it yourself.

Stopping `opx77_status` publishes one final, **forced**, empty payload on this
name. The chips live in another resource's page and nothing there knows this
resource stopped, so without that last publish they would stay on screen for the
rest of the session.

### opx77:status:needs {#status-needs}

Published whenever a need moves, and once on each end of a character's life. This
is how a consumer keeps a gauge current: [`opx77_hud`](../opx77_hud/index.md)
reads the [`getNeeds`](exports.md#getneeds) export once at boot and redraws from this
event thereafter, and never polls.

```lua
AddEventHandler("opx77:status:needs", function(payload) end)
```

- payload: `table`
    - `values`: `table` — every key of
      [`OPX_STATUS_CONFIG.NEEDS`](config.md#needs) with its current number. A
      fresh copy each time, and **empty** on `"unloaded"`.
    - `changed`: `string[]` — only the keys whose value actually moved, sorted.
      Empty on `"unloaded"`; every key on `"loaded"`.
    - `source`: `string` — why it fired, one of the five below.
    - `citizenId`: `string | nil` — the character the values belong to, `nil` on
      `"unloaded"`.
    - `ready`: `boolean` — whether the server half has answered for this
      character. `false` only on `"unloaded"`.

| `source` | Raised when |
|---|---|
| `loaded` | [`opx77_status:values`](#net-values) arrived and the client adopted it. The first event of a character's life. |
| `decay` | The decay pass moved at least one need. |
| `set` | [`setNeeds`](exports.md#setneeds) moved at least one need. |
| `add` | [`addNeeds`](exports.md#addneeds) moved at least one need. |
| `unloaded` | `opx77:client:onPlayerUnloaded` fired. The last event of a character's life. |

**Nothing else raises it.** A write that changes no value — setting a need to what
it already was, or adding to one already at its ceiling — publishes nothing, which
is why [`setNeeds`](exports.md#setneeds) answers `changed` as well as `ok`.

!!! warning "The name is a config key, and the consumer hard-codes it"
    This event's name is [`OPX_STATUS_CONFIG.NEEDS_EVENT`](config.md#needs-event),
    and `opx77_hud` has the literal `"opx77:status:needs"` in its own client code —
    a satellite cannot read another resource's config. Changing the key therefore
    stops the HUD's gauges updating, in silence and with nothing logged at either
    end. There is no reason to change it.

!!! warning "Nothing is raised when this resource stops"
    The strip gets a [final, forced, empty payload](#status-effects); the needs get
    no farewell at all. A consumer that wants to blank its gauges has to watch
    `onClientResourceStop` for `opx77_status` itself, which is what the HUD does.

#### Example {#status-needs-example}

```lua
-- a client script in your own resource
AddEventHandler("opx77:status:needs", function(payload)
  if not payload.ready then
    -- no character, or the server half has not answered yet: show nothing
    return
  end
  for _, key in ipairs(payload.changed) do
    if key == "thirst" and payload.values.thirst < 20 then
      -- warn the player once; `changed` means this really moved
    end
  end
end)
```
