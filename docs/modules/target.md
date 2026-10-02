---
title: target module
description: The target eye — hold a key, right-click something in the world, and pick from the rows other modules registered for it.
---

# target

The `target` module is the target eye. The player holds the target key (`ALT` by default), the cursor appears, and a right-click on a person, vehicle, door, prop, surface or empty sky lists the actions that apply to it. Modules register those actions as **rows**: each row says what it applies to (kinds, records, specific entities, spheres, distance), and optionally asks its owner at pick time whether it applies (`canInteract`). Choosing a row calls its `onSelect`. The module ships one row of its own, **Identifiers**, which shows and copies another player's server id and character id. Use it to give your module world interactions without a key of its own.

| | |
|---|---|
| Side | client |
| Optional | `downed` |
| Configuration | `config/target.lua` (shared script) |
| Contract | `target` v1 — client |

## Client contract {#client-contract}

`local target = OPX.Api.Get('target')` on the client, from code inside opx_infinity. Every function answers a Result: `{ ok = true, value }` or `{ ok = false, error = code }`. None yields.

`owner` is your module name. A module of this runtime keeps its rows until it stops. A separate Open77 resource's rows are dropped when it stops or reloads.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="client-target-register"></a>`Register` | `owner, definitions` | `{ token }` or `{ tokens }` | One definition (a table with `id`) or a list of up to 32, registered whole or not at all. Re-registering an owner's `id` replaces that row. |
| <a id="client-target-registerplayers"></a>`RegisterPlayers` | `owner, definitions` | as `Register` | Forces `types = { 'player' }` (other players). |
| <a id="client-target-registerself"></a>`RegisterSelf` | `owner, definitions` | as `Register` | Forces `types = { 'player' }, allowSelf = true, selfOnly = true` (own body). |
| <a id="client-target-registervehicles"></a>`RegisterVehicles` | `owner, definitions` | as `Register` | Forces `types = { 'vehicle' }`. |
| <a id="client-target-registernpcs"></a>`RegisterNpcs` | `owner, definitions` | as `Register` | Forces `types = { 'npc' }`. |
| <a id="client-target-registerprops"></a>`RegisterProps` | `owner, definitions` | as `Register` | Forces `types = { 'prop' }`. |
| <a id="client-target-registerdoors"></a>`RegisterDoors` | `owner, definitions` | as `Register` | Forces `types = { 'door' }`. |
| <a id="client-target-registerworld"></a>`RegisterWorld` | `owner, definitions` | as `Register` | Forces `types = { 'world' }` (bare surfaces). |
| <a id="client-target-registersky"></a>`RegisterSky` | `owner, definitions` | as `Register` | Forces `types = { 'sky' }` (empty space; distance is not checked). |
| <a id="client-target-registermodels"></a>`RegisterModels` | `owner, records, definitions` | as `Register` | Forces `records` (list of record names). |
| <a id="client-target-registerentities"></a>`RegisterEntities` | `owner, entities, definitions` | as `Register` | Forces `entities` (see below). |
| <a id="client-target-registerspheres"></a>`RegisterSpheres` | `owner, spheres, definitions` | as `Register` | Forces `spheres`: the ray's hit point must fall inside one. |
| <a id="client-target-update"></a>`Update` | `owner, token, patch` | `{ token }` | Re-registers the row with the patched fields under a **new** token. `patch.id` cannot change. |
| <a id="client-target-get"></a>`Get` | `owner, token` | `{ token, definition }` | A copy of the stored definition. |
| <a id="client-target-unregister"></a>`Unregister` | `owner, token` | `true` | Removes one row. |
| <a id="client-target-unregistermany"></a>`UnregisterMany` | `owner, tokens` | `true` | Removes up to 32 rows, all or none. |
| <a id="client-target-clear"></a>`Clear` | `owner` | `true` | Removes every row of the owner. |
| <a id="client-target-setenabled"></a>`SetEnabled` | `owner, token, value` | `true` | Switches one row on or off. |
| <a id="client-target-list"></a>`List` | `owner` | `{ options = { { token, id, label, enabled } } }` | The owner's rows, sorted by id. |
| <a id="client-target-settargetingenabled"></a>`SetTargetingEnabled` | `owner, value` | `true` | `false` switches the whole eye off while the owner runs (closes it if open); `true` lifts your own switch. |
| <a id="client-target-close"></a>`Close` | — | `true` | Closes the eye. |
| <a id="client-target-state"></a>`State` | — | `{ ready, open, enabled, handle, target, context, rows, owners }` | `ready` = this client can screen-pick; `rows`/`owners` = registry size. |

The `Register*` filters overwrite the same fields in your definitions.

### Row definition {#row-definition}

