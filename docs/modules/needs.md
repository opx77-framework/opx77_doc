---
title: needs module
description: The character's gameplay needs (hunger, thirst, stamina, street cred) and the status-effect registry every module adds a chip to.
---

# needs

The `needs` module holds two things. First, the character's needs — `hunger`, `thirst`, `stamina` and `streetCred` by default — which the client owns during play, decays over time and pushes to the server, which stores them per character. Second, the status-effect registry: any module can put a chip (a short label with a tone and an optional countdown) on the player's screen. This module draws nothing itself; it publishes the needs and the chip strip, and the [`hud`](hud.md) module draws both. Use it to feed or drain a need, or to show a temporary state such as "Bleeding" or "Well fed".

| | |
|---|---|
| Side | both |
| Requires | `character` (hard) |
| Configuration | `config/needs.lua` (shared script) |
| Contract | `needs` v1 — client |
| Data | `opx77_character_status` (one row per character: `citizen_id`, `needs` JSON) |

`health`, `armor`, `isDead` and `inLastStand` are not needs. They belong to the character and the engine.

## Client contract {#client-contract}

`local needs = OPX.Api.Get('needs')` on the client, from code inside opx_infinity. There is no server contract: the server half only stores what the client pushes.

Every function answers a Result table: `{ ok = true, value = ... }` or `{ ok = false, error = code, detail = ... }`. None yields.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="client-needs-getneeds"></a>`GetNeeds` | — | `{ values, citizenId, ready = true }` | `values` is a copy. Errors `no_character`, `not_loaded` (detail = the citizen id). |
| <a id="client-needs-setneeds"></a>`SetNeeds` | `patch` | `{ values, changed }` | Sets each named need outright, clamped to `MIN`..`MAX`. `changed` is the sorted list of keys whose value actually moved. |
| <a id="client-needs-addneeds"></a>`AddNeeds` | `patch` | `{ values, changed }` | Adds each delta (negative to take away), clamped. |
| <a id="client-needs-addeffect"></a>`AddEffect` | `owner, spec` | `{ id }` | Adds a chip, or replaces the owner's chip with the same `id` (start time and countdown restart). |
| <a id="client-needs-updateeffect"></a>`UpdateEffect` | `owner, id, patch` | `true` | Patches one of the owner's chips. Absent fields keep their value. Without `durationMs` the countdown keeps running; with it, it restarts. |
| <a id="client-needs-removeeffect"></a>`RemoveEffect` | `owner, id` | `true` | Removes the chip and raises its `removed` event. |
| <a id="client-needs-cleareffects"></a>`ClearEffects` | `owner` | `{ removed }` | Removes every chip of the owner. Raises no event. |

`patch` for `SetNeeds` / `AddNeeds` is `{ [needName] = number }`. One unknown key or bad value refuses the whole patch; nothing is written.

`owner` is the caller's own name (1–64 characters of letters, digits, `_ : - .`). It groups chips and lets the module drop them when the owner stops. If `owner` is the name of a running Open77 resource, its chips are dropped when that resource stops or reloads. A module name inside opx_infinity is never swept this way.

### Effect spec (chip format) {#effect-spec}

| Field | Type | Rule |
|---|---|---|
| `id` | string | Required. 1–64 characters of letters, digits, `_ : - .`. Unique per owner. |
| `label` | string | Required. Cleaned and cut to 32 characters; empty after cleaning is refused. |
| `icon` | string | Optional. Cut to 2 characters. |
| `tone` | string | Optional. One of `ok`, `warn`, `bad`, `accent`, `bleed`, `burn`, `shock`, `chem`. |
| `priority` | number | Optional, default `0`. Higher draws first. |
| `durationMs` | number | Optional. `1`..`3600000`. The chip expires on its own after this. |
| `progress` | number | Optional. Clamped to `0`..`1`. |
| `event` | string | Optional. A local event name (max 96 characters) raised when the chip is removed or expires. |
| `data` | table | Optional. Opaque data handed back in the event. At most 64 nodes and 4 levels deep. |

One owner may hold 24 chips. The strip is ordered by `priority` (highest first), then newest first. Only `MAX_VISIBLE` chips are published; the rest are counted in `hidden`.

