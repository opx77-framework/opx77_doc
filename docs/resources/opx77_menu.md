# opx77_menu

!!! warning "Early development"

    `opx77_menu` is version `0.1.0`. The API, the payload shape and the error
    codes are subject to change without notice. Do not build a production
    resource on the current surface.

## What it is

One resource owns the menu surface. Every other resource opens a menu through a
client export and is told which row the player chose.

It is built for a platform with no cursor. The strip is drawn on the **HUD
layer**, so it is never focused and can never take input from the game; it is
navigated entirely from the arrow keys, `ENTER` and `BACKSPACE`. Because it is
never focused, the resource needs no WebUI permission at all — only the
keyboard:

```lua
resource "opx77_menu"
version "0.1.0"
open77_version ">=0.0.1"
auto_start true

reload_policy "reconnect" -- a generation change needs a clean reconnect

web_ui_page "web/index.html"
web_ui_auto_create false -- client/main.lua creates it, so a failure is one logged line
web_files { "web/**" }

permissions {
  -- `Open77.input.isDown`, `isCaptured` and `registerKeyMapping`. The menu polls
  -- the keyboard and never takes focus, so it needs no webui permission.
  "input.actions",
}
```

The surface itself is created by `client/main.lua`, not by the manifest, so a
creation failure is one logged line rather than a dead resource. It is a
`1920x1080`, transparent, 30 fps HUD surface at `zIndex` **725** — above the
platform's chat (700) and toasts (720), below `open77_admin`'s strip (730).

When creation fails, every export that would draw something answers
`no_surface` instead of pretending to have opened a menu.

## How a caller gets an answer

This is the part that surprises everyone arriving from another framework.

