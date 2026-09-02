---
title: opx77_status configuration
description: The three keys in OPX_STATUS_CONFIG — where the effect strip sits, how far it clears the HUD's gauges, and how many chips are drawn before the rest collapse into a counter.
---

# Configuration

Everything lives in `config.lua`, in the global table `OPX_STATUS_CONFIG`. It is
a `client_script`, because this resource has no server half.

**Every value shown on this page is the shipped default.**

```lua
OPX_STATUS_CONFIG = {
  ANCHOR = "bottom-left",
  OFFSET = 120,
  MAX_VISIBLE = 6,
}
```

Two of the three are placement, and this resource reads them only to hand them
on. They travel in every [`opx77:status:effects`](events.md#status-effects)
payload, so [`opx77_hud`](../opx77_hud/index.md) never has to read another
resource's config file.

## ANCHOR {#anchor}

Which corner the effect strip sits in.

```lua
ANCHOR = "bottom-left"
```

**Type** `"bottom-left" | "bottom-right" | "top-left" | "top-right"`

Passed through as `anchor` in the published payload. The consumer maps it to a
CSS class and falls back to `bottom-left` on an unrecognised value rather than
raising.

It is independent of [`OPX_HUD_CONFIG.ANCHOR`](../opx77_hud/config.md#anchor).
Setting the two to the same corner is the shipped arrangement and is what
[`OFFSET`](#offset) exists to make readable.

## OFFSET {#offset}

Pixels the strip sits above that corner, to clear the HUD's gauge block.

```lua
OFFSET = 120
```

**Type** `integer`

Passed through as `offset` in the published payload, where it becomes the
`--strip-offset` custom property. Ignored by the page unless it is a finite
number that is not negative.

!!! warning "Nothing coordinates this with the HUD's layout"
    `--strip-offset` is the only thing keeping the strip clear of the gauges. It
    is a number you tune by looking at the screen, not a measurement anything
    computes. Raise [`OPX_HUD_CONFIG.WIDTH`](../opx77_hud/config.md#width), add a
    block to [`BLOCKS`](../opx77_hud/config.md#blocks), or point both resources at
    the same corner, and this value may need moving with it.

## MAX_VISIBLE {#max-visible}

How many chips are drawn at once; everything past that is counted, not drawn.

```lua
MAX_VISIBLE = 6
```

**Type** `integer`

This is the one key that changes behaviour rather than position. The strip is
[ordered first, then cut](effect-spec.md#ordering): the first `MAX_VISIBLE`
effects become chips and the remainder travel as `hidden`, which the consumer
collapses into a single `+3` counter chip.

Because the cut happens after the sort, raising it never changes which chip is
first, and lowering it only ever takes from the bottom — the lowest priority,
oldest effects.

!!! warning "The consumer has a ceiling of its own"
    `opx77_hud` keeps at most **12** chips from one payload, whatever this key
    says, because the event name is on a host-wide bus that any resource can
    raise. Setting `MAX_VISIBLE` above 12 silently loses the excess at the other
    end.

## What is deliberately not a key {#not-configurable}

These are constants in the resource's Lua. They are cadence and a guard rail, not
decisions an operator would make.

| Constant | Value | What it is |
|---|---|---|
| `TICK_MS` | `250` | How often deadlines and stopped owners are swept. |
| `MAX_PER_OWNER` | `24` | The most effects one resource may hold. See [ownership](exports.md#ownership). |
| `GLOBAL_EVENT` | `"opx77:status"` | The event raised beside each effect's own, so one listener can watch them all. |
| `EFFECTS_EVENT` | `"opx77:status:effects"` | The name the strip is published on. |
| `MAX_DURATION_MS` | `3600000` | One hour, the longest `durationMs` accepted. |
| `MAX_DATA_NODES` / `MAX_DATA_DEPTH` | `64` / `4` | The `data` budget. See [the effect spec](effect-spec.md#statusspec). |

The tone palette is **not** configurable here either, despite what the resource's
README says: the eight [tones](effect-spec.md#tones) are a fixed list in
`client/state.lua` and their colours are CSS classes in `opx77_hud`'s stylesheet.
