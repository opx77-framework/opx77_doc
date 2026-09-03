---
title: opx77_hud events
description: Every event opx77_hud listens to — the core's local character events, the needs and status strip payloads opx77_status publishes, and its own /hud net event — plus the complete message protocol between its Lua half and web/hud.js.
---

# Events

`opx77_hud` **raises no event of its own on the Lua bus.** Every entry on this
page is either something it listens to, or a message on the private channel
between its client half and its page.

## Networked (server → client) {#networked}

### opx77_hud:visibility {#visibility}

Carries the mode the [`/hud` command](commands.md#hud) resolved, from this
resource's server half back to the same player's client half; the client calls
the same code path [`setVisible`](exports.md#setvisible) calls, and a mode it
does not recognise does nothing.

```lua
RegisterNetEvent("opx77_hud:visibility", function(mode) end)
```

- mode: `string`
    - `"show"`, `"hide"` or `"toggle"`. Anything else is ignored in silence.

!!! warning "Not a public API"
    This is an internal channel and it carries a mode string, not a boolean.
    Another resource wanting to hide the HUD calls
    [`setVisible`](exports.md#setvisible) from a client script. Registering this
    name in your own resource, or sending it with `TriggerClientEvent` from a
    server resource holding `network.events`, works today and is not a contract.

This one grant — `permissions { "network.events" }` — exists for this event and
nothing else. Nothing that appears on screen comes over the network: the
character is read from `opx77_core` through a client export, and the needs and
the status chips arrive from `opx77_status` on the client's local bus.

## Non-networked (the client local bus) {#non-networked}

The client's local event bus is **host-wide**: a `TriggerEvent` in one client
resource reaches a plain `AddEventHandler` in another. That is the whole reason
this resource can be told about a character it does not own and chips it does not
own without a single permission. See
[The client export contract](../../concepts/export-contract.md#local-bus).

Every handler below ignores a payload that is not a table, so a malformed event
costs nothing.

### opx77:client:onPlayerLoaded {#onplayerloaded}

Adopts the whole `PlayerData` snapshot and redraws; a payload that is not a table
is ignored.

```lua
AddEventHandler("opx77:client:onPlayerLoaded", function(playerData) end)
```

- playerData: `table` — the core's `PlayerData`.

!!! warning "The local name, not the wire name"
    `opx77_core` publishes on two deliberately disjoint channels. This is the
    **local** one (`OPX.Events.Local`), registered with a bare `AddEventHandler`.
    The wire name is `opx77:client:playerLoaded`, needs `network.events`, and must
    be registered with `RegisterNetEvent`. Mixing the two vocabularies re-enters a
    handler from inside itself and produces a silent permanent busy loop.

### opx77:client:playerDataChanged {#playerdatachanged}

Adopts the whole replacement snapshot and redraws; the core resends all of
`PlayerData` after any change rather than a patch, so nothing is merged here.

```lua
AddEventHandler("opx77:client:playerDataChanged", function(playerData) end)
```

- playerData: `table` — the core's `PlayerData`.

The wire name behind it is `opx77:client:setPlayerData`. Use the local name.

### opx77:client:onPlayerUnloaded {#onplayerunloaded}

Drops the snapshot and redraws, which takes the gauges down; it carries no
payload.

```lua
AddEventHandler("opx77:client:onPlayerUnloaded", function() end)
```

The visibility flag is **not** touched here. It lives beside the snapshot, not
inside it, so a player who typed `/hud off` before switching characters comes
back to a hidden HUD.

### opx77:status:needs {#status-needs}

Replaces the gauges [`opx77_status`](../opx77_status/index.md) owns — stamina,
hunger, thirst and street cred — and redraws; a payload that is not a table is
ignored.

```lua
AddEventHandler("opx77:status:needs", function(payload) end)
```

- payload: `table`
    - `values`: `table` — the needs by name. Each is clamped to `0..100` and
      rounded before it reaches the page; street cred is floored instead.
    - `ready`: `boolean` — whether the publisher has an answer for the live
      character. Anything but `true` blanks the gauges it owns.
    - `citizenId`: `string` — whose needs these are. Not read here.

The name is `opx77_status`'s `NEEDS_EVENT`, and this resource hard-codes the
shipped value rather than reading another resource's config.

A `ready` that is not `true`, a `values` that is not a table, a value in it that
is not a finite number, and an authoritative refusal from the
[`getNeeds`](../opx77_status/exports.md#getneeds) export all
mean the same thing: that gauge is **left out of the frame** rather than drawn at
zero. An empty hunger bar is something a player acts on, so it is never shown for
a value the HUD does not have. Stopping `opx77_status` does the same — it takes
its chip strip down on the way out but raises no farewell for the needs, so
`onClientResourceStop` clears them here.

!!! info "Read once at start, pushed after that"
    On boot the client half calls `opx77_status`'s
    [`getNeeds`](../opx77_status/exports.md#getneeds) export once, to catch up on
    a character that loaded before this resource did. There is no second poll
    behind it: every later change arrives on this event, which the publisher
    raises after each one. The character snapshot from `opx77_core` works the
    same way — one `GetPlayerData` call at boot, then its local events.

### opx77:status:effects {#status-effects}

Replaces the status strip wholesale and redraws;
[`opx77_status`](../opx77_status/index.md) raises it, and a payload that is not a
table is ignored.

```lua
AddEventHandler("opx77:status:effects", function(payload) end)
```

- payload: `table`
    - `chips`: `table[]` — ordered, already cut to the publisher's `MAX_VISIBLE`.
    - `hidden`: `integer` — how many effects were left out of that cut.
    - `anchor`: `string` — which corner the strip sits in.
    - `offset`: `integer` — pixels above that corner.

Each chip carries `id`, `label`, `icon`, `tone`, `progress`, `remainingMs` and
`totalMs`; the authoritative shape is on
[the effect spec page](../opx77_status/effect-spec.md#published-chip).

!!! warning "Treated as untrusted input"
    The local bus is host-wide, so **any** client resource on the machine can
    raise this name — not only `opx77_status`. This resource therefore keeps at
    most **12** chips from one payload, drops any chip without an `id`, coerces
    `hidden` to a number defaulting to `0` and caps it at **999**, ignores an
    `anchor` that is not a string of at most 32 characters, and ignores an
    `offset` that is not a number between `0` and the surface's 1080 pixels. The
    chip id `__more` is reserved for the overflow counter the page draws and a
    raw publisher should not mint it.

The payload is carried into the next frame rather than sent to the page on its
own, so the page never has two sources deciding when it repaints. `anchor` and
`offset` join the frame signature, which is why moving the strip in
`opx77_status`'s config now actually moves it.

## The page channel (Lua ⇄ web/hud.js) {#page-channel}

A private protocol between `client/main.lua` and `web/hud.js`, over the WebUI
bridge: Lua sends with `page:send`, the page receives with `Open77.on`; the page
sends with `Open77.emit`, Lua receives with `page:on`. It is documented because a
satellite author reading the surface needs to know what crosses it — **not**
because another resource can join it. A WebUI page handle belongs to the resource
that created it and to that resource generation.

Lua drops every outbound message until the page has raised `hud:ready`.

### hud:ready {#hud-ready}

**page → Lua.** Raised once, at the end of `web/hud.js`, immediately after
`Open77.ready()`; it is emitted whatever happened during setup, because Lua drops
every message until it lands.

```lua
page:on("hud:ready", function() end)
```

Carries an empty table. On receipt Lua marks the page ready, sends
[`hud:config`](#hud-config) once, and forces a
[`hud:frame`](#hud-frame) — forced because the previous signature describes a DOM
that no longer exists.

### hud:diag {#hud-diag}

**page → Lua.** Carries a diagnostic line out of the page, because the bridge
swallows exceptions thrown inside an `Open77.on` handler and console output never
reaches the client log.

```lua
page:on("hud:diag", function(payload) end)
```

- payload: `table`
    - `text`: `string` — at most 400 characters.

The page emits at most **20** of these per session and never re-enters the
reporter, so a render loop that throws every frame costs twenty log lines rather
than a flood. `window.onerror` and a wrapped `console.error` both route here.

### hud:config {#hud-config}

**Lua → page.** Sent once per page, on `hud:ready`, and never again; it carries
placement and cadence, not content.

```lua
page:send("hud:config", {
  anchor = "bottom-left",   -- OPX_HUD_CONFIG.ANCHOR
  infoAnchor = "top-right", -- OPX_HUD_CONFIG.INFO_ANCHOR
  width = 210,              -- OPX_HUD_CONFIG.WIDTH
  segments = 10,
})
```

- anchor: `string` — the gauge block's corner. An unrecognised value falls back
  to `bottom-left`.
- infoAnchor: `string` — the text block's corner. An unrecognised value falls
  back to `top-right`.
- width: `integer` — sets `--hud-width`. Ignored unless finite and above zero.
- segments: `integer` — how many blocks a gauge is cut into. Ignored unless
  finite and at least 2, and read once per gauge element when that element is
  first built.

The page also honours `stripAnchor` and `stripOffset` on this message, falling
back to `anchor`. The shipped Lua never sends them here, so the strip starts in
the gauge block's corner and moves to the publisher's corner on the first frame
that carries one.

### hud:frame {#hud-frame}

**Lua → page.** One complete picture: rows, chips and the strip's placement, sent
only when the frame's signature differs from the last one sent.

```lua
page:send("hud:frame", {
  rows = { --[[ ordered rows, see below ]] },
  chips = { --[[ at most 12, from opx77:status:effects ]] },
  hidden = 0,
  stripAnchor = "bottom-left",
  stripOffset = 120,
})
```

- rows: `table[]` — built in `OPX_HUD_CONFIG.BLOCKS` order. Two shapes:

    | Field | `kind = "bar"` | `kind = "text"` |
    |---|---|---|
    | `id` | required; the DOM slot key and a CSS class | required |
    | `label` | **absent** — a gauge has none | drawn as the line's label |
    | `value` | drawn to the right of the blocks | drawn as the line's value |
    | `pct` | `0..100`, integer; lit blocks are rounded **up** | — |
    | `icon` | one of `health`, `armor`, `stamina`, `hunger`, `thirst` | — |
    | `tone` | `bad`, `warn`, or absent | `on`, or absent |

- chips: `table[]` — passed through from
  [`opx77:status:effects`](#status-effects) untouched.
- hidden: `integer` — above zero the page draws one extra `+n` chip with the
  reserved id `__more`.
- stripAnchor: `string` — the strip's corner. An unrecognised or absent value
  leaves the element where `hud:config` left it.
- stripOffset: `integer` — sets `--strip-offset`. Ignored unless finite and not
  negative.

A frame sent while no character is loaded but a chip is live carries an empty
`rows` list, which draws no gauge and no line.

!!! warning "A redraw that moves nothing sends nothing"
    Before each frame the rows are reduced to a signature — id, label, value,
    percent, tone and icon of every row, the label being empty for a gauge, plus
    the chips' ids, labels and tones, `hidden`, `anchor` and `offset`. If it
    matches the last frame sent, nothing is sent. `remainingMs` is deliberately
    absent from it: a countdown ticking down is not a new picture, and the page
    animates it on its own clock. The signature is forced only on `hud:ready` and
    on a visibility change, because neither is described by it.

### hud:hide {#hud-hide}

**Lua → page.** Takes the whole surface down — gauges, text block and status
strip together — by removing one class from `<body>`.

```lua
page:send("hud:hide", {})
```

Carries an empty table. It is sent when either is true:

- the player, a command or an export has set visibility to `false`; or
- no character is loaded **and** no chip is live.

!!! warning "A live chip cannot keep a hidden HUD on screen"
    The whole surface is one element's `open` class, strip included, so hiding is
    decided on visibility first and on content second. A resource that adds a
    status effect while the player has `/hud off` sees nothing appear, and this is
    correct: the player turned the surface off.
