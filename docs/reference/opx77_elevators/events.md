---
title: opx77_elevators events
description: Every event opx77_elevators sends, receives or raises — the five net events between its two halves, the local answer channel, the menu return channel, and the platform events both halves listen to.
---

# Events

This resource's two halves talk over five net events, and the client half raises
one local event of its own after every decision. Everything else it sends or
listens to belongs to somebody else — `opx77_core`, `opx77_menu`, `opx77_chat`,
or the host.

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
    returned silently. No lift was ever adopted and every `requestFloor` answered
    `not_adopted`, with no error anywhere. The server now logs that mismatch
    once, on the first rejected sighting.

```lua
-- server/main.lua
RegisterNetEvent('opx77_elevators:sighted', function(entity, x, y, z, floorCount, activeFloor)
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
[`opx77_elevators:answer`](#answer) — one answer per request, a `rate_limited`
refusal included.

```lua
-- server/main.lua
RegisterNetEvent('opx77_elevators:request', function(key, index)
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
the ground, and the rate limit, which is checked first. Not the job —
`opx77_core` has no server export that answers one.

On an accepted move the server remembers the player as the cabin's rider until
`TRAVEL_MS` has passed, so a departure mid-travel can recall the cabin — see
[`onPlayerDisconnected`](#on-player-disconnected).

**Side** `net event` — sent by this resource's client half only, from `requestFloor`
and from the built-in panel.

### opx77_elevators:bound {#bound}

Sent by the server to one player to tell them the Open77 id of an elevator this
resource has adopted, so that player's `requestFloor` has something to press.

```lua
-- client/main.lua
RegisterNetEvent('opx77_elevators:bound', function(key, id, floorCount)
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
    The client keeps only the `id` and ignores `floorCount` — its own floor
    list comes from `config.lua`'s `FLOORS`, and the real ceiling is enforced on
    the server against `Open77.elevators.get(id).floorCount`. The argument stays
    on the wire as part of the event's contract.

**Side** `net event` — sent by this resource's server half only.

### opx77_elevators:answer {#answer}

Sent by the server after every floor request whose `source` resolved, carrying
its own verdict; the client republishes it on
[`opx77:elevators`](#opx77-elevators) with `source = "server"`.

```lua
-- client/main.lua
RegisterNetEvent('opx77_elevators:answer', function(key, index, ok, failure)
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

!!! warning "One answer per request, and still no guarantee"

    A `rate_limited` request is answered like every other refusal, one event per
    request, so the player sees why nothing moved. Only a request whose `source`
    did not resolve is answered with nothing, and a net event can always be
    lost with the connection: a caller waiting on this event, or on the channel
    it feeds, must still tolerate never receiving one.

**Side** `net event` — sent by this resource's server half only.

### opx77_elevators:released {#released}

Sent by the server to every player it had handed an id for, when an adoption
ends — the host removed the lift, or the unused-adoption sweep gave it back.

```lua
-- client/main.lua
RegisterNetEvent('opx77_elevators:released', function(key)
end)
```

- key: `ElevatorKey`

The client drops its binding, so the next scan re-reports the lift rather than
sending requests for an id nobody owns. Until a new
[`opx77_elevators:bound`](#bound) arrives, `requestFloor` answers `not_adopted`.

**Side** `net event` — sent by this resource's server half only.

### chat:addMessage {#chat-addmessage}

Sent by the server to echo one line of the diagnostic command's output back to
the player who typed it; this resource sends it and does not listen for it.

```lua
-- server/main.lua
TriggerClientEvent('chat:addMessage', player, {
	type = 'info',
	author = locale('elevators.title'),
	text = line,
})
```

- type: `"info"` — always: the server only sends output lines, never
  refusals. The host sends its own refusal when the ACL check fails.
- author: `string` — the locale's `elevators.title`, `ELEVATORS` in `en`.
- text: `string` — one line of the report, in English.

No `color` is sent: `opx77_chat` styles the line from its `type`. The report is
a diagnostic dump, so it stays text in the chat box, where two runs can be
scrolled back and compared. It does not go on `open77:command:result`, whose
accepted answers `opx77_chat` does not print. See [Commands](commands.md) for
what the lines say.

The client half also raises `chat:addMessage` **locally**, with `type = 'error'`
and the same author, when a floor refused from the built-in panel cannot be
shown as a toast — see [the panel's refusals](#panel-refusals).

**Side** `net event` — sent by this resource's server half; drawn by
[`opx77_chat`](../opx77_chat/events.md#chat-addmessage).

### chat:ready {#chat-ready}

Sent by a player's chat box when it is up; the server answers with the
diagnostic command's suggestion, on
[`chat:addSuggestion`](../opx77_chat/events.md#chat-addsuggestion), to that
player only when the ACL grants them `command.<COMMAND>`.

```lua
-- server/main.lua
RegisterNetEvent('chat:ready', function()
end)
```

Registered only when [`COMMAND`](config.md#command) names a command. Cooled at
one suggestion per ten seconds per player, because anybody can raise the event.
The grant is read with `Open77.acl.isAllowed`, which is why the manifest
declares `acl.read`; a host without the ACL reader suggests the command to
nobody. The suggestion's text and its `key` help, which lists the configured
elevator keys, are translated.

**Side** `net event` — received by this resource's server half.

## Non-networked {#non-networked}

### opx77:elevators {#opx77-elevators}

Raised on the client after **every** decision this resource makes, local or
remote; it is the channel a caller listens on, and the name is
`OPX_ELEVATORS_CONFIG.EVENT` rather than a literal.

```lua
-- a client script of your own resource
AddEventHandler('opx77:elevators', function(payload)
end)
```

- payload: `table`
    - `elevator`, `floor`, `ok`, `error`, `label`, `reason`, `source`, `queued` —
      the same shape a [`FloorDecision`](types.md#floordecision) carries.

`source` tells you whose press this was: the **invoking resource's own name** for
a press made through the [`requestFloor`](exports.md#requestfloor) export,
`"panel"` for one made
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
    exactly that: it acts on the channel only for the elevator of a list it
    opened itself, and only once — see [the panel's refusals](#panel-refusals).

**Side** `client local event` — raised in this resource's client VM, heard by
every client resource on the machine.

#### The panel's refusals {#panel-refusals}

The built-in floor list opens with `closeOnSelect`, so `opx77_menu` closes it
right after it raises the selection: a refusal cannot be written under a list
that is already gone. The panel says it in an
[`opx77_notify`](../opx77_notify/exports.md#show) toast instead:

| Field | Value |
|---|---|
| `id` | `opx77_elevators.answer`, with `replace = true`, so a second refusal replaces the first |
| `type` | `error` |
| `title` | the locale's `elevators.title` |
| `message` | the floor's `REASON` when the refusal carries one (a local refusal does), or this resource's wording for the code — see [What the player is shown](errors.md#wording) |
| `durationMs` | `5000` |

When the toast cannot be shown — `opx77_notify` is not running, or its answer is
anything but `ok = true` — the same text is raised locally as a
`chat:addMessage` line with `type = 'error'` and no colour, and one warning is
logged the first time.

Only the **first** answer on `opx77:elevators` that carries the elevator of the
list this file opened is shown; a local refusal and the server's verdict both
count. Any answer for that elevator, accepted or refused, ends the wait, and so
does a close of the list that is not the selection (Escape, the pause menu,
another menu). An answer for another elevator is ignored.

### opx77_elevators:floor {#floor}

Raised by [`opx77_menu`](../opx77_menu/index.md) when a row of the built-in floor
list is selected or the list closes; this resource listens for it and turns a
selection into a floor request.

```lua
-- client/panel.lua
AddEventHandler('opx77_elevators:floor', function(payload)
end)
```

- payload: `table`
    - `opx77_menu`'s own payload. Believed only when `payload.owner` is this
      resource, as `opx77_menu` stamps it, because any resource can raise the
      name. On `payload.action == "select"`, `payload.data` is the table this
      resource put on the item, echoed back untouched, carrying `elevator` and
      `floor`. On `payload.action == "close"` with a reason other than `select`
      or `reopened`, the panel stops waiting for an answer.

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
AddEventHandler('opx77:client:onPlayerLoaded', function(playerData)
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
AddEventHandler('opx77:client:playerDataChanged', function(playerData)
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
AddEventHandler('opx77:client:onPlayerUnloaded', function()
end)
```

Dropping the snapshot is different from letting it age out. Being **told** there
is no character is authoritative; a call that never landed says nothing about the
character, only about the core, and leaves the snapshot to expire under
`JOB_MAX_AGE_MS` instead.

An `opx77_core` stop is treated the same way — see
[`onClientResourceStop`](#client-resource-lifecycle).

**Side** `client local event` — raised by `opx77_core`'s client half.

### onClientResourceStart and onClientResourceStop {#client-resource-lifecycle}

The host's own client lifecycle events; this resource starts its scan loop on
its own start, clears every binding on its own stop, and drops the job snapshot
when `opx77_core` stops.

```lua
-- client/main.lua
AddEventHandler('onClientResourceStart', function(name)
end)

AddEventHandler('onClientResourceStop', function(name)
end)
```

- name: `string`
    - The resource starting or stopping. The start handler returns immediately
      unless it is this one; the stop handler acts on this one and on
      `opx77_core`.

On start, `Open77.elevators` is checked for existence before anything else: it is
absent on a client that has not loaded the world and on one whose game build
predates the elevator API. Saying so once, as an error line, beats a stack trace
per scan. Then [`SCAN_MS`](config.md#scan-ms) is checked: when it does not come
out as a whole number of milliseconds above zero, an error line is logged and no
loop runs at all — no scan, and no poll of the core.

**An `opx77_core` stop is a character unload.** A restart of the core raises no
`opx77:client:onPlayerUnloaded`, so the stop handler runs the unload body itself
and drops the snapshot: gated floors close at once instead of staying open on a
character that no longer exists until the snapshot ages out. The next poll or
`opx77:client:onPlayerLoaded` brings it back once the core is up.

**Side** `client local event` — raised by the host.

### onElevatorRemoved {#on-elevator-removed}

The host's notice that an elevator is gone; the server drops the adoption and
tells everyone it had handed the id to.

```lua
-- server/main.lua
AddEventHandler('onElevatorRemoved', function(id, _, reason)
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

The host's notice that an admitted player has left; the server forgets that
player's rate-limit windows, removes them from every elevator's audience, and
recalls a cabin they left in motion.

```lua
-- server/main.lua
local function forget(playerId, reason)
	local player = tonumber(playerId) or 0
	if player <= 0 then return end
	-- ...
end

AddEventHandler('onPlayerDisconnected', forget)
```

- playerId: `string`
    - Like every host event argument. Convert it before using it as a table
      key: Lua 5.4 keeps `"3"`, `3` and `3.0` apart.
- reason: `string`
    - `connection_closed` when the transport dropped or the player quit,
      otherwise the text the disconnect was queued with by
      `Open77.players.disconnect`, `kick` or `ban`. Written in the recall's log
      line.

**A cabin left in motion is recalled.** A floor request the server accepted
remembers its rider until `TRAVEL_MS` has passed. When that rider leaves before
the journey ends, the server sends the cabin to floor `0` — the one floor every
configured elevator has and none of them gates — rather than let it arrive and
park open on a gated floor nobody is answerable for. The log line reads
`<key>: rider <id> left mid-travel (<reason>); recalled to floor 0 (<true|false>)`,
the last value being whether the host accepted the move.

The chat suggestion's per-player window is forgotten here too, with the other
windows, and a minute sweep collects any window older than a minute that a late
packet recreated after the player had gone.

!!! warning "`playerDropped` does not exist on this host"

    Nothing in the platform ever emits it. A registration for it is a handler
    that never runs, and this resource carried one until it was removed.
    `onPlayerDisconnected` is the only *departure* event there is —
    [`onPlayerRejected`](../../concepts/connection-gate.md#rejected) reports a
    connection refused before admission, which is a different thing.

**Side** `server local event` — raised by the host, inside this resource's own
server VM.

## Names that no longer exist {#removed}

Two net events were removed. They are named here because earlier documentation
described them, and a listener for either is now a handler that never runs.

| Name | Direction | Replaced by |
|---|---|---|
| `opx77_elevators:floors` | client → server | [`floors`](exports.md#floors) and [`nearestElevator`](exports.md#nearestelevator), which answer from the client's own config and sightings without a round trip |
| `opx77_elevators:list` | server → client | the same |
