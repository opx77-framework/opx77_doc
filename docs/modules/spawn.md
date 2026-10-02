---
title: spawn module
description: The spawn menu — where a character starts when it enters the world, chosen from a fixed list of places.
---

# spawn

The `spawn` module shows a menu of places when a character enters the world and puts the character where the player clicks. Which joins get the menu is set by `OFFER_POLICY`: the shipped `'first'` asks only a character that has never been placed, so a returning player resumes where they left. A player who picks nothing before the deadline is placed by the [`character`](character.md) module from their stored position, or at `DEFAULT_SPAWN`. The coordinates live in the config and never cross the wire: the client sends only the id of a place. Turn it off and every character is placed by `character` alone.

| | |
|---|---|
| Side | both |
| Requires | `character` (read with `OPX.Api.Require` at start) |
| Optional | `entry` (client: the menu waits for it) |
| Configuration | `config/spawn.lua` (shared script) |
| Contract | `spawn` v1 — server |

## How a choice runs {#flow}

1. When a joining character gets a living body, `character` calls `spawn.Offer(source, citizenId)`. A `/opx.select` switch inside the world is placed directly and never offered the menu.
2. `Offer` answers `false` (character places the body itself, at once) when the module is off, the policy is `'never'`, no location is usable, a choice is already open, or the policy is `'first'` and the character already has a stored position.
3. Otherwise it sends `opx:net:spawn:offer`. The client opens the menu as soon as `entry` reports itself idle (name form and fitting room done) and reports `opx:net:spawn:opened`.
4. The player's window (`TIMEOUT_SECONDS`) starts at that report. Before it, only `HOLD_MAX_SECONDS` can end the offer.
5. A click sends the place id. The server looks it up in its own list and calls `character.PlaceCharacter`. A timeout places the character with no target (stored position, then `DEFAULT_SPAWN`). Either way the server sends `opx:net:spawn:close`.

## Server contract {#server-contract}

`local spawn = OPX.Api.Get('spawn')` on the server, from code inside opx_infinity.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="server-spawn-offer"></a>`Offer` | `source, citizenId` | `boolean` | Called by `character` on every join. `true` means spawn has taken over placement; `false` means "place them yourself". Does not yield. Do not call it for a character already placed. |

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-net-spawn-offer"></a>`opx:net:spawn:offer` | server → client | `{ timeoutMs }` | A choice is open. The client ignores a second offer while one is open. |
| <a id="opx-net-spawn-opened"></a>`opx:net:spawn:opened` | client → server | `{}` | The menu is on screen; the player's window starts now. Only the first report counts. |
| <a id="opx-net-spawn-choose"></a>`opx:net:spawn:choose` | client → server | `{ id }` | The place clicked. Unknown ids are refused (`spawn.noChoice`) and the menu stays up. Cooldown `CHOOSE_COOLDOWN_MS`. |
| <a id="opx-net-spawn-close"></a>`opx:net:spawn:close` | server → client | `{ reason, place? }` | The choice is over. `reason` is `'chosen'` or `'timeout'`; `place` is the label chosen. The client toasts the result. |
| <a id="opx-on-spawn-state"></a>`opx:on:spawn:state` | client local | `{ open, phase }` | `{ open = true, phase = 'spawn' }` when the menu opens, `{ open = false, phase = 'idle' }` when it closes. Same shape as `opx:on:entry:state`. |

## Page channels {#page-channels}

On the `interactive` surface.

| Channel | Direction | Payload | Meaning |
|---|---|---|---|
| `spawn:open` | Lua → page | `{ locations = [{ id, label, district }], title, about, hint }` | Draw the menu. Re-sent every 250 ms until the page takes it. |
| `spawn:close` | Lua → page | `{}` | Take the menu down. |
| <a id="page-spawn-choose"></a>`spawn:choose` | page → Lua | `{ id }` | The player clicked a place. A second click within 400 ms is dropped. |
| `focus:set` | page → Lua | `{ focus, owner }` | Shared focus broadcast; the module takes keyboard and cursor while its owner `spawn` is on top. |

## Configuration {#configuration}

`config/spawn.lua` sets `OPX.Config.MODULES.spawn`. Shared script.

| Key | Default | What it does |
|---|---|---|
| <a id="config-spawn-enabled"></a>`enabled` | `true` | `false` does not load the module; every character is placed by `character`. |
| <a id="config-spawn-offer-policy"></a>`OFFER_POLICY` | `'first'` | `'first'`: only a character with no stored position. `'always'`: every join (picking nothing resumes). `'never'`: nobody; no hold, no clock. Unknown values fall back to `'always'` with a warning. |
| <a id="config-spawn-timeout-seconds"></a>`TIMEOUT_SECONDS` | `45` | Time to choose once the menu is on screen (floor 5). |
| <a id="config-spawn-hold-max-seconds"></a>`HOLD_MAX_SECONDS` | `300` | Longest a character waits unplaced for a menu that never opens (floor 60). Covers the name form and fitting room too: do not set it below the time a new player needs for those. |
| <a id="config-spawn-choose-cooldown-ms"></a>`CHOOSE_COOLDOWN_MS` | `1000` | Rate limit on `opx:net:spawn:choose`. |
| <a id="config-spawn-wait-for-entry"></a>`WAIT_FOR_ENTRY` | `true` | The menu waits until `entry` reports idle (name and clothes done). |
| <a id="config-spawn-locations"></a>`LOCATIONS` | 11 places | List of `{ id, label, district, x, y, z, heading }`. |

### LOCATIONS entries

| Field | Rule |
|---|---|
| `id` | 1–32 characters of letters, digits, `_ : - .`; unique. Sent on the wire, so **do not rename** one. |
| `label` | 1–48 characters, shown on the card. |
| `district` | Up to 32 characters, the hint line. Optional. |
| `x`, `y`, `z` | Finite numbers. Copy them from the game; a guessed coordinate can drop the player through the world. |
| `heading` | Degrees; missing means `0.0` (north). |

A bad entry is dropped with a warning at start. At most 64 entries are used.

## Refusal codes {#codes}

| Code | Meaning |
|---|---|
| `spawn.noChoice` | No choice is open for you, or the id is not in the list. |
| `error.tooFast` | Clicked again inside `CHOOSE_COOLDOWN_MS`. |
