---
title: opx77_status configuration
description: Every key in OPX_STATUS_CONFIG — where the effect strip sits, how many chips are drawn before the rest collapse into a counter, and the four gameplay needs this resource owns with their bounds, their decay and the intervals that govern the write path.
---

# Configuration

Everything lives in `config.lua`, in the global table `OPX_STATUS_CONFIG`. It is a
`shared_script`: the client half reads all of it, and the server half reads
[`NEEDS`](#needs) and [`AUTOSAVE_MS`](#autosave-ms) so that both ends clamp a
value to the same bounds.

**Every value shown on this page is the shipped default.**

```lua
OPX_STATUS_CONFIG = {
  ANCHOR = "bottom-left",
  OFFSET = 120,
  MAX_VISIBLE = 6,

  NEEDS_EVENT = "opx77:status:needs",

  NEEDS = {
    hunger = { MIN = 0, MAX = 100, DEFAULT = 100, DECAY_PER_MINUTE = 0.20 },
    thirst = { MIN = 0, MAX = 100, DEFAULT = 100, DECAY_PER_MINUTE = 0.28 },
    stamina = { MIN = 0, MAX = 100, DEFAULT = 100 },
    streetCred = { MIN = 0, MAX = 100000, DEFAULT = 0 },
  },

  DECAY_MS = 60000,
  PUSH_MS = 120000,
  PUSH_DELTA = 5,
  AUTOSAVE_MS = 300000,
}
```

The first three are the strip. Two of them are placement, and this resource reads
them only to hand them on: they travel in every
[`opx77:status:effects`](events.md#status-effects) payload, so
[`opx77_hud`](../opx77_hud/index.md) never has to read another resource's config
file. The rest are the needs.

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
number that is neither negative nor taller than the 1080-pixel surface.

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

This is the one strip key that changes behaviour rather than position. The strip
is [ordered first, then cut](effect-spec.md#ordering): the first `MAX_VISIBLE`
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

## NEEDS_EVENT {#needs-event}

The local event name raised after every change to a need.

```lua
NEEDS_EVENT = "opx77:status:needs"
```

**Type** `string`

Documented in full as [`opx77:status:needs`](events.md#status-needs).

!!! warning "The consumer hard-codes this name"
    `opx77_hud` carries the literal `"opx77:status:needs"` in its own client code,
    because a satellite cannot read another resource's config. Change this key and
    the HUD's gauges stop updating — in silence, with nothing logged at either end.
    Unlike [`ANCHOR`](#anchor) and [`OFFSET`](#offset), this one does **not**
    travel in a payload. There is no reason to change it.

## NEEDS {#needs}

Every gameplay need this resource owns, with its bounds, its value on a new
character and how fast it falls.

```lua
NEEDS = {
  hunger = { MIN = 0, MAX = 100, DEFAULT = 100, DECAY_PER_MINUTE = 0.20 },
  thirst = { MIN = 0, MAX = 100, DEFAULT = 100, DECAY_PER_MINUTE = 0.28 },
  stamina = { MIN = 0, MAX = 100, DEFAULT = 100 },
  streetCred = { MIN = 0, MAX = 100000, DEFAULT = 0 },
}
```

**Type** `table<string, { MIN: number, MAX: number, DEFAULT: number, DECAY_PER_MINUTE?: number }>`

**This table is the whole list.** A key absent from it is refused by
[`setNeeds`](exports.md#setneeds) and [`addNeeds`](exports.md#addneeds) with
`unknown_need`, never appears in a [`needs`](exports.md#needs) answer, and is
dropped from the stored JSON on the next write.

| Field | Does |
|---|---|
| `MIN` / `MAX` | The bounds. Every value is **clamped** into them — on the way in from an export, on the way in from a client push, and on the way out of the database. Out of range is never an error. |
| `DEFAULT` | The value on a new character, and the fallback for anything a payload or a stored row leaves out or gets wrong. |
| `DECAY_PER_MINUTE` | Optional. Subtracted at this rate for as long as a character is loaded. Absent, zero, negative or non-finite means the need does not decay on its own. |

The decay is charged against real elapsed time, not against the number of passes,
so `DECAY_PER_MINUTE = 0.20` on `hunger` costs a character 12 points an hour
whatever [`DECAY_MS`](#decay-ms) is set to.

!!! warning "`ram` is not here, and will not be recognised"
    There used to be a fifth need. It was deleted outright, not moved. A patch
    naming `ram` is `unknown_need`.

!!! warning "Adding a key is not the whole job"
    Adding one here really does make it a need — the exports accept it, it decays
    if you give it a rate, and it is stored in the `needs` JSON column. But
    `types.lua`'s `NeedKey` alias lists the four by name, and `opx77_hud` draws
    only `hunger`, `thirst`, `stamina` and `streetCred`. A fifth need is state that
    nothing on screen shows until you write the surface for it.

!!! warning "`DEFAULT` is not checked against `MIN` and `MAX`"
    A `DEFAULT` outside its own bounds is used as written on a new character and
    on every fallback. Nothing clamps it and nothing logs it. *(Unverified whether
    this is deliberate; the code simply reads the field.)*

## DECAY_MS {#decay-ms}

How often `DECAY_PER_MINUTE` is charged.

```lua
DECAY_MS = 60000
```

**Type** `integer` — milliseconds

Once a minute by default. This is a *granularity*, not a rate: the amount charged
is always proportional to the time that actually passed, so halving this halves
the step size and doubles how often a gauge visibly moves, without changing how
fast a character gets hungry.

The needs loop waits `max(1000, min(DECAY_MS, PUSH_MS, 10000))` between passes, so
setting this below ten seconds does speed the loop up, and setting it above ten
seconds does not slow it down — the loop still has the push and the pull retry to
serve.

## PUSH_MS {#push-ms}

How often the client hands its values to the server half.

```lua
PUSH_MS = 120000
```

**Type** `integer` — milliseconds

Every two minutes by default, and only when something has actually moved since the
last acknowledged push. It is a floor on the *routine* push;
[`PUSH_DELTA`](#push-delta) is what jumps the queue, and this resource stopping
forces one regardless.

!!! warning "The server's rate limit is a real ceiling"
    The server half accepts **12** pushes per player per ten seconds and drops the
    rest without a word. The client counts the drift a dropped push carried and
    sends it again, so nothing is lost — but a `PUSH_MS` low enough to be refused
    is pure traffic, and the values would be no fresher.

## PUSH_DELTA {#push-delta}

A move this large on any one need pushes at once instead of waiting out
[`PUSH_MS`](#push-ms).

```lua
PUSH_DELTA = 5
```

**Type** `number`

The disconnect is the one moment the client cannot speak, so what ends up in the
database is the last push it managed during play. This key is what makes a meal or
a street cred payout reach the server immediately rather than being lost with the
two minutes around it.

It is compared against the largest absolute move on **any** need since the last
acknowledged push, which puts `streetCred` — bounded at `100000`, not `100` — on
the same five-point trigger as `hunger`. Every payout past five cred pushes at
once.

## AUTOSAVE_MS {#autosave-ms}

How often the server half writes the pushes it is holding.

```lua
AUTOSAVE_MS = 300000
```

**Type** `integer` — milliseconds

Read by the **server** half only. Every five minutes it walks the players it holds
a push for and writes each one that has changed since its last write. Nothing is
written on the push itself.

Two other paths write the same held row and do not wait for this interval:
`onPlayerDisconnected`, for the player who has gone, and this resource's own
`onResourceStop`, for everyone still connected. A write that fails on either of
those is logged and the row stays dirty, so the next pass tries again — except on
the disconnect path, where the record is dropped before the write is attempted and
a failure there is not retried.

## What is deliberately not a key {#not-configurable}

These are constants in the resource's Lua. They are cadence, a guard rail and a
rate limit, not decisions an operator would make.

| Constant | Value | Side | What it is |
|---|---|---|---|
| `TICK_MS` | `250` | client | How often deadlines and stopped owners are swept. |
| `OWNER_SWEEP_MS` | `1000` | client | How often every owner is re-checked against the host, as a backstop for a generation that moved without a stop being seen. |
| `MAX_PER_OWNER` | `24` | client | The most effects one resource may hold. See [ownership](exports.md#ownership). |
| `GLOBAL_EVENT` | `"opx77:status"` | client | The event raised beside each effect's own, so one listener can watch them all. |
| `EFFECTS_EVENT` | `"opx77:status:effects"` | client | The name the strip is published on. |
| `MAX_DURATION_MS` | `3600000` | client | One hour, the longest `durationMs` accepted. |
| `MAX_DATA_NODES` / `MAX_DATA_DEPTH` | `64` / `4` | client | The `data` budget. See [the effect spec](effect-spec.md#statusspec). |
| `MAX_LABEL` / `MAX_ICON` / `MAX_EVENT` | `32` / `2` / `96` | client | The lengths a spec's text fields are held to. |
| `PULL_RETRY_MS` | `10000` | client | How long the client waits before asking again for a character the server never answered for. |
| `WINDOW_MS` | `10000` | server | The rate-limit window on both inbound net events. |
| `PULLS_PER_WINDOW` / `PUSHES_PER_WINDOW` | `4` / `12` | server | How many of each that window allows per player. A guard against a flood, not a budget a well-behaved client ever reaches. |
| `MAX_LOGGED` | `64` | server | How much of a value that came off the wire may reach a log line. |

The four wire names — `opx77_status:pull`, `:values`, `:push` and `:pushed` —
are literals in both halves as well. They are listed in the manifest's
`permissions` block as a comment, which is documentation and not a binding.

The tone palette is not configurable here either: the eight
[tones](effect-spec.md#tones) are a fixed list in `client/state.lua` and their
colours are CSS classes in `opx77_hud`'s stylesheet.

There is **no locale catalogue** in this resource, and no `LOCALE` key. There is
no `shared/locale.lua` and no `locales/` directory, and that is deliberate: every
word on the strip is a chip label the calling resource supplied, so that resource
is where it is translated. The only strings this one owns are its `Open77.log`
lines and its error codes, and neither is translated.
