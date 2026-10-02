---
title: animations module
description: Emotes for players — the /e and /opx.anim commands, the F3 picker, the X stop key, walking paces, and the client contract other modules use to play an animation.
---

# animations

The animations module lets players play emotes: `/e dance`, a picker on `F3` built with the [menu](menu.md), and `X` to stop. Other modules use its contract to play an animation on the local player (a ripperdoc chair, drinking from an item). It does not play anything itself: it asks the platform's animation service, which replicates the animation to everyone in the bucket and refuses a dead player or one in a vehicle. The module adds a catalogue of 15 animations in 6 categories, a per-player rate limit, a readiness check, and walking paces offered on the player's own eye menu. It writes nothing to the database.

| | |
|---|---|
| Side | both |
| Requires | none |
| Optional | `menu` (picker), `form` (picker search), `prompts` (stop key hint), `downed` (closes the picker), `target` (walking pace rows) |
| Configuration | `config/animations.lua` (shared script) |
| Contract | `animations` v1 — client |
| Data | none |

Catalogue: `gestures` (handsup, clap), `social` (dance, phone), `emotions` (cry, think), `relaxation` (sit, meditate, stretch), `consumables` (smoke, cigar, drink), `interactions` (give, examine, wounded). Most have several variants.

## Commands {#commands}

All four act on the caller only and are open by default.

| Command | Access | Arguments | What it does |
|---|---|---|---|
| <a id="opx-anim"></a>`/opx.anim` | everyone | `[name\|category\|stop\|list] [variant]` | No argument: opens the picker. A category: opens the picker on it. `stop`, `list`: as below. A name: plays it (variant number optional). |
| <a id="e"></a>`/e` | everyone | same as `/opx.anim` | Short form. |
| <a id="opx-anim-stop"></a>`/opx.anim.stop` | everyone | — | Stops your animation, unless it was started as not cancelable. |
| <a id="opx-anim-list"></a>`/opx.anim.list` | everyone | — | Lists every offered animation by category, with variant counts. From the console it prints the catalogue to the log. |

