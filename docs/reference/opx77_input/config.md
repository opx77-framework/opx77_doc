---
title: opx77_input configuration
description: The four keys in opx77_input's config.lua — the language, the anchor that ships centred, the width it shares with opx77_menu, and the scrim that ships off — the locale catalogue, and what is deliberately not configurable.
---

# Configuration

`opx77_input` is configured from `config.lua`, loaded first by the manifest,
which defines one global table:

```lua
--- @author DemiAutomatic
--- @file config.lua
--- @description Operator configuration: language, form anchor, strip width and scrim.
--- @field LOCALE {string} Catalogue code in locales/ player-facing text is read from.
--- @field ANCHOR {string} center, top-left, top-right, left or right; unknown means center.
--- @field WIDTH {integer} Strip width in pixels on the 1920-wide surface.
--- @field DIM {boolean} Dim the scene behind an open form.

OPX_INPUT_CONFIG = {
	LOCALE = 'en',
	ANCHOR = 'center',
	WIDTH = 340,
	DIM = false,
}
```

**Every value shown on this page is the shipped default.** `ANCHOR`, `WIDTH`
and `DIM` are pushed to the page once, when it reports ready, so changing one
needs a resource restart.

!!! info "Keep `WIDTH` on `opx77_menu`'s value"

    The form is drawn as [`opx77_menu`](../opx77_menu/config.md)'s strip, and a
    form usually follows a menu — the character roster, then the identity form.
    Both ship at `340` pixels. The anchor differs on purpose: the menu ships
    `top-left`, the form `center`.

## LOCALE {#locale}

Which `locales/<code>.lua` catalogue this resource's own lines are read from.

```lua
LOCALE = 'en'
```

**Type** `string` — `"en"` or `"fr"` as shipped.

An unknown code falls back to `en`, key by key.

Unlike `opx77_menu`, whose only own strings are its five key-prompt labels,
this resource owns lines a player reads — the key line under the fields and the four refusals a
text field answers with — so it carries a catalogue. See [Locales](#locales).

## ANCHOR {#anchor}

Where the strip sits on screen.

```lua
ANCHOR = 'center'
```

**Type** `"center" | "top-left" | "top-right" | "left" | "right"` — `left` and
`right` are mid-height.

`"center"` ships: the form is drawn in the menu's style, but it is a question
the player has to answer before anything else happens, so it sits in the middle
of the screen rather than where a menu does. The other four are the positions of
[`opx77_menu`'s `ANCHOR`](../opx77_menu/config.md#anchor), for a server that
wants the form where the list before it sat. Anything unrecognised falls back to
`center` on the page.

## WIDTH {#width}

The width of the strip, in pixels, at the 1920-wide surface.

```lua
WIDTH = 340
```

**Type** `integer`

`opx77_menu`'s width. A value that is not a positive number leaves the page's
own width in place. A text field's plate grows with what it holds, so a narrow
strip shows less of a long answer rather than cutting it: the answer itself is
bounded by the field's `maxLength`, never by this.

## DIM {#dim}

Whether a scrim is drawn behind the form while it is open.

```lua
DIM = false
```

**Type** `boolean` — only `true` turns it on.

Off as shipped, because `opx77_menu` draws none: the strip is the same panel the
menu is, and a scene dimmed behind one and not the other reads as two UIs.

## Locales {#locales}

`locales/en.lua` and `locales/fr.lua`, both carrying the same nine keys:

| Key | English |
|---|---|
| `input.hint.edit` | `TYPE TO EDIT` |
| `input.hint.spin` | `← → CHANGE` |
| `input.hint.move` | `↑ ↓ FIELD` |
| `input.hint.confirm` | `ENTER CONFIRM` |
| `input.hint.cancel` | `ESC CANCEL` |
| `input.refuse.required` | `This field cannot be left empty.` |
| `input.refuse.format` | `That is not a value this field accepts.` |
| `input.refuse.character` | `That character is not accepted here.` |
| `input.refuse.tooLong` | `This field takes at most {max} characters.` |

The key line is built from the hints for the focused field — `FIELD` only when
there is more than one, `TYPE TO EDIT` on a text field, `CHANGE` on a choice or a
slider — joined with `  ·  `.

Everything a caller sends is rendered as the caller wrote it, and the error codes
are a branching surface rather than text, so neither is translated.

To add a language, copy `locales/en.lua` to `locales/<code>.lua`, change the code
in the `register` call, translate the values, add a
`shared_script "locales/<code>.lua"` line to `open77.lua` beside the others, and
set [`LOCALE`](#locale) to it.

## What is deliberately not configurable {#not-configurable}

**The keys.** They are the ones the menu uses, reported by the page while the
form holds the keyboard; they are not key mappings and cannot be rebound.

**The limits.** Eight fields, 64 options, a 512-character text ceiling: each is
a bound against the host's payload, or the point where a form becomes a list.
See [Limits](form-spec.md#limits).

**The status timeout (6 s) and the owner sweep (1 s).** Cadence, not policy.

**The surface's layer, frame rate and `zIndex`.** `hud` at 728, above
`opx77_menu` (725) and below `open77_admin`'s strip (730), at 60 fps because the
player is typing at it. None of the three is a preference.
