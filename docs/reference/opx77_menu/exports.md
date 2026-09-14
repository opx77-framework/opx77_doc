---
title: opx77_menu exports
description: The six client exports opx77_menu publishes — open, update, close, state, status and keys — with the arguments each takes, the response table each answers and every stable error code each can refuse with.
---

# Exports

`opx77_menu` publishes six exports. All six are **client** exports, because the
client runtime is the only one that has `exports` and `GetInvokingResource`; a
server resource that wants a menu calls these from its own client half. See
[The client export contract](../../concepts/export-contract.md) for the call
shape and the three levels of failure.

| Export | Answers | Does |
|---|---|---|
| [`open`](#open) | [`MenuOpened`](types.md#menuopened) | Opens a menu, refusing the spec whole if any row is malformed. |
| [`update`](#update) | [`MenuResponse`](types.md#menuresponse) | Rebuilds a menu you own from a fresh spec, keeping the player where they are. |
| [`close`](#close) | [`MenuResponse`](types.md#menuresponse) | Closes your own menu. |
| [`state`](#state) | [`MenuState`](types.md#menustate) | Reports whether a menu is open and whether it is yours. |
| [`setStatus`](#setstatus) | [`MenuResponse`](types.md#menuresponse) | Writes the transient line under the list. |
| [`keys`](#keys) | [`MenuKeys`](types.md#menukeys) | Reports the keys that drive the menu, for a caller printing its own hint. |

Every export answers a table and **never raises**. `ok` is always present;
`error` is a stable code meant for branching, never for showing to a player.

Identity is never an argument. Every export reads the caller from
`GetInvokingResource()` and `GetInvokingResourceGeneration()`, both of which
come from the host, so a caller can neither claim to be another resource nor
outlive its own reload. A call that did not arrive through the export mechanism
answers `export_call_required`.

The examples below share this helper, which collapses the three failure levels
into one `nil, reason`:

```lua
local MENU = "opx77_menu"

--- Call an opx77_menu export from inside a CreateThread.
---@return table|nil result, string|nil reason
local function call(name, ...)
  local promise, dispatchError = Open77.exports.call(MENU, name, ...)
  if not promise then return nil, dispatchError end
  local result, callError = promise:await()
  if callError then return nil, callError end
  if type(result) ~= "table" or not result.ok then
    return nil, type(result) == "table" and result.error or "no_result"
  end
  return result
end
```

## open {#open}

Opens a menu and returns its handle, or refuses the spec whole and returns
`ok = false` with a code naming what was wrong — nothing is ever partially
applied.

!!! warning "Opening replaces whatever is on screen"

    There is one menu on the client. Opening yours when you already have one
    closes the old one with `reason = "reopened"`; opening with `steal = true`
    over another resource's closes theirs with `reason = "superseded"`. The
    previous owner is told, but it is told after the fact. The new spec is
    validated *before* the old menu is closed, so a refused spec costs the
    player nothing.

```lua
Open77.exports.call("opx77_menu", "open", spec)
```

- spec: [`MenuSpec`](types.md#menuspec)
    - The menu to build. Only `items` is required; see
      [The menu spec](menu-spec.md#spec).

**Returns** [`MenuOpened`](types.md#menuopened) — on success `handle` (unique
for the life of the client session), `id` (the menu's id, defaulting to your
resource name) and `nodes` (how many nodes the whole tree came to, submenus
included).

**Errors — call and ownership**

| Code | Meaning |
|---|---|
| `no_surface` | The WebUI surface never came up. Nothing can be drawn. |
| `export_call_required` | The call did not arrive through the export mechanism, so the host named no calling resource. |
| `spec_must_be_a_table` | `spec` was not a table. |
| `menu_busy` | Another resource has a menu open and you did not pass `steal = true`. |
| `invalid_owner` | The calling resource's name failed name validation. |

**Errors — structure. The spec is refused whole**

| Code | Meaning |
|---|---|
| `invalid_menu_id` | `spec.id` is not a [valid name](menu-spec.md#names). |
| `invalid_menu_event` | `spec.event` is not a valid name. |
| `invalid_status` | `spec.status` is neither a string, a number nor `nil` — a table would sanitise to `nil` and silently *clear* the line, so it is refused instead. |
| `invalid_menu_data` | `spec.data` is not a table. |
| `menu_data_too_large` | `spec.data` exceeds 64 value nodes or 4 levels of nesting. |
| `items_must_be_a_table` | `spec.items`, or a submenu's `items`, is not a table. |
| `too_many_items` | More than 200 rows on one level. Counted before any row is normalised. |
| `empty_menu` | A level came out with no rows at all. |
| `only_separators` | A level holds nothing but separators. |
| `item_must_be_a_table` | A row is not a table. |
| `menu_too_large` | More than 400 nodes across the whole tree. |
| `menu_too_deep` | More than 8 levels of nesting. |
| `invalid_item_id` | An item `id` is not a valid name. |
| `invalid_item_label` | A non-separator row has no usable `label` or `text`. |
| `invalid_item_event` | An item `event` is not a valid name. |
| `invalid_item_description` | A `description` is neither a string nor a number. |
| `invalid_item_data` | An item `data` is not a table. |
| `item_data_too_large` | An item `data` exceeds 64 value nodes or 4 levels of nesting. |
| `invalid_slider` | `slider` is not a table. |
| `invalid_slider_range` | The slider's `max` is not above its `min`. |
| `invalid_choices` | `choices` is not a table. |
| `invalid_choice` | An entry in `choices` is neither a string nor a number. |
| `empty_choices` | `choices` came out with no entries. |

**Side** `client export` — callable by any client resource through
`Open77.exports.call`. Asynchronous: it answers a promise, and `await` is only
usable inside a `CreateThread`. Not reachable from a server resource, and not
reachable as an event.

### Example {#open-example}

```lua
-- a client file of your own resource
CreateThread(function()
  local opened, reason = call("open", {
    id = "myresource.garage",
    title = "GARAGE",
    event = "myresource:garage",       -- the default event for every row
    data = { station = "watson_01" },  -- echoed as menuData in every payload
    items = {
      { id = "take", label = "TAKE OUT", data = { plate = "77-XYZ" } },
      { id = "exit", label = "CLOSE", close = true },
    },
  })
  if not opened then
    return Open77.log.warn("garage menu refused: " .. tostring(reason))
  end
  Open77.log.info("menu " .. tostring(opened.handle) .. ", " .. tostring(opened.nodes) .. " nodes")
end)
```

## update {#update}

Rebuilds the open menu from a fresh spec while keeping the player where they
are, or returns `ok = false` when no menu is open, the open menu is not yours,
or the new spec is malformed.

Only the fields present in the patch change. The honoured fields are `items`,
`title`, `event`, `data`, `closeOnSelect`, `reportFocus` and `status`; `id`,
`cursor` and `steal` are ignored, because `cursor` says where a menu *opens*,
not where it moves. `items` is all-or-nothing: the whole tree is rebuilt, or the whole call
is refused and the live menu is untouched.

The navigation stack is re-walked onto the fresh tree **by id**, so an update
does not throw the player back to the root — a submenu they are standing in
stays open if a row with the same `id` and the same kind is still there, and
the walk stops at the first level where it is not. The cursor is then
re-*settled* rather than clamped, because the update may have disabled the very
row it was sitting on.

```lua
Open77.exports.call("opx77_menu", "update", spec)
Open77.exports.call("opx77_menu", "update", handle, spec)
```

- handle?: [`MenuHandle`](types.md#menuhandle)
    - Omit for *"my menu, whichever handle it has"*. A handle that is not the
      open menu's is refused with `not_open` rather than silently ignored.
- spec: [`MenuSpec`](types.md#menuspec)
    - A patch, not a replacement. Absent fields keep their current value.

**Returns** [`MenuResponse`](types.md#menuresponse) — `{ ok = true }` and
nothing else on success.

**Errors — call and ownership**

| Code | Meaning |
|---|---|
| `no_surface` | The WebUI surface never came up. Nothing can be drawn. |
| `export_call_required` | The call did not arrive through the export mechanism. |
| `spec_must_be_a_table` | `spec` was not a table. |
| `no_menu_open` | Nothing is on screen. |
| `not_owner` | The open menu belongs to another resource. You may not update it, even with `steal`. |
| `not_open` | You passed a `handle` that is not the open menu's. |

**Errors — structure. The patch is refused whole and the live menu is untouched**

| Code | Meaning |
|---|---|
| `invalid_menu_event` | `spec.event` is not a [valid name](menu-spec.md#names). |
| `invalid_status` | `spec.status` is neither a string, a number nor `nil`, as on [`open`](#open). |
| `invalid_menu_data` | `spec.data` is not a table. |
| `menu_data_too_large` | `spec.data` exceeds 64 value nodes or 4 levels of nesting. |
| `items_must_be_a_table` | `spec.items`, or a submenu's `items`, is not a table. |
| `too_many_items` | More than 200 rows on one level. |
| `empty_menu` | A level came out with no rows at all. |
| `only_separators` | A level holds nothing but separators. |
| `item_must_be_a_table` | A row is not a table. |
| `menu_too_large` | More than 400 nodes across the whole tree. |
| `menu_too_deep` | More than 8 levels of nesting. |
| `invalid_item_id` | An item `id` is not a valid name. |
| `invalid_item_label` | A non-separator row has no usable `label` or `text`. |
| `invalid_item_event` | An item `event` is not a valid name. |
| `invalid_item_description` | A `description` is neither a string nor a number. |
| `invalid_item_data` | An item `data` is not a table. |
| `item_data_too_large` | An item `data` exceeds 64 value nodes or 4 levels of nesting. |
| `invalid_slider` | `slider` is not a table. |
| `invalid_slider_range` | The slider's `max` is not above its `min`. |
| `invalid_choices` | `choices` is not a table. |
| `invalid_choice` | An entry in `choices` is neither a string nor a number. |
| `empty_choices` | `choices` came out with no entries. |

`menu_busy`, `invalid_owner` and `invalid_menu_id` cannot occur here: none of
the three applies to a patch.

**Side** `client export` — callable by any client resource through
`Open77.exports.call`. Asynchronous: it answers a promise, and `await` is only
usable inside a `CreateThread`. Not reachable from a server resource, and not
reachable as an event.

### Example {#update-example}

```lua
-- Re-draw the list after the player took a car out, without losing their place.
CreateThread(function()
  local _, reason = call("update", {
    status = "vehicle released",
    items = buildGarageRows(),   -- same ids where the rows survived
  })
  if reason then Open77.log.warn("garage update refused: " .. tostring(reason)) end
end)
```

## close {#close}

Closes your own menu, or returns `ok = false` when nothing is open or the open
menu belongs to another resource — a caller may never close a menu it did not
open.

The close raises a [`close` payload](events.md#payload) with `reason = "caller"`
before the menu goes, so your own handler still hears about it.

```lua
Open77.exports.call("opx77_menu", "close")
Open77.exports.call("opx77_menu", "close", handle)
```

- handle?: [`MenuHandle`](types.md#menuhandle)
    - Omit for *"my menu, whichever handle it has"*. A handle that is not the
      open menu's is refused with `not_open`.

**Returns** [`MenuResponse`](types.md#menuresponse) — `{ ok = true }` and
nothing else on success.

**Errors**

| Code | Meaning |
|---|---|
| `no_surface` | The WebUI surface never came up. |
| `export_call_required` | The call did not arrive through the export mechanism. |
| `no_menu_open` | Nothing is on screen. |
| `not_owner` | The open menu belongs to another resource. |
| `not_open` | You passed a `handle` that is not the open menu's. |

**Side** `client export` — callable by any client resource through
`Open77.exports.call`. Asynchronous: it answers a promise, and `await` is only
usable inside a `CreateThread`. Not reachable from a server resource, and not
reachable as an event.

### Example {#close-example}

```lua
-- Best-effort teardown: the menu may already be gone, which answers no_menu_open.
CreateThread(function() call("close") end)
```

## state {#state}

Reports whether a menu is open and whether it is yours; it never fails, and
`ok` is always `true`.

When the open menu is **not** yours — or when nothing is open at all — the
answer is deliberately just `{ ok = true, open = <boolean>, mine = false }`.
What is inside another resource's menu is not your business. `mine` is the
field to branch on, never `open`.

When it is yours, the full snapshot arrives: `handle`, `owner`, `menu`, `title`
(the *current screen's* title, not the menu's), `depth`, `index`, `total`,
`itemId`, `label`, and `value` for the row under the cursor.

This is the one export that answers even when the WebUI surface failed: it
draws nothing, so there is nothing for `no_surface` to protect.

```lua
Open77.exports.call("opx77_menu", "state")
```

Takes no arguments.

**Returns** [`MenuState`](types.md#menustate).

**Errors** — none. `state` cannot fail and sets no `error`.

**Side** `client export` — callable by any client resource through
`Open77.exports.call`. Asynchronous: it answers a promise, and `await` is only
usable inside a `CreateThread`. Not reachable from a server resource, and not
reachable as an event.

### Example {#state-example}

```lua
CreateThread(function()
  local snapshot = call("state")
  if not snapshot then return end
  if snapshot.mine then
    Open77.log.info("cursor on " .. tostring(snapshot.itemId) ..
      " (" .. tostring(snapshot.index) .. "/" .. tostring(snapshot.total) .. ")")
  elseif snapshot.open then
    Open77.log.info("somebody else has the surface")
  end
end)
```

## setStatus {#setstatus}

Writes the transient line under the list, or clears it now when `text` is
`nil`; it returns `ok = false` when no menu is open or the open menu is not
yours.

The line is truncated to 120 characters, has its control characters replaced
with spaces, and clears itself after **6 seconds**. Clearing is `nil` —
never an empty string, which sanitises to nothing and is treated the same way.

```lua
Open77.exports.call("opx77_menu", "setStatus", text, ok)
```

- text: `string | number | nil`
    - The line to write. `nil` clears it immediately.
- ok?: `boolean`
    - `false` marks the line as a failure, which changes its colour.
    - Default: `true`

**Returns** [`MenuResponse`](types.md#menuresponse) — `{ ok = true }` and
nothing else on success.

**Errors**

| Code | Meaning |
|---|---|
| `no_surface` | The WebUI surface never came up. |
| `export_call_required` | The call did not arrive through the export mechanism. |
| `no_menu_open` | Nothing is on screen. |
| `not_owner` | The open menu belongs to another resource. |
| `invalid_status` | `text` was neither a string, a number nor `nil` — a table would sanitise to `nil` and silently *clear* the line, so it is refused instead. |

**Side** `client export` — callable by any client resource through
`Open77.exports.call`. Asynchronous: it answers a promise, and `await` is only
usable inside a `CreateThread`. Not reachable from a server resource, and not
reachable as an event.

### Example {#setstatus-example}

```lua
-- Report the outcome of a row the player chose. Best-effort: their ENTER may
-- have closed the menu before this lands, which answers no_menu_open.
CreateThread(function()
  local ok, why = DoTheThing()
  call("setStatus", ok and "done" or why, ok)
end)
```

## keys {#keys}

Reports which keys drive the menu and which backend is reading them; it never
fails, and `ok` is always `true`.

A resource that prints its own *"press ENTER to confirm"* hint should print
what this says rather than hardcode a key name. The six actions are not
rebindable — the platform exposes no key-mapping API — but the backend can be
`"none"`, in which case no key drives anything and a hint would be a lie.

Like [`state`](#state), this answers even when the WebUI surface failed.

```lua
Open77.exports.call("opx77_menu", "keys")
```

Takes no arguments.

**Returns** [`MenuKeys`](types.md#menukeys) — a [`MenuResponse`](types.md#menuresponse)
with two extra fields:

- backend: `"poll" | "none"`
    - `"poll"` — `Open77.input.isDown` answered and the keyboard is being read
      each frame. `"none"` — the keyboard cannot be read at all, which in
      practice means the manifest did not grant `input.actions`.
- keys: `table<string, string>`
    - `UP`, `DOWN`, `LEFT`, `RIGHT`, `SELECT` and `BACK`, each mapped to the
      key that drives it, upper-cased. Empty under the `"none"` backend.

**Errors** — none. `keys` cannot fail and sets no `error`.

**Side** `client export` — callable by any client resource through
`Open77.exports.call`. Asynchronous: it answers a promise, and `await` is only
usable inside a `CreateThread`. Not reachable from a server resource, and not
reachable as an event.

### Example {#keys-example}

```lua
CreateThread(function()
  local result = call("keys")
  if not result or result.backend == "none" then
    return Open77.log.warn("the menu cannot be driven on this client")
  end
  Open77.log.info("press " .. tostring(result.keys.SELECT) .. " to confirm")
end)
```