Names come from [`COMMANDS`](#config-animations-commands); setting `RESTRICTED = true` gates `command.<name>`.

## Client contract {#client-contract}

`local anim = OPX.Api.Get('animations')` on the client, from code inside opx_infinity. Every function answers `{ ok, value }` / `{ ok = false, error }` and does not yield. A function that raises answers `internal_error`.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="client-animations-play"></a>`Play` | `name, options?, owner?` | `{ queued = true, requestId, animation, variant }` | Sends the request. The server's verdict arrives on [`opx:on:animations:result`](#opx-on-animations-result) with the same `requestId`. See [Play options](#play-options). `owner` is your module id: the animation stops when that module stops, and the owner may stop or replace its own locked animation. |
| <a id="client-animations-stop"></a>`Stop` | `owner?` | `{ queued, requestId? }` | Stops the local player's animation. Refused with `animation_locked` while a non-cancelable one runs, unless `owner` started it. |
| <a id="client-animations-list"></a>`List` | `category?` | `{ animations = { listing, … } }` | A listing is `{ name, label, category, categoryLabel, prop, placement, variants = { { variant, clip, words } } }`. |
| <a id="client-animations-categories"></a>`Categories` | — | `{ categories = { { name, label, count } } }` | |
| <a id="client-animations-get"></a>`Get` | `name` | `{ animation = listing }` | |
| <a id="client-animations-state"></a>`State` | `playerId?` | `{ active, playbackId?, animation?, clip?, variant?, known?, step?, steps?, cycle?, presenting }` | What a player (default: you) is playing, as seen by this client. |
| <a id="client-animations-openpicker"></a>`OpenPicker` | `category?` | `{ queued = true }` | Opens the picker. |
| <a id="client-animations-closepicker"></a>`ClosePicker` | — | `{ queued = true }` | `picker_not_open` if none is up. |

### Play options {#play-options}

| Field | Type | Default | Meaning |
|---|---|---|---|
| `variant` | integer | first offered | Variant number. |
| `clip` | string | — | Engine clip name, instead of `variant`. |
| `loop` | boolean | `LOOP_BY_DEFAULT` | `false` plays once for `ONE_SHOT_MS` unless `durationMs` is given. |
| `durationMs` | integer | none | 1000..`MAX_DURATION_MS`. |
| `cancelable` | boolean | `true` | `false` blocks `/opx.anim.stop`, the stop key and other plays until it ends. Needs a duration (or a non-looping play). |

```lua
local anim = OPX.Api.Get('animations')
local sent = anim.Play('drink', { loop = false, durationMs = 4000, cancelable = false }, 'mymodule')
if not sent.ok then print(sent.error) end
```

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-net-animations-play"></a>`opx:net:animations:play` | client → server | `requestId, name, variant, { loop, durationMs, cancelable, override }` | Play request. `loop` is `'default'`, `'loop'` or `'once'`; `variant`/`durationMs` `0` for none. |
| <a id="opx-net-animations-stop"></a>`opx:net:animations:stop` | client → server | `requestId, override` | Stop request. |
| <a id="opx-net-animations-hello"></a>`opx:net:animations:hello` | client → server | none | Asks which animations this server offers. Answered at most once a second. |
| <a id="opx-net-animations-offer"></a>`opx:net:animations:offer` | server → client | `{ { name, variants }, … }` | The offered catalogue (after `DISABLED` and the platform's own list). |
| <a id="opx-net-animations-answer"></a>`opx:net:animations:answer` | server → client | `requestId, action, ok, code, { animation, variant, playbackId, cancelable, durationMs }` | Verdict on a play or stop. `requestId` is `0` for one started by a command. |
| <a id="opx-net-animations-cancel"></a>`opx:net:animations:cancel` | server → client | none | `/opx.anim.stop` ran: release the local playback too. |
| <a id="opx-net-animations-picker"></a>`opx:net:animations:picker` | server → client | `category` or `''` | A command asked for the picker. |
| <a id="opx-on-animations-result"></a>`opx:on:animations:result` | client local | `{ requestId, action, ok, error?, animation?, variant?, playbackId?, source, owner? }` | Every verdict, including `request_timeout` after 15 s with no answer. |
| <a id="opx-on-animations-changed"></a>`opx:on:animations:changed` | client local | `{ playerId, active, playbackId?, animation?, clip?, variant?, known?, step?, steps?, cycle? }` | Any player in the bucket started, changed or stopped an animation. |
| <a id="opx-on-animations-failed"></a>`opx:on:animations:failed` | client local | `{ playerId, playbackId, reason }` | A playback could not be posed on this client. |

The `opx:on:` events reach only code inside opx_infinity's client VM. The module also reads the platform's own `open77:animations:*` wire.

## Configuration {#configuration}

`config/animations.lua` sets `OPX.Config.MODULES.animations`. Shared script.

| Key | Default | What it does |
|---|---|---|
| <a id="config-animations-enabled"></a>`enabled` | `true` | `false` switches the module off. |
| <a id="config-animations-presenter"></a>`PRESENTER` | `'auto'` | Who poses the bodies on this client. `auto` leaves it to `open77_animations` while that runs; `always` and `never` force it. |
| <a id="config-animations-notify"></a>`NOTIFY` | `true` | Refusals as toasts; `false` writes chat lines. |
| <a id="config-animations-toast-ms"></a>`TOAST_MS` | `4000` | Toast duration, 750..120000. |
| <a id="config-animations-prompts"></a>`PROMPTS` | `true` | Show the stop key in the prompt strip while an animation plays. |
| <a id="config-animations-disabled"></a>`DISABLED` | `{}` | Catalogue names never offered. |
| <a id="config-animations-loop-by-default"></a>`LOOP_BY_DEFAULT` | `true` | Loop when a request does not say. |
| <a id="config-animations-one-shot-ms"></a>`ONE_SHOT_MS` | `10000` | Length of a non-looping play with no duration. Tunable `ANIM_ONE_SHOT_MS`. |
| <a id="config-animations-max-duration-ms"></a>`MAX_DURATION_MS` | `600000` | Longest duration a request may name. Tunable `ANIM_MAX_DURATION_MS`. |
| <a id="config-animations-rate-limit"></a>`RATE_LIMIT` | `{ WINDOW_MS = 10000, REQUESTS = 6 }` | Plays per player per window; stops get twice as many. Tunables `ANIM_RATE_WINDOW_MS`, `ANIM_RATE_REQUESTS`. |
| <a id="config-animations-picker"></a>`PICKER` | `{ CLOSE_ON_SELECT = true, SHOW_VARIANT_WORDS = true }` | Close the picker after a choice; show the engine clip words beside each variant. |
| <a id="config-animations-keys"></a>`KEYS` | `{ PICKER = 'F3', STOP = 'X' }` | Default keys (`opx.animations.picker`, `opx.animations.stop`); players rebind them in the pause menu. `false` registers none. The same key for both drops the stop key. |
| <a id="config-animations-walk-paces"></a>`WALK_PACES` | `stroll` 0.8, `walk` 1.2, `brisk` 1.8 | `{ ID, SPEED }` paces in m/s (0.5..2.5) a player cycles from their own eye menu. Cycling past the last gives normal movement back. |
| <a id="config-animations-commands"></a>`COMMANDS` | `ANIM = opx.anim`, `EMOTE = e`, `STOP = opx.anim.stop`, `LIST = opx.anim.list`, all `RESTRICTED = false` | `{ KEY = { NAME, RESTRICTED } }`. `NAME = false` registers none. |

## Refusal codes {#codes}

| Code | Meaning | Locale key |
|---|---|---|
| `unknown_animation` | Not in the catalogue, disabled, or not offered. | `animations.error.unknownAnimation` |
| `unknown_category` | Not one of the six categories. | — |
| `invalid_variant` | No such variant, or not offered. | `animations.error.invalidVariant` |
| `invalid_options` | Bad `options` field, or non-cancelable with no end. | `animations.error.invalidOptions` |
| `animation_locked` | A non-cancelable animation is running. | `animations.error.locked` |
| `rate_limited` | Over `RATE_LIMIT`. Only the first refusal per window is answered. | `animations.error.rateLimited` |
| `player_not_ready` | The player has not finished loading. | `animations.error.notReady` |
| `player_not_alive`, `player_in_vehicle`, `animation_owned` | Refused by the platform service. | `animations.error.notAlive`, `animations.error.inVehicle`, `animations.error.owned` |
| `service_unavailable` | No animation service, or `players.animations.control` not granted. | `animations.error.unavailable` |
| `play_raised`, `play_refused`, `stop_raised` | The service call failed. | `animations.error.refused` |
| `not_sent`, `request_timeout` | The request did not leave, or got no answer in 15 s. | `animations.error.notSent`, `animations.error.timeout` |
| `menu_not_running`, `player_down`, `picker_not_open` | Picker only. | `animations.error.menuNotRunning` |
| `invalid_player`, `presentation_unavailable` | `State` only. | — |
| `internal_error` | A contract function raised. | — |

A refusal caused by a contract call is not shown to the player; the caller decides. Refusals from keys, commands and the picker are shown.
