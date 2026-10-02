---
title: hud module
description: The player HUD — health and needs gauges, money and job read-out, status chips, microphone block and speed dial — and the hiding of the game's own HUD.
---

# hud

The `hud` module draws the player's HUD on the overlay page: a column of gauges (health, armour, stamina, hunger, thirst), a read-out of money, job and street cred, the status chips published by [`needs`](needs.md), a microphone block and a vehicle speed dial. It owns no game state. It samples other modules and the engine, picks each gauge's tone and formats each number, then pushes the result to the page. It also hides the game's own HUD components it replaces. It steps aside while the player is down, and while the join screen, the spawn menu, a menu or the fitting room is open. There is no player command to toggle it; other modules can hide it through the contract.

| | |
|---|---|
| Side | client |
| Requires | `character` (hard) |
| Optional | `needs`, `downed` |
| Configuration | `config/hud.lua` (shared script) |
| Contract | `hud` v1 — client |

## Client contract {#client-contract}

`local hud = OPX.Api.Get('hud')` on the client, from code inside opx_infinity.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="client-hud-isvisible"></a>`IsVisible` | — | Result `{ visible, down, covered }` | `visible` is the chosen state; `down` = player is down; `covered` = a full-screen view (join, spawn, menu, wardrobe) holds the display. |
| <a id="client-hud-setvisible"></a>`SetVisible` | `value` | Result `{ visible, down, covered }` | Any value but `false` shows. Not stored: resets to shown on restart. Raises `opx:on:hud:visibility` when it changes. |
| <a id="client-hud-vanilla"></a>`Vanilla` | — | Result `{ available, found, state }` | Read-only report on the game's own HUD. `available` = `Open77.hud` exists; `found` = each component's visibility before this module first touched it; `state` = `Open77.hud.state()` verbatim. |
| <a id="client-hud-applyvanilla"></a>`ApplyVanilla` | — | integer | Re-applies the `VANILLA` hide/show plan and answers how many components were set. Not a Result. `downed` calls it after a revive, because its own release cleared this resource's hide claims. |

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-on-hud-visibility"></a>`opx:on:hud:visibility` | client local | `{ visible, down, covered }` | Raised when `SetVisible` changes the chosen state, or when `covered` changes. |

The module listens to `opx:on:character:loaded`, `unloaded`, `changed`, `money`, `job`, `opx:on:needs:changed`, `opx:on:needs:effects`, `opx:on:downed:changed`, `opx:on:entry:state`, `opx:on:spawn:state`, `opx:on:menu:state` and `opx:on:appearance:decision`, plus the host events `open77:playerStatsChanged`, `open-voice:modeChanged` and `open77:voice:pushToTalkKeyChanged`. It sends nothing to the server.

## Page channels {#page-channels}

All on the `overlay` surface. The page sees them as `opx:<channel>`.

| Channel | Direction | Payload | Meaning |
|---|---|---|---|
| <a id="page-hud-ready"></a>`hud:ready` | page → Lua | `{}` | The page mounted. Lua resends everything. |
| `hud:config` | Lua → page | `{ anchor, infoAnchor, statusAnchor, statusOffset, vehicleAnchor, width, segments, voiceSegments }` | Layout. |
| `hud:show` | Lua → page | `{ visible }` | Whole-HUD switch (false while hidden, down or covered). |
| `hud:vitals` | Lua → page | `{ gauges = { { id, icon, label, pct, points, tone } } }` | The gauge column. `label` is a locale key; `tone` is decided here. |
| `hud:info` | Lua → page | `{ eyebrow, lines = { { id, label, value, tone } } }` | Money, job and cred lines, values already formatted. |
| `hud:status` | Lua → page | `{ chips, hidden }` | The chip strip from `needs`. |
| `hud:voice` | Lua → page | `{ active, state, caption, mode, distance, level, count, index, key, activation, heard }` or `{ active = false }` | Microphone block. `state` is `offline`, `muted`, `talking`, `detected` or `idle`. |
| `hud:vehicle` | Lua → page | `{ active, speed, unit, gear, rpm?, integrity?, integrityLabel, tone, airborne, airborneLabel }` or `{ active = false }` | Speed dial in km/h. |

## Configuration {#configuration}

`config/hud.lua` sets `OPX.Config.MODULES.hud`. Shared script. `enabled = false` switches the module off.

Anchors are `bottom-left`, `bottom-right`, `top-left`, `top-right`, `top-center`, `bottom-center`. The page falls back to its own default for an unknown name.

