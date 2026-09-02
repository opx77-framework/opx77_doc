---
title: opx77_menu types
description: Every shape opx77_menu names — the aliases, the spec and item tables you hand it, the response tables its exports answer with, the payload its events carry, and the internal shapes that never cross the export boundary.
---

# Types

`opx77_menu` ships its annotations in `types.lua`, a `---@meta` file that is
never loaded at runtime. The types below are what those annotations describe.

The first two groups are the ones you write and read. The
[internal shapes](#internal) are documented because they appear in the source
and in log lines, but none of them ever crosses the export boundary and none is
part of the contract.

## MenuHandle {#menuhandle}

An opaque integer identifying one open menu, unique for the life of the client
session and never reused within it.

`Type:` `integer`

It is handed back by [`open`](exports.md#open), carried in every
[payload](events.md#payload), and accepted by
[`update`](exports.md#update) and [`close`](exports.md#close) — where omitting
it means *"my menu, whichever handle it has"* and passing the wrong one is
refused with `not_open` rather than ignored. It does not survive a reconnect,
which is why the manifest declares `reload_policy "reconnect"`.

## MenuAction {#menuaction}

What the player did, on the `action` field of every payload.

`Type:` `"select" | "change" | "open" | "back" | "close"`

See [Which action sets what](events.md#actions) for which fields each one
populates. Branch on this before anything else in a handler.

## MenuKind {#menukind}

What a row *is*, decided once at build time from the shape of the item table.

`Type:` `"action" | "submenu" | "toggle" | "choices" | "slider" | "separator" | "back" | "close"`

There is no `kind` field on a [`MenuItem`](#menuitem) and this alias is never
sent anywhere: it names the eight outcomes of
[the derivation](menu-spec.md#kinds), which is checked in a fixed order so that
the first match wins.

## MenuCursor {#menucursor}

Which row a screen's cursor starts on: an item `id`, or a 1-based index.

`Type:` `string | integer`

**Advisory.** A value that names no row, or names a separator or a disabled
row, falls back to the first selectable row on the screen rather than refusing
the menu. Honoured by [`open`](exports.md#open) and on every push of a
[submenu](menu-spec.md#kind-submenu); ignored by
[`update`](exports.md#update), because it says where a menu *opens*, not where
it moves.

## MenuSpec {#menuspec}

The table you hand to [`open`](exports.md#open), and the patch you hand to
[`update`](exports.md#update). Only `items` is required.

**Fields**

- items: [`MenuItem[]`](#menuitem) — the root screen's rows.
- id?: `string` — unique per owner. Default: your resource name.
- title?: `string` — the root screen's heading. Default: your resource name, upper-cased.
- event?: `string` — the default event name for every row.
- data?: `table` — opaque, echoed in every payload as `menuData`.
- cursor?: [`MenuCursor`](#menucursor) — where the cursor starts. Open and push only.
- status?: `string` — a transient line written as the menu opens.
- closeOnSelect?: `boolean` — close after any `action` row fires. Default: `false`.
- steal?: `boolean` — take over another resource's open menu. Read on `open` only. Default: `false`.

Field-by-field detail, including every default and every limit, is on
[The menu spec](menu-spec.md#spec).

## MenuItem {#menuitem}

One row. Which of these fields you set is what decides the row's
[kind](menu-spec.md#kinds) — there is no `kind` field to set.

**Fields**

Shared by every kind:

- label: `string` — the text on the left. Required except on a separator.
- text?: `string` — accepted as an alias for `label`.
- id?: `string` — unique within its level. Default: `item_<n>`.
- description?: `string` — shown under the list while this row is selected.
- disabled?: `boolean` — drawn, never selectable. Default: `false`.
- event?: `string` — overrides the menu's event for this row.
- data?: `table` — opaque, echoed in this row's payloads as `data`.
- close?: `boolean` — close after this row fires. Effective on an `action` row only.

Kind-deciding, checked in this order:

- separator?: `boolean` — a rule, or a section caption when it carries a label.
- items?: [`MenuItem[]`](#menuitem) — makes the row a submenu.
- title?: `string` — a submenu's own heading. Default: its `label`.
- cursor?: [`MenuCursor`](#menucursor) — where a submenu's cursor starts.
- toggle?: `boolean` — a boolean row. The field's *type* is the test, not its truth.
- onLabel?: `string` — what a true toggle reads. Default: `"ON"`.
- offLabel?: `string` — what a false toggle reads. Default: `"OFF"`.
- choices?: `string[]` — a fixed list.
- selected?: `integer` — which choice is current, 1-based. Default: `1`.
- slider?: [`MenuSlider`](#menuslider) — a number the player steps.
- back?: `boolean` — this row pops one level.
- value?: `string | number` — the right-hand text on an `action` or `submenu` row.

## MenuSlider {#menuslider}

The bounds of a [slider](menu-spec.md#kind-slider) row. Every field is
optional, but `max` must end up strictly above `min` or the whole spec is
refused with `invalid_slider_range`.

**Fields**

- min?: `number` — Default: `0`
- max?: `number` — Default: `100`
- step?: `number` — taken as its absolute value; zero or negative becomes `1`. Default: `1`
- value?: `number` — clamped into range on build. Default: `min`
- suffix?: `string` — drawn after the number, e.g. `"%"`. Truncated to 8 characters. Default: none

The live value is clamped rather than wrapped, and snapped back onto the step
grid after every move.

## MenuPayload {#menupayload}

What every event this resource raises carries. One shape for all five actions;
which fields are populated depends on the action.

**Fields**

- menu: `string` — the menu's `id`.
- handle: [`MenuHandle`](#menuhandle)
- owner: `string` — the resource that opened it, read from the host.
- action: [`MenuAction`](#menuaction)
- itemId?: `string` — absent on a menu-level `back` and on every `close`.
- label?: `string` — absent in the same two cases.
- index: `integer` — the cursor's 1-based position within the current screen's full row list.
- depth: `integer` — `1` at the root.
- value: `any` — boolean, string or number depending on the row's kind. **Absent** when no row is involved.
- data?: `table` — the row's own `data`, echoed untouched.
- menuData?: `table` — the menu's `data`, echoed untouched.
- reason?: `string` — on `close` only. See [Close reasons](events.md#reasons).

!!! warning "Read `value` by presence, not by truthiness"

    A `false` toggle is a legitimate value and `nil` means *no row was
    involved*. Test `payload.value ~= nil`, then compare with `== true`.

## MenuResponse {#menuresponse}

The envelope every export answers. No export ever raises, so this table — or
one of the two that extend it — is always what you get.

**Fields**

- ok: `boolean`
- error?: `string` — a stable code meant for branching, never for showing to a player. Absent when `ok` is `true`.

[`status`](exports.md#status), [`update`](exports.md#update) and
[`close`](exports.md#close) answer this shape exactly.
[`keys`](exports.md#keys) answers it with `backend` and `keys` added.

## MenuOpened {#menuopened}

What [`open`](exports.md#open) answers.

Extends [`MenuResponse`](#menuresponse)

**Fields**

- handle?: [`MenuHandle`](#menuhandle) — the new menu's handle. Absent on failure.
- id?: `string` — the menu's id, which is your resource name unless the spec named one.
- items?: `integer` — how many nodes the whole tree came to, submenus and separators included. Compare it against the 400-node ceiling if you build menus from data.

## MenuState {#menustate}

What [`state`](exports.md#state) answers. It never fails, so `ok` is always
`true` and `error` is never set.

Extends [`MenuResponse`](#menuresponse)

**Fields**

Always present:

- open: `boolean` — whether any menu is on screen.
- mine: `boolean` — whether it belongs to the calling resource. **This is the field to branch on.**

Present only when `mine` is `true` — what is inside another resource's menu is
not your business, so the answer is deliberately truncated otherwise:

- handle?: [`MenuHandle`](#menuhandle)
- owner?: `string`
- menu?: `string` — the menu's id.
- title?: `string` — the **current screen's** title, not the menu's.
- depth?: `integer` — `1` at the root.
- index?: `integer` — the cursor's position within the current screen.
- total?: `integer` — how many rows the current screen has.
- itemId?: `string` — the row under the cursor.
- label?: `string`
- value: `any` — the row under the cursor's current value. Absent when the screen has no row to stand on.

## Internal shapes {#internal}

None of these crosses the export boundary. They are named here because they
appear in `types.lua` and in the source, and a reader following a stack trace
needs to know what they are — not because anything outside `opx77_menu` may
depend on them.

- **`MenuEntry`** — a normalised [`MenuItem`](#menuitem) with its
  [`kind`](#menukind) resolved and its text already sanitised and truncated.
  The tree the resource actually navigates.
- **`MenuFrame`** — one screen on the navigation stack: its `items`, its
  `title`, the `id` of the row that opened it, and the cursor `index`. The
  `id` is what lets [`update`](exports.md#update) re-walk the stack onto a
  freshly built tree and put the player back where they were.
- **`MenuRecord`** — the one open menu: handle, owner, owner generation, id,
  title, event, data, `closeOnSelect`, the built tree, the node count and the
  frame stack.
- **`MenuStatus`** — the transient line: `text`, `ok`, and the millisecond it
  was written at, after which it has six seconds to live.
- **`MenuView`** — one frame as the WebUI page receives it: the title, the
  breadcrumb, a **window** of rows, the window's first index, the total, the
  cursor, the depth, the selected row's description as `hint`, and the status
  line.
- **`MenuRow`** — one drawn row: `label`, `value`, and the flags `arrow`,
  `spin`, `rule`, `off` and `on`. Every flag is `true` or **absent**, never
  `false`: an absent field costs no value node against the host's 1024-node
  ceiling, and the whole frame has to fit under it.
