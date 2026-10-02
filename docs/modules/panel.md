---
title: panel module
description: The mouse-driven drawer with tabs, a searchable item list, buttons, sliders and a confirm dialog, opened by other client modules through the panel contract.
---

# panel

The panel module draws a large mouse-driven drawer: a title, optional tabs, a searchable and paged list of items, rows of buttons, and a confirm dialog. Instead of items, a caller can send sliders, which turns the left side into a category rail with a picture grid (the clothing fitting room uses this). Other client modules open it through the `panel` contract, stream items into it, and get a callback for every click. Use it for lists too long for a [menu](menu.md), such as shop stock or a wardrobe.

| | |
|---|---|
| Side | client |
| Requires | none |
| Optional | `downed` (no panel opens over a downed player) |
| Configuration | `config/panel.lua` (shared script) |
| Contract | `panel` v1 — client |
| Data | none |

## Client contract {#client-contract}

`local panel = OPX.Api.Get('panel')` on the client, from code inside opx_infinity. Every function answers `{ ok = true, value = … }` or `{ ok = false, error = code }`. None yields.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="client-panel-open"></a>`Open` | `spec` | `{ handle, id }` | Opens a panel from a [spec](#the-panel-spec). An unknown field refuses it (`unknown_field`). If another owner's panel is open, answers `panel_busy` unless `spec.steal = true`. |
| <a id="client-panel-close"></a>`Close` | `handle, reason?` | `true` | Closes it; the callback gets `close` with `reason` (default `caller`, max 32 characters). |
| <a id="client-panel-update"></a>`Update` | `handle?, patch` | `true` | Changes any [patchable field](#the-panel-spec). `clearItems = true` empties the item list first. `selected` is merged per tab. |
| <a id="client-panel-append"></a>`Append` | `handle?, items, done?` | `true` | Adds up to 200 [items](#items) per call, 5000 per panel. An item with an existing `id` replaces it. `done = true` ends the loading state. Large batches are split to fit the host's 1024-node payload limit. |
| <a id="client-panel-confirm"></a>`Confirm` | `handle?, question` | `true` | Shows a confirm dialog `{ id, title?, text?, yes?, no? }` (title max 60, text max 240, buttons max 40). `nil` or `false` withdraws it. The answer arrives as a `confirm` action. |
| <a id="client-panel-state"></a>`State` | — | `{ open = false }` or `{ open, handle, owner, id, tab, items, busy, dialog }` | `items` is the item count. |

Messages written before the page is ready are queued (max 256), then sent once it reports ready.

### The panel spec {#the-panel-spec}

Spec-only fields (cannot be patched):

| Field | Type | Meaning |
|---|---|---|
| `owner` | string | Required. Your module id, max 64. Closes with `owner_stopped` if that module stops. |
| `id` | string | Required. Panel id, max 64, echoed as `payload.panel`. |
| `on` | function | Required. `on(payload)` for every action. |
| `hover` | boolean | Report `hover`/`leave` on items. Default `false`. |
| `dismiss` | `'close'` or `'ask'` | Escape on the page: `close` closes; `ask` raises a `dismiss` action and leaves the panel open. Default `close`. |
| `columns` | `1` or `2` | Item columns. Default `COLUMNS`. |
| `steal` | boolean | Replace another owner's panel. |

Patchable fields (allowed in `Open` and `Update`):

| Field | Shape | Meaning |
|---|---|---|
| `eyebrow`, `title`, `subtitle` | string (max 60, 60, 40) | Header text. |
| `intro` | string (max 240) | Paragraph under the header. |
| `tabs` | list of `{ id, label, marked?, disabled? }`, max 12 | Tab strip. |
| `tab` | string | The active tab id. |
| `search` | `true`, string, or `false` | Show the search box (string = initial text). Absent at open = no search box. |
| `summary` | `{ label, value, action? }` | A summary plate; `action` is one button. |
| `actions` | list of buttons, max 4 | The commit row. |
| `tools` | list of buttons, max 8 | Buttons that adjust the view. |
| `groups` | list of buttons, max 8 | Other screens reachable from this one. |
| `sliders` | list of `{ id, label, count, index, value?, disabled? }`, max 12 | Ranges the caller owns. `index` is 0..`count`; 0 means "none". Replaces the item column with the rail. |
| `tiles` | `{ slot, from, entries }` | A window of up to 60 names for the picture grid of slider `slot`, starting at position `from`. |
| `selected` | `{ [tabId] = itemId or false }` | The selected item per tab. |
| `status` | string, or `{ text, kind = 'info'/'error' }` | Status line, max 160. |
| `busy` | boolean | While true, select, slide and button clicks are ignored. |
| `loading` | boolean | Shows the loading label. |
| `labels` | table | Overrides the words `count`, `empty`, `loading`, `search`, `nothing`, `confirmYes`, `confirmNo`. |
| `clearItems` | boolean | `Update` only. |

A button is `{ id, label, icon?, primary?, disabled? }`: `id` max 64, `label` max 40, `icon` a name from `OPX.Glyphs`.

### Items {#items}

| Field | Meaning |
|---|---|
| `id` | Required, max 160 characters, no control characters. |
| `label` | Required, max 80. |
| `tab` | Tab id the item belongs to. |
| `detail` | Second line, max 120. |
| `disabled` | Drawn greyed. |

### The action payload {#the-action-payload}

`on(payload)` and [`opx:on:panel:action`](#opx-on-panel-action) receive `{ panel, handle, owner, action, … }` plus:

| `action` | Extra fields | Raised when |
|---|---|---|
| `select` | `item, tab` | An item was clicked (not while `busy`). The page does not select it itself: send `selected` back. |
| `hover`, `leave` | `item, tab` / none | Pointer over an item, with `hover = true`. |
| `tab` | `tab` | A tab was clicked. |
| `action` | `id` | An `actions`, `tools`, `groups` or summary button was clicked (not while `busy`). |
| `slide` | `id, index, commit` | A slider moved; `commit = false` is a preview, `true` the release. |
| `tiles` | `slot, from` | The grid wants the window starting at `from`. Answer with `Update({ tiles = … })`. |
| `confirm` | `item, value` | The dialog `item` was answered; `value` is true for yes. |
| `dismiss` | none | Escape with `dismiss = 'ask'`. |
| `close` | `reason` | `caller`, `dismissed`, `pause`, `reopened`, `superseded`, `owner_stopped`, `player_down`, `stopped`. |

The pause key closes the panel even when `dismiss = 'ask'`.

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-on-panel-action"></a>`opx:on:panel:action` | client local | the [action payload](#the-action-payload) | Raised after the owner's callback for every action. Reaches only code inside opx_infinity's client VM. |

## Page channels {#page-channels}

All on the `interactive` surface; every payload carries the panel `handle`.

| Channel | Direction | Payload | Meaning |
|---|---|---|---|
| <a id="page-panel-select"></a>`panel:select` | page → Lua | `{ handle, item }` | Item clicked. |
| <a id="page-panel-hover"></a>`panel:hover` | page → Lua | `{ handle, item }` | Pointer on an item. |
| <a id="page-panel-leave"></a>`panel:leave` | page → Lua | `{ handle }` | Pointer left the items. |
| <a id="page-panel-tab"></a>`panel:tab` | page → Lua | `{ handle, tab }` | Tab clicked. |
| <a id="page-panel-slide"></a>`panel:slide` | page → Lua | `{ handle, id, index, commit }` | Slider moved. |
| <a id="page-panel-tiles"></a>`panel:tiles` | page → Lua | `{ handle, slot, from }` | Grid needs the next window. |
| <a id="page-panel-action"></a>`panel:action` | page → Lua | `{ handle, id }` | Button clicked. |
| <a id="page-panel-answer"></a>`panel:answer` | page → Lua | `{ handle, id, value }` | Confirm dialog answered. |
| <a id="page-panel-dismiss"></a>`panel:dismiss` | page → Lua | `{ handle }` | Escape on the page. Ignored while a dialog is up. |
| `focus:set` | page → Lua | `{ owner, focus }` | Shared; the panel answers for owners `panel` and `panel.confirm`. |
| `panel:open`, `panel:update`, `panel:items`, `panel:confirm`, `panel:close` | Lua → page | the parsed view, a patch, `{ handle, items, done }`, a dialog, `{ handle }` | Drawing. |

## Configuration {#configuration}

`config/panel.lua` sets `OPX.Config.MODULES.panel`. Shared script.

| Key | Default | What it does |
|---|---|---|
| <a id="config-panel-enabled"></a>`enabled` | `true` | `false` switches the module off. |
| <a id="config-panel-columns"></a>`COLUMNS` | `2` | Item columns when a spec names none. `1` or `2`. |
| <a id="config-panel-while-down"></a>`WHILE_DOWN` | `{ admin = true }` | Owners whose panel may open, and stays open, while the player is down. |

## Refusal codes {#codes}

| Code | Meaning |
|---|---|
| `spec_must_be_a_table`, `patch_must_be_a_table` | Not a table. |
| `invalid_owner`, `invalid_id`, `callback_required`, `invalid_dismiss` | Spec basics wrong. |
| `unknown_field` | A field the panel does not draw (or `clearItems` in `Open`). |
| `no_surface` | The interactive WebUI surface does not exist. |
| `player_down` | The player is down and the owner is not in `WHILE_DOWN`. |
| `panel_busy` | Another owner's panel is open and `steal` was not set. |
| `invalid_<field>` | That field is malformed: `eyebrow`, `title`, `subtitle`, `intro`, `tabs`, `tab`, `search`, `summary`, `actions`, `tools`, `groups`, `sliders`, `tiles`, `selected`, `status`, `labels`. |
| `invalid_items`, `invalid_item`, `too_many_items` | `Append` list over 200, a bad item, or more than 5000 items in the panel. |
| `invalid_dialog` | `Confirm` question malformed. |
| `handle_required`, `no_panel_open`, `stale_handle` | Nothing open, or an old handle. |
| `payload_too_large`, `payload_refused`, `page_not_ready`, `queue_full` | A message did not reach the page. |

Locale keys owned here: `panel.count`, `panel.empty`, `panel.loading`, `panel.search`, `panel.nothing`, `panel.confirmYes`, `panel.confirmNo`.
