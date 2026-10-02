---
title: prompts module
description: The key strip — "press this to do that" rows any module can post, drawn with the player's own key bindings.
---

# prompts

The `prompts` module draws the key strip: short rows such as "E — Open" or "F — Pick up", posted by whichever module has something to offer. A caller posts a group of rows under its own name. The module orders the groups, names every key with the player's current binding, cuts the strip to `MAX_ROWS`, and drops a group when its owner stops. The strip steps aside (without forgetting anything) while another surface holds the keyboard, while the HUD is turned off, and while the player is down. Server modules can post to one player through the server contract.

| | |
|---|---|
| Side | both |
| Optional | `downed`, `hud` |
| Configuration | `config/prompts.lua` (shared script) |
| Contract | `prompts` v1 — server, client |

## Client contract {#client-contract}

`local prompts = OPX.Api.Get('prompts')` on the client, from code inside opx_infinity. Each function answers a Result. None yields.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="client-prompts-show"></a>`Show` | `owner, id, spec` | `{ id, replaced, rows }` | Puts a group up, or replaces the owner's group with that id in place. The spec is validated whole or refused. |
| <a id="client-prompts-update"></a>`Update` | `owner, id, patch` | `{ id }` | Patches a held group. Absent fields keep their value. Error `prompts.notFound`. |
| <a id="client-prompts-hide"></a>`Hide` | `owner, id` | `{ removed }` | Takes one group down. An unknown id answers `removed = false`, not an error. |
| <a id="client-prompts-hideall"></a>`HideAll` | `owner` | `{ removed }` | Takes every group of the owner down. |
| <a id="client-prompts-list"></a>`List` | `owner` | `{ prompts, count, visible }` | The owner's group ids (sorted), and whether any of them was in the last drawn strip. |

`owner` is your module name (1–64 characters of letters, digits, `_ : - .`). It is a label for grouping and expiry, not a security boundary. If it is a module of this runtime or a running resource, its groups are dropped when it stops.

### Spec format {#spec}

| Field | Type | Rule |
|---|---|---|
| `title` | string | Optional, max 32 bytes, no control characters. `false` or `''` = no title. |
| `priority` | integer | Optional, default `0`, `-100`..`100`. Higher draws first; at equal priority the newest group wins. |
| `rows` | table | Required, 1–8 rows. |

Row fields:

| Field | Type | Rule |
|---|---|---|
| `label` | string | Required, max 48 bytes. Your own text (translate it yourself). |
| `keys` | string, table or list | Required. A literal string is split on spaces (`'W A S D'` = four caps). `{ action = 'mapping.id', fallback = 'E' }` is one cap drawn with the player's binding of that key mapping. A list mixes both. Max 6 caps per row. |
| `id` | string | Optional, max 32 characters, unique in the group. Needed to patch with `values`. |
| `value` | string or number | Optional, max 24 bytes. Drawn beside the label. |
| `hold` | boolean | Optional. Sent to the page, but the shipped page no longer draws a hold tag. |
| `combo` | boolean | Optional. The page joins the caps (one combination, not alternatives). |
| `dim` | boolean | Optional. The page draws the row dimmed. |

A row whose key cannot be named (no binding and no `fallback`) is held but not drawn. One owner may hold 8 groups; 32 groups are held at most across all owners.

`patch` for `Update` takes `title`, `priority`, `rows`, or `values` = `{ [rowId] = value }` (`false` clears a value). `rows` and `values` cannot be combined.

```lua
local prompts = OPX.Api.Get('prompts')
prompts.Show('mymodule', 'door', {
  title = 'DOOR',
  rows = { { id = 'open', label = 'Open', keys = { action = 'mymodule.open', fallback = 'E' } } },
})
```

## Server contract {#server-contract}

`local prompts = OPX.Api.Get('prompts')` on the server. Each call only sends a net event to one player; the client validates the spec. The answer says the event was sent, not that the group was accepted.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="server-prompts-show"></a>`Show` | `source, owner, id, spec` | `{ id }` | Sends `opx:net:prompts:show`. |
| <a id="server-prompts-update"></a>`Update` | `source, owner, id, patch` | `{ id }` | Sends `opx:net:prompts:update`. |
| <a id="server-prompts-hide"></a>`Hide` | `source, owner, id` | `{ id }` | Sends `opx:net:prompts:hide`. |
| <a id="server-prompts-hideall"></a>`HideAll` | `source, owner` | `true` | Sends `opx:net:prompts:hideAll`. |

