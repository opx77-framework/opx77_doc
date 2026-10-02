---
title: Runtime events and channels
description: The net events the core itself sends and listens to, the host event names in OPX.Host, the core's WebUI page channels, and its private internal events.
---

# Runtime events and channels

The core uses a few events of its own, outside any module: refusals and command answers going to a player, notes coming back to the server journal, and the WebUI channels that every view shares. Use this page when you need the exact name or payload, for example to draw command answers in a custom chat. Module events are on each module's page. How the three prefixes work is in [Events and channels](../how-it-works/events.md).

Core calls itself `runtime` on the net channel, so its names are `opx:net:runtime:<verb>`.

## Net events {#net}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-net-runtime-notify"></a>`opx:net:runtime:notify` | server → client | `{ kind = 'error', code, operation, icon? }` | A refusal, sent by [`OPX.Refuse`](core.md#opx-refuse). `code` is always a locale key that exists. The client shows `locale(code)` as a toast; an `icon` outside `OPX.Glyphs` is dropped. |
| <a id="opx-net-runtime-commandanswer"></a>`opx:net:runtime:commandAnswer` | server → client | `raw, kind, message, toasted, icon?` | What a command did, sent by [`OPX.CommandNotice`](core.md#opx-commandnotice). The client shows `message` as a toast with id `opx.command` (a new answer replaces the last one), unless `toasted` is `true`. |
| <a id="opx-net-runtime-commandresult"></a>`opx:net:runtime:commandResult` | server → client | `{ type = 'info'\|'error', author, text }` | A command's read-back (a list or a dump), sent by [`OPX.CommandResult`](core.md#opx-commandresult). `author` is `SERVER_NAME`. The [chat](../modules/chat.md) module draws it; with no listener nothing is shown. |
| <a id="opx-net-runtime-note"></a>`opx:net:runtime:note` | client → server | `module, text` | One line for the server journal, sent by [`OPX.Note`](core.md#opx-note). The server drops it unless `module` is 1–32 characters matching `^[a-z0-9][a-z0-9_.-]*$` and `text` is 1–2048 bytes; it allows 12 per player per 10 s and 60 per session. The text is stripped of control characters and cut to 400 characters. It is evidence only: nothing reads it back. |

Any client can raise `opx:net:runtime:note`. Do not act on what it says.

## Host events (`OPX.Host`) {#host}

`OPX.Host` names the platform's own events, so code does not spell them by hand.

| Key | Event name | Side the core uses it on |
|---|---|---|
| `PLAYER_CONNECTED` | `onPlayerConnected` | server |
| `PLAYER_DISCONNECTED` | `onPlayerDisconnected` | server — the core clears notes, cooldowns and any session left behind |
| `PLAYER_READY` | `onPlayerReady` | server — the core warns when the host opened a gate the core was holding (`liveness_lost:` or `timeout:`), or when it was never held (`no_holds`) |
| `CLIENT_RESOURCE_START` | `onClientResourceStart` | client — client boot |
| `CLIENT_RESOURCE_STOP` | `onClientResourceStop` | client — client shutdown |
| `RESOURCE_START` | `onResourceStart` | server |
| `RESOURCE_STOP` | `onResourceStop` | server — stops jobs and modules, releases selection buckets |
| `WORLD_READY` | `open77:worldReady` | — |
| `GAMEPLAY_READY` | `open77:session:gameplayReady` | — the platform's own gate hold clears only after a client sends it |
| `VEHICLE_REMOVED` | `onVehicleRemoved` | — |
| `TUNABLE_CHANGED` | `onTunableChanged` | server — re-raised as `opx:in:tune:changed` |
| `KEYBINDS_CHANGED` | `open77:keybinds:changed` | client, no payload — raised after any key mapping is registered, rebound, reset or removed. Every module that shows a key name (admin, animations, clothing, dealership, garages, inventory, prompts, teleports) listens to this one constant to redraw. |

The server and client pairs are different names. Using `CLIENT_RESOURCE_START` on the server registers a handler nothing raises.

## Page channels {#page-channels}

The runtime has one WebUI page with id `opx`. Lua sends and listens on `<channel>`; the page sees `opx:<channel>`. See [The WebUI page](../how-it-works/webui.md).

### Page → Lua {#page-to-lua}

| Channel | Payload | Meaning |
|---|---|---|
| <a id="page-ready"></a>`ready` | — | The page has loaded. Nothing is sent to it before this. Lua then writes the locale catalogue with `locale:set`. |
| <a id="page-module-ready"></a>`<module>:ready` | any | A view has mounted. The core wires one for every declared module before any module starts, and holds what arrives (up to 8 payloads) until the module registers its handler. |
| <a id="page-focus-set"></a>`focus:set` | `{ focus, owner }` | What the page holds focus for. With `focus` not `true` (or no `owner`), the core empties the Lua focus stack and drops focus. Otherwise it drops every owner above `owner`. Modules may listen as well. |
| <a id="page-diag"></a>`diag` | `{ text }` | A page-side error or message. Written to the client log as `[surface opx] page: <text>`. |
| <a id="page-notify-ready"></a>`notify:ready` | — | The toast view has mounted. Lua answers with `notify:config`, `notify:down` if the player is down, and every toast still up. |
| <a id="page-notify-gone"></a>`notify:gone` | `{ id }` | A toast finished its countdown. Lua forgets it. |

### Lua → page {#lua-to-page}

| Channel | Payload | Meaning |
|---|---|---|
| `locale:set` | `{ locale, strings, first, done }` | The locale catalogue, in parts of 250 keys, one part per frame. `first` clears the page's copy; `done` marks the last part. |
| `reply` | `{ ref, ... }` | The answer to a page request, from [`OPX.UI.Answer`](core.md#opx-ui-answer). |
| `notify:config` | `{ position, width }` | From [`TOASTS`](core-config.md#config-client-toasts). |
| `notify:show` | `{ id, kind, title, message, icon, durationMs, stinger }` | Show or replace a toast. |
| `notify:update` | the whole toast | A toast changed. |
| `notify:dismiss` | `{ id }` | Take one toast down. |
| `notify:clear` | `{}` | Take every toast down. |
| `notify:down` | `{ down }` | Hide or show the toast stacks. |

## Internal events {#internal}

These `opx:in:` names are private to `opx_infinity`. They are listed so a module author knows they exist; they are raised with `TriggerEvent` on the server. A server `TriggerEvent` reaches every server resource, so another resource can hear them, but they are not a supported API and may change.

| Event | Arguments | Raised when |
|---|---|---|
| `opx:in:gate:held` | `source` | [`OPX.Gate.Hold`](core.md#opx-gate-hold) took a hold. No module listens to it in this version. |
| `opx:in:gate:released` | `source, note` | [`OPX.Gate.Release`](core.md#opx-gate-release) released one. No module listens to it in this version. |
| `opx:in:session:forgotten` | `playerId` | [`OPX.ForgetSession`](core.md#opx-forgetsession) is dropping a session. The `character` module unloads on it. |
| `opx:in:tune:changed` | `key` | The host reported a tunable change. No module listens to it in this version: read tunables with `OPX.Tune.Number` at the moment of use. |
