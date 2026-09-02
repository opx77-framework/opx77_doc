---
title: opx77_chat configuration
description: The six keys of OPX_CHAT_CONFIG in opx77_chat/config.lua — where the box sits, how wide it is, how much it keeps, how long lines stay visible, and the two limits on what a player may send.
---

# Configuration

Everything below lives in `opx77_chat/config.lua`. **The value shown in each fence is the
shipped default**, so a key you never touch behaves exactly as written here.

`config.lua` is listed as both a `client_script` and a `server_script`, so both halves read the
same table. The page is sent everything except `RATE_MS`, which is a server rule and has no
meaning in the browser:

```lua
send("chat:config", {
  anchor = Config.ANCHOR,
  width = Config.WIDTH,
  history = Config.HISTORY,
  fadeMs = Config.FADE_MS,
  maxLength = Config.MAX_LENGTH,
})
```

The page validates each value on the way in and keeps its own built-in default for anything
that does not survive: a `WIDTH` that is not a finite number above zero, a `HISTORY` that is
not above zero, a negative `FADE_MS` or a `MAX_LENGTH` that is not above zero are ignored
rather than applied. A wrong value therefore shows up as "the setting did nothing", not as a
broken box.

Changing any of these needs a restart of `opx77_chat`. There is no live reload of the config
table and no tunable declaration.

## ANCHOR {#anchor}

Which corner the box sits in.

```lua
ANCHOR = "bottom-left",
```

**Type** `"bottom-left" | "top-left"`

`"top-left"` is the only alternative; **any other value reads as bottom-left**, because the
page tests for the one string and falls through. The completion list is always drawn above the
input, whichever anchor is in use, so a list growing downward from a box at the bottom of the
screen cannot leave the screen.

## WIDTH {#width}

The width of the box in pixels, measured against the 1920-wide surface rather than against the
player's real resolution.

```lua
WIDTH = 620,
```

**Type** `number`

The surface is created at a fixed 1920×1080 and scaled by the compositor, so this is a
proportion in disguise: 620 is a shade under a third of the screen at any resolution. Ignored
unless it is a finite number above zero.

## HISTORY {#history}

How many lines the log keeps on screen. Older ones fall off the top.

```lua
HISTORY = 60,
```

**Type** `integer`

This is the rendered log, not the recall buffer: ++arrow-up++ walks back through the last **40
lines you typed**, which is a separate list in the page and is not configurable.

## FADE_MS {#fade-ms}

How long a line stays visible once the box is closed.

```lua
FADE_MS = 12000,
```

**Type** `integer` — milliseconds; `0` never fades

Opening the box brings the whole retained log back, and a new message resets the timer for
every line on screen. The log is history, not furniture — a faded line is hidden, not deleted,
and `HISTORY` is what actually drops it.

## MAX_LENGTH {#max-length}

The longest message a player may send.

```lua
MAX_LENGTH = 240,
```

**Type** `integer` — characters

Enforced twice, and the second one is the one that counts. The page sets it as the input's
`maxlength` attribute, which is a convenience; the server also truncates any `chat:submit` to
`MAX_LENGTH` and appends `...`, because everything off the wire is treated as hostile.

!!! warning "It bounds the relay, not what another resource may send"

    `MAX_LENGTH` is applied to player messages arriving on `chat:submit`. A line your own
    resource sends with [`chat:addMessage`](events.md#chat-addmessage) is not truncated by
    anything, and neither is a command's `open77:command:result`. Long lines wrap in the box
    rather than being cut.

## RATE_MS {#rate-ms}

The floor between two messages from the same player.

```lua
RATE_MS = 800,
```

**Type** `integer` — milliseconds

Server-side only. A message that arrives inside the floor is **dropped silently** — the sender
is not told, on purpose: an answer would cost more than the message it refused. The timestamp
is kept per session player id and cleared on `onPlayerDisconnected`.

!!! warning "Commands are not rate limited here"

    `RATE_MS` guards `chat:submit`, the message path. A slash command goes straight to the
    host's dispatcher on `open77:command:execute` and never passes through this resource's
    server half, so it is not affected. If a command of yours needs a floor, put one in your
    own handler — `opx77_weather` floors its two open commands at 2 s per player and leaves
    the ACL-gated ones alone.

## See also {#see-also}

- [Events](events.md) — what each of these limits actually guards.
- [Overview](index.md#limits) — every limit in the resource in one table, including the ones
  that are not configurable.