```lua
local needs = OPX.Api.Get('needs')
local r = needs.AddEffect('mymodule', {
  id = 'bleeding', label = 'Bleeding', tone = 'bleed',
  priority = 80, durationMs = 30000, event = 'mymodule:bleedEnded',
})
if not r.ok then print(r.error) end
```

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-net-needs-pull"></a>`opx:net:needs:pull` | client → server | `citizenId` | Asks for the stored needs of the loaded character. Refused (audit `needs.pull.refused`) if the id is not the player's loaded character. Limited to 4 per 10 s. |
| <a id="opx-net-needs-values"></a>`opx:net:needs:values` | server → client | `citizenId, values` | Answer to a pull. |
| <a id="opx-net-needs-push"></a>`opx:net:needs:push` | client → server | `citizenId, values` | The client's current values. Clamped, held in memory and written on autosave or disconnect. Limited to 12 per 10 s. |
| <a id="opx-net-needs-pushed"></a>`opx:net:needs:pushed` | server → client | `citizenId` | Acknowledges one push. |
| <a id="opx-on-needs-changed"></a>`opx:on:needs:changed` | client local | `{ values, changed, source, citizenId, ready }` | A need moved. `source` is `loaded`, `decay`, `set`, `add` or `unloaded`. |
| <a id="opx-on-needs-effects"></a>`opx:on:needs:effects` | client local | `{ anchor, offset, chips, hidden }` | The chip strip changed. Each chip: `{ id = 'owner:id', label, icon, tone, progress, remainingMs, totalMs }`. |
| <a id="opx-on-needs-effect"></a>`opx:on:needs:effect` | client local | `{ status, owner, action, label, tone, data }` | One chip was `removed` or `expired`. `status` is the chip id. Also raised on the chip's own `event` name, if it set one. |

Client `opx:on:` events reach only handlers inside opx_infinity.

A character deleted through the `character` module also deletes its needs row (it listens to the private `opx:in:character:deleted`).

## Configuration {#configuration}

`config/needs.lua` sets `OPX.Config.MODULES.needs`. Shared script. `enabled = false` switches the module off.

| Key | Default | What it does |
|---|---|---|
| <a id="config-needs-enabled"></a>`enabled` | `true` | Switches the module on or off. |
| <a id="config-needs-anchor"></a>`ANCHOR` | `'bottom-left'` | Corner the chip strip sits in. Sent in the strip payload. |
| <a id="config-needs-offset"></a>`OFFSET` | `120` | Pixels above that corner. |
| <a id="config-needs-max-visible"></a>`MAX_VISIBLE` | `6` | Chips published at once. |
| <a id="config-needs-needs"></a>`NEEDS` | see below | Every need, with bounds. A key not listed here is refused and never stored. A need added later is served at its `DEFAULT` to existing characters. |
| <a id="config-needs-decay-ms"></a>`DECAY_MS` | `60000` | Milliseconds between two decay charges. |
| <a id="config-needs-push-ms"></a>`PUSH_MS` | `120000` | Milliseconds between two throttled pushes to the server. |
| <a id="config-needs-push-delta"></a>`PUSH_DELTA` | `5` | A move this large on any need pushes at once. |
| <a id="config-needs-autosave-ms"></a>`AUTOSAVE_MS` | `300000` | Milliseconds between two server writes of the held pushes (minimum 1000). |

### NEEDS

Each entry is `name = { MIN, MAX, DEFAULT, DECAY_PER_MINUTE? }`. A need without `DECAY_PER_MINUTE` only moves when a caller moves it.

| Need | MIN | MAX | DEFAULT | DECAY_PER_MINUTE |
|---|---|---|---|---|
| `hunger` | 0 | 100 | 100 | 0.20 |
| `thirst` | 0 | 100 | 100 | 0.28 |
| `stamina` | 0 | 100 | 100 | — |
| `streetCred` | 0 | 100000 | 0 | — |

## Refusal codes {#codes}

| Code | Meaning |
|---|---|
| `no_character` | No character is loaded on this client. |
| `not_loaded` | A character is loaded but the server has not answered the pull yet. |
| `spec_must_be_a_table` | The spec or patch is not a table. |
| `unknown_need` | A patch key is not in `NEEDS`. |
| `invalid_need_value` | A patch value is not a finite number. |
| `empty_patch` | The patch names no need. |
| `invalid_owner` | `owner` is not a valid name. |
| `missing_id` / `invalid_id` | The effect `id` is missing or malformed. |
| `invalid_label` | The label is missing or empty after cleaning. |
| `invalid_event` | `event` is not a valid name. |
| `invalid_tone` | `tone` is not one of the eight tones. |
| `invalid_duration` | `durationMs` is not in `1`..`3600000`. |
| `invalid_data` / `data_too_large` | `data` is not a table, or is over 64 nodes / 4 levels. |
| `invalid_progress` | `progress` is not a finite number. |
| `owner_limit` | The owner already holds 24 chips and the id is new. |
| `not_found` | The owner holds no chip with that id. |

These codes are not translated; they are for the calling code.