| Field | Type | Default | Rule |
|---|---|---|---|
| `id` | string | — | Required. 1–64 characters of letters, digits, `_ . : -`. Unique per owner. |
| `label` | string | — | Required. 1–80 bytes, one line. |
| `onSelect` | function, string or `{ resource, export }` | — | Required. Called with the context when the row is chosen. A function runs in-process. A string is an export of the owner's resource; `{ resource, export }` names another resource's export (called through `OPX.Lib.Rpc.Call`). |
| `canInteract` | same as `onSelect` | none | Optional. Called at pick time; the row is listed only if it answers `true`. |
| `checked` | same as `onSelect` | none | Optional. Answer `true`/`false` to draw a check box. |
| `description` | string | none | 1–180 bytes. |
| `group` | string | `''` | 1–40 bytes. Rows of one group form a folder. |
| `icon` | string | `'interact'` | A name from `OPX.Glyphs` (e.g. `person`, `vehicle`, `door`, `lock`, `money`, `heal`, `tag`, `warning`). |
| `enabled` | boolean | `true` | A disabled row is never listed. |
| `networked` | boolean | any | If set, the target's `networked` flag must equal it. |
| `allowSelf` | boolean | `false` | Allow the local player's own body. |
| `selfOnly` | boolean | `false` | Only the local player's body. Needs `allowSelf = true` and, if `types` is set, `player` in it. |
| `danger` | boolean | `false` | Drawn as a dangerous action. |
| `distance` | number | `3.0` | Metres from the player to the hit point, 0.1–50. Not checked for `sky`. |
| `order` | integer | `0` | −1000..1000. Lower first. A group sorts at its lowest `order`. |
| `types` | string list | any | Up to 32 of `player`, `vehicle`, `npc`, `prop`, `door`, `device`, `item`, `object`, `world`, `sky`. `sky` rows must list `sky`. |
| `records` | string list | any | Up to 32 record names (1–200 bytes each). The target's record must be one of them. |
| `entities` | table list | any | Up to 32 entries, each naming exactly one of `playerId`, `vehicleId`, `npcId` (positive integers), `engineEntity` or `propId` (digit strings). |
| `spheres` | table list | any | Up to 32 `{ x, y, z, radius }`, radius 0.1–10 m. |
| `data` | table | none | Plain data (no functions, max 4 levels, about 2 KB). Handed back in `context.option.data`. |

Bands for `order` used by the shipped modules (from `config/target.lua`): 0–9 the thing itself, 10–19 its state, 20–39 what it holds, 40–59 work, 60–89 leaving, 100–999 staff.

Limits: 48 rows per owner, 128 in total.

### The context

`canInteract`, `checked` and `onSelect` receive one table: the screen-ray hit (`position`, `direction`, `origin`, `hit`, …), plus `screen = { x, y }` (0–1), `kind`, `playerDistance`, `target` and `option = { id, owner, token, data }`. `target` holds `kind`, `networked`, `isLocalPlayer`, `record`, and the id field that applies (`playerId`, `vehicleId`, `npcId`, `engineEntity` or `propId`). For empty sky, `target = { kind = 'sky', networked = false }`. Before `onSelect`, the target and `canInteract` are checked again; if the target moved, the eye closes instead.

```lua
local target = OPX.Api.Get('target')
target.RegisterVehicles('mymodule', {
  id = 'refuel', label = 'Refuel', icon = 'bolt', order = 10, distance = 4.0,
  canInteract = function(ctx) return ctx.target.vehicleId ~= nil end,
  onSelect = function(ctx) print('refuel', ctx.target.vehicleId) end,
})
```

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-on-target-opened"></a>`opx:on:target:opened` | client local | `{ handle }` | The eye opened. |
| <a id="opx-on-target-closed"></a>`opx:on:target:closed` | client local | `reason` | The eye closed. `reason` is e.g. `selected`, `cancelled`, `input_released`, `target_changed`, `player_down`, `provider_disabled`, `provider_closed`, `no_surface`, `payload_refused`, `controls_unavailable`, `option_unavailable`, `module_stopped`. |
| <a id="opx-on-target-selected"></a>`opx:on:target:selected` | client local | `context` | A row was chosen, just before its `onSelect` runs. |

The module listens to `opx:on:downed:changed`: the eye closes and will not open while the player is down.

## Page channels {#page-channels}

On the `interactive` surface. Every message carries the `handle` of the current open; others are ignored.