| Key | Default | What it does |
|---|---|---|
| <a id="config-hud-enabled"></a>`enabled` | `true` | Switches the module on or off. |
| <a id="config-hud-anchor"></a>`ANCHOR` | `'bottom-left'` | Corner of the gauge column. |
| <a id="config-hud-info-anchor"></a>`INFO_ANCHOR` | `'top-left'` | Corner of the money/job read-out. |
| <a id="config-hud-status-anchor"></a>`STATUS_ANCHOR` | `'bottom-left'` | Corner of the chip strip. If absent, the `needs` module's `ANCHOR` is used. |
| <a id="config-hud-status-offset"></a>`STATUS_OFFSET` | `120` | Pixels between the chip strip and the gauges. If absent, the `needs` `OFFSET` is used. |
| <a id="config-hud-vehicle-anchor"></a>`VEHICLE_ANCHOR` | `'bottom-center'` | Corner of the speed dial. |
| <a id="config-hud-width"></a>`WIDTH` | `210` | Gauge column width in pixels (1920-wide surface). |
| <a id="config-hud-segments"></a>`SEGMENTS` | `10` | Segments per gauge. |
| <a id="config-hud-voice-segments"></a>`VOICE_SEGMENTS` | `8` | Segments of the voice meter. |
| <a id="config-hud-vitals-ms"></a>`VITALS_MS` | `33` | Milliseconds between two samples of the gauges. |
| <a id="config-hud-widget-ms"></a>`WIDGET_MS` | `100` | Milliseconds between two samples of the voice and vehicle blocks. |
| <a id="config-hud-tone-warn"></a>`TONE_WARN` | `33` | Percent at or under which a gauge takes the `warn` tone. |
| <a id="config-hud-tone-bad"></a>`TONE_BAD` | `15` | Percent at or under which a gauge takes the `bad` tone. |
| <a id="config-hud-gauges"></a>`GAUGES` | health, armor, stamina, hunger, thirst | The gauges in drawing order. See below. |
| <a id="config-hud-money"></a>`MONEY` | `{ 'EDDIES', 'BANK' }` | Money lines in order. A held money type not listed is added after them, sorted. Zero amounts are not drawn. |
| <a id="config-hud-money-separator"></a>`MONEY_SEPARATOR` | `' '` | Thousands separator. |
| <a id="config-hud-info-eyebrow"></a>`INFO_EYEBROW` | `'hud.info.eyebrow'` | Locale key of the read-out title. |
| <a id="config-hud-show-job"></a>`SHOW_JOB` | `true` | Draw the job line. |
| <a id="config-hud-show-cred"></a>`SHOW_CRED` | `true` | Draw the street cred line (when cred is above 0). |
| <a id="config-hud-voice"></a>`VOICE` | `{ OPEN_VOICE = 'open-voice', DRIVER = 'open77_voice', HIDE_OPEN_VOICE = true }` | Microphone block. The two names are platform voice resources read through their exports (not dependencies). `HIDE_OPEN_VOICE` hides open-voice's own HUD line. Set `VOICE` to a non-table to drop the block. |
| <a id="config-hud-vehicle"></a>`VEHICLE` | `{ PASSENGER = true }` | Speed dial. `PASSENGER = false` draws it for the driver only. |
| <a id="config-hud-vanilla"></a>`VANILLA` | see below | Components of the game's own HUD: `true` leaves one to the game, `false` hides it. |

### GAUGES

Each row: `ID`, `SOURCE` (`health`, `armor`, `stamina` or any need name), `LABEL` (locale key), `ICON` (`health`, `armor`, `stamina`, `hunger`, `thirst`; anything else draws no glyph), and optional `TONE` (tone above `TONE_WARN`), `ALERT = false` (never toned), `HIDE_AT_ZERO`, `HIDE_ABOVE`. Shipped: `armor` has `ALERT = false, HIDE_AT_ZERO = true`; `stamina` has `HIDE_ABOVE = 99`. A gauge whose source is not readable is not drawn, so without `needs` there are no hunger and thirst gauges.

### VANILLA

Shipped: `minimap = true`; `compass`, `clock`, `health`, `stamina`, `weapon`, `speedometer`, `questTracker`, `vanillaNotifications`, `hubMenu`, `crosshair`, `scanner`, `phone` all `false`.

When the client reports its component list (`Open77.hud.components()`), every component **not named** in `VANILLA` is hidden too. Name a component `true` to leave it to the game. Hides are released by the platform when the resource stops.

!!! warning "Crosshair and scanner are hidden"
    The shipped config hides `crosshair` (weapons fire without a reticle) and `scanner` (the platform also refuses scanner activation). Set them to `true` to give them back.
