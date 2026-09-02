---
title: opx77_menu configuration
description: The three operator keys in opx77_menu's config.lua — the screen anchor, the strip width and how many rows are drawn at once — and why the keys, the global event name and the timings are deliberately not among them.
---

# Configuration

`opx77_menu` is configured from `config.lua`, which is loaded first by the
manifest and defines one global table:

```lua
OPX_MENU_CONFIG = {
  ANCHOR = "top-left",
  WIDTH = 340,
  VISIBLE_ROWS = 9,
}
```

Three keys, all of them operator concerns. **Every value shown on this page is
the shipped default.** Changing any of them needs a resource restart; the whole
table is read at start and pushed to the surface once, when the page reports
ready.

## ANCHOR {#anchor}

Where the strip sits on screen.

```lua
ANCHOR = "top-left"
```

**Type** `"top-left" | "top-right" | "left" | "right"`

The four positions are chosen rather than free-form: they are the corners and
edges that avoid the platform's own chat band and its notification band. An
unrecognised value falls back to `top-left` on the page rather than leaving the
strip unpositioned.

## WIDTH {#width}

The width of the strip, in pixels.

```lua
WIDTH = 340
```

**Type** `integer`

Measured against the surface, which is a fixed `1920x1080` regardless of the
player's actual resolution, so the strip scales with the display rather than
shrinking on a 4K monitor. Labels are truncated at 96 characters and values at
48 whatever this is set to, so a narrow strip clips text the resource has
already accepted.

## VISIBLE_ROWS {#visible-rows}

How many rows are drawn at once. A longer list scrolls around the cursor.

```lua
VISIBLE_ROWS = 9
```

**Type** `integer`

This is not only cosmetic. Only this many rows ever cross to the WebUI page —
the resource sends a **window**, never the whole list, with the cursor near the
middle of it except at the two ends. A hundred-row list sent whole would be
past the host's 1024-value-node ceiling and would be dropped in silence. See
[Limits](menu-spec.md#limits).

!!! warning "The list is capped at 56% of the viewport height, independently of this key"

    The maximum height the strip may take is a constant in `client/main.lua`,
    not a function of `VISIBLE_ROWS`. Raising this key past roughly a dozen
    rows will clip the list rather than grow it. Raise it, then look at the
    result in game before shipping it.

## What is deliberately not configurable {#not-configurable}

Each of these is an omission with a reason, not an oversight.

**The keys.** `UP`, `DOWN`, `LEFT`, `RIGHT`, `ENTER` and `BACKSPACE` are the
keys everyone already tries on a list, and there is no rebinding to offer:
`Open77.input` has exactly `isDown` and `isCaptured`, and the platform exposes
no key-mapping API at all. A caller printing its own hint should ask the
[`keys`](exports.md#keys) export rather than assume.

**The global event name.** `opx77:menu` is a name, not a setting. A caller that
wants a different one listens on [its own](events.md#your-event) instead, which
costs nothing and does not make one server's payloads unrecognisable on another.

**The status timeout (6 s), the auto-repeat delay (260 ms) and interval
(55 ms), and the owner sweep interval (1 s).** These are cadence, not policy.
They were tuned in game rather than guessed, and exposing them would mostly
produce servers where the menu feels wrong.

**The surface's layer, size and `zIndex`.** The `hud` layer is what stops the
menu from ever taking focus, and `zIndex` 725 is a position in a stack shared
with the platform's chat (700), its toasts (720) and `open77_admin`'s strip
(730). None of the three is a preference.

**A locale.** There is no `locales/` directory here and no `LOCALE` key, where
[`opx77_core`](../opx77_core/index.md) and
[`opx77_elevators`](../opx77_elevators/index.md) both have one. This resource
draws the caller's own text, in whatever language the caller chose; the only
strings it owns are its `Open77.log` lines and its `error` codes, and neither is
ever shown to a player.
