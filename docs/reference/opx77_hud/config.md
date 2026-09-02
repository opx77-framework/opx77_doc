---
title: opx77_hud configuration
description: The six keys in OPX_HUD_CONFIG that decide where the HUD sits, which blocks it builds and in what order, when a gauge hides itself, and the name of the /hud command.
---

# Configuration

Everything lives in `config.lua`, in the global table `OPX_HUD_CONFIG`. It is a
`shared_script`: the client half reads the layout, the server half reads the
command name.

**Every value shown on this page is the shipped default.**

```lua
OPX_HUD_CONFIG = {
  ANCHOR = "bottom-left",
  WIDTH = 210,
  INFO_ANCHOR = "top-right",
  BLOCKS = { "vitals", "cyber", "needs", "money", "identity" },
  NEEDS_THRESHOLD = 90,
  COMMAND = "hud",
}
```

## ANCHOR {#anchor}

Which corner the segmented gauge block sits in.

```lua
ANCHOR = "bottom-left"
```

**Type** `"bottom-left" | "bottom-right" | "top-left" | "top-right"`

An unrecognised value falls back to `bottom-left` in the page rather than
raising. It reaches the page once, on
[`hud:config`](events.md#hud-config), and is never resent — a change needs a
reconnect, like every other change to this resource.

## WIDTH {#width}

Width of the gauge block, in pixels at a 1920-wide surface.

```lua
WIDTH = 210
```

**Type** `integer`

Ignored by the page unless it is a finite number above zero, in which case it
sets the `--hud-width` custom property. It does not affect the text block, which
sizes itself to its content.

## INFO_ANCHOR {#info-anchor}

Which corner the money, job and street-cred lines sit in.

```lua
INFO_ANCHOR = "top-right"
```

**Type** `"bottom-left" | "bottom-right" | "top-left" | "top-right"`

The same four values as [`ANCHOR`](#anchor), and independent of it. An
unrecognised value falls back to `top-right`.

## BLOCKS {#blocks}

Which row builders run, **in order**; the order is the order rows appear in.

```lua
BLOCKS = { "vitals", "cyber", "needs", "money", "identity" }
```

**Type** `string[]`

| Name | Builds |
|---|---|
| `vitals` | `HP` always, `ARMOR` only above zero. Armour carries no tone — low armour is not the warning low health is. |
| `cyber` | `STAMINA`, and only once something has written `metadata.stamina`. On a bare install this block appends nothing, which is the intended state. |
| `needs` | `FOOD` from `metadata.hunger` and `HYDRATION` from `metadata.thirst`, each skipped when the key is not a finite number. |
| `money` | One text line per money type. `EDDIES` and `BANK` lead in that order; every other **string** key follows, sorted alphabetically. A zero or non-finite amount is not drawn. |
| `identity` | The job line — label, grade name, and the `on` tone while `job.onDuty` is `true` — and `CRED` from `metadata.streetCred` when it is above zero, floored. |

**Removing a name drops that block entirely**; there is no separate enable flag.
A name that matches no builder is ignored rather than raising, so a typo costs
you a block silently.

!!! warning "Money keys that are not strings are dropped"
    A non-string key in `PlayerData.money` is discarded before the sort. Sorting
    mixed types raises, and `:lower()` on a number raises — both inside the single
    thread that keeps this surface repaired, which would leave the HUD frozen on
    its last frame.

## NEEDS_THRESHOLD {#needs-threshold}

The percentage above which a need or stamina gauge hides itself, so a full bar
does not sit on screen saying nothing.

```lua
NEEDS_THRESHOLD = 90
```

**Type** `integer | false`

`false` always shows them. It applies to the `needs` and `cyber` blocks only:
`HP` is always drawn, and `ARMOR` has its own rule (above zero).

## COMMAND {#command}

The chat command that shows and hides the HUD, without its leading slash.

```lua
COMMAND = "hud"
```

**Type** `string | false`

`false` or an empty string registers nothing, offers no chat suggestion, and logs
one informational line at startup. See [Commands](commands.md#no-command). The
value is used verbatim in the usage line the server answers with, so renaming the
command renames it everywhere.

## What is deliberately not a key {#not-configurable}

These are constants in `client/main.lua`. They are cadence, visual detail and a
guard rail — not decisions an operator would make — and changing one means
editing the resource.

| Constant | Value | What it is |
|---|---|---|
| `GAUGE_SEGMENTS` | `10` | How many blocks a gauge is cut into. |
| `POLL_MS` | `5000` | How often the core is re-read as a net under its change events. |
| `TWEEN_MS` | `220` | Sent to the page as `tween` and currently read by nothing there; the animation is a CSS transition. |
| `MAX_CHIPS` | `12` | The most chips kept from one `opx77:status:effects` payload. |

The strip's own corner and offset are **not** here either. They belong to
[`opx77_status`](../opx77_status/config.md), which publishes them with every
payload so this resource never has to read another resource's config.
