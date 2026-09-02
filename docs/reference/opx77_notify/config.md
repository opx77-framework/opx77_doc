---
title: opx77_notify configuration
description: The four keys in OPX_NOTIFY_CONFIG — where a toast goes when its definition does not say, how long it lives, whether it draws a lifetime bar, and how wide the stack is — and everything that is deliberately not a key.
---

# Configuration

Everything lives in `config.lua`, in the global table `OPX_NOTIFY_CONFIG`. It is a
`client_script`, because this resource has no server half.

**Every value shown on this page is the shipped default.**

```lua
OPX_NOTIFY_CONFIG = {
  POSITION = "top_right",
  DURATION_MS = 5000,
  PROGRESS = true,
  WIDTH = 340,
}
```

All four are **defaults for a definition that says nothing**. A caller that names
`position`, `durationMs` or `progress` gets exactly what it named; changing a key
here never overrides a caller.

## POSITION {#position}

Where a toast goes when its definition does not say.

```lua
POSITION = "top_right"
```

**Type** [`NotifyPosition`](types.md#notifyposition) — `"top_left"`,
`"top_center"`, `"top_right"`, `"middle_left"`, `"bottom_left"`,
`"bottom_center"` or `"bottom_right"`.

!!! info "This is the one default that departs from the official package"
    `open77_notifications` defaults to `"middle_left"`. This resource defaults to
    the top right, because that is where this framework's other surfaces already
    put transient notices — [`opx77_hud`](../opx77_hud/config.md)'s info column is
    anchored there by default — and a player who has learned to read one corner
    for "something just happened" should not have to learn a second one.

    A caller that names a `position` explicitly still gets the position it named,
    so a resource ported from the official package keeps its own placement.

The set is the platform's and is asymmetric: there is no `middle_right` and no
`middle_center`. Inventing the missing two would hand a caller a position the
official package refuses, so this resource does not. An unrecognised value is
refused with `invalid_position` rather than quietly corrected — a toast in the
wrong corner is a bug an operator would never find.

## DURATION_MS {#duration-ms}

How long a toast lives when its definition does not say, in milliseconds.

```lua
DURATION_MS = 5000
```

**Type** `integer`

`0` is persistent: the toast stays until an [`update`](exports.md#update),
[`dismiss`](exports.md#dismiss) or [`clear`](exports.md#clear) takes it down. Any
other value is a timed lifetime and must be an integer in **750–120000**; a value
outside that range is refused with `invalid_duration`, and so is a value set here.

5000 is the official package's default, and there is no reason to differ.

!!! warning "The clamp is a refusal, not a correction"
    750 ms is the floor because the entrance animation has not finished below it;
    120000 ms is the ceiling because two minutes on screen is a panel, not a toast.
    Neither bound rounds a bad value into range — the call is refused so the caller
    hears about it.

## PROGRESS {#progress}

Whether a timed toast draws its lifetime bar when its definition does not say.

```lua
PROGRESS = true
```

**Type** `boolean`

A persistent toast never draws one whatever this says: there is no lifetime to
draw. The bar's width is the page's own arithmetic against one absolute deadline,
so a frame the browser skips costs no accuracy.

!!! info "`progress` is stricter here than in the official package"
    The official code computes `definition.progress ~= false`, which is a boolean
    by construction, and then checks that boolean is a boolean — so its
    `invalid_progress` can never fire and `progress = "yes"` reads as true. This
    resource refuses anything that is neither absent nor a boolean. It is the one
    rule that is stricter than the package it mirrors, and it is stricter in the
    direction of telling a caller about its bug.

## WIDTH {#width}

The stack's width in pixels, at the 1920-wide surface the page is composited on.

```lua
WIDTH = 340
```

**Type** `integer`

Read by the page as the `--toast-width` custom property, and ignored unless it is
a finite number greater than zero. A long message wraps inside this width rather
than pushing the stack into the middle of the screen; the stack also never exceeds
the viewport less the standard inset on both sides.

## What is deliberately not a key {#not-configurable}

These are constants in the resource's Lua and its stylesheet. They are the
platform's numbers, a cadence, or a guard rail — not decisions an operator would
make.

| Constant | Value | What it is |
|---|---|---|
| `MAX_NOTIFICATIONS` | `32` | The most toasts held at once, across every owner. The platform's documented ceiling. |
| `MAX_PER_POSITION` | `8` | The most in one position; a ninth evicts that position's oldest. Also the platform's. |
| `TICK_MS` | `100` | How often deadlines are checked. |
| `OWNER_SWEEP_MS` | `1000` | How often every owner is re-checked against the host, as a backstop to `onClientResourceStop`. |
| Title / body / icon / id limits | `96` / `384` / `16` / `96` | UTF-8 bytes, and characters for the id. The platform's schema. |
| `MAX_DATA_NODES` / `MAX_DATA_DEPTH` | `64` / `4` | The `data` budget. See [`NotifyDefinition`](types.md#notifydefinition). |
| `zIndex` | `720` | The platform's own number for toasts: above `opx77_hud` (705) and `opx77_chat` (700), below [`opx77_menu`](../opx77_menu/config.md) (725). |
| `fps` | `30` | The surface's frame rate. Nothing here animates per frame except one bar per toast. |

Raising the two ceilings would make this resource behave differently from the
package it stands in for, which is the one thing a drop-in may not do. That is why
they are not keys.

**A locale** is not a key either. There is no `locales/` directory here and no
`LOCALE`, because this resource renders no words of its own: every title, body
and icon it draws was handed to it by the caller, in whatever language that
caller chose. Its error codes are a branching surface rather than text, and its
`Open77.log` lines stay English. Five resources in this set do carry a
catalogue — see
[`opx77_core`'s configuration page](../opx77_core/config.md#satellite-locales).

The four **kind accents** are not keys either. `info`, `success`, `warning` and
`error` are `#22D8E2`, `#4FE3A9`, `#F5C95C` and `#FF5964` — the OPEN//77 signal
tokens, written in two places that must stay in step: `client/state.lua`, which
sends the literal down as `color`, and `web/notify.css`, which holds the same four
as the fallback when a colour fails the page's own `#RRGGBB` check. A caller that
wants a different accent passes `color` per toast.