| Channel | Direction | Payload | Meaning |
|---|---|---|---|
| <a id="page-target-hover"></a>`target:hover` | page → Lua | `{ handle, x, y }` | Cursor moved (0–1 coordinates). Lua answers whether anything there has rows. |
| <a id="page-target-pick"></a>`target:pick` | page → Lua | `{ handle, x, y }` | Right-click at that point. |
| <a id="page-target-select"></a>`target:select` | page → Lua | `{ handle, token }` | A listed row was clicked. |
| <a id="page-target-cancel"></a>`target:cancel` | page → Lua | `{ handle }` | Close the eye. |
| `target:open` | Lua → page | `{ handle, hoverMs, labels = { hint, looking, unavailable, back } }` | Eye opened. |
| `target:hover` | Lua → page | `{ handle, available }` | Something under the cursor has rows. |
| `target:loading` | Lua → page | `{ handle, x, y }` | A pick is being resolved. |
| `target:menu` | Lua → page | `{ handle, x, y, options = { { token, label, description, group, icon, danger, checked } } }` | The rows to list. |
| `target:empty` | Lua → page | `{ handle }` | Nothing to offer. |
| `target:busy` | Lua → page | `{ handle, token }` | A choice is being checked. |
| `target:error` | Lua → page | `{ handle }` | The choice no longer applies. |
| `target:close` | Lua → page | `{ handle }` | Eye closed. |

## Configuration {#configuration}

`config/target.lua` sets `OPX.Config.MODULES.target`. Shared script. `enabled = false` switches the module off. Numbers are clamped to the ranges shown.

| Key | Default | What it does |
|---|---|---|
| <a id="config-target-enabled"></a>`enabled` | `true` | Switches the module on or off. |
| <a id="config-target-key"></a>`KEY` | `'ALT'` | Default key of the mapping `opx.target.activate` ("Target (hold)"). Players can rebind it in the pause menu. |
| <a id="config-target-block-weapon-wheel"></a>`BLOCK_WEAPON_WHEEL` | `true` | Blocks the game's weapon wheel while the module runs (it shares the key). |
| <a id="config-target-ray-distance"></a>`RAY_DISTANCE` | `12.0` | Metres the screen ray reaches (1–100). Each row also checks its own `distance`. |
| <a id="config-target-max-options"></a>`MAX_OPTIONS` | `32` | Rows listed at once (1–128). |
| <a id="config-target-hover-ms"></a>`HOVER_MS` | `90` | Milliseconds between two hover looks (30–1000). |
| <a id="config-target-watch-ms"></a>`WATCH_MS` | `50` | Milliseconds between two checks of key, focus and target (10–1000). |
| <a id="config-target-resolve-ms"></a>`RESOLVE_MS` | `25` | Milliseconds between two slices of a pick (1–1000). |
| <a id="config-target-sweep-ms"></a>`SWEEP_MS` | `2000` | Milliseconds between two sweeps of stopped owners' rows (250–60000). |
| <a id="config-target-revalidate-ms"></a>`REVALIDATE_MS` | `200` | Milliseconds between two checks that the picked target is still there (50–5000). |
| <a id="config-target-lookup-budget-ms"></a>`LOOKUP_BUDGET_MS` | `1500` | Total time all `canInteract`/`checked` calls of one pick may take (100–10000). |
| <a id="config-target-batch"></a>`BATCH` | `5` | Rows resolved per slice (1–16). Keep it small. |
| <a id="config-target-identify"></a>`IDENTIFY` | `{ ENABLED = true, DISTANCE = 12.0 }` | The built-in **Identifiers** row on other players: shows and copies `server id / citizen id`. `DISTANCE` is clamped to 1–50 m. |

Scheduler intervals below about 100 ms run at roughly 100 ms unless another job keeps the loop busy.

## Refusal codes {#codes}

| Code | Meaning |
|---|---|
| `invalid_caller` | `owner` is missing or empty. |
| `invalid_owner` | `owner` is not a running module or resource, or not a valid name. |
| `invalid_options` | `definitions` is not a table or not a list of 1–32. |
| `invalid_or_duplicate_id` | A batch has a missing or repeated `id`. |
| `invalid_option` | Bad `id`, `label` or `onSelect`. |
| `invalid_predicate` / `invalid_checked` | Bad `canInteract` / `checked`. |
| `invalid_description`, `invalid_group`, `invalid_icon`, `invalid_distance`, `invalid_order`, `invalid_types`, `invalid_records`, `invalid_entities`, `invalid_spheres`, `invalid_data` | That field breaks its rule. |
| `invalid_enabled`, `invalid_networked`, `invalid_allowSelf`, `invalid_selfOnly`, `invalid_danger` | That field is not a boolean. |
| `invalid_self_filter` | `selfOnly` without `allowSelf`, or with `types` lacking `player`. |
| `option_limit` | 48 rows for this owner, or 128 in total. |
| `not_owner` | The token is unknown or belongs to another owner. |
| `option_not_found` | `Unregister` on an unknown token. |
| `invalid_patch` | `patch` is not a table, or changes `id`. |
| `invalid_tokens` | `tokens` is not a list of 1–32. |
| `expected_boolean` | `SetEnabled` / `SetTargetingEnabled` value is not a boolean. |
