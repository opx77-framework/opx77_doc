---
title: opx77_prompts configuration
description: The seven keys in OPX_PROMPTS_CONFIG — the key-name language, the corner, the offset, the row width, how many rows are drawn, and what makes the strip step aside — and everything that is deliberately not a key.
---

# Configuration

Everything lives in `config.lua`, in the global table `OPX_PROMPTS_CONFIG`. It is
a `client_script`, because this resource has no server half.

**Every value shown on this page is the shipped default.**

```lua
--- @author DemiAutomatic
--- @file config.lua
--- @description Where the key strip sits and what takes it down.
--- @field LOCALE {string} Catalogue for key names and the hold tag: 'en' or 'fr'.
--- @field ANCHOR {string} 'bottom-right', 'bottom-left', 'top-right' or 'top-left'.
--- @field OFFSET {integer} Pixels from the anchored edge's inset, 0..540, 1080-high surface.
--- @field MAX_WIDTH {integer} Widest a row grows, 200..960 pixels at 1920 wide.
--- @field MAX_ROWS {integer} Rows drawn at once across every group, 1..24.
--- @field HIDE_WHEN_CAPTURED {boolean} Step aside while chat, a form or pause has the keyboard.
--- @field FOLLOW_HUD {boolean} Step aside while opx77_hud is toggled off.

OPX_PROMPTS_CONFIG = {
	LOCALE = 'en',
	ANCHOR = 'bottom-right',
	OFFSET = 0,
	MAX_WIDTH = 420,
	MAX_ROWS = 10,
	HIDE_WHEN_CAPTURED = true,
	FOLLOW_HUD = true,
}
```

Every key is read once, at load, into a validated copy no other file bypasses. A
key that is absent takes its default in silence. A key that is present and does
not validate takes its default with one warning in the client log:

```text
config: MAX_ROWS is invalid (40); using 10
```

