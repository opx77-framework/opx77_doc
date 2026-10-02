---
title: downed module
description: Death and revive — who is down, the full-screen down view, waiting for help, giving up at a medical centre, and reviving through the contract.
---

# downed

The `downed` module decides who is down and how they get back up. A player whose life phase becomes `dead` (with a character loaded) is down. They see a full-screen view with two choices: **wait for help**, which marks them as waiting (a distress signal other modules can list), or **give up**, which unlocks after a delay and wakes them at the nearest configured medical centre. Staff or job modules stand a player up through the `Revive` contract function. Nothing else in the runtime respawns a dead player. Being down survives a disconnect: the player is put back down when they return with the same character.

| | |
|---|---|
| Side | both |
| Requires | `character` (hard) |
| Configuration | `config/downed.lua` (shared script) |
| Contract | `downed` v1 — server, client |
| Data | `opx77_character_down` (one row per character: `citizen_id`, `down_for_ms`, `waiting`) |

## Server contract {#server-contract}

`local downed = OPX.Api.Get('downed')` on the server, from code inside opx_infinity. Each function answers a Result: `{ ok = true, value }` or `{ ok = false, error = code }`.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="server-downed-isdown"></a>`IsDown` | `playerId` | `{ down, waiting, downForMs? }` | `downForMs` only when down. Error `bad_player`. |
| <a id="server-downed-list"></a>`List` | — | `{ players = { { id, name, waiting, downForMs, position } } }` | Every downed player, those waiting for help first, then longest down. `position` is `{ x, y, z, bucket }`. For a dispatch screen. |
| <a id="server-downed-revive"></a>`Revive` | `playerId, caller, why?` | `true` | Revives where the body lies, at `REVIVE.HEALTH`. `caller` is your module name (audited, checked against `REVIVERS`); `why` is an optional reason, audited after the caller (cut to 64 characters). The `Revive` [server export](../creators/server-exports.md#downed) calls this with the calling resource's name. Errors: `invalid_caller`, `caller_denied`, `bad_player`, `not_down`, `not_incarnated`, `gate_unreadable`, `gate_closed`, or the host's refusal reason. |

## Client contract {#client-contract}

`local downed = OPX.Api.Get('downed')` on the client.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="client-downed-isdown"></a>`IsDown` | — | Result `{ down, waiting }` | The local player's state as the server last pushed it. |
| <a id="client-downed-suspend"></a>`Suspend` | `owner, on` | Result `true` | Sets the down screen aside (it fades and gives the input back) while your own surface is up; `on = false` brings it back. `owner` must be in `SUSPENDERS`. Errors `invalid_caller`, `caller_denied`. A suspender whose module or resource stops is released automatically. |

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-net-downed-state"></a>`opx:net:downed:state` | server → client | `{ down, waiting?, downForMs?, giveUpInMs?, waitingForMs? }` | The player's down state. All times are relative. |
| <a id="opx-net-downed-refused"></a>`opx:net:downed:refused` | server → client | `code` | A give-up was refused. Shown as `medic.refused.<code>`. |
| <a id="opx-net-downed-ready"></a>`opx:net:downed:ready` | client → server | — | Ask for the state again (on start and world entry). |
| <a id="opx-net-downed-wait"></a>`opx:net:downed:wait` | client → server | — | Wait for help. Marks the player as waiting. |
| <a id="opx-net-downed-giveup"></a>`opx:net:downed:giveup` | client → server | — | Give up. The server checks the delay, that the player is still dead and the readiness gate, then respawns at the nearest hospital in the same bucket. |
| <a id="opx-on-downed-changed"></a>`opx:on:downed:changed` | client local, and server (host-wide) | client: `{ down, waiting }`; server: `playerId, { citizenId, down = true, waiting, restored }` or `playerId, { citizenId, down = false, reason, kept }` | Down or waiting changed. On the client, `hud`, `prompts`, `target`, `progress` and `appearance` react to it. On the server it is raised for every server resource; see [Public server events](../creators/server-events.md#downed). |
| <a id="opx-on-downed-view"></a>`opx:on:downed:view` | client local | `{ kind, ... }` | The state half talking to the view. `kind` is `config`, `show`, `hide`, `notice` or `focus`. |
| <a id="opx-on-downed-key"></a>`opx:on:downed:key` | client local | `key` | A key (`F1`–`F12`, `A`–`Z`, `0`–`9`) pressed while the down screen holds the keyboard. Key mappings do not fire then, so this is how another module hears one. |

Each request event is limited to one per second per player. The server also rescans every player's life state each second.

Audit entries: `downed.down`, `downed.up`, `downed.wait`, `downed.giveUp`, `downed.revive`, `downed.restore`, and the security entry `downed.revive.denied`.

## Page channels {#page-channels}

On the `interactive` surface.

| Channel | Direction | Payload | Meaning |
|---|---|---|---|
| <a id="page-downed-ready"></a>`downed:ready` | page → Lua | `{}` | The view mounted. Lua answers with `config` (all `medic.*` texts) and the current state. |
| <a id="page-downed-wait"></a>`downed:wait` | page → Lua | `{}` | Wait-for-help button. |
| <a id="page-downed-giveup"></a>`downed:giveUp` | page → Lua | `{ holding }` | Give-up button state. The page repeats `holding = true` while pressed; Lua times the hold (`GIVE_UP_HOLD_MS`) on its own clock. A gap over 1 s ends the press. |
| <a id="page-downed-key"></a>`downed:key` | page → Lua | `{ key }` | A key heard while the keyboard is held. |
| <a id="page-downed-diag"></a>`downed:diag` | page → Lua | `{ text }` | A view-side message for the client log. |
| <a id="page-focus-set"></a>`focus:set` | page → Lua | `{ focus, owner }` | Page focus broadcast. This module acquires keyboard and cursor for owner `downed` and releases it otherwise. |
| `downed:view` | Lua → page | `{ kind, ... }` | `config` `{ text }`, `show` `{ suspended, waiting, giveUpInMs, downForMs, holdMs }`, `hide`, `notice` `{ text }`, `focus` `{ hold }`. |

## Configuration {#configuration}

`config/downed.lua` sets `OPX.Config.MODULES.downed`. Shared script. `enabled = false` switches the module off.

| Key | Default | What it does |
|---|---|---|
| <a id="config-downed-enabled"></a>`enabled` | `true` | Switches the module on or off. |
| <a id="config-downed-give-up-after-s"></a>`GIVE_UP_AFTER_S` | `120` | Seconds down before give up unlocks (0–3600). Enforced on the server. |
| <a id="config-downed-give-up-hold-ms"></a>`GIVE_UP_HOLD_MS` | `1500` | How long the give-up button must be held (minimum 300). |
| <a id="config-downed-respawn"></a>`RESPAWN` | `{ HEALTH = 0.5, GRACE_MS = 5000 }` | After give up: fraction of full health (0.01–1) and spawn protection in ms (0–60000). |
| <a id="config-downed-hospitals"></a>`HOSPITALS` | one row: `Watson medical center` at `-667.14, -382.61, 9.16`, heading `0.0` | Respawn points `{ LABEL, X, Y, Z, HEADING }`. The nearest to the player wins. With no usable row, give up is refused with `no_hospital`. |
| <a id="config-downed-revive"></a>`REVIVE` | `{ HEALTH = 0.35, GRACE_MS = 3000 }` | What a contract `Revive` leaves the player with. |
| <a id="config-downed-revivers"></a>`REVIVERS` | `'*'` | Callers allowed to `Revive`: `'*'` for all, or a set `{ name = true }`. The name is the caller's own claim, so this is a switch, not a security boundary. |
| <a id="config-downed-suspenders"></a>`SUSPENDERS` | `{ admin = true, opx77_admin = true }` | Callers allowed to `Suspend` the screen. |
| <a id="config-downed-vanilla-hud"></a>`VANILLA_HUD` | all 13 components (`minimap`, `compass`, `clock`, `health`, `stamina`, `weapon`, `speedometer`, `questTracker`, `phone`, `scanner`, `vanillaNotifications`, `crosshair`, `hubMenu`) | Game HUD components hidden while down. |

## Refusal codes {#codes}

| Code | Meaning | Player text |
|---|---|---|
| `too_soon` | Give up before `GIVE_UP_AFTER_S`. | `medic.refused.too_soon` |
| `no_hospital` | No usable `HOSPITALS` row. | `medic.refused.no_hospital` |
| `respawn_refused` | The host refused the respawn. | `medic.refused.respawn_refused` |
| `not_incarnated` | The player has no body in the world. | `medic.refused.not_incarnated` |
| `gate_closed` | The player is still joining. | `medic.refused.gate_closed` |
| `gate_unreadable` | The readiness gate could not be read. | `medic.refused.gate_unreadable` |
| `failed` | Any other code (generic). | `medic.refused.failed` |
| `not_down` | `Revive` on a player who is not dead. | — |
| `bad_player` | Not a whole positive player id. | — |
| `invalid_caller` / `caller_denied` | Missing caller name, or not in `REVIVERS` / `SUSPENDERS`. | — |
