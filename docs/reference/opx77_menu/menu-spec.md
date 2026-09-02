---
title: The opx77_menu menu spec
description: The table you hand to opx77_menu's open and update exports — every spec field, the eight item kinds and the shape that produces each one, the name rules, and every limit the resource enforces before it will draw anything.
---

# The menu spec

A menu is one table. You hand it to [`open`](exports.md#open), and a patch of
the same shape to [`update`](exports.md#update). Only `items` is required —
everything else has a default that is right for a menu opened by a resource
that has not thought about it yet.

A spec is validated **whole**. Nothing is partially applied, nothing is
truncated to fit, and the first structural problem refuses the entire call with
a code naming what it was. That is deliberate: half of a caller's menu is not
something to guess about.

## The spec {#spec}

```lua
{
  items = { ... },
  id = "myresource.garage",
  title = "GARAGE",
  event = "myresource:garage",
  data = { station = "watson_01" },
  cursor = "take",
  status = "connected",
  closeOnSelect = false,
  steal = false,
}
```

- items: [`MenuItem[]`](types.md#menuitem)
    - The rows of the root screen. Required.
- id?: `string`
    - Unique per owner, and a [valid name](#names). It is echoed as `menu` in
      every payload.
    - Default: your resource's name.
- title?: `string`
    - The heading of the root screen.
    - Default: your resource's name, upper-cased.
- event?: `string`
    - The default event name for every row that does not declare its own. A
      [valid name](#names) of at most 96 characters.
    - Default: none — such rows then reach only the global event
      [`opx77:menu`](events.md#opx77-menu).
- data?: `table`
    - Opaque to the menu. Echoed untouched in every payload as `menuData`.
      Bounded at 64 value nodes and 4 levels of nesting.
    - Default: none.
- cursor?: [`MenuCursor`](types.md#menucursor)
    - Which row the cursor starts on: an item `id`, or a 1-based index.
      **Advisory** — a value that does not resolve to a selectable row falls
      back to the first selectable row rather than refusing the menu. Honoured
      on `open` and on a submenu push; ignored by `update`, because it says
      where a menu *opens*, not where it moves.
    - Default: the first selectable row.
- status?: `string`
    - A transient line written under the list as the menu opens. See
      [`status`](exports.md#status) for its lifetime. A number is accepted;
      anything else refuses the spec with `invalid_status`.
    - Default: none.
- closeOnSelect?: `boolean`
    - Close the menu after any `action` row fires. Has no effect on a toggle, a
      choice list or a slider, none of which raise `select`.
    - Default: `false`
- steal?: `boolean`
    - Take over another resource's open menu, closing theirs with
      `reason = "superseded"`. Without it, an open menu belonging to somebody
      else refuses your `open` with `menu_busy`. Read on `open` only.
    - Default: `false`

## Fields every row shares {#common-fields}

Every non-separator row accepts these, whatever its kind:

- label: `string`
    - The text on the left. Required on every kind except a separator; `text`
      is accepted as an alias. A row with neither is refused with
      `invalid_item_label`.
- id?: `string`
    - A [valid name](#names), unique within its own level. It is what
      [`update`](exports.md#update) re-walks the navigation stack by, so a row
      whose id survives an update keeps the player standing on it.
    - Default: `item_<n>`, where `n` is the row's 1-based position in its level.
- description?: `string`
    - Shown under the list while this row is selected. Truncated to 160
      characters.
    - Default: none.
- disabled?: `boolean`
    - Drawn, dimmed, and never selectable — the cursor skips it. A level of
      nothing but disabled rows is allowed, because *"your garage is empty"* is
      a real menu; a level of nothing but separators is not.
    - Default: `false`
- event?: `string`
    - Overrides the menu's `event` for this row. A [valid name](#names) of at
      most 96 characters.
    - Default: the menu's `event`.
- data?: `table`
    - Opaque to the menu. Echoed untouched in this row's payloads as `data`.
      Bounded at 64 value nodes and 4 levels of nesting. This is where your
      identifiers ride, because [there is no callback](events.md#no-callback).
    - Default: none.
- close?: `boolean`
    - Close the menu after this row fires. It takes effect on an
      [`action`](#kind-action) row only — every other kind returns before it is
      read. On a row with no `event` it does something different: it makes the
      row a [`close`](#kind-close) row instead.
    - Default: `false`

A **separator** ignores all of this except `id` and `label`. It returns from
normalisation before any of the rest is read, so a `description`, an `event`,
a `data` table or a `disabled` flag on a separator is silently dropped rather
than refused.

## How a row's kind is decided {#kinds}

!!! info "The kind is derived from the shape, never declared"

    There is no `kind` field on a `MenuItem`, and adding one would not help.
    The resource decides what a row is from which fields you set, once, at
    build time — and it checks them in a fixed order, so **the first match
    wins**. A row carrying both `toggle` and `choices` is a toggle, and the
    `choices` table is ignored without a word.

| Order | Kind | The shape that produces it |
|---|---|---|
| 1 | [`separator`](#kind-separator) | `separator = true` |
| 2 | [`submenu`](#kind-submenu) | `items = { ... }` |
| 3 | [`toggle`](#kind-toggle) | `toggle = true` or `toggle = false` — a **boolean**, not truthiness |
| 4 | [`choices`](#kind-choices) | `choices = { ... }` |
| 5 | [`slider`](#kind-slider) | `slider = { ... }` |
| 6 | [`back`](#kind-back) | `back = true` |
| 7 | [`close`](#kind-close) | `close = true` **and no `event`** |
| 8 | [`action`](#kind-action) | anything else with a label |

## action {#kind-action}

Fires on `ENTER` and on nothing else, raising a [`select`](events.md#payload)
payload; a row with no `event` and no menu `event` reaches only the global
event.

```lua
{ id = "repair", label = "REPAIR", value = "€$ 250", data = { job = "repair" } }
```

- value?: `string | number`
    - The right-hand text. Truncated to 48 characters. It reads back in the
      payload as `value`, unchanged.
    - Default: none.

`LEFT` pops one level; `RIGHT` does nothing. `close = true` beside an `event`
keeps the row an action that *also* closes — the close-kind test requires the
absence of an `event`.

!!! warning "`close = true` with no `event` is a different row"

    `{ label = "CLOSE", close = true }` is a [`close`](#kind-close) row, not an
    action, **even when the menu declares an `event`**: the test looks only at
    the item's own `event`. It raises no `select` at all. If you want an action
    that closes, give the row an `event` of its own.

## submenu {#kind-submenu}

Descends into a child screen on `ENTER` or `RIGHT`, raising an
[`open`](events.md#payload) payload *after* the push — so `depth` and `index`
in that payload already describe the child.

```lua
{ id = "doors", label = "DOORS", title = "DOORS", cursor = "door_all",
  items = {
    { id = "door_all", label = "ALL", data = { door = -1 } },
    { id = "doors_back", label = "BACK", back = true },
  } }
```

- items: [`MenuItem[]`](types.md#menuitem)
    - The child screen's rows. Its presence is what makes the row a submenu.
- title?: `string`
    - The child screen's heading, and the segment this level contributes to the
      breadcrumb.
    - Default: this row's `label`.
- cursor?: [`MenuCursor`](types.md#menucursor)
    - Where the child screen's cursor starts, resolved each time the screen is
      pushed. Advisory, exactly as on the menu itself.
    - Default: the child's first selectable row.
- value?: `string | number`
    - Right-hand text, drawn beside the descend arrow. Truncated to 48
      characters.
    - Default: none.

`LEFT` and `BACKSPACE` come back up, raising a `back` payload with no `itemId`.
Nesting is capped at 8 levels; a ninth refuses the whole spec with
`menu_too_deep`.

## toggle {#kind-toggle}

Flips a boolean on `ENTER`, `LEFT` or `RIGHT` — all three do the same thing —
raising a [`change`](events.md#payload) payload whose `value` is the
**boolean**, which is never `nil` and may legitimately be `false`.

```lua
{ id = "sirens", label = "SIRENS", toggle = false,
  onLabel = "ARMED", offLabel = "OFF" }
```

- toggle: `boolean`
    - The starting state, and the field whose *type* makes the row a toggle. A
      truthy non-boolean does not produce a toggle; the row falls through to
      the next test.
- onLabel?: `string`
    - What the row reads on the right while true. Truncated to 48 characters.
    - Default: `"ON"`
- offLabel?: `string`
    - What it reads while false.
    - Default: `"OFF"`

A toggle always changes, so it always raises. It never raises `select`, so
`closeOnSelect` does not apply to it.

!!! warning "Read the payload's `value` by presence, not by truthiness"

    A `false` toggle is a legitimate value. The payload assigns `value`
    explicitly for exactly this reason, so branch on `payload.value ~= nil` and
    compare with `== true`, never `if payload.value then`.

## choices {#kind-choices}

Cycles a fixed list on `LEFT` and `RIGHT`, wrapping at both ends, and advances
by one on `ENTER`, raising a [`change`](events.md#payload) payload whose
`value` is the chosen **string**; a list of one never moves and therefore never
raises anything.

```lua
{ id = "plate", label = "PLATE",
  choices = { "CIVILIAN", "CORPO", "NOMAD" }, selected = 2 }
```

- choices: `string[]`
    - The entries, each truncated to 48 characters. Numbers are accepted and
      stringified. An empty list is refused with `empty_choices`; an entry that
      is neither a string nor a number is refused with `invalid_choice`.
- selected?: `integer`
    - Which entry starts current, 1-based. A value outside the list falls back
      to `1` rather than refusing the menu.
    - Default: `1`

It never raises `select`, so `closeOnSelect` does not apply to it.

## slider {#kind-slider}

Steps a number on `LEFT` and `RIGHT`, and once upward on `ENTER`, raising a
[`change`](events.md#payload) payload whose `value` is the **number** — but
only when the value actually moved, so a slider held at its maximum goes quiet.

```lua
{ id = "tint", label = "WINDOW TINT",
  slider = { min = 0, max = 100, step = 10, value = 30, suffix = "%" } }
```

- slider: [`MenuSlider`](types.md#menuslider)
    - `min` (default `0`), `max` (default `100`), `step` (default `1`, taken as
      its absolute value; zero becomes `1`), `value` (default `min`, clamped
      into range) and `suffix` (default none, truncated to 8 characters).
      `max` must be strictly above `min`, or the whole spec is refused with
      `invalid_slider_range`.

The value is **clamped, not wrapped** — a volume that jumps from 0 to 100 is a
complaint, not a feature — and snapped back onto the step grid after every
move, because 0.1 added ten times is not 1.0. On screen a whole number is drawn
without decimals and anything else to two places, then the suffix; in the
payload it is the raw number.

It never raises `select`, so `closeOnSelect` does not apply to it.

## separator {#kind-separator}

Draws a rule, or a section caption when it carries a label, and is never
selectable — the cursor skips straight over it and it raises nothing, ever.

```lua
{ separator = true }
{ separator = true, label = "PERSONAL" }
```

- separator: `boolean`
    - Must be exactly `true`. This is the only kind that does not need a label.

It still counts against the node budget, and it is the one kind that ignores
every shared field except `id` and `label`. A level made of nothing but
separators is refused with `only_separators`, because it would leave the cursor
nowhere to stand.

## back {#kind-back}

Pops one level on `ENTER`, raising a [`back`](events.md#payload) payload that
carries this row's own `itemId` and `label` — and at the root, where there is
nothing to pop, closes the menu with `reason = "back"` instead.

```lua
{ id = "back", label = "BACK", back = true }
```

- back: `boolean`
    - Must be exactly `true`.

This is the explicit row; `LEFT` and `BACKSPACE` pop the same level without one,
but raise a `back` payload with **no** `itemId` and no `label`. That difference
is how a handler tells "the player chose the BACK row" from "the player pressed
back".

## close {#kind-close}

Closes the menu on `ENTER` with `reason = "item"`, raising the
[`close`](events.md#payload) payload and **no `select`**.

```lua
{ id = "exit", label = "CLOSE", close = true }
```

- close: `boolean`
    - Must be exactly `true`, **and the row must declare no `event` of its
      own**. A row with both stays an [`action`](#kind-action) that also closes.

!!! warning "The menu's own `event` does not save you here"

    The close-kind test looks at `item.event`, never at the menu's. Under a
    menu that declares `event = "myresource:garage"`, the row
    `{ label = "CLOSE", close = true }` is still a close row and still raises
    no `select` — your handler sees only the `close` payload with
    `reason = "item"`.

## Names {#names}

Resource names, menu ids, item ids and event names are all validated against
the same rule: non-empty, within its length cap, and matching
`^[%w_:%-%.]+$` — alphanumerics, `_`, `:`, `-` and `.`. Nothing else, and no
spaces.

| What | Cap |
|---|---|
| Calling resource name | 64 characters |
| Menu `id` | 64 characters |
| Item `id` | 64 characters |
| Event name, menu or item | 96 characters |

## Limits {#limits}

!!! danger "Every limit here exists because the host drops oversized events in silence"

    The host discards any event carrying more than **1024 value nodes**, and it
    does so without a word. A caller's `data` table rides in every payload the
    menu raises, and the drawn frame crosses to the WebUI page the same way. A
    menu that quietly stopped answering would be far worse to debug than a menu
    that refused to open, so every one of these is checked up front and refuses
    the whole spec.

| Limit | Value | Applies to |
|---|---|---|
| `MAX_NODES` | 400 | Rows across the **whole tree**, submenus and separators included. Reported back by `open` as `nodes`. |
| `MAX_ROWS` | 200 | Rows on one level. Counted before any row is normalised, so a caller handing over a thousand rows is told immediately. |
| `MAX_DEPTH` | 8 | Nesting levels, root included. |
| `MAX_DATA_NODES` | 64 | Value nodes in one `data` table, keys counted as well as values. |
| `MAX_DATA_DEPTH` | 4 | Levels of nesting inside a `data` table. |
| `MAX_LABEL` | 96 | Characters in a label or a title. |
| `MAX_VALUE` | 48 | Characters in a `value`, a choice entry or a toggle word. |
| `MAX_DESCRIPTION` | 160 | Characters in a description. |
| — | 120 | Characters in the [status line](exports.md#status). |
| — | 8 | Characters in a slider suffix. |

Only the visible window of rows ever reaches the page — `VISIBLE_ROWS` at a
time, with the cursor near the middle except at the two ends — for the same
1024-node reason. A hundred-row list sent whole would be dropped in silence.

## Text is sanitised; structure is refused {#sanitising}

The two are treated differently on purpose.

**Cosmetic text is sanitised, never refused.** Control characters become
spaces and the string is truncated to its cap, counted in characters so a cut
never lands inside a multi-byte one. A label should not lose a menu over a
stray tab someone pasted in.

**Structure is refused, never truncated.** An oversized `data` table, a level
with too many rows, a tree that is too deep: all of them refuse the whole call.
Half of a caller's table is not something to guess about, and a silently
truncated one produces a payload that looks right and is wrong.

## A complete example {#example}

A vehicle panel using seven of the eight kinds.

```lua
-- a client file of your own resource
local MENU = "opx77_menu"
local EVENT = "myresource:vehicle"

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

function OpenVehiclePanel(plate)
  -- A declared dependency would be a hard one, so check instead.
  if GetResourceState(MENU) ~= "running" then return end

  CreateThread(function()
    local _, reason = call("open", {
      id = "myresource.vehicle",
      title = "VEHICLE",
      event = EVENT,
      data = { plate = plate },   -- rides back in every payload as menuData
      cursor = "engine",          -- advisory: falls back to the first selectable row
      status = "connected",
      items = {
        { separator = true, label = "CONTROL" },

        -- toggle: the BOOLEAN type of `toggle` is what makes it one
        { id = "engine", label = "ENGINE", toggle = false,
          onLabel = "RUNNING", offLabel = "OFF",
          description = "LEFT, RIGHT or ENTER to flip" },

        -- choices: LEFT/RIGHT cycle and wrap, ENTER advances
        { id = "livery", label = "LIVERY",
          choices = { "STOCK", "CORPO", "NOMAD" }, selected = 1 },

        -- slider: clamped, and snapped back onto the step grid
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

        -- an action that also closes: `close` beside an `event` stays an action
        { id = "valet", label = "CALL VALET", close = true,
          event = "myresource:valet", data = { plate = plate } },

        -- a close row: `close` with NO event of its own raises no select
        { id = "exit", label = "CLOSE", close = true },
      },
    })
    if reason then Open77.log.warn("panel did not open: " .. tostring(reason)) end
  end)
end
```

The handler that reads the answers back is on [Events](events.md#example).