The three numbers are rounded down to an integer once they pass. A missing
`OPX_PROMPTS_CONFIG` table gives every default and one line saying so.
[`LOCALE`](#locale) is the exception: it is not validated, and never logs.

## LOCALE {#locale}

The catalogue the key names and the hold tag are read from.

```lua
LOCALE = 'en'
```

**Type** `string` — `'en'` or `'fr'` as shipped.

It covers only what this resource draws on its own: the key cap names in
`locales/<code>.lua` (`prompts.key.<NAME>`) and the `HOLD` tag. A caller's labels,
titles and values are drawn exactly as sent, already in the player's language.
Log lines and error codes stay in English.

| Name | `en` | `fr` |
|---|---|---|
| `SPACE` | `SPACE` | `ESPACE` |
| `ENTER`, `RETURN` | `ENTER` | `ENTRÉE` |
| `ESC`, `ESCAPE` | `ESC` | `ÉCHAP` |
| `BACKSPACE` | `BKSP` | `RETOUR` |
| `DELETE` / `INSERT` | `DEL` / `INS` | `SUPPR` / `INSER` |
| `HOME` / `END` | `HOME` / `END` | `DÉBUT` / `FIN` |
| `PAGEUP` / `PAGEDOWN` | `PG UP` / `PG DN` | `PG PRÉC` / `PG SUIV` |
| `CAPSLOCK` | `CAPS` | `VERR MAJ` |
| `TAB` | `TAB` | `TAB` |
| `SHIFT` | `SHIFT` | `MAJ` |
| `CTRL`, `CONTROL` | `CTRL` | `CTRL` |
| `ALT` | `ALT` | `ALT` |
| `MOUSE` | `MOUSE` | `SOURIS` |
| `LMB` / `RMB` / `MMB` | `LMB` / `RMB` / `MMB` | `CLIC G` / `CLIC D` / `CLIC M` |
| `SCROLL` | `SCROLL` | `MOLETTE` |
| the hold tag | `HOLD` | `MAINTENIR` |

A name is looked up upper-cased, so `space` is `SPACE`. `UP`, `DOWN`, `LEFT` and
`RIGHT` are drawn as `↑ ↓ ← →` whatever the language, and any other name is drawn
upper-cased as spelled. A key the player bound to a mapping goes through the same
lookup, so a binding the registry reports as `PAGEUP` is drawn `PG UP`.

An unknown code is accepted, and every lookup then falls back to `en`. A third
language is a `locales/<code>.lua` file calling `OpxPrompts.Locale.register`,
listed in `open77.lua` after `client/locale.lua`.

## ANCHOR {#anchor}

The corner the strip sits in.

```lua
ANCHOR = 'bottom-right'
```

**Type** [`PromptAnchor`](types.md#promptanchor) — `'bottom-right'`,
`'bottom-left'`, `'top-right'` or `'top-left'`.

The strip grows away from that edge, and the highest priority sits nearest it.
The shipped corner is the one no other OPX//77 surface uses — see
[The surface](index.md#surface).

## OFFSET {#offset}

Pixels between the anchored edge's standard inset and the strip, at the
1080-high surface.

```lua
OFFSET = 0
```

**Type** `integer` — 0..540.

!!! info "Raise it when something else uses the corner"
    The game's own weapon read-out lives in the bottom-right corner, and
    `opx77_hud` hides it as shipped. With it back, or with `opx77_notify` toasts
    sent to `bottom_right`, raise `OFFSET` to about 150. A resource cannot read
    another's config, so nothing does it for you.

## MAX_WIDTH {#max-width}

The widest a row grows, in pixels at the 1920-wide surface.

```lua
MAX_WIDTH = 420
```

**Type** `integer` — 200..960.

Each row's plate is only as wide as its own text, up to this width; the strip
never grows past the screen less the standard inset on both sides.

## MAX_ROWS {#max-rows}

How many rows are drawn at once, across every group.

```lua
MAX_ROWS = 10
```

**Type** `integer` — 1..24.

Rows are counted from the highest priority down, so the lowest priority is cut
first, and the last group drawn may lose only its lower rows. A cut row is still
held and comes back when there is room; a row whose key cannot be named does not
count. A caller none of whose groups has a row drawn reads `visible = false`
from [`list`](exports.md#list).

This is not the per-group ceiling: a single group holds at most 8 rows whatever
this says.

## HIDE_WHEN_CAPTURED {#hide-when-captured}

Whether the strip steps aside while another surface has the keyboard.

```lua
HIDE_WHEN_CAPTURED = true
```

**Type** `boolean`

While `Open77.input.isCaptured()` answers `true` — chat, an `opx77_input` form,
the pause menu — the strip is hidden, and it comes back as it was when the
keyboard is released. It is read by the strip's own pass, every 120 ms while a
group is held. Hiding never drops a group.

## FOLLOW_HUD {#follow-hud}

Whether the strip steps aside while `opx77_hud` is toggled off.

```lua
FOLLOW_HUD = true
```

**Type** `boolean`

While a group is held and `opx77_hud` is running, the strip calls `opx77_hud`'s
[`isVisible`](../opx77_hud/exports.md#isvisible) once a second, and hides while
the answer carries `ok = true` and `visible = false`. Any other answer — none, a
failed call, a refusal — leaves the strip drawn. With `opx77_hud` stopped, or this
key `false`, the HUD is never asked.

It is a poll because `opx77_hud` raises no event when its visibility changes. The
cost is up to a second of lag in either direction — see
[Known limits](index.md#limits).

## What is deliberately not a key {#not-configurable}

These are constants in the resource's Lua. They are guard rails, a cadence, or
the surface's place among the others — not decisions an operator would make.

| Constant | Value | What it is |
|---|---|---|
| Rows per group | `8` | `too_many_rows` past it. |
| Caps per row | `6` | `too_many_keys` past it. |
| Groups per owner | `8` | `owner_limit` past it. |
| Groups held at once | `32` | `prompt_limit` past it, across every owner. |
| Priority | `-100..100` | `invalid_priority` outside it. |
| Title / label / value / key name / row id | `32` / `48` / `24` / `16` / `32` | bytes, and characters for the row id. Short on purpose: a label is a few words beside a key, and the strip never wraps a line. |
| Group id / owner / mapping id | `64` | characters of `[%w_:%-%.]`, the platform's own limit on mapping ids. |
| `TICK_MS` / `IDLE_MS` | `120` / `500` | the pass while a group is held, and while none is. |
| `OWNER_SWEEP_MS` | `1000` | how often every owner is re-checked, as a backstop to `onClientResourceStop`. |
| `HUD_POLL_MS` | `1000` | how often `opx77_hud` is asked, while a group is held. |
| `zIndex` | `710` | above `opx77_hud` (705) and `opx77_chat` (700), below `opx77_notify` (720) and every menu. |
| `fps` | `30` | the surface's frame rate. |

The colours are not keys either. They come from `web/open77-ui.css`, the
platform's token file copied unchanged into every WebUI resource, and from the
`:root` block at the top of `web/prompts.css`.