!!! danger "There is no callback channel"

    You cannot pass an `onSelect` function to a menu item. The client runtime
    puts every export through a **codec** — *"arguments and results must be
    serializable"* — and a function does not serialize, so it cannot cross a
    resource boundary. See
    [the client export contract](../index.md#the-client-export-contract).

    The return channel is an **event**, because it is the only channel there
    is. A chosen row raises a local event and the item's `data` table is echoed
    back to you inside the payload. That is where your identifiers ride.

The full round trip: you call the export inside a `CreateThread`, and you
listen on your own event name for the answer.

```lua
local MENU = "opx77_menu"
local EVENT = "myresource:menu"

-- 1. Open. `Open77.exports.call` is asynchronous, so this needs a thread.
CreateThread(function()
  local promise, reason = Open77.exports.call(MENU, "open", {
    id = "myresource.main",
    title = "GARAGE",
    event = EVENT,                       -- the default event for every item
    data = { station = "watson_01" },    -- echoed as `menuData` in every payload
    items = {
      { id = "take", label = "TAKE OUT", data = { plate = "77-XYZ" } },
    },
  })
  if not promise then return Open77.log.warn(reason) end       -- dispatch failure
  local result, callError = promise:await()                    -- resolution failure
  if callError then return Open77.log.warn(callError) end
  if not result.ok then return Open77.log.warn(result.error) end
end)

-- 2. Listen. The payload is a `MenuPayload`; `data` is your own table, untouched.
AddEventHandler(EVENT, function(payload)
  if type(payload) ~= "table" or payload.action ~= "select" then return end
  local data = payload.data
  if type(data) ~= "table" then return end
  print(("row %s of %s, plate %s"):format(payload.itemId, payload.menuData.station, data.plate))
end)
```

Each event is raised on the item's own `event` if it has one, on the menu's
`event` otherwise, and then on the global event `opx77:menu` when that name is
not the one already raised. One listener on `opx77:menu` therefore sees every
menu on the machine. If an item and its menu both declare no event, only the
global one fires.

!!! warning "Your event name is not private"

    The client runtime *does* have a cross-resource event bus. Any resource on
    the player's machine can raise your event name with any payload it likes.
    Validate the payload before acting on it — check `action`, check the type of
    `data` — and do not spawn a thread per message: a client resource is allowed
    1024 tasks, and a loop will empty its budget.

## Exports

All six are **client-side** — the server runtime installs no `exports` at all.
Each answers a `MenuResponse` table and never raises. `error` is a stable code
meant for branching, never for showing to a player.

| Export | Answers | Does |
|---|---|---|
| [`open`](#open) | `MenuOpened` | Open a menu, refusing the spec whole if any row is malformed. |
| [`update`](#update) | `MenuResponse` | Replace the rows of a menu you own, keeping the player's position. |
| [`close`](#close) | `MenuResponse` | Close your own menu. |
| [`state`](#state) | `MenuState` | Whether a menu is open, and whether it is yours. |
| [`status`](#status) | `MenuResponse` | Write a transient line under the list. |
| [`keys`](#keys) | `MenuResponse` | The keys the player actually has. |

Every export reads the caller from `GetInvokingResource()` and
`GetInvokingResourceGeneration()`. Both come from the host, so a caller can
neither claim to be another resource nor outlive its own reload. A call that
does not arrive through the export mechanism answers `export_call_required`.

### `open`

```lua
Open77.exports.call("opx77_menu", "open", spec)  --> MenuOpened
```

| Parameter | Type | |
|---|---|---|
| `spec` | `MenuSpec` | Required. |

On success: `{ ok = true, handle, id, items }` — `handle` is unique for the
life of the client session, `id` is the menu id, and `items` is how many nodes
the whole tree came to.

The spec is refused **whole**; nothing is partially applied and `error` names
where it went wrong.

| Code | Meaning |
|---|---|
| `no_surface` | The WebUI surface never came up. |
| `export_call_required` | Not called through the export mechanism. |
| `spec_must_be_a_table` | `spec` was not a table. |
| `menu_busy` | Another resource has a menu open and you did not pass `steal`. |
| `invalid_owner` | The calling resource name failed validation. |
| `invalid_menu_id` | `spec.id` is not a valid name. |
| `invalid_menu_event` | `spec.event` is not a valid name. |
| `invalid_menu_data` | `spec.data` is not a table. |
| `menu_data_too_large` | `spec.data` exceeds the payload budget. |
| `items_must_be_a_table` | `spec.items` is not a table. |
| `too_many_items` | More than 200 rows on one level. |
| `empty_menu` | A level came out with no rows. |
| `only_separators` | A level holds nothing but separators. |
| `item_must_be_a_table` | A row is not a table. |
| `menu_too_large` | More than 400 nodes across the whole tree. |
| `menu_too_deep` | More than 8 levels. |
| `invalid_item_id` | An `id` is not a valid name. |
| `invalid_item_label` | A non-separator row has no usable label. |
| `invalid_item_event` | An item `event` is not a valid name. |
| `invalid_item_description` | A `description` is not text. |
| `invalid_item_data` | An item `data` is not a table. |
| `item_data_too_large` | An item `data` exceeds the payload budget. |
| `invalid_slider` | `slider` is not a table. |
| `invalid_slider_range` | `max` is not above `min`. |
| `invalid_choices` | `choices` is not a table. |
| `invalid_choice` | An entry in `choices` is not text. |
| `empty_choices` | `choices` came out empty. |

### `update`

```lua
Open77.exports.call("opx77_menu", "update", spec)          --> MenuResponse
Open77.exports.call("opx77_menu", "update", handle, spec)  --> MenuResponse
```

| Parameter | Type | |
|---|---|---|
| `handle` | `MenuHandle` | Optional. Omit for *"my menu, whichever handle it has"*. |
| `spec` | `MenuSpec` | Required. |

Only the fields present in the patch change; `items` is all-or-nothing. The
honoured fields are `items`, `title`, `event`, `data`, `closeOnSelect` and
`status`. `id`, `cursor` and `steal` are ignored — `cursor` says where a menu
*opens*, not where it moves.

The stack is re-walked onto the fresh tree **by id**, so an update does not
throw the player back to the root: a submenu they are standing in stays open if
a row with the same id and the same kind is still there. The cursor is
re-settled rather than clamped, because the update may have disabled the row it
was sitting on.

Errors: `no_surface`, `export_call_required`, `spec_must_be_a_table`,
`no_menu_open`, `not_owner`, `not_open` (the handle is not the open menu's),
plus every structural validation code listed under [`open`](#open) — all of
them except `menu_busy`, `invalid_owner` and `invalid_menu_id`, none of which
apply to a patch.

### `close`

```lua
Open77.exports.call("opx77_menu", "close")          --> MenuResponse
Open77.exports.call("opx77_menu", "close", handle)  --> MenuResponse
```

A caller may not close another resource's menu. The close raises a `close`
payload with `reason = "caller"` before the menu goes.

Errors: `no_surface`, `export_call_required`, `no_menu_open`, `not_owner`,
`not_open`.

### `state`

```lua
Open77.exports.call("opx77_menu", "state")  --> MenuState
```

Never fails and returns no error code: `ok` is always `true`.

When the open menu is **not** yours, the answer is deliberately just
`{ ok = true, open = <boolean>, mine = false }` — what is inside a menu is not
a third resource's business. `mine` is the field to branch on.

When it is yours, the full snapshot arrives: `handle`, `owner`, `menu`,
`title` (the *current screen's* title), `depth`, `index`, `total`, `itemId`,
`label` and `value` for the row under the cursor.

### `status`

```lua
Open77.exports.call("opx77_menu", "status", text, ok)  --> MenuResponse
```

| Parameter | Type | |
|---|---|---|
| `text` | `string`, `number` or `nil` | `nil` clears the line now. |
| `ok` | `boolean` or `nil` | `false` marks a failure, which changes its colour. Default `true`. |

The line sits under the list, is truncated to 120 characters, and clears itself
after **6 seconds**. Clearing is `nil`, never an empty string.

Errors: `no_surface`, `export_call_required`, `no_menu_open`, `not_owner`,
`invalid_status` (a table would sanitise to `nil` and silently *clear* the line,
so it is refused instead).

### `keys`

```lua
Open77.exports.call("opx77_menu", "keys")  --> { ok = true, backend, keys }
```

Never fails. `backend` is `"mappings"`, `"poll"` or `"none"`; `keys` maps each
of the six action names to the key that currently drives it, upper-cased. See
[Keys](#keys_1).

## The menu spec

Only `items` is required.

| Field | Type | Meaning |
|---|---|---|
| `items` | `MenuItem[]` | The rows. Required. |
| `id` | `string` | Unique per owner. Defaults to the owner's resource name. |
| `title` | `string` | Defaults to the owner name, upper-cased. |
| `event` | `string` | The default event for every item. |
| `data` | `table` | Opaque, echoed in every payload as `menuData`. |
| `cursor` | `string` or `integer` | Where the cursor starts: an item `id`, or a 1-based index. Open and submenu push only. |
| `status` | `string` | A transient line under the list, written as the menu opens. |
| `closeOnSelect` | `boolean` | Close after any item fires. Default `false`. |
| `steal` | `boolean` | Take over another resource's open menu. |

`cursor` is **advisory**: a value that does not resolve to a selectable row
falls back to the first selectable row rather than refusing the menu.

## Item kinds

!!! info "The kind is derived from the shape, never declared"

    There is no `kind` field on a `MenuItem`. The resource decides what a row is
    from which fields you set, once, at build time — and it checks them in a
    fixed order, so the first match wins.

The order is: `separator` → `items` → `toggle` → `choices` → `slider` →
`back` → `close` → `action`.

| Kind | The shape that produces it |
|---|---|
| `separator` | `separator = true` |
| `submenu` | `items = { ... }` |
| `toggle` | `toggle = true` or `toggle = false` (a **boolean**, not truthiness) |
| `choices` | `choices = { ... }` |
| `slider` | `slider = { ... }` |
| `back` | `back = true` |
| `close` | `close = true` **and no `event`** |
| `action` | anything else with a label |

Common to every kind: `label` (or `text` as an alias), `id` (defaults to
`item_<n>` within its level), `description` (shown under the list while the row
is selected), `disabled` (drawn, never selectable), `event`, `data` and `close`.

### `action`

```lua
{ id = "repair", label = "REPAIR", value = "€$ 250", data = { job = "repair" } }
```

`ENTER` fires it and nothing else does. `LEFT` pops one level, `RIGHT` does
nothing. It raises `select`, and `value` reads back as the row's own `value`
string.

`close = true` beside an `event` stays an action that also closes — it does
*not* become a `close` row.

### `submenu`

```lua
{ id = "lights", label = "LIGHTING", title = "LIGHTING", items = { ... } }
```

`ENTER` or `RIGHT` descends; `LEFT` or `BACKSPACE` comes back up. It raises
`open` **after** the push, so `depth` and `index` in the payload already
describe the child screen. `title` defaults to the row's label, and `cursor`
says where the child screen's cursor starts. `value` reads back as the row's
own `value` string.

### `toggle`

```lua
{ id = "sirens", label = "SIRENS", toggle = false, onLabel = "ARMED", offLabel = "OFF" }
```

A boolean. `ENTER`, `LEFT` and `RIGHT` all flip it, and each flip raises
`change`. It reads `onLabel` / `offLabel` on screen (default `"ON"` / `"OFF"`)
and `value` in the payload is the **boolean**.

### `choices`

```lua
{ id = "plate", label = "PLATE", choices = { "CIVILIAN", "CORPO", "NOMAD" }, selected = 2 }
```

A fixed list. `LEFT` and `RIGHT` cycle and wrap, `ENTER` advances by one; each
raises `change`. `selected` is 1-based and falls back to `1` when out of range.
A list of one never changes and therefore never raises anything. `value` in the
payload is the chosen **string**.

### `slider`

```lua
{ id = "volume", label = "VOLUME", slider = { min = 0, max = 100, step = 5, value = 70, suffix = "%" } }
```

A number the player steps. `LEFT` and `RIGHT` step by `step`, `ENTER` steps up
once; each raises `change` **only when the value actually moved**. The value
is clamped, not wrapped — a volume that jumps from 0 to 100 is a complaint —
and snapped to the step grid, because 0.1 added ten times is not 1.0.

`min` defaults to `0`, `max` to `100`, `step` to `1` (its absolute value; a
zero or negative step becomes `1`), `value` to `min`, `suffix` to nothing.
`max` must be above `min`. On screen a whole number is drawn without decimals
and anything else to two places, then the suffix. `value` in the payload is the
**number**.

### `separator`

```lua
{ separator = true }
{ separator = true, label = "PERSONAL" }
```

A rule, or a section caption when it carries a label. Never selectable — the
cursor skips it — and it is the one kind that does not need a label. A level
made of nothing but separators is refused with `only_separators`.

### `back`

```lua
{ id = "back", label = "BACK", back = true }
```

`ENTER` pops one level and raises a `back` payload carrying this row's
`itemId` and `label`. At the root there is nothing to pop, so it closes the
menu with `reason = "back"`.

### `close`

```lua
{ id = "exit", label = "CLOSE", close = true }
```

`ENTER` closes the menu with `reason = "item"`. No `select` is raised — only
the `close` payload.

## The payload

Every event this resource raises carries the same shape.

| Field | Type | |
|---|---|---|
| `menu` | `string` | The menu's id. |
| `handle` | `MenuHandle` | |
| `owner` | `string` | The resource that opened it. |
| `action` | `"select"`, `"change"`, `"open"`, `"back"` or `"close"` | |
| `itemId` | `string` or `nil` | `nil` on a menu-level `back` or on `close`. |
| `label` | `string` or `nil` | Same. |
| `index` | `integer` | The cursor's position on the current screen. |
| `depth` | `integer` | 1 at the root. |
| `value` | `any` | Boolean for a toggle, string for a choice, number for a slider, the row's `value` string otherwise. **Absent** when no row is involved. |
| `data` | `table` or `nil` | The item's own `data`, echoed untouched. |
| `menuData` | `table` or `nil` | The menu's `data`. |
| `reason` | `string` or `nil` | On `close` only. |

Which action sets what:

| Action | Raised by | `itemId` / `label` / `value` |
|---|---|---|
| `select` | `ENTER` on an `action` row | set |
| `change` | a `toggle`, `choices` or `slider` that actually moved | set |
| `open` | a submenu pushed by `ENTER` or `RIGHT` | set |
| `back` | `ENTER` on a `back` row | set |
| `back` | `LEFT` or `BACKSPACE` popping a level | **absent** |
| `close` | the menu closing, for any reason | **absent**, plus `reason` |

`reason` is one of `caller` (the `close` export), `select`, `item`, `back`,
`pause` (the player opened the pause menu), `reopened` (the same owner opened
another menu), `superseded` (another owner stole the surface),
`owner_reloaded`, `owner_stopped`, `menu_stopped` (this resource itself
stopped), or `closed`.

!!! tip "Read `value` by presence, not by truthiness"

    A `false` toggle is a legitimate value. The payload assigns `value`
    explicitly for exactly this reason, so test `payload.value ~= nil` rather
    than `if payload.value then`.

## Keys

Six actions, and the key each starts on:

| Action | Default key | Registered as | Shown in the rebinding UI as |
|---|---|---|---|
| `UP` | `UP` | `menu.up` | Menu: move up |
| `DOWN` | `DOWN` | `menu.down` | Menu: move down |
| `LEFT` | `LEFT` | `menu.left` | Menu: back / value down |
| `RIGHT` | `RIGHT` | `menu.right` | Menu: open / value up |
| `SELECT` | `ENTER` | `menu.select` | Menu: select |
| `BACK` | `BACKSPACE` | `menu.back` | Menu: back |

The keys are **not** an operator setting. These are the keys everyone already
tries on a list, and the answer an operator would actually want is the one the
mappings backend already gives: the player rebinds them from **Pause →
Settings → KEY BINDINGS**.

### Two backends

**`mappings`** — the six actions are registered with the engine through
`Open77.input.registerKeyMapping`, both edges, so the engine owns dispatch and
the player can rebind. Registration is all or nothing: a half-registered menu
where `SELECT` works and `BACK` does not is worse than polling, so a single
rejection unregisters the rest and falls through.

**`poll`** — the fallback for a host without key mappings. The keyboard is read
directly with `Open77.input.isDown` on the fixed keys above, and nothing can be
rebound.

**`none`** — neither is available, which means the manifest did not grant
`input.actions`. This is logged as an error and the menu cannot be driven.

The backend is picked once, at resource start, and logged.

!!! tip "Print the keys you were given, not the keys you assumed"

    Under the `mappings` backend the player may have rebound anything. A caller
    that prints its own *"press ENTER to confirm"* hint should ask the
    [`keys`](#keys) export what the player actually has, rather than hardcode a
    key name that may be wrong. The resource re-reads its effective keys
    whenever the client raises `open77:keybinds:changed`.

### Feel and courtesy

A held key repeats after **260 ms**, then every **55 ms**.

The menu stands down whenever another surface owns the keyboard — chat's
composer, the pause menu, an operator panel. On every captured tick it also
re-primes its edge state, so a key pressed into chat cannot leak out of it into
the menu. The same priming runs when a menu opens, because a menu is very often
opened by a chat command whose `ENTER` is still down.

`LEFT` and `BACKSPACE` are not quite the same key. Both pop a level, but
`BACKSPACE` at the root closes the menu, and `LEFT` at the root does nothing.
`LEFT` also belongs to the row first: on a `toggle`, `choices` or `slider` it
changes the value instead of popping — decided by the row's **kind**, not by
whether the value moved, so a slider already at its minimum does not
unexpectedly drop the player up a level.

## Ownership and lifetime

**One menu at a time.** A second resource asking to open one is refused with
`menu_busy` unless it passes `steal = true`; the same resource opening a second
menu always replaces its own.

A replaced menu is **closed, not dropped** — the previous owner is entitled to
hear it is gone, and receives a `close` payload with `reason = "reopened"` or
`"superseded"`.

A menu never outlives the code that opened it:

- Every export call records the caller's **generation**. If a caller comes back
  at a different generation, its open menu is closed with
  `reason = "owner_reloaded"`.
- A tick sweeps the open menu once a second, checking that the owner is still
  `running` and still at the generation it opened at. A caller that crashed,
  was stopped or reloaded mid-menu loses its menu within that second, with
  `reason = "owner_stopped"`.
- When `opx77_menu` itself stops, it closes the open menu with
  `reason = "menu_stopped"` while there is still a Lua state to say so.

The manifest declares `reload_policy "reconnect"`: a generation change needs a
clean reconnect rather than a hot swap, because handles, generations and the
registered key mappings all belong to the client session.

!!! note "Treat the menu as optional"

    Nothing forces a caller to hard-depend on this resource. A declared
    dependency is a hard one, so [`opx77_elevators`](opx77_elevators.md) checks
    `GetResourceState("opx77_menu") == "running"` and answers
    `menu_not_running` when it is not — a missing menu costs one logged line
    and leaves its own exports doing exactly what they did before.

## Limits

Every limit exists for one reason: **the host silently drops any event past
1024 value nodes**, and a caller's `data` rides in every payload the menu
raises. A menu that quietly stopped answering would be far worse than a menu
that refused to open.

| Limit | Value | Applies to |
|---|---|---|
| `MAX_NODES` | 400 | Rows across the **whole tree**, submenus included. |
| `MAX_ROWS` | 200 | Rows on one level. Counted before any work is done. |
| `MAX_DEPTH` | 8 | Nesting levels. |
| `MAX_DATA_NODES` | 64 | Value nodes in one `data` table, keys included. |
| `MAX_DATA_DEPTH` | 4 | Nesting inside a `data` table. |
| `MAX_LABEL` | 96 | Characters in a label or title. |
| `MAX_VALUE` | 48 | Characters in a value, a choice or a toggle word. |
| `MAX_DESCRIPTION` | 160 | Characters in a description. |
| — | 120 | Characters in the status line. |
| — | 8 | Characters in a slider suffix. |
| — | 64 | Characters in a resource name, menu id or item id. |
| — | 96 | Characters in an event name. |

Ids and event names must match `^[%w_:%-%.]+$` — alphanumerics, `_`, `:`, `-`
and `.`.

Text and structure are treated differently on purpose. **Cosmetic text is
sanitised, never refused**: control characters become spaces and the string is
truncated, because a label should not lose a menu over a stray tab. **Structure
is refused, never truncated**: an oversized `data` table is rejected outright,
because half a caller's table is not something to guess about.

Only the visible window of rows ever reaches the page — `VISIBLE_ROWS` at a
time, with the cursor near the middle except at the two ends — for the same
1024-node reason. A hundred-row list sent whole would be dropped in silence.

## Configuration

`config.lua` is deliberately small. Three keys, all operator concerns:

```lua
OPX_MENU_CONFIG = {
  ANCHOR = "top-left", -- "top-left" | "top-right" | "left" | "right"
  WIDTH = 340, -- strip width in pixels, at a 1920-wide surface
  VISIBLE_ROWS = 9, -- rows drawn at once; a longer list scrolls around the cursor
}
```

The four anchors are chosen rather than free-form: they are the positions that
avoid the platform's own chat and notification bands. The maximum height the
list may take before it clips follows `VISIBLE_ROWS` in code, rather than being
a fourth key that could disagree with it.

Nothing else is configurable, and that is a decision rather than an omission.
The keys are not, because the `mappings` backend already lets the *player*
rebind them. The global event name `opx77:menu` is not, because a caller that
wants a different name listens on its own. The status timeout and the sweep
interval are cadence, not policy.

## A complete example

A vehicle panel with a submenu, a toggle, a choice list, a slider, a separator
and a way out — plus the handler that reads the payload back.

```lua
local MENU = "opx77_menu"
local EVENT = "myresource:vehicle"

local function call(name, ...)
  local promise, reason = Open77.exports.call(MENU, name, ...)
  if not promise then return nil, reason end
  local result, callError = promise:await()
  if callError then return nil, callError end
  if type(result) ~= "table" or not result.ok then
    return nil, type(result) == "table" and result.error or "no_result"
  end
  return result
end

function OpenVehiclePanel(plate)
  if GetResourceState(MENU) ~= "running" then return end

  CreateThread(function()
    local _, failure = call("open", {
      id = "myresource.vehicle",
      title = "VEHICLE",
      event = EVENT,
      data = { plate = plate },      -- rides back in every payload as `menuData`
      cursor = "engine",             -- advisory: falls back to the first selectable row
      status = "connected",
      items = {
        { separator = true, label = "CONTROL" },

        -- toggle: `toggle` is a boolean, which is what makes it a toggle
        { id = "engine", label = "ENGINE", toggle = false,
          onLabel = "RUNNING", offLabel = "OFF",
          description = "LEFT, RIGHT or ENTER to flip" },

        -- choices: LEFT/RIGHT cycle, ENTER advances
        { id = "livery", label = "LIVERY", choices = { "STOCK", "CORPO", "NOMAD" },
          selected = 1 },

        -- slider: clamped and snapped to the step grid
        { id = "tint", label = "WINDOW TINT",
          slider = { min = 0, max = 100, step = 10, value = 30, suffix = "%" } },

        { separator = true },

        -- submenu: the presence of `items` is what makes it one
        { id = "doors", label = "DOORS", title = "DOORS", cursor = "door_all",
          items = {
            { id = "door_all", label = "ALL", data = { door = -1 } },
            { id = "door_hood", label = "HOOD", data = { door = 4 } },
            { id = "door_trunk", label = "TRUNK", data = { door = 5 },
              disabled = true, value = "welded shut" },
            { id = "doors_back", label = "BACK", back = true },
          } },

        -- action that also closes: `close` beside an `event` stays an action
        { id = "valet", label = "CALL VALET", close = true,
          event = "myresource:valet", data = { plate = plate } },

        { id = "exit", label = "CLOSE", close = true },
      },
    })
    if failure then Open77.log.warn("panel did not open: " .. tostring(failure)) end
  end)
end

AddEventHandler(EVENT, function(payload)
  -- Any resource on this machine can raise this name. Check before acting.
  if type(payload) ~= "table" then return end
  local plate = type(payload.menuData) == "table" and payload.menuData.plate or nil

  if payload.action == "change" then
    if payload.itemId == "engine" then
      -- A false toggle is a real value: test presence, never truthiness.
      SetVehicleEngine(plate, payload.value == true)
    elseif payload.itemId == "livery" then
      SetVehicleLivery(plate, payload.value)          -- the chosen string
    elseif payload.itemId == "tint" then
      SetVehicleTint(plate, payload.value)            -- the number
    end
    return
  end

  if payload.action == "select" and type(payload.data) == "table" then
    local ok, why = OpenDoor(plate, payload.data.door)
    -- Best-effort: the menu may already be gone, which answers `no_menu_open`.
    CreateThread(function() call("status", ok and "done" or why, ok) end)
    return
  end

  if payload.action == "close" then
    print("panel gone: " .. tostring(payload.reason))
  end
end)
```

## See also

- [`opx77_core`](opx77_core.md) — the framework the menu's callers usually read
  their state from.
- [`opx77_elevators`](opx77_elevators.md) — a real caller: it owns no surface of
  its own and draws its floor panel entirely through this resource.
