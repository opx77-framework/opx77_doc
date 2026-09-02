---
title: opx77_elevators events
description: Every event opx77_elevators sends, receives or raises — the five net events between its two halves, the local answer channel, the menu return channel, and the platform events both halves listen to.
---

# Events

This resource's two halves talk over five net events, and the client half raises
one local event of its own after every decision. Everything else it listens to
belongs to somebody else — `opx77_core`, `opx77_menu`, or the host.

The distinction decides which registration call you write, so it is the top-level
split on this page:

- **Networked** — crosses the wire. Register with `RegisterNetEvent`. Requires
  `network.events`, which this resource declares.
- **Non-networked** — never leaves the machine it is on. Register with a bare
  `AddEventHandler`.

!!! warning "On the client, both kinds arrive on one bus"

    The client's local event bus is **host-wide**: any resource on the player's
    machine can `TriggerEvent` any name, and a local `TriggerEvent` also reaches
    `RegisterNetEvent` handlers of the same name. So every client-side handler
    on this page can be reached by a peer resource as well as by the server, and
    nothing here is a trust boundary. The server re-derives every clause of a
    request regardless — see
    [What the server does prove](index.md#what-the-server-proves).

    The same fact has a sharper edge: **never re-emit a wire name inside its own
    handler.** A `TriggerEvent` of the name you are handling reaches your own
    handler again, tick-paced, and the loop is silent and permanent.

## Networked {#networked}

### opx77_elevators:sighted {#sighted}

Sent by the client when it sees a native lift that matches a configured position
and that nobody has adopted yet; the server answers by adopting the lift, or
answers nothing at all.

!!! danger "Six arguments, and the count is the contract"

    The client sends exactly six and the server declares exactly six. When they
    disagreed — the client sent a leading `key` the server did not declare — the
    configured key landed in the `entity` slot, failed the hex-hash guard and
    returned silently. No lift was ever adopted and every `use` answered
    `not_adopted`, with no error anywhere. The server now logs that mismatch
    once, on the first rejected sighting.

```lua
-- server/main.lua
RegisterNetEvent("opx77_elevators:sighted", function(entity, x, y, z, floorCount, activeFloor)
end)
```

- entity: `string`
    - The native `LiftDevice` hash, as `"0x"` and exactly sixteen hex digits.
      Rejected outright in any other shape; engine identifiers are opaque and
      never survive `tonumber`.
- x: `number`
- y: `number`
- z: `number`
    - The lift's replicated position. Each must be finite and within 1 000 000 of
      the origin.
- floorCount: `integer`
    - The native device's floor count, 1 to 1025.
- activeFloor: `integer`
    - The floor the cabin is on, 0 to `floorCount - 1`.

**What the server does with it.** It believes the shape and nothing else.
Discovery only proposes immutable topology: the server picks the elevator, the
bucket and the floor count itself. It checks the reporter is within
`SCAN_RADIUS` of the position it claims to see — the one distance here still
measured in three dimensions — matches the position against `config.lua` within
`MATCH_RADIUS` across the ground, requires the reporter to be in the
**elevator's** bucket, and prefers the elevator's declared `FLOOR_COUNT` over the
reported one — logging the mismatch once per elevator. Rate-limited to twelve
sightings per second per player.

**Answers with** [`opx77_elevators:bound`](#bound), to that one player, whether
the lift was adopted just now or was already owned. A rejected sighting is
answered with silence.

**Side** `net event` — sent by this resource's client half only. Any resource
holding `network.events` can send it; everything above is why that is not worth
doing.

### opx77_elevators:request {#request}

Sent by the client to ask for a floor, and answered by the server with
[`opx77_elevators:answer`](#answer) — except when the refusal is
`rate_limited`, which is answered with nothing.

```lua
-- server/main.lua
RegisterNetEvent("opx77_elevators:request", function(key, index)
end)
```

- key: `ElevatorKey`
    - The `config.lua` key. Not the Open77 id, which changes every restart.
- index: `FloorIndex`
    - The **native** floor index, 0-based.

**What the server does with it.** Everything listed in
[What the server does prove](index.md#what-the-server-proves), from its own
authority: the key, the floor, the adoption, the native floor count, the
replicated position, the bucket, the distance to the **declared** shaft across
the ground, and the rate limit. Not the job — it has no way to ask.

**Side** `net event` — sent by this resource's client half only, from `use` and
from the built-in panel.

### opx77_elevators:bound {#bound}

Sent by the server to one player to tell them the Open77 id of an elevator this
resource has adopted, so that player's `use` has something to press.

```lua
-- client/main.lua
RegisterNetEvent("opx77_elevators:bound", function(key, id, floorCount)
end)
```

- key: `ElevatorKey`
    - Discarded unless it names an entry of this client's `config.lua`.
- id: `integer`
    - The Open77 elevator id. Assigned at adoption, and different after every
      restart.
- floorCount: `integer`
    - The floor count the server settled on, between the config's declaration and
      the host's own count.

!!! warning "The id is not a name, and `floorCount` is not the client's ceiling"

    Store the `key`; the `id` is a runtime handle that changes on every restart.
    The client records `floorCount` and reads nothing from it — its own floor
    list comes from `config.lua`'s `FLOORS`, and the real ceiling is enforced on
    the server against `Open77.elevators.get(id).floorCount`.

**Side** `net event` — sent by this resource's server half only.

### opx77_elevators:answer {#answer}

Sent by the server after a floor request it did not silently drop, carrying its
own verdict; the client republishes it on
[`opx77:elevators`](#opx77-elevators) with `source = "server"`.

```lua
-- client/main.lua
RegisterNetEvent("opx77_elevators:answer", function(key, index, ok, failure)
end)
```

- key: `string`
    - The key the client sent, echoed back after control characters are stripped
      and the string is truncated to 64 characters — it reaches a format string,
      where a newline would forge a whole log line.
- index: `integer|nil`
    - The index the client sent, echoed back as an integer. `nil` when the client
      sent something that is not one.
- ok: `boolean`
    - `true` means the server accepted the request and the cabin was told to
      move.
- failure: `string|nil`
    - The [error code](errors.md), on a refusal.

!!! warning "No answer is also an answer"

    A `rate_limited` request is answered with nothing at all, and so is a request
    whose `source` did not resolve. A caller waiting on this event, or on the
    channel it feeds, must tolerate never receiving one.

**Side** `net event` — sent by this resource's server half only.

### opx77_elevators:released {#released}

Sent by the server to every player it had handed an id for, when an adoption
ends — the host removed the lift, or the unused-adoption sweep gave it back.

```lua
-- client/main.lua
RegisterNetEvent("opx77_elevators:released", function(key)
end)
```

- key: `ElevatorKey`

The client drops its binding, so the next scan re-reports the lift rather than
sending requests for an id nobody owns. Until a new
[`opx77_elevators:bound`](#bound) arrives, `use` answers `not_adopted`.

**Side** `net event` — sent by this resource's server half only.

### open77:command:result {#command-result}

Sent by the server to echo one line of the diagnostic command's output back to
the player who typed it; this resource sends it and does not listen for it.

```lua
-- a client script of your own resource
RegisterNetEvent("open77:command:result", function(raw, accepted, message)
end)
```

- raw: `string`
    - The raw command line, as the host handed it to the command handler.
- accepted: `boolean`
    - Always `true` from this resource: it only sends output lines, never
      refusals. The host sends its own refusal when the ACL check fails.
- message: `string`
    - One line of the report.

This is the platform's own console channel, which every resource on the server
already speaks. See [Commands](commands.md) for what the lines say.

**Side** `net event` — sent by this resource's server half; received by whatever
draws the player's console, normally [`opx77_chat`](../opx77_chat/index.md).

## Non-networked {#non-networked}

### opx77:elevators {#opx77-elevators}

Raised on the client after **every** decision this resource makes, local or
remote; it is the channel a caller listens on, and the name is
`OPX_ELEVATORS_CONFIG.EVENT` rather than a literal.

```lua
-- a client script of your own resource
AddEventHandler("opx77:elevators", function(payload)
end)
```

- payload: `table`
    - `elevator`, `floor`, `ok`, `error`, `label`, `reason`, `source`, `queued` —
      the same shape a [`FloorDecision`](types.md#floordecision) carries.

`source` tells you whose press this was: the **invoking resource's own name** for
a press made through the [`use`](exports.md#use) export, `"panel"` for one made
in the built-in floor list, and `"server"` for the verdict itself.

**What is published, and when.** A local refusal — the gate, `not_adopted`,
`not_sent` — is published immediately, before anything leaves the client. A press
that passes locally publishes **nothing** at that moment; the next event about it
is the server's verdict, with `source = "server"`. So a successful press produces
exactly one event, and a locally refused one also produces exactly one.

!!! warning "The event name is not a trust boundary"

    The client's local bus is host-wide, so any resource on the player's machine
    can raise `opx77:elevators` with any payload it likes. Treat what arrives as
    a notification, never as authority. This resource's own panel guards against
    exactly that: it acts on the channel only for a list it opened itself, and
    only once, because a thread per message would drain the client's task budget.

**Side** `client local event` — raised in this resource's client VM, heard by
every client resource on the machine.

### opx77_elevators:floor {#floor}

Raised by [`opx77_menu`](../opx77_menu/index.md) when a row of the built-in floor
list is selected; this resource listens for it and turns the selection into a
`use`.

```lua
-- client/panel.lua
AddEventHandler("opx77_elevators:floor", function(payload)
end)
```

- payload: `table`
    - `opx77_menu`'s own selection payload. Acted on only when
      `payload.action == "select"`; `payload.data` is the table this resource put
      on the item, echoed back untouched, carrying `elevator` and `floor`.

The return channel is an **event** because that is the only channel there is: the
client runtime puts every export through a codec, so a callback cannot be handed
across a resource boundary. The name is fixed in `client/panel.lua` and is not
configurable.

**Side** `client local event` — raised by `opx77_menu`, heard here.

### opx77:client:onPlayerLoaded {#on-player-loaded}

`opx77_core`'s **local** re-emission that a character has loaded; this resource
takes the job out of the payload and stamps it with the client clock.

```lua
-- client/main.lua
AddEventHandler("opx77:client:onPlayerLoaded", function(playerData)
end)
```

- playerData: `table`
    - `opx77_core`'s `PlayerData`. Only `job` and `jobs` are copied; money,
      metadata and the citizen id have no use here, and copying them would make
      this resource a second answer to a question the core already answers.

!!! warning "This is the local name, not the wire name"

    `opx77:client:onPlayerLoaded` is the name `opx77_core` re-emits locally, for
    satellites, with `AddEventHandler`. The name the **server** sends is
    `opx77:client:playerLoaded`, and it is the core's own to receive. Listening
    on the wrong one of the two is silent. See
    [`opx77_core`'s events](../opx77_core/events.md).

**Side** `client local event` — raised by `opx77_core`'s client half.

### opx77:client:playerDataChanged {#player-data-changed}

`opx77_core`'s local notice that something on the character changed; this
resource re-reads the job from it, which is how a promotion reaches the panel.

```lua
-- client/main.lua
AddEventHandler("opx77:client:playerDataChanged", function(playerData)
end)
```

- playerData: `table`
    - The whole `PlayerData` again.

The gate reads the snapshot on every press, so there is nothing to invalidate:
the next press is already using this. A promotion, a demotion or a job swapped at
a terminal changes the panel from the next press onward.

**Side** `client local event` — raised by `opx77_core`'s client half.

### opx77:client:onPlayerUnloaded {#on-player-unloaded}

`opx77_core`'s local notice that the character has gone; this resource drops the
job snapshot at once, closing every gated floor and leaving every public one
open.

```lua
-- client/main.lua
AddEventHandler("opx77:client:onPlayerUnloaded", function()
end)
```

Dropping the snapshot is different from letting it age out. Being **told** there
is no character is authoritative; a call that never landed says nothing about the
character, only about the core, and leaves the snapshot to expire under
`JOB_MAX_AGE_MS` instead.

**Side** `client local event` — raised by `opx77_core`'s client half.

### onClientResourceStart and onClientResourceStop {#client-resource-lifecycle}

The host's own client lifecycle events; this resource starts its scan loop on
its own start and clears every binding on its own stop.

```lua
-- client/main.lua
AddEventHandler("onClientResourceStart", function(name)
end)

AddEventHandler("onClientResourceStop", function(name)
end)
```

- name: `string`
    - The resource starting or stopping. Both handlers return immediately unless
      it is this one.

On start, `Open77.elevators` is checked for existence before anything else: it is
absent on a client that has not loaded the world and on one whose game build
predates the elevator API. Saying so once, as an error line, beats a stack trace
per scan.

**Side** `client local event` — raised by the host.

### onElevatorRemoved {#on-elevator-removed}

The host's notice that an elevator is gone; the server drops the adoption and
tells everyone it had handed the id to.

```lua
-- server/main.lua
AddEventHandler("onElevatorRemoved", function(id, revision, reason)
end)
```

- id: `integer`
    - The Open77 elevator id.
- revision: `integer`
    - The host's revision counter. Unused here.
- reason: `string`
    - The host's removal reason, logged verbatim.

**Answers with** [`opx77_elevators:released`](#released) to each player who was
told the id.

**Side** `server local event` — raised by the host, inside this resource's own
server VM.

### onPlayerDisconnected {#on-player-disconnected}

The host's notice that a player has left; the server forgets that player's rate
limit windows and removes them from every elevator's audience.

```lua
-- server/main.lua
AddEventHandler("onPlayerDisconnected", function(playerId)
end)
```

- playerId: `integer`

!!! warning "`playerDropped` does not exist on this host"

    Nothing in the platform ever emits it. A registration for it is a handler
    that never runs, and this resource carried one until it was removed.
    `onPlayerDisconnected` is the only departure event there is.

**Side** `server local event` — raised by the host, inside this resource's own
server VM.

## Names that no longer exist {#removed}

Two net events were removed. They are named here because earlier documentation
described them, and a listener for either is now a handler that never runs.

| Name | Direction | Replaced by |
|---|---|---|
| `opx77_elevators:floors` | client → server | [`floors`](exports.md#floors) and [`nearest`](exports.md#nearest), which answer from the client's own config and sightings without a round trip |
| `opx77_elevators:list` | server → client | the same |
