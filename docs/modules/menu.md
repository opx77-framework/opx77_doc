---
title: menu module
description: The keyboard-driven list menu that other client modules open through the menu contract, and the spec format it accepts.
---

# menu

The menu module draws one list menu at a time on the player's screen: a titled strip of rows the player moves through with the arrow keys and chooses with Enter. It has no content of its own. Other client modules (admin, elevators, animations, garages, shops…) build a spec, call `Open`, and get a callback for every choice. Use it when a module needs the player to pick from a short list, toggle a setting or step through submenus.

| | |
|---|---|
| Side | client |
| Requires | none |
| Optional | `downed` (no menu opens over a downed player) |
| Configuration | `config/menu.lua` (shared script) |
| Contract | `menu` v1 — client |
| Data | none |

## Client contract {#client-contract}

`local menu = OPX.Api.Get('menu')` on the client, from code inside opx_infinity. Every function answers a Result table: `{ ok = true, value = … }` or `{ ok = false, error = code }`. None of them yields.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="client-menu-open"></a>`Open` | `spec` | `{ handle, id, nodes }` | Opens a menu from a [spec](#the-menu-spec). The spec is refused whole on the first bad field. If another owner's menu is open, answers `menu_busy` unless `spec.steal = true`. The same owner opening again replaces its menu (`close` reason `reopened`). |
| <a id="client-menu-close"></a>`Close` | `handle, reason?` | `true` | Closes the menu. `reason` (max 32 characters) is passed to the `close` callback; default `caller`. |
| <a id="client-menu-update"></a>`Update` | `handle?, patch` | `true` | Rebuilds the open menu and keeps the player's position (submenus stay open while a row with the same `id` still exists). `Update(patch)` without a handle is allowed. Patchable: `items`, `title`, `on`, `data`, `closeOnSelect`, `reportFocus`, `status`, `statusBad`, `cursor`. `items` is all or nothing. Geometry and `focus` are fixed at open. |
| <a id="client-menu-setstatus"></a>`SetStatus` | `handle?, text, bad?` | `true` | Shows `text` (max 120 characters) as a toast, red when `bad` is true. There is no status line under the list any more. |
| <a id="client-menu-state"></a>`State` | — | `{ open = false }` or `{ open, handle, owner, menu, title, depth, index, total, itemId, label, value }` | What is on screen now. |
| <a id="client-menu-keys"></a>`Keys` | — | `{ backend, keys, labels }` | `backend` is `page`, or `none` when no surface exists. `keys` maps `UP DOWN LEFT RIGHT SELECT BACK` to `ARROW UP`… `ENTER`, `BACKSPACE`; `labels` are the locale words. For a caller printing its own key hint. |

### The menu spec {#the-menu-spec}

| Field | Type | Default | Meaning |
|---|---|---|---|
| `owner` | string | required | Your module id. Letters, digits, `_ : - .`, max 64. If it names a module that stops, the menu closes (`owner_stopped`). |
| `on` | function | required | `on(payload)` for every action. See [The action payload](#the-action-payload). |
| `items` | list | required | The rows of the root level. See [Rows](#rows). |
| `id` | string | `owner` | Menu id, echoed as `payload.menu`. |
| `title` | string | `owner` upper-cased | Max 96 characters. |
| `data` | table | — | Echoed as `payload.menuData`. Max 64 value nodes, 4 levels deep. |
| `focus` | string | `none` | `none`: the menu takes no input focus and the player keeps walking; Lua reads the six keys itself. `cursor`: the page gets the mouse. `full`: the page gets keyboard and mouse. `true`/`false` read as `none`. |
| `closable` | boolean | `true` | `false` means Escape does not close it; the owner must call `Close`. |
| `closeOnSelect` | boolean | `false` | Close after any `select`. |
| `reportFocus` | boolean | `false` | Raise a `focus` action each time the cursor lands on a row. |
| `cursor` | string or integer | first selectable row | Row `id` or index to start on. |
| `steal` | boolean | `false` | Replace another owner's open menu. |
| `status`, `statusBad` | string, boolean | — | Shown as a toast at open. |
| `anchor` | string | `ANCHOR` | `top-left`, `top-right`, `left`, `right` or `center`. |
| `width` | integer | `WIDTH` | Pixels, clamped 240..1200. |
| `maxHeight` | integer | `MAX_HEIGHT_VH` | Viewport height %, clamped 20..100. |
| `height` | integer | none | Fixed pixel height, clamped 120..1200. Absent: the rows decide. |
| `rows` | integer | `VISIBLE_ROWS` | Rows drawn at once, clamped 3..24. |

Limits: 200 rows per level, 400 rows across the whole tree, 8 levels deep. Only the visible window of rows is sent to the page.

### Rows {#rows}

A row's kind comes from its shape. The tests run in this order and the first match wins.

| Kind | Shape | Behaviour |
|---|---|---|
| separator | `separator = true`, optional `label` | A divider. Cannot be selected. Other fields are ignored. |
| submenu | `items = { … }`, optional `title`, `value`, `cursor` | Enter or Right opens the level (`open` action). |
| toggle | `toggle = true/false`, optional `onLabel`, `offLabel` | Enter, Left or Right flips it (`change`). `value` is the boolean. |
| choices | `choices = { 'a', 'b' }`, optional `selected` (index) | Left/Right cycles (`change`). `value` is the chosen string. |
| slider | `slider = { min = 0, max = 100, step = 1, value, suffix }` | Left/Right steps and clamps (`change`). `value` is the number. `max` must be above `min`. |
| back | `back = true` | Pops one level, or closes at the root. |
| close | `close = true` and no `act` | Closes the menu (reason `item`). |
| action | anything else | Enter raises `select`. `value` (max 48) is the right-hand text. |

Fields every row may carry:

| Field | Meaning |
|---|---|
| `id` | Row id, echoed as `itemId`. Default `item_<index>`. |
| `label` (or `text`) | Required, max 96 characters. |
| `icon` | A name from `OPX.Glyphs`; an unknown name refuses the spec (`invalid_item_icon`). |
| `description` | Hint shown for the focused row, max 160. |
| `data` | Echoed as `payload.data`. Max 64 nodes, 4 deep. |
| `disabled` | Drawn greyed; the cursor skips it. |
| `act` | `act(payload)`, called before `on` for this row only. |
| `close` | On an action row with `act`: close after it fires. |
| `submenu` | `true` draws the arrow on a row with no `items` of its own (for owners that open one flat screen at a time). It still raises `select`. |

### The action payload {#the-action-payload}

`on(payload)` and the [`opx:on:menu:action`](#opx-on-menu-action) event receive the same table.

| Field | Meaning |
|---|---|
| `menu`, `handle`, `owner` | Which menu. |
| `action` | `select`, `change`, `open`, `back`, `focus` or `close`. |
| `itemId`, `label`, `value`, `data` | The row involved. Absent on `close` and on a `back` from Left/Backspace. |
| `index`, `depth` | Cursor position on the current screen (1-based) and stack depth (1 at the root). |
| `menuData` | The spec's `data`. |
| `reason` | On `close`: `caller` (or your own reason), `select`, `item`, `back`, `dismissed`, `pause`, `reopened`, `superseded`, `owner_stopped`, `player_down`, `stopped`. |
| `repeated` | On `focus`: true when the key is held down. |

```lua
local menu = OPX.Api.Get('menu')
local opened = menu.Open({
  owner = 'mymodule',
  title = 'GARAGE',
  items = {
    { id = 'out', label = 'Take out', icon = 'vehicle' },
    { id = 'lights', label = 'Lights', toggle = false },
    { label = 'Close', close = true },
  },
  on = function(p)
    if p.action == 'select' and p.itemId == 'out' then --[[ ... ]] end
  end,
})
if not opened.ok then print(opened.error) end
```

## Events {#events}

Client-local only: they reach handlers inside opx_infinity's client VM, not other resources.

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-on-menu-action"></a>`opx:on:menu:action` | client local | the [action payload](#the-action-payload) | Raised after the owner's callback for every action on every menu. |
| <a id="opx-on-menu-state"></a>`opx:on:menu:state` | client local | `{ open = boolean }` | A menu opened, or the last one closed. Raised on change only. The HUD listens to it. |

## Page channels {#page-channels}

All on the `interactive` surface. Every payload carries the menu `handle`; a payload with a stale handle is dropped.

| Channel | Direction | Payload | Meaning |
|---|---|---|---|
| <a id="page-menu-key"></a>`menu:key` | page → Lua | `{ handle, key, repeat }` | `key` is `up`, `down`, `left`, `right`, `enter` or `back`. Only sent when the page holds the keyboard (`focus = 'full'`). |
| <a id="page-menu-choose"></a>`menu:choose` | page → Lua | `{ handle, index }` | A row was clicked: move there and activate it. |
| <a id="page-menu-dismiss"></a>`menu:dismiss` | page → Lua | `{ handle }` | Escape on the page; closes with reason `dismissed`. |
| `focus:set` | page → Lua | `{ owner, focus }` | Shared by every view; the menu answers for owner `menu` only. |
| `menu:open` | Lua → page | first frame plus `anchor, width, maxHeight, height, focus, closable` | Re-sent until the page is ready. |
| `menu:frame` | Lua → page | `{ handle, title, trail, rows, first, total, hint }` | The visible window of rows. |
| `menu:close` | Lua → page | `{ handle }` | Take the menu down. |

## Configuration {#configuration}

`config/menu.lua` sets `OPX.Config.MODULES.menu`. Shared script. These are defaults a spec may override per menu.

| Key | Default | What it does |
|---|---|---|
| <a id="config-menu-enabled"></a>`enabled` | `true` | `false` switches the module off; `OPX.Api.Get('menu')` then answers nil. |
| <a id="config-menu-anchor"></a>`ANCHOR` | `'top-left'` | `top-left`, `top-right`, `left`, `right` or `center`. Anything else reads as `top-left`. |
| <a id="config-menu-width"></a>`WIDTH` | `340` | Pixels, clamped 240..1200. |
| <a id="config-menu-max-height-vh"></a>`MAX_HEIGHT_VH` | `56` | Maximum height in viewport %, clamped 20..100. |
| <a id="config-menu-visible-rows"></a>`VISIBLE_ROWS` | `9` | Rows drawn at once, clamped 3..24. |
| <a id="config-menu-status-ms"></a>`STATUS_MS` | `6000` | Not read by the current code: status text is now a toast. |
| <a id="config-menu-while-down"></a>`WHILE_DOWN` | `{ admin = true }` | Owners whose menu may open, and stays open, while the player is down. |

## Refusal codes {#codes}

| Code | Meaning |
|---|---|
| `spec_must_be_a_table` | `spec` is not a table. |
| `invalid_owner` | `owner` missing or not a valid name. |
| `no_surface` | The interactive WebUI surface does not exist. |
| `player_down` | The player is down and the owner is not in `WHILE_DOWN`. |
| `menu_busy` | Another owner's menu is open and `steal` was not set. |
| `callback_required` | `on` is not a function. |
| `invalid_menu_id`, `invalid_status`, `invalid_focus`, `invalid_closable` | That spec field is malformed. |
| `invalid_menu_data`, `menu_data_too_large` | `data` is not a table, or over 64 nodes / 4 levels. |
| `items_must_be_a_table`, `empty_menu`, `only_separators`, `too_many_items` | A level is not a list, is empty, holds only separators, or has more than 200 rows. |
| `menu_too_large`, `menu_too_deep` | More than 400 rows in the tree, or more than 8 levels. |
| `item_must_be_a_table`, `invalid_item_id`, `invalid_item_label`, `invalid_item_description`, `invalid_item_icon` | A row field is malformed. |
| `invalid_item_data`, `item_data_too_large` | A row's `data` is not a table, or too large. |
| `invalid_slider`, `invalid_slider_range` | `slider` is not a table, or `max` is not above `min`. |
| `invalid_choices`, `invalid_choice`, `empty_choices` | `choices` is malformed or empty. |
| `handle_required` | `Close` was called without a handle. |
| `no_menu_open`, `stale_handle` | Nothing is open, or the handle is not the open menu's. |

Locale keys owned here: `menu.key.choose`, `menu.key.select`, `menu.key.change`, `menu.key.back` (the `Keys` labels).
