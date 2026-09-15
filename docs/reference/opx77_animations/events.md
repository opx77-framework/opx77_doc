---
title: opx77_animations events
description: Every event opx77_animations raises, sends or listens to — the three local events a caller listens on, the private net events between its two halves, the platform animation service's wire the presenter mirrors, and the host and chat events it uses.
---

# Events

Three **local** client events are this resource's public channel: the verdict on
a request, a change in what any player in the bucket is playing, and a body that
could not be posed. Everything else on this page is either a private wire
between this resource's two halves or somebody else's event it uses.

The split decides which registration call you write:

- **Networked** — crosses the wire. Register with `RegisterNetEvent`. Requires
  `network.events`.
- **Non-networked** — never leaves the machine. Register with a bare
  `AddEventHandler`, no permission needed.

!!! warning "The client's local bus is host-wide"

    Any resource on the player's machine can `TriggerEvent` any name with any
    payload, and a local `TriggerEvent` also reaches `RegisterNetEvent` handlers
    of the same name. Check a payload's shape before trusting it, and treat
    nothing here as authority: the service is the only producer of a playback
    state, and this resource's server half re-checks every request. See
    [The export contract](../../concepts/export-contract.md#local-bus).

## Non-networked {#non-networked}

### opx77:animations:result {#result}

Raised on the client with the verdict on one play or stop request — the answer
this resource's server half sent, or a request that went unanswered for 15
seconds.

```lua
-- a client script of your own resource
AddEventHandler("opx77:animations:result", function(result)
end)
```

- result: [`AnimationResult`](types.md#animationresult)
    - `requestId` — the `requestId` [`play`](exports.md#play) or
      [`stop`](exports.md#stop) answered; `0` for a typed command.
    - `action` — `"play"` or `"stop"`.
    - `ok`, and `error` on a refusal.
    - `animation`, `variant`, and `playbackId` — the service's id for a playback
      that started.
    - `source` — who asked: `"export"`, `"picker"`, `"key"` (the stop key),
      `"command"`, `"presenter"` (a local body that could not be posed) or
      `"owner_stopped"` (the resource that started it stopped).
    - `owner` — the export caller's resource name, when there was one.

**When it is raised.** Once per request, when the server's answer arrives. A
request still unanswered 15 seconds after it was sent is raised with
`error = "request_timeout"`; the pending requests are swept every five seconds,
so that verdict lands between 15 and 20 seconds after the request.

!!! info "A rate-limited request after the first is never answered"

    The server answers only the **first** `rate_limited` refusal in a window,
    so a held key is one toast rather than a stack of them. Every refusal after
    it in the same window is dropped without an answer, and a request from an
    export or the picker therefore reaches this event as `request_timeout`.

**The toast.** A refusal whose `source` is anything but `"export"` is also shown
to the player — through `opx77_notify` when it runs and
[`NOTIFY`](config.md#notify) is on, as a chat line otherwise, or when the toast's
answer is anything but `ok = true`. An export caller decides for itself.

**Side** `client local event` — raised in this resource's client VM, heard by
every client resource on the machine.

### opx77:animations:changed {#changed}

Raised on the client whenever any player in this client's bucket starts, loops,
moves to another step of, or stops a playback, as the service replicated it.

```lua
-- a client script of your own resource
AddEventHandler("opx77:animations:changed", function(change)
end)
```

- change: [`AnimationChange`](types.md#animationchange)
    - `playerId` and `active`.
    - While active: `playbackId`, `animation` (the profile), `clip`, `variant`
      when the clip is one of this catalogue's, `known`, `step` and `steps`
      (1-based), and `cycle`.

It is raised whether or not this client is the one posing bodies, at most 32 per
100 ms tick — a join into a busy bucket is hundreds of states, and they drain over
the ticks that follow. A change of world, bucket or connection, or a restart of
the service, raises every mirrored player as `active = false` before the new
snapshot fills the mirror again.

Nothing is raised on a client without the presentation natives: there is no
mirror to raise from.

**Side** `client local event`.

### opx77:animations:failed {#failed}

Raised on the client when a body could not be posed for a playback.

```lua
-- a client script of your own resource
AddEventHandler("opx77:animations:failed", function(failure)
end)
```

- failure: `table`
    - `playerId` — whose body.
    - `playbackId` — which playback.
    - `reason` — the natives' code, or `presentation_failed`. `play_raised` when
      the native call raised.

Only raised while this client is posing bodies — see
[Who poses the bodies](index.md#presenter). The same playback is not retried on
the same entity until it moves to another step, cycle or body.

When the body is the **local** player's, the playback is stopped
(`source = "presenter"`), the player is shown *Your animation could not be shown
and was stopped.*, and the log says so:

```text
own playback <playbackId> could not be posed: <reason>
```

**Side** `client local event`.

### opx77_animations:row {#row}

Raised by [`opx77_menu`](../opx77_menu/index.md) for a row of the picker; this
resource listens and plays, stops, moves between screens, or forgets its handle.

```lua
-- client/picker.lua
AddEventHandler("opx77_animations:row", function(payload)
end)
```

- payload: `table`
    - `opx77_menu`'s selection payload. Ignored unless `payload.owner` is this
      resource and `payload.menu` is `"opx77_animations.picker"`, which every
      screen of the picker shares. `select` on a row whose `data` carries `go`
      opens that screen — `category` or `variants` — and one carrying `back`
      steps up a screen; one carrying `stop` stops; one carrying `name` and
      `variant` plays. `close` forgets the handle, unless it is the close of a
      screen this resource replaced (`reopened`, or another handle); a close
      whose reason is `back`, on a screen below the root, steps up a screen
      instead.

Not a public contract. Named here so a listener on the same bus knows what it is
looking at. See [`opx77_menu` events](../opx77_menu/events.md#your-event).

**Side** `client local event` — raised by `opx77_menu`, heard here.

### chat:addMessage {#chat-addmessage}

Raised locally on the client when a message to the player cannot be a toast —
[`NOTIFY`](config.md#notify) is off, `opx77_notify` is not running, or its
answer to the toast is anything but `ok = true`.

```lua
-- client/main.lua
TriggerEvent('chat:addMessage', {
	type = 'system',
	author = locale('animations.title'),
	text = message,
})
```

`author` is the locale's `animations.title`, `Animations` in `en`. No `color` is
sent: `opx77_chat` styles the line from its `type`. Drawn by
[`opx77_chat`](../opx77_chat/events.md#chat-addmessage). The player's form of
[`opx77.anim.list`](commands.md#opx77-anim-list) arrives on the same name from
the server instead — see [Networked: chat and commands](#chat-wire).

**Side** `client local event` — raised here.

### Host lifecycle {#lifecycle}

| Event | Side | What this resource does |
|---|---|---|
| `onClientResourceStart` | client | on its own start: starts the presenter, asks the server for the offer, starts the 5 s sweep of unanswered requests, and registers the two [key mappings](index.md#keys). On `opx77_prompts`' start: shows the stop key again if an animation is playing |
| `onClientResourceStop` | client | on its own stop: stops posing and closes its picker. On **another** resource's stop: ends the local playback that resource started through an export, and forgets `opx77_menu`'s handle when the menu stops |
| `open77:keybinds:changed` | client | a player rebound or reset a mapping: an open root screen of the picker is redrawn so its **Stop** row names the key |
| `onPlayerDisconnected` | server | forgets the player's rate windows, command cooldowns and offer throttle. It is the departure of an admitted player; a connection refused before admission raises `onPlayerRejected`, which this resource does not need |

## Networked: between the two halves {#private-wire}

This resource's own wire. **None of it is a public contract**: the names and
argument order may change with any version, and every field is checked by the
receiving half before it is used. Listed so a packet capture or a log line can be
read.

| Event | Direction | Arguments |
|---|---|---|
| `opx77_animations:play` | client → server | `requestId` (1 to 2147483647), `name`, `variant` (`0` for the default), `{ loop = "default" \| "loop" \| "once", durationMs }` (`0` for none) |
| `opx77_animations:stop` | client → server | `requestId` |
| `opx77_animations:hello` | client → server | none — asks for the offer. Answered at most once a second per player |
| `opx77_animations:offer` | server → client | `{ { name, variants = { … } }, … }` — what this build offers. A client reads at most 256 rows and 64 variants a row |
| `opx77_animations:answer` | server → client | `requestId`, `action`, `ok`, `code` (`""` on success), `{ animation, variant, playbackId }` |
| `opx77_animations:picker` | server → client | `category`, or `""` — a command asked for the picker, on that category's screen when one is named |
| `opx77_animations:cancel` | server → client | none — `opx77.anim.stop` ran; release a client-owned playback too |
| `opx77_animations:notice` | server → client | `kind`, `message` — a typed command's usage line or unknown name or variant, already in the configured locale; raised as a toast in the refusal slot, or a chat line. Not a verdict, so nothing is raised on [`result`](#result) |

`source` on the server is always the authenticated connection, never a payload
value, so a request can only ever play or stop the player who sent it.

## Networked: the platform's animation service {#service-wire}

The presenter reads and writes the service's own wire. That protocol is the
**platform's**, observed in its own client rather than documented by it, and
[`ServicePlaybackState`](types.md#serviceplaybackstate) records its shape only as
far as this resource reads it. The net handlers are registered only on a client
with the presentation natives.

| Event | Direction | Used for |
|---|---|---|
| `open77:animations:state` | service → client | one player's playback state; taken into the mirror by revision |
| `open77:animations:snapshot` | service → client | every active playback in the bucket, possibly across pages; replaces the mirror, so absence from it is an end |
| `open77:animations:result` | service → client | the answer to a release this client sent; only ids carrying this client's own nonce are read |
| `open77:animations:sync` | client → service | asks for a snapshot, every five seconds |
| `open77:animations:stopRequest` | client → service | releases the local player's playback, from [`stop`](exports.md#stop) and `opx77.anim.stop` |

A state or a snapshot page from another bucket, another incarnation of the
service than a snapshot established, or an older revision than the mirror
already holds is dropped. A snapshot split across pages that does not complete
within ten seconds is abandoned.

## Networked: chat and commands {#chat-wire}

| Event | Direction | Used for |
|---|---|---|
| `chat:ready` | client → server | a player's chat box is up; answered with suggestions, at most once every two seconds per player |
| `chat:addSuggestions` | server → client | one suggestion per registered command, with help in the configured locale. See [`opx77_chat`](../opx77_chat/events.md#chat-addsuggestions) |
| `chat:addMessage` | server → client | the player's form of `opx77.anim.list`, a report, `type = 'info'`, authored `animations.title`, with no colour of its own. See [`opx77_chat`](../opx77_chat/events.md#chat-addmessage) |

No command answers on `open77:command:result`: `opx77_chat` prints none of that
event's accepted answers. A usage error and an unknown name or variant go to
the client on `opx77_animations:notice`, as a toast — see
[the two halves](#private-wire).

## See also {#see-also}

- [Exports](exports.md) — the requests whose verdict arrives on
  [`result`](#result).
- [Types](types.md) — every payload on this page.
- [Integration channels](../../concepts/integration-channels.md#local-events) —
  what a local event can and cannot carry.
