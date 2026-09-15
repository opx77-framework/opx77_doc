---
title: The opx77_status effect spec
description: Every field of a StatusSpec, the eight tones a chip may take, the three-key ordering rule that decides what survives the visible cut, and how a countdown runs on the page for no traffic at all.
---

# The effect spec

The table you hand to [`addEffect`](exports.md#addeffect), and the shape any
subset of which you hand to [`updateEffect`](exports.md#updateeffect).

## StatusSpec {#statusspec}

`id` and `label` are the only required fields. Every other field is optional, and
an optional field that is `nil` is simply absent — it is never a refusal.

**Fields**

- id: `string`
    - Unique **per owner**, so two resources may both hold `bleeding`. 1–64
      characters, and only letters, digits, `_`, `:`, `-` and `.`.
    - Refused with `missing_id` when `nil`, `invalid_id` otherwise.
- label: `string`
    - The words on the chip. **Cleaned rather than refused**: control characters
      become spaces and the result is cut to 32 characters. A number is accepted
      and stringified.
    - Refused with `invalid_label` when it is any other type, or empty after
      cleaning — including `false`.
- icon?: `string`
    - One or two glyphs, drawn before the label. Cleaned the same way as `label`
      and cut to 2 characters.
    - An unusable value is dropped to `nil`, never refused. There is no icon
      font on a WebUI page, so this is text, not a name.
- tone?: `string`
    - One of the [tones](#tones). Omitting it leaves the chip to whatever the
      HUD draws by default.
    - Refused with `invalid_tone`.
- durationMs?: `integer`
    - How long the effect lives. It removes itself when this elapses and
      [tells you](events.md#opx77-status).
    - A finite number in `1 .. 3600000` (one hour). Refused with
      `invalid_duration` outside that, or when not a number.
    - Absent means the effect stays until somebody takes it down.
- progress?: `number`
    - `0 .. 1`, drawn as a fill across the chip. Out of range is **clamped**, not
      an error.
    - Refused with `invalid_progress` when not a finite number.
    - A `durationMs` on the same effect wins: the page draws the countdown and
      ignores `progress`.
- priority?: `number`
    - Higher sorts first and survives the [`MAX_VISIBLE` cut](#ordering).
    - Anything non-finite falls back to `0` — there is **no error code** for a
      bad priority.
    - Default: `0`
- event?: `string`
    - An event name raised for this effect in addition to the global one. Same
      character rules as `id`, up to 96 characters.
    - Refused with `invalid_event`.
- data?: `table`
    - Opaque to this resource, echoed back in every event payload it raises for
      the effect.
    - Refused with `invalid_data` when not a table, and `data_too_large` past
      **64 nodes** or **4 levels** of nesting.

!!! warning "Why `data` is bounded"
    `data` rides in every event raised for the effect, and the host silently drops
    a payload past 1024 nodes. A budget that refuses at 64 turns a payload that
    would have vanished without a word into an error code you can read. **Keys
    count towards the budget as well as values**, so a flat table of thirty pairs
    is already sixty nodes.

!!! info "Two length rules, and they differ"
    `id` and `event` are **names**, measured with `#value`: their limits of 64 and
    96 are byte counts, and the character class they must match rules out
    multi-byte text anyway.

    `label` and `icon` are **display text**, cleaned by `OpxStatus.Text.Clean` in
    `shared/text.lua`, and their limits of 32 and 2 are counted in **characters**.
    The cut is UTF-8 aware and never lands mid-sequence, so an `icon` of two
    emoji fits and arrives whole. The scan behind it is bounded in bytes at four
    times the character cap, so a run of continuation bytes cannot make it walk
    an arbitrarily long string. This is a change: these two used to be truncated
    with `string.sub` on a byte count, which both refused an emoji and could split
    one.

    Nothing is appended when display text is cut here — no ellipsis — so a long
    label simply stops at 32 characters.

## Tones {#tones}

A tone is a presentation role, or one of 2077's damage types. It reaches the page
as a CSS class and colours the chip's border, icon and progress fill. The complete
list is eight values and anything else is `invalid_tone`:

| Tone | |
|---|---|
| `ok` | presentation roles |
| `warn` | |
| `bad` | |
| `accent` | |
| `bleed` | damage types |
| `burn` | |
| `shock` | |
| `chem` | |

Omitting `tone` is allowed and leaves the chip in the HUD's default colours.

## Ordering {#ordering}

The strip is sorted **once, across every owner**, on three keys in order:

1. **Highest `priority` first**, so the urgent chip is never pushed off the strip
   by the trivial one.
2. Then **most recently started**, so the newest thing to happen sits nearest the
   top of its priority group.
3. Then a stable tie-break on `owner` then `id`.

```lua
table.sort(all, function(a, b)
  if a.priority ~= b.priority then return a.priority > b.priority end
  if a.startedAtMs ~= b.startedAtMs then return a.startedAtMs > b.startedAtMs end
  -- a total order: equal keys would leave the strip reshuffling on `pairs` order
  return a.owner .. "\1" .. a.id < b.owner .. "\1" .. b.id
end)
```

**The third key exists because the first two are not a total order.** Two effects
added in the same tick at the same priority compare equal on both — and the
registry is walked with `pairs`, whose order is not guaranteed between passes.
Without a final tie-break the strip would reshuffle those chips on nothing more
than table iteration order, which reads on screen as chips swapping places by
themselves.

The sort happens **before** the cut. The first
[`MAX_VISIBLE`](config.md#max-visible) effects become chips and everything past
the cut is counted, not drawn; the count travels as `hidden` and the HUD collapses
it into a single `+3` counter chip. Because the cut is second, raising
`MAX_VISIBLE` never changes which chip is first, and lowering it only ever takes
from the bottom — the lowest priority, oldest effects.

!!! warning "Replacing an effect moves it"
    `startedAtMs` is set on every [`addEffect`](exports.md#addeffect), including
    one that
    replaces an id you already hold. A resource that re-adds the same effect every
    tick will drag it to the front of its priority group every tick. Use
    [`updateEffect`](exports.md#updateeffect), which keeps the start time
    whenever the patch
    omits `durationMs`.

## Countdowns {#countdowns}

`durationMs` is a *duration on arrival* and an *absolute deadline* thereafter:

```lua
-- absolute, not remaining: the page counts down from this on its own clock
expiresAtMs = duration and (atMs + math.floor(duration)) or nil,
```

The published chip carries `remainingMs` and `totalMs`, and `opx77_hud`'s page
animates between them itself on a `requestAnimationFrame` loop that stops once no
chip has a deadline left. **Nothing has to be sent per frame, or per second, for a
timer to appear to tick** — a running countdown costs no traffic at all, and
`remainingMs` is deliberately left out of the change signature so a ticking chip
never republishes.

The registry sweeps for deadlines four times a second. An effect whose time is up
is removed and raises [`expired`](events.md#opx77-status).

## The published chip {#published-chip}

What one entry of the `chips` array in
[`opx77:status:effects`](events.md#status-effects) actually contains. This is a
projection of the spec, not the spec: `priority`, `event` and `data` never leave
this resource.

**Fields**

- id: `string` — the effect id **prefixed with its owner**, `"myresource:bleeding"`,
  so two resources can both call an effect `bleeding` and the page can key one DOM
  element per chip.
- label: `string` — the cleaned label.
- icon: `string | nil`
- tone: `string | nil` — one of the [tones](#tones).
- progress: `number | nil` — `0 .. 1`.
- remainingMs: `integer | nil` — milliseconds left at the moment of publication,
  never negative. Absent when the effect has no deadline.
- totalMs: `integer | nil` — the effect's full duration, so the page can draw a
  proportion. Absent when the effect has no deadline.

!!! warning "The chip id is prefixed; the event payload's `status` is not"
    A chip's `id` is `owner:id`. The `status` field in the events raised back to
    you is the **bare** id you passed to [`addEffect`](exports.md#addeffect). They are
    deliberately different, and matching a chip id against your own id will never
    succeed.
