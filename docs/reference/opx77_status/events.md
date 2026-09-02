---
title: opx77_status events
description: The two local events opx77_status raises back to an effect's owner when it is removed or expires, the payload they carry, and the opx77:status:effects payload opx77_hud draws.
---

# Events

Every event on this page is **non-networked**. It is raised with `TriggerEvent`
on the client's local bus and received with a bare `AddEventHandler`, and none of
it needs a permission.

## Networked {#networked}

There are none. `opx77_status` registers no net event, sends no
`TriggerServerEvent`, and has no server half to send anything back. Its manifest's
`permissions {}` block is empty for exactly this reason.

## Non-networked (the client local bus) {#non-networked}

The client's local event bus is **host-wide**: a `TriggerEvent` in one client
resource reaches a plain `AddEventHandler` in another. See
[The client export contract](../../concepts/export-contract.md#local-bus).

!!! warning "Do not name your per-effect event after a wire name"
    A `TriggerEvent` also reaches every `RegisterNetEvent` handler of the same
    name — the dispatcher matches on the name and ignores the network flag. Giving
    an effect an `event` that collides with a networked name you already handle
    will fire that handler with a status payload it does not expect.

### opx77:status {#opx77-status}

Fires whenever an effect is removed or expires, for **every** owner on the strip,
so one listener can watch them all; it carries the effect's bare id, not a chip
id.

```lua
AddEventHandler("opx77:status", function(payload) end)
```

- payload: `table`
    - `status`: `string` — the effect id you passed to
      [`add`](exports.md#add), **unprefixed**.
    - `owner`: `string` — the resource that added it.
    - `action`: `string` — `"removed"` or `"expired"`.
    - `label`: `string` — the cleaned label it had.
    - `tone`: `string | nil` — the tone it had.
    - `data`: `table | nil` — your opaque table, echoed back.

| `action` | Raised when |
|---|---|
| `removed` | The owner called [`remove`](exports.md#remove) for it. |
| `expired` | Its `durationMs` elapsed and the 250 ms sweep took it down. |

**Nothing else raises.** [`add`](exports.md#add), [`update`](exports.md#update),
[`clear`](exports.md#clear), a stopped owner and a reloaded owner are all silent
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
characters, or the [`add`](exports.md#add) call is refused with `invalid_event`.

The reason this channel exists at all is that **an export cannot answer a
callback** on this platform. When an effect goes away for a reason its owner did
not ask for, an event is the only way to say so. See
[Integration channels](../../concepts/integration-channels.md#local-events).

#### Example {#spec-event-example}

```lua
-- a client script in your own resource
CreateThread(function()
  Open77.exports.call("opx77_status", "add", {
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
