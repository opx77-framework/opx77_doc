---
title: progress module
description: A timed-action bar that holds the player still, optionally plays a gesture, and reports how it ended.
---

# progress

The `progress` module shows a timed-action bar — "Eating", "Picking the lock" — for a few seconds. While it runs, the player cannot move or attack (when `LOCK` is on), and an optional animation plays. Only one bar runs at a time. `Start` answers at once whether the bar is up; the outcome (finished, stopped, cancelled or interrupted) arrives later on `opx:on:progress:done`. The bar ends early if the player goes down, the character unloads or the module stops. It never takes keyboard focus. Server code starts a bar on one client with a net event.

| | |
|---|---|
| Side | both (all logic is client-side; the server has no contract) |
| Optional | `downed`, `animations` |
| Configuration | `config/progress.lua` (shared script) |
| Contract | `progress` v1 — client |

## Client contract {#client-contract}

`local progress = OPX.Api.Get('progress')` on the client, from code inside opx_infinity. Each function answers a Result. None yields.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="client-progress-start"></a>`Start` | `owner, spec` | `{ owner, durationMs }` | Puts a bar up. `spec` = `{ label, durationMs, animation?, cancelable? }`. Errors `invalid_caller`, `invalid_spec`, `progress_busy`, `invalid_duration`, `invalid_label`. |
| <a id="client-progress-stop"></a>`Stop` | `owner, ending?` | `true` | Takes the owner's bar down early. `ending = 'cancelled'` reports `cancelled`; anything else reports `stopped`. Errors `progress_not_active`, `not_owner`. |
| <a id="client-progress-state"></a>`State` | — | `{ open = false }` or `{ open = true, owner, label, remainingMs }` | Whether a bar is up, and whose. |

Spec fields:

| Field | Type | Rule |
|---|---|---|
| `label` | string | Required. Cut to 64 bytes. Your own text. |
| `durationMs` | number | Required. Between `MIN_MS` and `MAX_MS`. |
| `animation` | table | Optional `{ name, variant? }`. Played through `animations.Play` (looped, not cancellable) and stopped with the bar. Ignored if `animations` is not running or refuses it. |
| `cancelable` | boolean | Optional, default `false`. Lets the page cancel the bar. |

While a bar is up and `LOCK` is true, the input actions `Movement` and `Attack` are blocked. The camera stays free.

```lua
local progress = OPX.Api.Get('progress')
local r = progress.Start('mymodule', { label = 'Eating', durationMs = 4000 })
AddEventHandler('opx:on:progress:done', function(done)
  if done.owner == 'mymodule' and done.finished then --[[ apply the effect ]] end
end)
```

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-net-progress-start"></a>`opx:net:progress:start` | server → client | `spec` | Starts a bar owned by `@server`. A client `Stop` cannot end it. |
| <a id="opx-net-progress-cancel"></a>`opx:net:progress:cancel` | server → client | — | Ends a bar owned by `@server` with `stopped`. |
| <a id="opx-on-progress-done"></a>`opx:on:progress:done` | client local | `{ owner, label, ending, finished }` | The bar ended. `ending` is `finished`, `stopped`, `cancelled` or `interrupted`; only `finished = true` means the action happened. |
| <a id="opx-on-progress-state"></a>`opx:on:progress:state` | client local | `{ open, owner?, label? }` | A bar went up or down. |

The server half has no contract: a server module sends `TriggerClientEvent('opx:net:progress:start', playerId, spec)` itself and never hears the outcome.

## Page channels {#page-channels}

On the `overlay` surface.

| Channel | Direction | Payload | Meaning |
|---|---|---|---|
| <a id="page-progress-cancel"></a>`progress:cancel` | page → Lua | `{}` | Cancel the bar, if it allowed it. Ends with `cancelled`. The shipped page shows the "Hold to cancel" hint but does not send this channel. |
| `progress:show` | Lua → page | `{ label, durationMs, cancelable }` | Show the bar; the page animates from the duration. |
| `progress:hide` | Lua → page | `{}` | Hide the bar. |

## Configuration {#configuration}

`config/progress.lua` sets `OPX.Config.MODULES.progress`. Shared script. `enabled = false` switches the module off.

| Key | Default | What it does |
|---|---|---|
| <a id="config-progress-enabled"></a>`enabled` | `true` | Switches the module on or off. |
| <a id="config-progress-lock"></a>`LOCK` | `true` | Block `Movement` and `Attack` while a bar is up. `false` keeps the bar but lets the player walk away. |
| <a id="config-progress-min-ms"></a>`MIN_MS` | `250` | Shortest duration accepted (valid 100–60000, else 250). |
| <a id="config-progress-max-ms"></a>`MAX_MS` | `60000` | Longest duration accepted (valid 1000–600000, else 60000). |

## Refusal codes {#codes}

| Code | Meaning |
|---|---|
| `invalid_caller` | `owner` is missing or empty. |
| `invalid_spec` | `spec` is not a table. |
| `progress_busy` | Another bar is already up. |
| `invalid_duration` | `durationMs` is outside `MIN_MS`..`MAX_MS`. |
| `invalid_label` | `label` is missing or empty. |
| `progress_not_active` | `Stop` with no bar up. |
| `not_owner` | `Stop` by an owner that did not start the bar. |