Errors: `prompts.invalidPlayer` (source is not a number), `prompts.invalidOwner`. The server owner is stored on the client as `@server:<owner>`, so it never collides with a client owner. A client cannot see a server module stop: a server module that restarts should call `HideAll` before posting again.

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-net-prompts-show"></a>`opx:net:prompts:show` | server → client | `{ owner, id, spec }` | Server `Show`. |
| <a id="opx-net-prompts-update"></a>`opx:net:prompts:update` | server → client | `{ owner, id, patch }` | Server `Update`. |
| <a id="opx-net-prompts-hide"></a>`opx:net:prompts:hide` | server → client | `{ owner, id }` | Server `Hide`. |
| <a id="opx-net-prompts-hideall"></a>`opx:net:prompts:hideAll` | server → client | `owner` (a string) | Server `HideAll`. |

A malformed server envelope is dropped on the client in silence. The module also listens to `opx:on:downed:changed` and the host event `open77:keybinds:changed` (redraws caps after a rebind).

## Page channels {#page-channels}

On the `overlay` surface.

| Channel | Direction | Payload | Meaning |
|---|---|---|---|
| <a id="page-prompts-ready"></a>`prompts:ready` | page → Lua | `{}` | The page mounted. Lua sends the config and the frame. |
| `prompts:config` | Lua → page | `{ anchor, offset, maxWidth, hold = 'prompts.hold' }` | Layout. The page no longer reads `hold`. |
| `prompts:frame` | Lua → page | `{ groups = { { key, title, rows = { { key, caps, combo, label, value, hold, dim } } } } }` | The whole strip, ordered, cut and with caps already named. |
| `prompts:hide` | Lua → page | `{}` | Take the strip off screen. |

## Configuration {#configuration}

`config/prompts.lua` sets `OPX.Config.MODULES.prompts`. Shared script. `enabled = false` switches the module off. An invalid value is replaced by its default with a warning.

| Key | Default | What it does |
|---|---|---|
| <a id="config-prompts-enabled"></a>`enabled` | `true` | Switches the module on or off. |
| <a id="config-prompts-anchor"></a>`ANCHOR` | `'bottom-right'` | `bottom-right`, `bottom-left`, `top-right` or `top-left`. |
| <a id="config-prompts-offset"></a>`OFFSET` | `0` | Pixels above the anchored edge, 0–540. |
| <a id="config-prompts-max-width"></a>`MAX_WIDTH` | `420` | Widest row in pixels, 200–960. |
| <a id="config-prompts-max-rows"></a>`MAX_ROWS` | `10` | Rows drawn at once across all groups, 1–24. |
| <a id="config-prompts-hide-when-captured"></a>`HIDE_WHEN_CAPTURED` | `true` | Hide while chat, a form or the pause menu holds the keyboard. |
| <a id="config-prompts-follow-hud"></a>`FOLLOW_HUD` | `true` | Hide while `hud.IsVisible()` answers `visible = false`. |
| <a id="config-prompts-tick-ms"></a>`TICK_MS` | `150` | Milliseconds between two passes, 50–1000. |
| <a id="config-prompts-owner-sweep-ms"></a>`OWNER_SWEEP_MS` | `1000` | Milliseconds between two checks that owners still run, 250–10000. |

## Refusal codes {#codes}

All codes start with `prompts.`.

| Code | Meaning |
|---|---|
| `prompts.invalidOwner` / `prompts.invalidId` | Owner or group id is not a valid name. |
| `prompts.invalidPlayer` | Server only: `source` is not a number. |
| `prompts.invalidSpec` / `prompts.invalidPatch` | Spec or patch is not a table. |
| `prompts.invalidTitle` / `prompts.invalidPriority` | Bad title or priority. |
| `prompts.rowsRequired` / `prompts.tooManyRows` | No rows, or more than 8. |
| `prompts.invalidRow` / `prompts.invalidRowId` / `prompts.duplicateRowId` | Bad row, row id, or repeated row id. |
| `prompts.invalidLabel` / `prompts.invalidValue` | Bad label or value. |
| `prompts.invalidHold` / `prompts.invalidCombo` / `prompts.invalidDim` | Not a boolean. |
| `prompts.keysRequired` / `prompts.invalidKey` / `prompts.invalidFallback` / `prompts.tooManyKeys` | Bad `keys` entry, or more than 6 caps. |
| `prompts.invalidValues` / `prompts.rowsAndValues` / `prompts.rowNotFound` | Bad `values` patch. |
| `prompts.ownerLimit` / `prompts.limit` | 8 groups for this owner, or 32 in total. |
| `prompts.notFound` | `Update` on a group the owner does not hold. |
